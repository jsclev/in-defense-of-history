import Foundation

/// Refresh before opening SQLite. Old journals must never replay over new seeds.
public enum BundledDatabase {
    @discardableResult
    public static func prepare(source: URL, destination: URL) throws -> URL {
        let files = FileManager.default
        let content = try Data(contentsOf: source)
        try files.createDirectory(at: destination.deletingLastPathComponent(),
                                  withIntermediateDirectories: true)
        try content.write(to: destination, options: .atomic)
        for suffix in ["-wal", "-shm", "-journal"] {
            let sidecar = URL(fileURLWithPath: destination.path + suffix)
            if files.fileExists(atPath: sidecar.path) { try files.removeItem(at: sidecar) }
        }
        return destination
    }

    /// Delete preferences written by older builds; never import them into SQLite.
    public static func discardLegacyPreferences(domain: String, defaults: UserDefaults = .standard) {
        defaults.removePersistentDomain(forName: domain)
    }
}
