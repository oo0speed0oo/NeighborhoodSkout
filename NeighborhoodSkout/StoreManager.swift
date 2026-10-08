import Foundation

// MARK: - Persisted store envelope

struct NeighborhoodStore: Codable {
    var version: Int = 1
    var streets: [Street]
    var blocks: [Block]
    var savedAt: Date = Date()
}

// MARK: - StoreManager
// Handles JSON persistence in Application Support.
// This is the app's source of truth — not the CSV.

struct StoreManager {

    // MARK: - URLs

    private static var storeDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NeighborhoodSkout", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var storeURL: URL {
        storeDir.appendingPathComponent("neighborhood_data.json")
    }

    static var backupDir: URL {
        let dir = storeDir.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Encoder / decoder

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Save

    static func save(_ store: NeighborhoodStore) {
        var s = store; s.savedAt = Date()
        guard let data = try? encoder.encode(s) else { return }
        // .atomic writes to a temp file then renames — safe against crashes mid-write
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: - Load

    static func load() -> NeighborhoodStore? {
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        return try? decoder.decode(NeighborhoodStore.self, from: data)
    }

    // MARK: - Backups (keep last 5)

    static func makeBackup(of store: NeighborhoodStore) {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = backupDir.appendingPathComponent("backup_\(stamp).json")
        var s = store; s.savedAt = Date()
        guard let data = try? encoder.encode(s) else { return }
        try? data.write(to: url, options: .atomic)
        pruneBackups()
    }

    static func listBackups() -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: backupDir, includingPropertiesForKeys: [.creationDateKey]
        ) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a > b
            }
    }

    static func pruneBackups(keep: Int = 5) {
        for url in listBackups().dropFirst(keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - CSV migration
    // Called once on first launch after upgrade.
    // Reads the old Documents CSV and returns it as a NeighborhoodStore.
    // Also copies the CSV to the backup dir so nothing is lost.

    static func migrateFromCSV() -> NeighborhoodStore? {
        guard let result = CSVManager.load() else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let csvBackup = backupDir.appendingPathComponent("pre_migration_\(stamp).csv")
        try? FileManager.default.copyItem(at: CSVManager.csvURL, to: csvBackup)
        return NeighborhoodStore(streets: result.streets, blocks: result.blocks)
    }
}
