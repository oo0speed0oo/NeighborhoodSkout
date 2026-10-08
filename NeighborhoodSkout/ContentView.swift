import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = BlockMapViewModel()

    @State private var selectedBlock:         Block? = nil
    @State private var showActionSheet        = false
    @State private var showRenameAlert        = false
    @State private var renameText             = ""
    @State private var movingBlockId:         UUID?  = nil
    @State private var residentsBlockId:      UUID?  = nil
    @State private var showFilePicker         = false
    @State private var showLineSheet          = false
    @State private var lineSheetBlock:        Block? = nil
    @State private var showAddStreet          = false
    @State private var showDeleteStreetAlert  = false
    @State private var streetToDelete:        Int?   = nil
    @State private var showImportSheet        = false
    @State private var decorateMode           = false
    @State private var decoratingBlock:       Block? = nil
    @State private var showExportSheet        = false
    @State private var exportURL:             URL?   = nil
    @State private var importPreview:         ImportPreview? = nil
    @State private var showImportPreview      = false
    @State private var showSettings           = false

    // Zoom
    @State private var zoomLevel: Int = 3
    let zoomSteps: [CGFloat] = [36, 48, 56, 68, 84, 100, 120]
    var cellSize: CGFloat { zoomSteps[zoomLevel] }
    var canZoomIn:  Bool { zoomLevel < zoomSteps.count - 1 }
    var canZoomOut: Bool { zoomLevel > 0 }
    let cellGap:     CGFloat = 3
    let gridSpacing: CGFloat = 20

    func fireTestNotification() {
        let mgr = BirthdayNotificationManager.shared
        mgr.requestPermissionIfNeeded { granted in
            guard granted else {
                vm.showMessage("⚠️ Notifications are off — enable them in Settings")
                return
            }
            // Use the first resident found, or a placeholder
            if let block = vm.blocks.first(where: { !$0.residents.isEmpty }),
               let person = block.residents.first {
                let streetName = vm.streets.indices.contains(block.gridIndex)
                    ? vm.streets[block.gridIndex].name : "your street"
                let age = Calendar.current.dateComponents([.year], from: person.birthday, to: Date()).year ?? 0
                mgr.fireTestNotification(firstName: person.firstName, streetName: streetName, age: age + 1)
                vm.showMessage("📲 Test notification fires in 5 s — lock screen or background the app")
            } else {
                mgr.fireTestNotification(firstName: "Neighbor", streetName: "Oak Ave", age: 30)
                vm.showMessage("📲 Test notification fires in 5 s (no residents yet — using placeholder)")
            }
        }
    }

    func handleCellTap(gridIndex: Int, row: Int, col: Int) {
        guard vm.isHouseable(gridIndex: gridIndex, row: row, col: col) else { return }
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
        if decorateMode {
            if let block = tappedBlock { decoratingBlock = block }
            return
        }
        if let block = tappedBlock { selectedBlock = block; showActionSheet = true }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Banner
                if let msg = vm.csvLoadMessage {
                    Text(msg).font(.caption)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(red:0.90,green:0.97,blue:0.90))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                zoomBar
                mapScrollView
            }
            .animation(.easeInOut(duration: 0.3), value: vm.csvLoadMessage)
            .navigationTitle("NeighborhoodSkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
                        Button(action: {
                            exportURL = vm.exportCSVURL()
                            showExportSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // House & Street
                        Button(action: { vm.addBlock() }) {
                            Label("Add Home", systemImage: "plus.circle")
                        }
                        Button(action: { showAddStreet = true }) {
                            Label("Add Street", systemImage: "road.lanes")
                        }
                        Divider()
                        // File loading
                        Button(action: { showFilePicker = true }) {
                            Label("Load from iCloud Drive", systemImage: "icloud.and.arrow.down")
                        }
                        Button(action: { showFilePicker = true }) {
                            Label("Load from Local Storage", systemImage: "folder")
                        }
                        Divider()
                        Button(action: { vm.loadBundledCSV() }) {
                            Label("Load Default Data", systemImage: "arrow.clockwise")
                        }
                        Divider()
                        // Neighbor sharing
                        ShareLink(
                            item: vm.templateJSON(),
                            subject: Text("Neighborhood Template"),
                            message: Text("Import this into NeighborhoodSkout to get our neighborhood map.")
                        ) {
                            Label("Share Template", systemImage: "person.2.fill")
                        }
                        Button(action: { showImportSheet = true }) {
                            Label("Import from URL", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(action: { fireTestNotification() }) {
                            Label("Test Birthday Alert", systemImage: "bell.badge")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddStreet) {
                AddStreetView { name, template, rows in
                    vm.addStreet(name: name, template: template, rows: rows)
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportTemplateView(vm: vm)
            }
            .sheet(item: $decoratingBlock) { block in
                DecorationPickerView(block: block) { deco in
                    vm.setDecoration(blockId: block.id, decoration: deco)
                    // refresh the block reference so the picker shows updated state
                    decoratingBlock = nil
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText, UTType.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if let preview = vm.previewCSVImport(from: url) {
                        importPreview = preview
                        showImportPreview = true
                    } else {
                        // Fallback: direct load (unrecognised format)
                        vm.loadFromURL(url)
                    }
                case .failure(let error):
                    vm.csvLoadMessage = "⚠️ \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { vm.csvLoadMessage = nil }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ActivitySheet(items: [url])
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showImportPreview) {
                if let preview = importPreview {
                    ImportPreviewSheet(preview: preview, vm: vm) {
                        importPreview = nil
                        showImportPreview = false
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(vm: vm)
            }
            // Residents page
            .navigationDestination(isPresented: Binding(
                get: { residentsBlockId != nil },
                set: { if !$0 { residentsBlockId = nil } }
            )) {
                if let bid = residentsBlockId,
                   let block = vm.blocks.first(where: { $0.id == bid }) {
                    ResidentsView(vm: vm, blockId: bid, blockLabel: block.houseName)
                }
            }
            // LINE page
            .navigationDestination(isPresented: Binding(
                get: { showLineSheet },
                set: { if !$0 { showLineSheet = false } }
            )) {
                if let block = lineSheetBlock {
                    LineContactSheet(block: block)
                }
            }
            .confirmationDialog(
                selectedBlock?.houseName ?? "House",
                isPresented: $showActionSheet, titleVisibility: .visible
            ) {
                Button("👥 Residents") {
                    if let b = selectedBlock { residentsBlockId = b.id }
                }
                if let b = selectedBlock, b.residents.contains(where: { !$0.lineId.isEmpty }) {
                    Button("💬 Message on LINE") {
                        lineSheetBlock = b
                        showLineSheet = true
                    }
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
            .alert("Remove Street", isPresented: $showDeleteStreetAlert) {
                Button("Remove", role: .destructive) {
                    if let idx = streetToDelete {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            vm.removeStreet(at: idx)
                            streetToDelete = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { streetToDelete = nil }
            } message: {
                Text("This will remove the street and all houses on it.")
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

            // Decorate mode toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    decorateMode.toggle()
                    if decorateMode { movingBlockId = nil }
                }
            }) {
                Image(systemName: decorateMode ? "paintbrush.fill" : "paintbrush")
                    .font(.system(size: 18))
                    .foregroundColor(decorateMode ? .orange : .secondary)
            }

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
            } else if decorateMode {
                HStack(spacing: 6) {
                    Image(systemName: "paintbrush.fill").font(.caption)
                    Text("Tap a house").font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.orange.opacity(0.12)).cornerRadius(99)
                Button(action: { withAnimation { decorateMode = false } }) {
                    Text("Done").font(.caption).foregroundColor(.secondary)
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
                ForEach(Array(vm.streets.enumerated()), id: \.element.id) { gIdx, street in
                    let cfg = street.config
                    StreetLabelView(index: gIdx, vm: vm, onDelete: {
                        streetToDelete = gIdx
                        showDeleteStreetAlert = true
                    })
                    .padding(.top, gIdx == 0 ? 16 : gridSpacing)
                    BlockGridView(
                        gridIndex: gIdx,
                        cellSize: cellSize,
                        cellGap: cellGap,
                        rows: cfg.rows,
                        cols: cfg.cols,
                        vm: vm,
                        movingBlockId: $movingBlockId,
                        decorateMode: decorateMode,
                        onCellTap: handleCellTap
                    )
                    .padding(.horizontal, 16)
                }
                // Add Street button at bottom of map
                Button(action: { showAddStreet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle").font(.caption)
                        Text("Add Street").font(.caption).fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(99)
                }
                .padding(.top, 20).padding(.horizontal, 20)
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.mapGrass)
    }
}

// MARK: - Decoration Picker

struct DecorationPickerView: View {
    let block: Block
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    private let options = ["🌳","🌸","🌻","🌿","🚗","🚲","📪","⛩️","🪧","🏮","💧","🪨"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(options, id: \.self) { emoji in
                        Button(action: { onSelect(emoji); dismiss() }) {
                            Text(emoji)
                                .font(.system(size: 36))
                                .frame(width: 72, height: 72)
                                .background(block.decoration == emoji
                                    ? Color.orange.opacity(0.18)
                                    : Color(.systemGray6))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(block.decoration == emoji ? Color.orange : Color.clear, lineWidth: 2))
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 20)

                if block.decoration != nil {
                    Button(role: .destructive, action: { onSelect(nil); dismiss() }) {
                        Label("Remove Decoration", systemImage: "trash")
                            .font(.callout)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Decorate \(block.houseName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Import Template Sheet

struct ImportTemplateView: View {
    @ObservedObject var vm: BlockMapViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText    = ""
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://...", text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Template URL")
                } footer: {
                    Text("Paste the URL your neighbor shared. This replaces your map layout — personal resident info is never imported.")
                }

                if let error = vm.importError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Import Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") { showConfirm = true }
                        .fontWeight(.semibold)
                        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isImporting)
                }
            }
            .overlay {
                if vm.isImporting {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Importing…").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .confirmationDialog(
                "Replace your map?",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                Button("Import & Replace", role: .destructive) {
                    Task {
                        await vm.importTemplate(from: urlText)
                        if vm.importError == nil { dismiss() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace your current streets and houses with the template. Your resident info will be cleared.")
            }
        }
    }
}

// MARK: - Import Preview Sheet

struct ImportPreviewSheet: View {
    let preview:   ImportPreview
    @ObservedObject var vm: BlockMapViewModel
    let onDismiss: () -> Void

    @State private var confirmReplaceAll = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    Label(preview.canMerge ? "Ready to import" : "Replace all data?",
                          systemImage: preview.canMerge ? "square.and.arrow.down" : "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundColor(preview.canMerge ? .primary : .orange)

                    Text(preview.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !preview.canMerge {
                        Text("This file has no house IDs so a smart merge isn't possible. You can only replace all current data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(20)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if preview.canMerge {
                        Button(action: {
                            vm.applyMerge(preview)
                            onDismiss(); dismiss()
                        }) {
                            Label("Merge Changes", systemImage: "arrow.triangle.merge")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button(role: .destructive, action: { confirmReplaceAll = true }) {
                        Label("Replace All", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss(); dismiss() }
                }
            }
            .confirmationDialog("Replace all data?", isPresented: $confirmReplaceAll, titleVisibility: .visible) {
                Button("Replace All", role: .destructive) {
                    vm.replaceAll(preview)
                    onDismiss(); dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A backup will be made first. Your current streets, houses, and resident info will be replaced.")
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Activity Sheet (UIActivityViewController wrapper)

import UIKit

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview { ContentView() }
