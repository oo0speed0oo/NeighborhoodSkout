import SwiftUI
import Combine

class BlockMapViewModel: ObservableObject {
    @Published var blocks: [Block] = []
    @Published var streetNames: [String] = ["Maple Street", "Oak Avenue", "Elm Drive"]

    // Import state
    @Published var isImporting = false
    @Published var importError: String? = nil

    let rows      = 5
    let cols      = 3
    let gridCount = 3

    let colorNames = ["purple","teal","coral","pink","blue","green","orange","red"]
    let icons       = ["🏠","🏡","🏘","🏚","🏗","🏢","🏣","🏤"]

    private static let saveKey = "neighborhoodData_v1"
    private var cancellables = Set<AnyCancellable>()

    init() {
        if !loadSaved() {
            blocks = [
                Block(houseName: "House 1", colorName: "purple", icon: "🏠", gridIndex: 0, row: 0, col: 0),
                Block(houseName: "House 2", colorName: "teal",   icon: "🏡", gridIndex: 0, row: 2, col: 2),
            ]
        }
        // Auto-save whenever blocks or street names change
        $blocks
            .dropFirst()
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
        $streetNames
            .dropFirst()
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    @discardableResult
    private func loadSaved() -> Bool {
        guard let data    = UserDefaults.standard.data(forKey: Self.saveKey),
              let decoded = try? JSONDecoder().decode(NeighborhoodData.self, from: data)
        else { return false }
        blocks      = decoded.blocks
        streetNames = decoded.streetNames
        return true
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(
            NeighborhoodData(streetNames: streetNames, blocks: blocks)
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.saveKey)
    }

    // MARK: - Template export
    // Produces a JSON string with the map layout but NO resident data.
    // Share this with neighbors so they get your street/house setup
    // without any of your personal information.

    func templateJSON() -> String {
        let stripped = NeighborhoodData(
            streetNames: streetNames,
            blocks: blocks.map { var b = $0; b.residents = []; return b }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stripped),
              let str  = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    // MARK: - Template import
    // Downloads a template JSON from a URL and replaces the current map layout.
    // Any residents already on this device are wiped — the import is a fresh start.

    func importTemplate(from urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            await MainActor.run { importError = "That doesn't look like a valid URL." }
            return
        }
        await MainActor.run { isImporting = true; importError = nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let template  = try JSONDecoder().decode(NeighborhoodData.self, from: data)
            await MainActor.run {
                streetNames = template.streetNames
                // Strip any residents that were in the file — only the layout comes across
                blocks      = template.blocks.map { var b = $0; b.residents = []; return b }
                isImporting = false
            }
        } catch {
            await MainActor.run {
                importError = "Couldn't load template: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }

    // MARK: - Queries

    func block(gridIndex: Int, row: Int, col: Int) -> Block? {
        blocks.first { $0.gridIndex == gridIndex && $0.row == row && $0.col == col }
    }

    func isCellEmpty(gridIndex: Int, row: Int, col: Int) -> Bool {
        block(gridIndex: gridIndex, row: row, col: col) == nil
    }

    func isHouseable(gridIndex: Int, col: Int) -> Bool {
        guard gridIndex < gridLayouts.count else { return false }
        return gridLayouts[gridIndex].isHouseable(col: col)
    }

    func isRoad(gridIndex: Int, col: Int) -> Bool {
        return !isHouseable(gridIndex: gridIndex, col: col)
    }

    // MARK: - Block mutations

    func addBlock() {
        let color = colorNames[blocks.count % colorNames.count]
        let icon  = icons[blocks.count % icons.count]
        for g in 0..<gridCount {
            for r in 0..<rows {
                for c in 0..<cols {
                    if isHouseable(gridIndex: g, col: c) && isCellEmpty(gridIndex: g, row: r, col: c) {
                        blocks.append(Block(
                            houseName: "House \(blocks.count + 1)",
                            colorName: color, icon: icon,
                            gridIndex: g, row: r, col: c
                        ))
                        return
                    }
                }
            }
        }
    }

    func moveBlock(id: UUID, toGrid: Int, toRow: Int, toCol: Int) {
        guard isHouseable(gridIndex: toGrid, col: toCol) else { return }
        guard isCellEmpty(gridIndex: toGrid, row: toRow, col: toCol) else { return }
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx].gridIndex = toGrid
            blocks[idx].row       = toRow
            blocks[idx].col       = toCol
        }
    }

    func renameBlock(id: UUID, houseName: String) {
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx].houseName = houseName
        }
    }

    func deleteBlock(id: UUID) {
        blocks.removeAll { $0.id == id }
    }

    func renameStreet(index: Int, newName: String) {
        guard index < streetNames.count else { return }
        streetNames[index] = newName
    }

    // MARK: - Resident mutations

    func addResident(to blockId: UUID, person: Person) {
        if let idx = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[idx].residents.append(person)
        }
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
}
