import Foundation
import OSLog

final class SimulatorStore {
    let db: Db
    static var executableURL: URL {
        get throws {
            guard let url = Bundle.main.executableURL else {
                throw DbError.Db(message: "Cannot locate LibertyLineSimulator executable")
            }
            return url.resolvingSymlinksInPath()
        }
    }

    init(existing: URL, readOnly: Bool = false) throws {
        SimulatorLog.database.info("Opening database; readOnly=\(readOnly) path=\(existing.path, privacy: .private(mask: .hash))")
        do {
            db = try SimulatorDatabase.open(existing, readOnly: readOnly)
        } catch {
            SimulatorLog.database.error("Database open failed; path=\(existing.path, privacy: .private(mask: .hash)) detail=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    init(destination: URL?, content: URL) throws {
        SimulatorLog.database.notice("Creating invocation database; source=\(content.path, privacy: .private(mask: .hash))")
        do {
            let source = try SimulatorDatabase.open(content, readOnly: true)
            defer { source.close() }
            let target = try destination ?? SimulatorDatabase.destination(beside: Self.executableURL, buildName: BuildVersion.version)
            db = try SimulatorDatabase.create(source: source, destination: target, arguments: CommandLine.arguments)
            SimulatorLog.database.notice("Invocation database ready; path=\(target.path, privacy: .private(mask: .hash))")
        } catch {
            SimulatorLog.database.error("Invocation database creation failed: \(String(describing: error), privacy: .private)")
            throw error
        }
    }

    /// Installer-only preparation from a freshly generated authored database.
    static func prepareStarter(source: URL, destination: URL) throws {
        SimulatorLog.database.notice("Preparing starter database; build=\(BuildVersion.version, privacy: .public)")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw DbError.Db(message: "Generated content database does not exist: \(source.path)")
        }
        let directory = Db.authoredDatabaseURL.deletingLastPathComponent()
        let authored = Db(dbPath: source.path, fullRefresh: false,
                          levelGeoJSONDao: LevelGeoJSONDAO(directory: directory), readOnly: true)
        defer { authored.close() }
        let starter = try SimulatorDatabase.create(source: authored, destination: destination,
            arguments: CommandLine.arguments, schema: directory.appendingPathComponent("DDL/create_simulator_invocation.sql"))
        defer { starter.close() }
        try starter.simulatorInvocationDao.saveDocument(JSONEncoder().encode(
            ["kind": "simulator-starter", "buildName": BuildVersion.version]), name: "starter.json")
        SimulatorLog.database.notice("Starter database ready; build=\(BuildVersion.version, privacy: .public) path=\(destination.path, privacy: .private(mask: .hash))")
    }
}

/// JSON checkpoints live in SQLite. File exports are an explicit convenience.
final class SimulatorReports {
    private let db: Db
    private let exports: Bool
    let root: URL

    init(db: Db, directory: String?) throws {
        self.db = db
        exports = directory != nil
        root = directory.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: db.path).deletingPathExtension()
        if exports {
            let checkout = Db.authoredDatabaseURL.deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath().path
            let path = root.resolvingSymlinksInPath().path
            guard path != checkout, !path.hasPrefix(checkout + "/") else {
                throw DbError.Db(message: "Report exports must be outside the source checkout")
            }
            if FileManager.default.fileExists(atPath: root.path) {
                guard try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty else {
                    throw DbError.Db(message: "Use a new, empty report directory")
                }
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    func write(_ data: Data, to url: URL) throws {
        let prefix = root.path + "/"
        guard url.path.hasPrefix(prefix) else { throw DbError.Db(message: "Report is outside its invocation directory") }
        let name = String(url.path.dropFirst(prefix.count))
        do {
            try db.simulatorInvocationDao.saveDocument(data, name: name)
            SimulatorLog.database.debug("Saved report in SQLite; document=\(name, privacy: .public) bytes=\(data.count)")
            if exports {
                try data.write(to: url, options: .atomic)
                SimulatorLog.database.debug("Exported report; document=\(name, privacy: .public) path=\(url.path, privacy: .private(mask: .hash))")
            }
        } catch {
            SimulatorLog.database.error("Report write failed; document=\(name, privacy: .public) detail=\(String(describing: error), privacy: .private)")
            throw error
        }
    }
}
