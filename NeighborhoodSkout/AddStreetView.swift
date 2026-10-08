import SwiftUI

struct AddStreetView: View {
    @Environment(\.dismiss) var dismiss
    var onAdd: (String, StreetTemplate, Int) -> Void

    @State private var streetName = ""
    @State private var template   = StreetTemplate.bothSides
    @State private var rows       = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("Street Name") {
                    TextField("e.g. Maple Street", text: $streetName)
                }

                Section {
                    ForEach(StreetTemplate.allCases, id: \.self) { t in
                        Button(action: { template = t }) {
                            HStack(spacing: 14) {
                                Text(t.icon).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.rawValue)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(t.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if template == t {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    Text("Street Layout")
                }

                Section {
                    Stepper("Number of houses per side: \(rows)", value: $rows, in: 1...10)
                } footer: {
                    Text("Each side of the street will have \(rows) house slots")
                        .font(.caption)
                }

                // Preview
                Section("Preview") {
                    StreetPreview(template: template, rows: rows)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Add Street")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let name = streetName.trimmingCharacters(in: .whitespaces)
                        onAdd(name.isEmpty ? "New Street" : name, template, rows)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Mini street preview

struct StreetPreview: View {
    let template: StreetTemplate
    let rows: Int

    var body: some View {
        let cfg = template.makeConfig(rows: min(rows, 3))
        HStack(spacing: 2) {
            ForEach(0..<cfg.cols, id: \.self) { col in
                VStack(spacing: 2) {
                    ForEach(0..<min(cfg.rows, 3), id: \.self) { row in
                        if cfg.isHouseable(row: row, col: col) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.3))
                                .overlay(Text("🏠").font(.system(size: 8)))
                        } else if cfg.isRoad(row: row, col: col) {
                            Rectangle()
                                .fill(Color(red: 0.25, green: 0.25, blue: 0.27))
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 120)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
