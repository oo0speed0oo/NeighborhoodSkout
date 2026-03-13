import SwiftUI

struct ContentView: View {
    @StateObject private var vm = BlockMapViewModel()

    @State private var selectedBlock:    Block? = nil
    @State private var showActionSheet   = false
    @State private var showRenameAlert   = false
    @State private var renameText        = ""
    @State private var movingBlockId:    UUID?  = nil
    @State private var residentsBlockId: UUID?  = nil

    // Zoom
    @State private var zoomLevel: Int = 3
    let zoomSteps: [CGFloat] = [36, 48, 56, 68, 84, 100, 120]
    var cellSize: CGFloat { zoomSteps[zoomLevel] }
    var canZoomIn:  Bool { zoomLevel < zoomSteps.count - 1 }
    var canZoomOut: Bool { zoomLevel > 0 }

    let cellGap:     CGFloat = 3
    let gridSpacing: CGFloat = 20

    func handleCellTap(gridIndex: Int, row: Int, col: Int) {
        // Ignore taps on road cells
        guard vm.isHouseable(gridIndex: gridIndex, col: col) else { return }

        let tappedBlock = vm.block(gridIndex: gridIndex, row: row, col: col)

        if let movingId = movingBlockId {
            if tappedBlock == nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    vm.moveBlock(id: movingId, toGrid: gridIndex, toRow: row, toCol: col)
                }
                movingBlockId = nil
            } else if tappedBlock?.id == movingId {
                movingBlockId = nil
            }
            return
        }

        if let block = tappedBlock {
            selectedBlock = block
            showActionSheet = true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                zoomBar
                mapScrollView
            }
            .navigationTitle("NeighborhoodSkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { vm.addBlock() }) {
                        Label("Add Home", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { residentsBlockId != nil },
                set: { if !$0 { residentsBlockId = nil } }
            )) {
                if let bid = residentsBlockId,
                   let block = vm.blocks.first(where: { $0.id == bid }) {
                    ResidentsView(vm: vm, blockId: bid, blockLabel: block.houseName)
                }
            }
            .confirmationDialog(
                selectedBlock?.houseName ?? "House",
                isPresented: $showActionSheet,
                titleVisibility: .visible
            ) {
                Button("👥 Residents") {
                    if let b = selectedBlock { residentsBlockId = b.id }
                }
                Button("Move") {
                    if let b = selectedBlock { movingBlockId = b.id }
                }
                Button("✏️ Rename House") {
                    if let b = selectedBlock { renameText = b.houseName; showRenameAlert = true }
                }
                Button("Delete", role: .destructive) {
                    if let b = selectedBlock {
                        vm.deleteBlock(id: b.id)
                        if movingBlockId == b.id { movingBlockId = nil }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("House Name", isPresented: $showRenameAlert) {
                TextField("e.g. The Johnsons or 42 Maple St", text: $renameText)
                Button("Save") {
                    if let b = selectedBlock,
                       !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        vm.renameBlock(id: b.id, houseName: renameText.trimmingCharacters(in: .whitespaces))
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Zoom bar

    var zoomBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                if canZoomOut { withAnimation(.easeInOut(duration: 0.18)) { zoomLevel -= 1 } }
            }) {
                Image(systemName: "minus.magnifyingglass").font(.system(size: 20))
                    .foregroundColor(canZoomOut ? .primary : .secondary.opacity(0.3))
            }.disabled(!canZoomOut)

            Text("Zoom").font(.caption).foregroundColor(.secondary)

            Button(action: {
                if canZoomIn { withAnimation(.easeInOut(duration: 0.18)) { zoomLevel += 1 } }
            }) {
                Image(systemName: "plus.magnifyingglass").font(.system(size: 20))
                    .foregroundColor(canZoomIn ? .primary : .secondary.opacity(0.3))
            }.disabled(!canZoomIn)

            Spacer()

            if movingBlockId != nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
                    Text("Tap green to place").font(.caption)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(red:0.90,green:0.97,blue:0.90)).cornerRadius(99)

                Button(action: { movingBlockId = nil }) {
                    Text("Cancel").font(.caption).foregroundColor(.secondary)
                }
            } else {
                Text("\(vm.blocks.count) homes")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(.systemGray6)).cornerRadius(99)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(Rectangle().frame(height: 0.5)
            .foregroundColor(Color(.separator).opacity(0.4)), alignment: .bottom)
    }

    // MARK: - Map scroll view

    var mapScrollView: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<vm.gridCount, id: \.self) { gIdx in
                    StreetLabelView(index: gIdx, vm: vm)
                        .padding(.top, gIdx == 0 ? 16 : gridSpacing)
                    BlockGridView(
                        gridIndex: gIdx,
                        cellSize: cellSize,
                        cellGap: cellGap,
                        rows: vm.rows,
                        cols: vm.cols,
                        vm: vm,
                        movingBlockId: $movingBlockId,
                        selectedBlock: $selectedBlock,
                        showActionSheet: $showActionSheet,
                        onCellTap: handleCellTap
                    )
                    .padding(.horizontal, 16)
                }
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ContentView()
}
