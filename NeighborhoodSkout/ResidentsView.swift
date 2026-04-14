import SwiftUI

struct ResidentsView: View {
    @ObservedObject var vm: BlockMapViewModel
    let blockId: UUID
    let blockLabel: String

    @State private var showAddSheet    = false
    @State private var editingPerson: Person? = nil
    @State private var showDeleteAlert = false
    @State private var deletingId: UUID? = nil

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
        .alert("Remove Resident", isPresented: $showDeleteAlert) {
            Button("Remove", role: .destructive) {
                if let id = deletingId { vm.removeResident(from: blockId, personId: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this person?")
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var residentsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("\(residents.count) resident\(residents.count == 1 ? "" : "s")", systemImage: "person.2")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 12)

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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(person.gender.color).frame(width: 46, height: 46)
                    .overlay(Circle().stroke(person.gender.borderColor, lineWidth: 1))
                Text(person.gender.icon).font(.system(size: 22))
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator).opacity(0.35), lineWidth: 0.5))
    }
}
