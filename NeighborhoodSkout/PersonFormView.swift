import SwiftUI
import PhotosUI

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

    // Photo state — changes are applied on Save, not immediately
    @State private var personId       = UUID()
    @State private var pickerItem:    PhotosPickerItem? = nil
    @State private var pendingPhoto:  UIImage? = nil   // newly picked, not yet saved
    @State private var currentPhoto:  UIImage? = nil   // loaded from store on appear
    @State private var removePhoto    = false

    var displayedPhoto: UIImage? {
        removePhoto ? nil : (pendingPhoto ?? currentPhoto)
    }

    var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        // Photo circle
                        Group {
                            if let img = displayedPhoto {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 60, height: 60).clipShape(Circle())
                                    .overlay(Circle().stroke(gender.borderColor, lineWidth: 1.5))
                            } else {
                                ZStack {
                                    Circle().fill(gender.color).frame(width: 60, height: 60)
                                        .overlay(Circle().stroke(gender.borderColor, lineWidth: 1.5))
                                    Text(gender.icon).font(.title)
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Text(displayedPhoto != nil ? "Change Photo" : "Add Photo")
                                    .font(.callout).foregroundColor(.accentColor)
                            }
                            if displayedPhoto != nil {
                                Button("Remove Photo") { removePhoto = true; pendingPhoto = nil }
                                    .font(.caption).foregroundColor(.red)
                            }
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 4)
                } header: { Text("Photo") }

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
                        // Apply photo changes before saving the person
                        let photoURL = PhotoStore.personURL(personId)
                        if let img = pendingPhoto {
                            PhotoStore.save(img, to: photoURL)
                        } else if removePhoto {
                            PhotoStore.delete(photoURL)
                        }
                        let p = Person(
                            id:        personId,
                            firstName: firstName.trimmingCharacters(in: .whitespaces),
                            lastName:  lastName.trimmingCharacters(in: .whitespaces),
                            gender:    gender,
                            birthday:  birthday,
                            role:      role,
                            lineId:    Self.cleanLineId(lineId)
                        )
                        // Ask for notification permission the first time a birthday is saved
                        BirthdayNotificationManager.shared.requestPermissionIfNeeded()
                        onSave(p)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let p = existing {
                    personId  = p.id
                    firstName = p.firstName
                    lastName  = p.lastName
                    gender    = p.gender
                    birthday  = p.birthday
                    role      = p.role
                    lineId    = p.lineId
                    currentPhoto = PhotoStore.load(PhotoStore.personURL(p.id))
                }
            }
            .onChange(of: pickerItem) { item in
                Task {
                    guard let item else { return }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run { pendingPhoto = image; removePhoto = false }
                    }
                }
            }
        }
    }

    private func ageFrom(_ date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }

    // Strip leading ~ that users sometimes type by mistake (we add it in the LINE URL)
    static func cleanLineId(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        while s.hasPrefix("~") { s = String(s.dropFirst()) }
        return s
    }
}
