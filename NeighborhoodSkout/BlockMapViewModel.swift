import SwiftUI
import Combine

class BlockMapViewModel: ObservableObject {
    @Published var blocks: [Block] = [
        Block(label: "House 1", colorName: "purple", icon: "🏠", gridIndex: 0, row: 0, col: 0),
        Block(label: "House 2", colorName: "teal",   icon: "🏡", gridIndex: 1, row: 2, col: 1),
    ]
    @Published var streetNames: [String] = ["Maple Street", "Oak Avenue", "Elm Drive"]

    let rows      = 5
    let cols      = 3
    let gridCount = 3

    let colorNames = ["purple","teal","coral","pink","blue","green","orange","red"]
    let icons       = ["🏠","🏡","🏘","🏚","🏗","🏢","🏣","🏤"]

    func block(gridIndex: Int, row: Int, col: Int) -> Block? {
        blocks.first { $0.gridIndex == gridIndex && $0.row == row && $0.col == col }
    }
    func isCellEmpty(gridIndex: Int, row: Int, col: Int) -> Bool {
        block(gridIndex: gridIndex, row: row, col: col) == nil
    }
    func addBlock() {
        let color = colorNames[blocks.count % colorNames.count]
        let icon  = icons[blocks.count % icons.count]
        for g in 0..<gridCount { for r in 0..<rows { for c in 0..<cols {
            if isCellEmpty(gridIndex: g, row: r, col: c) {
                blocks.append(Block(label: "House \(blocks.count + 1)", colorName: color, icon: icon, gridIndex: g, row: r, col: c))
                return
            }
        }}}
    }
    func moveBlock(id: UUID, toGrid: Int, toRow: Int, toCol: Int) {
        guard isCellEmpty(gridIndex: toGrid, row: toRow, col: toCol) else { return }
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx].gridIndex = toGrid; blocks[idx].row = toRow; blocks[idx].col = toCol
        }
    }
    func renameBlock(id: UUID, newLabel: String) {
        if let idx = blocks.firstIndex(where: { $0.id == id }) { blocks[idx].label = newLabel }
    }
    func deleteBlock(id: UUID) { blocks.removeAll { $0.id == id } }
    func renameStreet(index: Int, newName: String) {
        guard index < streetNames.count else { return }
        streetNames[index] = newName
    }
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
