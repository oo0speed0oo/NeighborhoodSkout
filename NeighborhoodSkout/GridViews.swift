import SwiftUI

// MARK: - Single Block Visual

struct SingleBlockView: View {
    let block: Block
    let cellSize: CGFloat
    var isPending: Bool    = false
    var decorateMode: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: max(2, cellSize * 0.04)) {
                // Decoration replaces the house icon when set
                Text(block.decoration ?? block.icon)
                    .font(.system(size: max(10, cellSize * 0.34)))
                Text(block.houseName)
                    .font(.system(size: max(7, cellSize * 0.13), weight: .medium))
                    .foregroundColor(.blockText(block.colorName))
                    .multilineTextAlignment(.center).lineLimit(2).padding(.horizontal, 2)
                if !block.residents.isEmpty {
                    Text("\(block.residents.count) 👤")
                        .font(.system(size: max(6, cellSize * 0.11)))
                        .foregroundColor(.blockText(block.colorName).opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blockBackground(block.colorName))
            .overlay(RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                .stroke(
                    decorateMode ? Color.orange :
                    isPending    ? Color.blue   :
                    Color.blockBorder(block.colorName),
                    lineWidth: (decorateMode || isPending) ? 2 : 0.5))
            .cornerRadius(max(4, cellSize * 0.12))
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .scaleEffect(isPending ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPending)

            // Birthday badge — shows in week before any resident's birthday
            if birthdaySoon {
                Text("🎂")
                    .font(.system(size: max(9, cellSize * 0.22)))
                    .offset(x: 3, y: -3)
            }
        }
    }

    private var birthdaySoon: Bool {
        let cal = Calendar.current
        let now = Date()
        return block.residents.contains { p in
            var comps = cal.dateComponents([.month, .day], from: p.birthday)
            comps.year = cal.component(.year, from: now)
            if let d = cal.date(from: comps) {
                let days = cal.dateComponents([.day], from: now, to: d).day ?? -1
                if days >= 0 && days <= 7 { return true }
            }
            // Year-end edge case: birthday is Dec 25-31 and today is Dec 25+
            if let y = comps.year {
                comps.year = y + 1
                if let d = cal.date(from: comps) {
                    let days = cal.dateComponents([.day], from: now, to: d).day ?? -1
                    return days >= 0 && days <= 7
                }
            }
            return false
        }
    }
}

// MARK: - Road Cell

struct RoadCellView: View {
    let cellSize: CGFloat
    let isCenter: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(Color(red: 0.22, green: 0.22, blue: 0.24))
            if isCenter {
                VStack(spacing: cellSize * 0.14) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.88, blue: 0.0).opacity(0.75))
                            .frame(width: 3, height: cellSize * 0.16)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1.5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Block Grid View

struct BlockGridView: View {
    let gridIndex:   Int
    let cellSize:    CGFloat
    let cellGap:     CGFloat
    let rows:        Int
    let cols:        Int
    @ObservedObject var vm: BlockMapViewModel
    @Binding var movingBlockId: UUID?
    var decorateMode: Bool = false
    var onCellTap: (Int, Int, Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: cellGap) {
                    ForEach(0..<cols, id: \.self) { col in
                        let isRoad     = vm.isRoad(gridIndex: gridIndex, row: row, col: col)
                        let isBlank    = vm.isBlank(gridIndex: gridIndex, row: row, col: col)
                        let block      = (isRoad || isBlank) ? nil : vm.block(gridIndex: gridIndex, row: row, col: col)
                        let isEmpty    = !isRoad && !isBlank && block == nil
                        let isPending  = block?.id == movingBlockId
                        let isMoveMode = movingBlockId != nil

                        ZStack {
                            if isBlank {
                                Color.clear
                            } else if isRoad {
                                RoadCellView(cellSize: cellSize, isCenter: isCenter(col: col, cols: cols))
                            } else {
                                // Empty lot
                                if isMoveMode && isEmpty {
                                    // Move-mode drop target: bright green
                                    RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                                        .fill(Color(red:0.88,green:0.97,blue:0.88))
                                        .overlay(RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                                            .stroke(Color(red:0.3,green:0.75,blue:0.3), lineWidth: 1.5))
                                } else if isEmpty {
                                    // Empty lot: dashed outline so position is visible over grass
                                    RoundedRectangle(cornerRadius: max(4, cellSize * 0.12))
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundColor(Color.white.opacity(0.45))
                                }
                                if let block = block {
                                    SingleBlockView(block: block, cellSize: cellSize,
                                                    isPending: isPending, decorateMode: decorateMode)
                                }
                                Color.clear.contentShape(Rectangle())
                                    .onTapGesture { onCellTap(gridIndex, row, col) }
                            }
                        }
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }

    private func isCenter(col: Int, cols: Int) -> Bool {
        cols == 3 && col == 1
    }
}

// MARK: - Street Label

struct StreetLabelView: View {
    let index: Int
    @ObservedObject var vm: BlockMapViewModel
    var onDelete: (() -> Void)? = nil
    @State private var isEditing = false
    @State private var editText  = ""

    var body: some View {
        guard index < vm.streets.count else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: "road.lanes").font(.caption).foregroundColor(.secondary)
                if isEditing {
                    TextField("Street name", text: $editText)
                        .font(.caption).fontWeight(.medium)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).frame(maxWidth: 200)
                        .onSubmit {
                            let t = editText.trimmingCharacters(in: .whitespaces)
                            if !t.isEmpty { vm.renameStreet(index: index, newName: t) }
                            isEditing = false
                        }
                        .onAppear { editText = vm.streets[index].name }
                    Button("Done") {
                        let t = editText.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { vm.renameStreet(index: index, newName: t) }
                        isEditing = false
                    }.font(.caption).foregroundColor(.blue)
                } else {
                    Text(vm.streets[index].name)
                        .font(.caption).fontWeight(.semibold).foregroundColor(.primary)
                    Text(vm.streets[index].template.icon).font(.caption)
                    Button(action: { isEditing = true }) {
                        Image(systemName: "pencil").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.7))
                    }
                    Spacer()
                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle").font(.system(size: 14)).foregroundColor(.red.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 20).padding(.bottom, 6)
        )
    }
}
