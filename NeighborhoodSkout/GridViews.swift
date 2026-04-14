import SwiftUI

// MARK: - Single Block Visual

struct SingleBlockView: View {
    let block: Block
    let cellSize: CGFloat
    var isPending: Bool = false

    var body: some View {
        VStack(spacing: max(2, cellSize * 0.04)) {
            Text(block.icon)
                .font(.system(size: max(10, cellSize * 0.34)))
            Text(block.houseName)
                .font(.system(size: max(7, cellSize * 0.13), weight: .medium))
                .foregroundColor(.blockText(block.colorName))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 2)
            if !block.residents.isEmpty {
                Text("\(block.residents.count) 👤")
                    .font(.system(size: max(6, cellSize * 0.11)))
                    .foregroundColor(.blockText(block.colorName).opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blockBackground(block.colorName))
        .overlay(
            RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                .stroke(isPending ? Color.blue : Color.blockBorder(block.colorName),
                        lineWidth: isPending ? 2.5 : 0.5)
        )
        .cornerRadius(max(4, cellSize * 0.12))
        .scaleEffect(isPending ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPending)
    }
}

// MARK: - Road Cell Visual

struct RoadCellView: View {
    let cellSize: CGFloat
    let isCenter: Bool  // true = center stripe, false = shoulder

    var body: some View {
        ZStack {
            // Asphalt background
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(red: 0.25, green: 0.25, blue: 0.27))

            if isCenter {
                // Dashed center line
                VStack(spacing: cellSize * 0.12) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.7))
                            .frame(width: 3, height: cellSize * 0.15)
                    }
                }
            } else {
                // Solid edge line
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Block Grid View

struct BlockGridView: View {
    let gridIndex: Int
    let cellSize: CGFloat
    let cellGap: CGFloat
    let rows: Int
    let cols: Int
    @ObservedObject var vm: BlockMapViewModel
    @Binding var movingBlockId: UUID?
    var onCellTap: (Int, Int, Int) -> Void

    var body: some View {
        VStack(spacing: 0) {           // no gap between rows for road continuity
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: cellGap) {
                    ForEach(0..<cols, id: \.self) { col in
                        let isRoad     = vm.isRoad(gridIndex: gridIndex, col: col)
                        let block      = isRoad ? nil : vm.block(gridIndex: gridIndex, row: row, col: col)
                        let isEmpty    = !isRoad && block == nil
                        let isPending  = block?.id == movingBlockId
                        let isMoveMode = movingBlockId != nil

                        ZStack {
                            if isRoad {
                                // Road — not tappable for placement
                                RoadCellView(cellSize: cellSize, isCenter: col == 1)
                            } else {
                                // House cell
                                RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                                    .fill(isMoveMode && isEmpty
                                          ? Color(red:0.88,green:0.97,blue:0.88)
                                          : Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                                            .stroke(
                                                isMoveMode && isEmpty
                                                    ? Color(red:0.3,green:0.75,blue:0.3)
                                                    : Color(.separator).opacity(0.35),
                                                lineWidth: isMoveMode && isEmpty ? 1.5 : 0.5
                                            )
                                    )
                                if let block = block {
                                    SingleBlockView(block: block, cellSize: cellSize, isPending: isPending)
                                }
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { onCellTap(gridIndex, row, col) }
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }
}

// MARK: - Street Label

struct StreetLabelView: View {
    let index: Int
    @ObservedObject var vm: BlockMapViewModel
    @State private var isEditing = false
    @State private var editText  = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "road.lanes").font(.caption).foregroundColor(.secondary)
            if isEditing {
                TextField("Street name", text: $editText)
                    .font(.caption).fontWeight(.medium)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
                    .onSubmit {
                        let t = editText.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { vm.renameStreet(index: index, newName: t) }
                        isEditing = false
                    }
                    .onAppear { editText = vm.streetNames[index] }
                Button("Done") {
                    let t = editText.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { vm.renameStreet(index: index, newName: t) }
                    isEditing = false
                }.font(.caption).foregroundColor(.blue)
            } else {
                Text(vm.streetNames[index])
                    .font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 6)
    }
}
