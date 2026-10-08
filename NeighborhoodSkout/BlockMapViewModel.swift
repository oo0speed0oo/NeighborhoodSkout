import SwiftUI
import Combine

class BlockMapViewModel: ObservableObject {

    @Published var streets: [Street] = [] {
        didSet { if !isSaving { saveAll() } }
    }
    @Published var blocks: [Block] = [] {
        didSet { if !isSaving { saveAll() } }
    }
    @Published var csvLoadMessage: String? = nil

    // Template import state
    @Published var isImporting = false
    @Published var importError: String? = nil

    private let sourceURLKey = "nsk_sourceURL"
    private var isSaving     = false
    private var sourceURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: sourceURLKey) else { return nil }
            return URL(fileURLWithPath: path)
        }
        set { UserDefaults.standard.set(newValue?.path, forKey: sourceURLKey) }
    }

    let colorNames = ["purple","teal","coral","pink","blue","green","orange","red"]
    let icons       = ["🏠","🏡","🏘","🏚","🏗","🏢","🏣","🏤"]

    var gridCount: Int { streets.count }

    init() {
        autoLoadOnLaunch()
        // Save whenever the app moves to the background — covers force-quit and suspend
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.forceSave()
        }
    }

    // MARK: - Auto load on launch

    private func autoLoadOnLaunch() {
        // 1. JSON store is the source of truth
        if let store = StoreManager.load() {
            applyStore(store)
            return
        }
        // 2. First launch after upgrade — migrate from CSV and back it up
        if let store = StoreManager.migrateFromCSV() {
            applyStore(store)
            StoreManager.save(store)
            showMessage("✅ Data saved to new storage format")
            return
        }
        // 3. Try iCloud CSV (for existing users who never had a Documents CSV)
        if let icloudURL = iCloudCSVURL(), FileManager.default.fileExists(atPath: icloudURL.path),
           let result = CSVManager.loadFrom(url: icloudURL) {
            let store = NeighborhoodStore(streets: result.streets, blocks: result.blocks)
            applyStore(store)
            StoreManager.save(store)
            sourceURL = icloudURL
            showMessage("🌩 Loaded from iCloud Drive")
            return
        }
        // 4. Blank template for new users
        loadBlankTemplate()
    }

    private func applyStore(_ store: NeighborhoodStore) {
        isSaving = true
        defer { isSaving = false }
        streets = store.streets.isEmpty ? CSVManager.defaultStreets() : store.streets
        blocks  = store.blocks
    }

    // MARK: - Save

    private func saveAll() {
        let store = NeighborhoodStore(streets: streets, blocks: blocks)
        StoreManager.save(store)
        saveBackToSource()
    }

    // Called on background / resign active — always saves regardless of isSaving state
    func forceSave() {
        let store = NeighborhoodStore(streets: streets, blocks: blocks)
        StoreManager.save(store)
    }

    // Optional: sync changes back to the iCloud CSV the user originally loaded from
    private func saveBackToSource() {
        guard let source = sourceURL else { return }
        let content = CSVManager.buildContent(blocks: blocks, streets: streets)
        let accessing = source.startAccessingSecurityScopedResource()
        try? content.write(to: source, atomically: true, encoding: .utf8)
        if accessing { source.stopAccessingSecurityScopedResource() }
    }

    // MARK: - iCloud URL

    private func iCloudCSVURL() -> URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let docsURL = base.appendingPathComponent("Documents").appendingPathComponent("neighborhood_data.csv")
        if FileManager.default.fileExists(atPath: docsURL.path) { return docsURL }
        return base.appendingPathComponent("neighborhood_data.csv")
    }

    // MARK: - Load from file picker (CSV import)

    func loadFromURL(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let result = CSVManager.loadFrom(url: url) {
            let existing = StoreManager.load()
            if let existing { StoreManager.makeBackup(of: existing) }
            let store = NeighborhoodStore(streets: result.streets, blocks: result.blocks)
            applyStore(store)
            StoreManager.save(store)
            sourceURL = url
            showMessage("✅ Loaded \(blocks.count) homes — saves will sync to iCloud")
        } else {
            showMessage("⚠️ Could not read that file")
        }
    }

    // MARK: - Load bundled CSV

    func loadBundledCSV() {
        guard let bundleURL = Bundle.main.url(forResource: "neighborhood_data", withExtension: "csv") else {
            showMessage("⚠️ No bundled CSV found"); return
        }
        let dest = CSVManager.csvURL
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: bundleURL, to: dest)
        if let result = CSVManager.load() {
            let store = NeighborhoodStore(streets: result.streets, blocks: result.blocks)
            applyStore(store)
            StoreManager.save(store)
            showMessage("✅ Loaded \(blocks.count) homes from default")
        }
    }

    // MARK: - Blank template

    func loadBlankTemplate() {
        isSaving = true
        defer { isSaving = false }
        streets = CSVManager.defaultStreets()
        blocks  = []
        var idx = 0
        for (gIdx, street) in streets.enumerated() {
            let cfg = street.config
            for r in 0..<cfg.rows {
                for c in 0..<cfg.cols {
                    if cfg.isHouseable(row: r, col: c) {
                        blocks.append(Block(
                            houseName: "House \(idx + 1)",
                            colorName: colorNames[idx % colorNames.count],
                            icon: icons[idx % icons.count],
                            gridIndex: gIdx, row: r, col: c
                        ))
                        idx += 1
                    }
                }
            }
        }
        saveAll()
    }

    // MARK: - CSV Export (Step 4)

    func exportCSVURL() -> URL {
        let data = CSVManager.exportV2Data(blocks: blocks, streets: streets)
        let dir  = CSVManager.exportDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url  = dir.appendingPathComponent("neighborhood_export.csv")
        try? data.write(to: url)
        return url
    }

    // MARK: - CSV Import preview (Step 4)
    // Returns a preview for v2 (UUID-based merge) or v1 (replace) files, or nil if unparseable.

    func previewCSVImport(from url: URL) -> ImportPreview? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        if CSVManager.isV2Format(content) {
            guard let imported = CSVManager.parseV2(content: content) else { return nil }
            return CSVManager.previewMerge(imported: imported, current: (blocks: blocks, streets: streets))
        } else {
            guard let imported = CSVManager.parse(content: content) else { return nil }
            return CSVManager.previewReplace(imported: imported)
        }
    }

    // Merge: update changed blocks/people, add new ones, keep everything else.
    func applyMerge(_ preview: ImportPreview) {
        let existing = StoreManager.load()
        if let existing { StoreManager.makeBackup(of: existing) }
        let updatedIds = Set(preview.updatedBlocks.map { $0.id })
        var merged = blocks.filter { !updatedIds.contains($0.id) } + preview.updatedBlocks + preview.newBlocks
        merged.sort {
            if $0.gridIndex != $1.gridIndex { return $0.gridIndex < $1.gridIndex }
            if $0.row != $1.row { return $0.row < $1.row }
            return $0.col < $1.col
        }
        isSaving = true
        blocks = merged
        isSaving = false
        saveAll()
        showMessage("✅ \(preview.summary)")
    }

    // Replace All: back up, then replace streets + blocks entirely.
    func replaceAll(_ preview: ImportPreview) {
        let existing = StoreManager.load()
        if let existing { StoreManager.makeBackup(of: existing) }
        applyStore(NeighborhoodStore(streets: preview.importedStreets, blocks: preview.allImportedBlocks))
        saveAll()
        showMessage("✅ Replaced with \(preview.allImportedBlocks.count) houses")
    }

    // MARK: - Save to CSV (manual, for sharing / iCloud sync)

    func saveToCSV() {
        CSVManager.save(blocks: blocks, streets: streets)
        saveBackToSource()
        let dest = sourceURL != nil ? "iCloud Drive" : "device"
        showMessage("💾 Saved \(blocks.count) homes to \(dest)")
    }

    // MARK: - Template export
    // Produces a JSON string with streets + house layout but NO resident data.
    // Safe to share publicly — neighbors import it to get the map without your personal info.

    func templateJSON() -> String {
        let data = NeighborhoodData(
            streets: streets,
            blocks: blocks.map { var b = $0; b.residents = []; return b }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data),
              let str     = String(data: encoded, encoding: .utf8) else { return "{}" }
        return str
    }

    // MARK: - Template import
    // Downloads a JSON template from a URL and replaces the current map layout.
    // Residents are always stripped from imported data — only the layout comes across.

    func importTemplate(from urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            await MainActor.run { importError = "That doesn't look like a valid URL." }
            return
        }
        await MainActor.run { isImporting = true; importError = nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let template = try decoder.decode(NeighborhoodData.self, from: data)
            await MainActor.run {
                isSaving = true
                streets  = template.streets
                blocks   = template.blocks.map { var b = $0; b.residents = []; return b }
                isSaving = false
                saveAll()
                isImporting = false
                showMessage("✅ Neighborhood template imported")
            }
        } catch {
            await MainActor.run {
                importError = "Couldn't load template: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }

    // MARK: - Street mutations

    func addStreet(name: String, template: StreetTemplate, rows: Int = 5) {
        streets.append(Street(name: name, template: template, rows: rows))
    }

    func removeStreet(at index: Int) {
        guard index < streets.count else { return }
        var newBlocks = blocks.filter { $0.gridIndex != index }
        for i in 0..<newBlocks.count {
            if newBlocks[i].gridIndex > index { newBlocks[i].gridIndex -= 1 }
        }
        var newStreets = streets
        newStreets.remove(at: index)
        DispatchQueue.main.async {
            self.isSaving = true
            self.blocks  = newBlocks
            self.streets = newStreets
            self.isSaving = false
            self.saveAll()
        }
    }

    func renameStreet(index: Int, newName: String) {
        guard index < streets.count else { return }
        streets[index].name = newName
        streets[index].lastModified = Date()
    }

    // MARK: - Queries

    func config(for gridIndex: Int) -> GridConfig? {
        guard gridIndex < streets.count else { return nil }
        return streets[gridIndex].config
    }

    func block(gridIndex: Int, row: Int, col: Int) -> Block? {
        blocks.first { $0.gridIndex == gridIndex && $0.row == row && $0.col == col }
    }
    func isCellEmpty(gridIndex: Int, row: Int, col: Int) -> Bool {
        block(gridIndex: gridIndex, row: row, col: col) == nil
    }
    func isHouseable(gridIndex: Int, row: Int, col: Int) -> Bool {
        config(for: gridIndex)?.isHouseable(row: row, col: col) ?? false
    }
    func isRoad(gridIndex: Int, row: Int, col: Int) -> Bool {
        config(for: gridIndex)?.isRoad(row: row, col: col) ?? false
    }
    func isBlank(gridIndex: Int, row: Int, col: Int) -> Bool {
        config(for: gridIndex)?.isBlank(row: row, col: col) ?? true
    }

    // MARK: - Block mutations

    func addBlock() {
        let color = colorNames[blocks.count % colorNames.count]
        let icon  = icons[blocks.count % icons.count]
        for g in 0..<streets.count {
            let cfg = streets[g].config
            for r in 0..<cfg.rows { for c in 0..<cfg.cols {
                if cfg.isHouseable(row: r, col: c) && isCellEmpty(gridIndex: g, row: r, col: c) {
                    blocks.append(Block(houseName: "House \(blocks.count + 1)",
                                        colorName: color, icon: icon, gridIndex: g, row: r, col: c))
                    return
                }
            }}
        }
    }

    func moveBlock(id: UUID, toGrid: Int, toRow: Int, toCol: Int) {
        guard isHouseable(gridIndex: toGrid, row: toRow, col: toCol) else { return }
        guard isCellEmpty(gridIndex: toGrid, row: toRow, col: toCol) else { return }
        guard let idx = blocks.firstIndex(where: { $0.id == id }) else { return }
        isSaving = true
        blocks[idx].gridIndex    = toGrid
        blocks[idx].row          = toRow
        blocks[idx].col          = toCol
        blocks[idx].lastModified = Date()
        isSaving = false
        saveAll()
    }

    func renameBlock(id: UUID, houseName: String) {
        guard let idx = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[idx].houseName    = houseName
        blocks[idx].lastModified = Date()
    }

    func deleteBlock(id: UUID) { blocks.removeAll { $0.id == id } }

    func setDecoration(blockId: UUID, decoration: String?) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        blocks[idx].decoration  = decoration
        blocks[idx].lastModified = Date()
    }

    func addResident(to blockId: UUID, person: Person) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        blocks[idx].residents.append(person)
        blocks[idx].lastModified = Date()
    }

    func removeResident(from blockId: UUID, personId: UUID) {
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        blocks[idx].residents.removeAll { $0.id == personId }
        blocks[idx].lastModified = Date()
    }

    func updateResident(in blockId: UUID, person: Person) {
        guard let bIdx = blocks.firstIndex(where: { $0.id == blockId }),
              let pIdx = blocks[bIdx].residents.firstIndex(where: { $0.id == person.id }) else { return }
        var updated = person
        updated.lastModified = Date()
        isSaving = true
        blocks[bIdx].residents[pIdx] = updated
        blocks[bIdx].lastModified    = Date()
        isSaving = false
        saveAll()
    }

    // MARK: - Message

    func showMessage(_ msg: String) {
        csvLoadMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.csvLoadMessage = nil }
    }
}
