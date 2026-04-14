import SwiftUI
import Combine

class BlockMapViewModel: ObservableObject {

    @Published var streets: [Street] = [] {
        didSet { saveAll() }
    }
    @Published var blocks: [Block] = [] {
        didSet { saveAll() }
    }
    @Published var csvLoadMessage: String? = nil

    private let iCloudCSVName   = "neighborhood_data.csv"
    private let sourceURLKey    = "nsk_sourceURL"  // remembers which file we loaded from
    private var isSaving        = false
    private var sourceURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: sourceURLKey) else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: sourceURLKey)
        }
    }

    let colorNames = ["purple","teal","coral","pink","blue","green","orange","red"]
    let icons       = ["🏠","🏡","🏘","🏚","🏗","🏢","🏣","🏤"]

    var gridCount: Int { streets.count }

    init() {
        autoLoadOnLaunch()
    }

    // MARK: - Auto load on launch
    // Priority: 1) iCloud Drive  2) Documents CSV  3) Blank template

    private func autoLoadOnLaunch() {
        // 1. Try remembered source URL first (file user previously loaded from)
        if let saved = sourceURL, FileManager.default.fileExists(atPath: saved.path) {
            let accessing = saved.startAccessingSecurityScopedResource()
            if let result = CSVManager.loadFrom(url: saved) {
                apply(result: result)
                if accessing { saved.stopAccessingSecurityScopedResource() }
                showMessage("🌩 Loaded from iCloud Drive")
                return
            }
            if accessing { saved.stopAccessingSecurityScopedResource() }
        }
        // 2. Try auto-detected iCloud Drive
        if let icloudURL = iCloudCSVURL(), FileManager.default.fileExists(atPath: icloudURL.path) {
            if let result = CSVManager.loadFrom(url: icloudURL) {
                apply(result: result)
                sourceURL = icloudURL  // remember it
                CSVManager.save(blocks: blocks, streets: streets)
                showMessage("🌩 Loaded from iCloud Drive")
                return
            }
        }
        // 3. Try Documents CSV
        if FileManager.default.fileExists(atPath: CSVManager.csvURL.path),
           let result = CSVManager.load() {
            apply(result: result)
            return
        }
        // 4. Blank template for new users
        loadBlankTemplate()
    }

    private func apply(result: (blocks: [Block], streets: [Street])) {
        isSaving = true
        streets = result.streets.isEmpty ? CSVManager.defaultStreets() : result.streets
        blocks  = result.blocks
        isSaving = false
    }

    private func saveAll() {
        guard !isSaving else { return }
        CSVManager.save(blocks: blocks, streets: streets)  // always save to Documents
        saveBackToSource()                                  // also sync to iCloud if known
    }

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
        let docsURL = base.appendingPathComponent("Documents").appendingPathComponent(iCloudCSVName)
        if FileManager.default.fileExists(atPath: docsURL.path) { return docsURL }
        return base.appendingPathComponent(iCloudCSVName)
    }

    // MARK: - Load from file picker

    func loadFromURL(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let result = CSVManager.loadFrom(url: url) {
            apply(result: result)
            sourceURL = url          // remember this file for future saves
            saveBackToSource()       // also mirror to Documents
            showMessage("✅ Loaded \(blocks.count) homes — saves will sync to iCloud")
        } else {
            showMessage("⚠️ Could not read that file")
        }
    }

    // MARK: - Load bundled CSV (your personal data, for you only)

    func loadBundledCSV() {
        guard let bundleURL = Bundle.main.url(forResource: "neighborhood_data", withExtension: "csv") else {
            showMessage("⚠️ No bundled CSV found"); return
        }
        let dest = CSVManager.csvURL
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: bundleURL, to: dest)
        if let result = CSVManager.load() {
            apply(result: result)
            showMessage("✅ Loaded \(blocks.count) homes from default")
        }
    }

    // MARK: - Blank template (for new App Store users)

    func loadBlankTemplate() {
        isSaving = true
        streets = CSVManager.defaultStreets()
        blocks  = []
        // Pre-populate empty house slots
        let colors = colorNames
        let icns   = icons
        var idx    = 0
        for (gIdx, street) in streets.enumerated() {
            let cfg = street.config
            for r in 0..<cfg.rows {
                for c in 0..<cfg.cols {
                    if cfg.isHouseable(row: r, col: c) {
                        blocks.append(Block(
                            houseName: "House \(idx + 1)",
                            colorName: colors[idx % colors.count],
                            icon: icns[idx % icns.count],
                            gridIndex: gIdx, row: r, col: c
                        ))
                        idx += 1
                    }
                }
            }
        }
        isSaving = false
        saveAll()
    }

    // MARK: - Save

    func saveToCSV() {
        CSVManager.save(blocks: blocks, streets: streets)
        saveBackToSource()
        let dest = sourceURL != nil ? "iCloud Drive" : "device"
        showMessage("💾 Saved \(blocks.count) homes to \(dest)")
    }

    // MARK: - Street mutations

    func addStreet(name: String, template: StreetTemplate, rows: Int = 5) {
        streets.append(Street(name: name, template: template, rows: rows))
    }

    func removeStreet(at index: Int) {
        guard index < streets.count else { return }
        // Build new blocks and streets atomically before publishing any changes
        var newBlocks = blocks.filter { $0.gridIndex != index }
        for i in 0..<newBlocks.count {
            if newBlocks[i].gridIndex > index {
                newBlocks[i].gridIndex -= 1
            }
        }
        var newStreets = streets
        newStreets.remove(at: index)
        // Apply both changes together on the main thread to avoid mid-update renders
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
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx].gridIndex = toGrid; blocks[idx].row = toRow; blocks[idx].col = toCol
        }
    }
    func renameBlock(id: UUID, houseName: String) {
        if let idx = blocks.firstIndex(where: { $0.id == id }) { blocks[idx].houseName = houseName }
    }
    func deleteBlock(id: UUID) { blocks.removeAll { $0.id == id } }

    func addResident(to blockId: UUID, person: Person) {
        if let idx = blocks.firstIndex(where: { $0.id == blockId }) { blocks[idx].residents.append(person) }
    }
    func removeResident(from blockId: UUID, personId: UUID) {
        if let idx = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[idx].residents.removeAll { $0.id == personId }
        }
    }
    func updateResident(in blockId: UUID, person: Person) {
        if let bIdx = blocks.firstIndex(where: { $0.id == blockId }),
           let pIdx = blocks[bIdx].residents.firstIndex(where: { $0.id == person.id }) {
            blocks[bIdx].residents[pIdx] = person
        }
    }

    // MARK: - Message

    func showMessage(_ msg: String) {
        csvLoadMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.csvLoadMessage = nil }
    }
}
