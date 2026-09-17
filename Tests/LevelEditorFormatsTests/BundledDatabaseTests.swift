import XCTest
@testable import LevelEditorFormats

final class BundledDatabaseTests: XCTestCase {
    private var directory: URL!
    private var source: URL!
    private var destination: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Db/in_defense_of_history.sqlite")
        destination = directory.appendingPathComponent("Documents/game.sqlite")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testRefreshReplacesEditedPlayerStateAndAllSidecars() throws {
        try BundledDatabase.prepare(source: source, destination: destination)
        let db = Db(dbPath: destination.path, fullRefresh: false)
        let authoredHeroes = try db.heroDao.getSelectedHeroes()
        let authoredSettings = try db.playerSettingsDao.get()
        try db.heroDao.setSelectedHeroes([authoredHeroes.primary.id])
        var changed = authoredSettings
        changed.debugMode.toggle()
        changed.showDebugInfo.toggle()
        changed.showDebugLayoutGuides.toggle()
        changed.enemyEscapeHapticsEnabled.toggle()
        try db.playerSettingsDao.set(changed)
        db.close()
        for suffix in ["-wal", "-shm", "-journal"] {
            try Data("stale SQLite state".utf8).write(to: URL(fileURLWithPath: destination.path + suffix))
        }

        try BundledDatabase.prepare(source: source, destination: destination)
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: source),
                       "Every database byte comes from the new bundle")
        for suffix in ["-wal", "-shm", "-journal"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path + suffix))
        }
        let refreshed = Db(dbPath: destination.path, fullRefresh: false)
        defer { refreshed.close() }
        XCTAssertEqual(try refreshed.heroDao.getSelectedHeroes(), authoredHeroes)
        XCTAssertEqual(try refreshed.playerSettingsDao.get(), authoredSettings)
    }

    func testFailedRefreshThrowsInsteadOfReturningOldDatabase() throws {
        try BundledDatabase.prepare(source: source, destination: destination)
        let old = try Data(contentsOf: destination)
        XCTAssertThrowsError(try BundledDatabase.prepare(
            source: directory.appendingPathComponent("missing.sqlite"),
            destination: destination))
        XCTAssertEqual(try Data(contentsOf: destination), old)
    }

    func testEveryPreparationRefreshesPlayerState() throws {
        try BundledDatabase.prepare(source: source, destination: destination)
        let db = Db(dbPath: destination.path, fullRefresh: false)
        let authored = try db.heroDao.getSelectedHeroIds()
        try db.heroDao.setSelectedHeroes([try XCTUnwrap(authored.first)])
        db.close()
        try BundledDatabase.prepare(source: source, destination: destination)
        let reopened = Db(dbPath: destination.path, fullRefresh: false)
        defer { reopened.close() }
        XCTAssertEqual(try reopened.heroDao.getSelectedHeroIds(), authored)
    }

    func testAllLegacyAppPreferencesAreDiscardedWithoutImport() throws {
        let domain = "BundledDatabaseTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.setPersistentDomain(["selectedHeroIDs": UUID().uuidString,
            "debugMode": true, "enemyEscapeHapticsEnabled": false,
            "unknownOldPlayerState": "old"], forName: domain)
        BundledDatabase.discardLegacyPreferences(domain: domain, defaults: defaults)
        XCTAssertTrue(defaults.persistentDomain(forName: domain)?.isEmpty ?? true)
    }
}
