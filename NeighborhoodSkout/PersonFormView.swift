import SwiftUI

struct PersonFormView: View {
    @Environment(\.dismiss) var dismiss
    var existing: Person? = nil
    var onSave: (Person) -> Void

    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var gender    = Person.Gender.male
    @State private var birthday  = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var role      = Person.FamilyRole.parent
    @State private var lineId    = ""

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name",  text: $lastName)
                }
                Section("Details") {
                    Picker("Gender", selection: $gender) {
                        ForEach(Person.Gender.allCases, id: \.self) { g in
                            Text("\(g.icon) \(g.rawValue)").tag(g)
                        }
                    }
                    Picker("Role in family", selection: $role) {
                        ForEach(Person.FamilyRole.allCases, id: \.self) { r in
                            Text("\(r.icon) \(r.rawValue)").tag(r)
                        }
                    }
                    DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                }
                Section {
                    HStack {
                        Image(systemName: "calendar").foregroundColor(.secondary)
                        Text("Age: \(ageFrom(birthday)) years old").foregroundColor(.secondary)
                    }
                }
                Section {
                    HStack(spacing: 10) {
                        // LINE logo green circle
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.07, green: 0.78, blue: 0.35))
                                .frame(width: 28, height: 28)
                            Text("L")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        TextField("LINE ID (optional)", text: $lineId)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                } header: {
                    Text("LINE")
                } footer: {
                    Text("Enter their LINE ID to message them directly from the app")
                        .font(.caption)
                }
            }
            .navigationTitle(isEditing ? "Edit Resident" : "Add Resident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let p = Person(
                            id:        existing?.id ?? UUID(),
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName:  lastName.trimmingCharacters(in: .whitespaces),
                            gender:    gender,
                            birthday:  birthday,
                            role:      role,
                            lineId:    lineId.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(p)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let p = existing {
                    firstName = p.firstName
                    lastName  = p.lastName
                    gender    = p.gender
                    birthday  = p.birthday
                    role      = p.role
                    lineId    = p.lineId
                }
            }
        }
    }

    private func ageFrom(_ date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
}
