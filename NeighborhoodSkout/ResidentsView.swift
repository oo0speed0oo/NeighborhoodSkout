import SwiftUI
import PhotosUI

struct ResidentsView: View {
    @ObservedObject var vm: BlockMapViewModel
    let blockId: UUID
    let blockLabel: String

    @State private var showAddSheet    = false
    @State private var editingPerson: Person? = nil
    @State private var showDeleteAlert = false
    @State private var deletingId: UUID? = nil

    @State private var housePickerItem: PhotosPickerItem? = nil
    @State private var housePhoto: UIImage? = nil

    var block: Block?       { vm.blocks.first { $0.id == blockId } }
    var residents: [Person] { block?.residents ?? [] }

    var grouped: [(String, [Person])] {
        let order: [Person.FamilyRole] = [.grandparent, .parent, .child, .other]
        return order.compactMap { role in
            let people = residents.filter { $0.role == role }
            let label: String
            switch role {
            case .child: label = "Children"
            default:     label = role.rawValue + "s"
            }
            return people.isEmpty ? nil : (label, people)
        }
    }

    var body: some View {
        Group {
            if residents.isEmpty { emptyState } else { residentsList }
        }
        .navigationTitle(blockLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Label("Add", systemImage: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PersonFormView { person in vm.addResident(to: blockId, person: person) }
        }
        .sheet(item: $editingPerson) { person in
            PersonFormView(existing: person) { updated in vm.updateResident(in: blockId, person: updated) }
        }
        .onAppear { housePhoto = PhotoStore.load(PhotoStore.houseURL(blockId)) }
        .onChange(of: housePickerItem) { item in
            Task {
                guard let item else { return }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    PhotoStore.save(image, to: PhotoStore.houseURL(blockId))
                    await MainActor.run { housePhoto = PhotoStore.load(PhotoStore.houseURL(blockId)) }
                }
            }
        }
        .alert("Remove Resident", isPresented: $showDeleteAlert) {
            Button("Remove", role: .destructive) {
                if let id = deletingId { vm.removeResident(from: blockId, personId: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this person?")
        }
    }

    var housePhotoHeader: some View {
        HStack(spacing: 14) {
            PhotosPicker(selection: $housePickerItem, matching: .images) {
                Group {
                    if let img = housePhoto {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray5))
                            .frame(width: 64, height: 64)
                            .overlay(Image(systemName: "camera.badge.plus")
                                .font(.title2).foregroundColor(.secondary))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(housePhoto != nil ? "House Photo" : "Add House Photo")
                    .font(.subheadline).fontWeight(.medium)
                Text(housePhoto != nil ? "Tap to change" : "Optional photo for this house")
                    .font(.caption).foregroundColor(.secondary)
                if housePhoto != nil {
                    Button("Remove") {
                        PhotoStore.delete(PhotoStore.houseURL(blockId))
                        housePhoto = nil
                    }
                    .font(.caption).foregroundColor(.red)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            housePhotoHeader
            Divider().padding(.horizontal, 20)
            Spacer()
            Text("🏠").font(.system(size: 52))
            Text("No residents yet").font(.title3).fontWeight(.medium)
            Text("Tap + to add the people who live here")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: { showAddSheet = true }) {
                Label("Add Resident", systemImage: "person.badge.plus")
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Color.accentColor).foregroundColor(.white).cornerRadius(99)
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var residentsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                housePhotoHeader
                HStack {
                    Label("\(residents.count) resident\(residents.count == 1 ? "" : "s")", systemImage: "person.2")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)

                ForEach(grouped, id: \.0) { groupName, people in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(groupName)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(.secondary).textCase(.uppercase)
                            Rectangle().frame(height: 0.5).foregroundColor(Color(.separator))
                        }
                        .padding(.horizontal, 20)

                        ForEach(people) { person in
                            PersonRowView(person: person)
                                .padding(.horizontal, 16)
                                .contextMenu {
                                    Button { editingPerson = person } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        deletingId = person.id; showDeleteAlert = true
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                .onTapGesture { editingPerson = person }
                        }
                    }
                }
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Person Row

struct PersonRowView: View {
    let person: Person
    @State private var showCopied  = false
    @State private var personPhoto: UIImage? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar: person photo if available, else gender icon
                if let img = personPhoto {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 46, height: 46).clipShape(Circle())
                        .overlay(Circle().stroke(person.gender.borderColor, lineWidth: 1))
                } else {
                    ZStack {
                        Circle().fill(person.gender.color).frame(width: 46, height: 46)
                            .overlay(Circle().stroke(person.gender.borderColor, lineWidth: 1))
                        Text(person.gender.icon).font(.system(size: 22))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(person.fullName).font(.system(size: 15, weight: .medium))
                        Text(person.role.rawValue).font(.system(size: 11))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color(.systemGray5)).cornerRadius(99).foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text("🎂 \(dateFormatter.string(from: person.birthday))")
                            .font(.caption).foregroundColor(.secondary)
                        Text("·").foregroundColor(.secondary)
                        Text("Age \(person.age)").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary.opacity(0.4))
            }
            .padding(12)

            // LINE button — only shows if lineId is set
            if !person.lineId.isEmpty {
                Divider().padding(.horizontal, 12)
                Button(action: { openLine(id: person.lineId) }) {
                    HStack(spacing: 8) {
                        // LINE logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.07, green: 0.78, blue: 0.35))
                                .frame(width: 24, height: 24)
                            Text("LINE")
                                .font(.system(size: 7, weight: .black))
                                .foregroundColor(.white)
                        }
                        Text(person.lineId)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.07, green: 0.65, blue: 0.30))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.07, green: 0.65, blue: 0.30))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.07, green: 0.78, blue: 0.35).opacity(0.08))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.35), lineWidth: 0.5))
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("LINE ID copied to clipboard")
                    .font(.caption).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.label).opacity(0.8)).cornerRadius(99)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCopied)
        .onAppear { personPhoto = PhotoStore.load(PhotoStore.personURL(person.id)) }
    }

    private func openLine(id: String) {
        // Strip any leading ~ the user may have typed (we add it in the URL)
        let clean = PersonFormView.cleanLineId(id)
        guard !clean.isEmpty, let lineURL = URL(string: "line://ti/p/~\(clean)") else {
            copyFallback(clean.isEmpty ? id : clean); return
        }
        UIApplication.shared.open(lineURL) { success in
            if success { return }
            // Try the web redirect form as a second attempt
            if let webURL = URL(string: "https://line.me/R/ti/p/~\(clean)") {
                UIApplication.shared.open(webURL) { webSuccess in
                    if !webSuccess { self.copyFallback(clean) }
                }
            } else {
                self.copyFallback(clean)
            }
        }
    }

    private func copyFallback(_ id: String) {
        UIPasteboard.general.string = id
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showCopied = false }
    }
}
