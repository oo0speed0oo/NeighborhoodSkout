import SwiftUI
import Combine

class BlockMapViewModel: ObservableObject {
    @Published var blocks: [Block] = [
        Block(houseName: "House 1", colorName: "purple", icon: "🏠", gridIndex: 0, row: 0, col: 0),
        Block(houseName: "House 2", colorName: "teal",   icon: "🏡", gridIndex: 0, row: 2, col: 2),
    ]
    @Published var streetNames: [String] = ["Maple Street", "Oak Avenue", "Elm Drive"]

    let rows      = 5
    let cols      = 3
    let gridCount = 3

    let colorNames = ["purple","teal","coral","pink","blue","green","orange","red"]
    let icons       = ["🏠","🏡","🏘","🏚","🏗","🏢","🏣","🏤"]

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
        // Only place in houseable cells
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
