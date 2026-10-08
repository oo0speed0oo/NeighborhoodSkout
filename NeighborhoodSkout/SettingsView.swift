import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: BlockMapViewModel
    @Environment(\.dismiss) private var dismiss

    // Notification time — mirror from UserDefaults via BirthdayNotificationManager
    @State private var notifTime: Date = {
        let mgr = BirthdayNotificationManager.shared
        var comps        = DateComponents()
        comps.hour       = mgr.notifHour
        comps.minute     = mgr.notifMinute
        return Calendar.current.date(from: comps) ?? Date()
    }()
    @State private var notifDayBefore: Bool = BirthdayNotificationManager.shared.notifDayBefore

    // Backups
    @State private var backups: [URL] = []
    @State private var confirmRestore: URL? = nil

    // Formatters
    private let backupFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                backupsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { backups = StoreManager.listBackups() }
            .confirmationDialog(
                "Restore this backup?",
                isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } }),
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let url = confirmRestore {
                        vm.restoreBackup(from: url)
                        backups = StoreManager.listBackups()
                        confirmRestore = nil
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { confirmRestore = nil }
            } message: {
                Text("Your current data will be backed up first.")
            }
        }
    }

    // MARK: - Notification section

    var notificationSection: some View {
        Section {
            DatePicker(
                "Alert time",
                selection: $notifTime,
                displayedComponents: .hourAndMinute
            )
            .onChange(of: notifTime) { time in
                let comps  = Calendar.current.dateComponents([.hour, .minute], from: time)
                let hour   = comps.hour ?? 9
                let minute = comps.minute ?? 0
                BirthdayNotificationManager.shared.setTime(hour: hour, minute: minute)
                reschedule()
            }

            Toggle("Remind day before", isOn: $notifDayBefore)
                .onChange(of: notifDayBefore) { on in
                    BirthdayNotificationManager.shared.setDayBefore(on)
                    reschedule()
                }
        } header: {
            Text("Birthday Notifications")
        } footer: {
            Text("Up to 60 upcoming birthdays are scheduled. Changing this time reschedules them immediately.")
        }
    }

    // MARK: - Backups section

    var backupsSection: some View {
        Section {
            if backups.isEmpty {
                Text("No backups yet")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(backups, id: \.path) { url in
                    Button(action: { confirmRestore = url }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backupLabel(url))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(backupDate(url) ?? url.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.accentColor)
                                .font(.subheadline)
                        }
                    }
                }
            }
        } header: {
            Text("Backups")
        } footer: {
            Text("Backups are created automatically before every import or restore. The 5 most recent are kept.")
        }
    }

    // MARK: - About section

    var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion).foregroundColor(.secondary)
            }
            HStack {
                Text("Language")
                Spacer()
                Text("English / 日本語").foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func reschedule() {
        BirthdayNotificationManager.shared.scheduleAll(blocks: vm.blocks, streets: vm.streets)
    }

    private func backupLabel(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        if name.hasPrefix("pre_migration_") { return "Pre-migration backup" }
        if name.hasPrefix("backup_") { return "Backup" }
        return name
    }

    private func backupDate(_ url: URL) -> String? {
        guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else { return nil }
        return backupFormatter.string(from: date)
    }
}

#Preview {
    SettingsView(vm: BlockMapViewModel())
}
