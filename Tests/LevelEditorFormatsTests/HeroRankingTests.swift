import XCTest
import SQLite3
@testable import LevelEditorFormats

final class HeroRankingTests: XCTestCase {
    private var conn: OpaquePointer?

    override func setUpWithError() throws {
        try super.setUpWithError()
        XCTAssertEqual(sqlite3_open(":memory:", &conn), SQLITE_OK)
        try execute("PRAGMA foreign_keys = ON")

        // Use the production schema and every seed in the actual build order,
        // without running the shell script's deletion or Documents copy steps.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let dbDirectory = root.appendingPathComponent("Db")
        let script = try String(contentsOf: dbDirectory.appendingPathComponent("create_db.sh"), encoding: .utf8)
        let paths = script.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("sqlite3 ") && $0.contains(" < ") }
            .compactMap { $0.components(separatedBy: " < ").last }
        XCTAssertFalse(paths.isEmpty)
        for path in paths {
            try execute(String(contentsOf: dbDirectory.appendingPathComponent(path), encoding: .utf8))
        }
    }

    override func tearDownWithError() throws {
        if let conn { XCTAssertEqual(sqlite3_close(conn), SQLITE_OK) }
        conn = nil
        try super.tearDownWithError()
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(conn, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(conn)))
        }
    }

    func testProductionSeedsExposeRankingThroughDAO() throws {
        let dao = HeroDAO(conn: conn)
        let heroes = try dao.getAll()
        XCTAssertEqual(heroes.count, 15)
        XCTAssertTrue(heroes.allSatisfy { (1...100).contains($0.ranking) })
        XCTAssertGreaterThan(Set(heroes.map(\.ranking)).count, 1)

        // Compare every model against the stored values to catch column-index
        // mistakes and ensure all roster entries survive the DAO joins.
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(conn, "SELECT short_name, ranking FROM hero", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var stored: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            stored[String(cString: sqlite3_column_text(stmt, 0))] = Int(sqlite3_column_int(stmt, 1))
        }
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: heroes.map { ($0.shortName, $0.ranking) }), stored)

        let selectedIDs = try dao.getSelectedHeroIds()
        let selected = heroes.filter { selectedIDs.contains($0.id) }
        XCTAssertEqual(Set(selected.map(\.shortName)), ["Henry Knox", "George Washington"])

        // Values must come from the database again, including both endpoints;
        // this guards against defaults, hardcoded ratings, and cached values.
        try execute("UPDATE hero SET ranking = 1 WHERE short_name = 'Henry Knox'")
        try execute("UPDATE hero SET ranking = 100 WHERE short_name = 'George Washington'")
        let updated = try dao.getAll()
        XCTAssertEqual(updated.first { $0.shortName == "Henry Knox" }?.ranking, 1)
        XCTAssertEqual(updated.first { $0.shortName == "George Washington" }?.ranking, 100)
    }

    func testRankingEnforcesWholeNumbersFromOneToOneHundred() throws {
        for value in ["NULL", "0", "-1", "101", "50.5", "'invalid'"] {
            XCTAssertThrowsError(try execute("UPDATE hero SET ranking = \(value)"), "Invalid ranking: \(value)")
        }
    }

    func testEveryChosenHeroHasDatabaseCombatStats() throws {
        let dao = HeroDAO(conn: conn)
        for hero in try dao.getAll() {
            XCTAssertGreaterThan(try dao.getCombatStats(heroID: hero.id).hp, 0, hero.shortName)
        }
        XCTAssertThrowsError(try dao.getCombatStats(heroID: UUID()))
    }

    func testOneOrTwoHeroesAlwaysHaveRankingDerivedRoles() throws {
        let dao = HeroDAO(conn: conn)
        let seeded = try dao.getSelectedHeroes()
        let washington = seeded.primary
        let knox = try XCTUnwrap(seeded.secondary)
        XCTAssertEqual(washington.shortName, "George Washington")
        XCTAssertEqual(knox.shortName, "Henry Knox")
        for ids in [[knox.id, washington.id], [washington.id, knox.id]] {
            try dao.setSelectedHeroes(ids)
            let selected = try dao.getSelectedHeroes()
            XCTAssertEqual(selected.primary.id, washington.id)
            XCTAssertEqual(selected.secondary?.id, knox.id)
            XCTAssertEqual(try dao.getSelectedHeroIds(), selected.ids)
            XCTAssertEqual(try storedSelectionIDs(), selected.ids)
        }
        try dao.setSelectedHeroes([knox.id])
        let single = try dao.getSelectedHeroes()
        XCTAssertEqual(single.primary.id, knox.id)
        XCTAssertNil(single.secondary)
        XCTAssertEqual(single.role(for: knox.id), .primary)
        XCTAssertNil(single.role(for: washington.id))
        XCTAssertEqual(try single.toggling(knox), single, "Cannot remove the only hero")
    }

    func testRankingEditsAndTiesDoNotDependOnSavedSlots() throws {
        let dao = HeroDAO(conn: conn)
        let old = try dao.getSelectedHeroes()
        let knoxID = try XCTUnwrap(old.secondary?.id)
        try execute("UPDATE hero SET ranking = 100 WHERE short_name = 'Henry Knox'")
        XCTAssertEqual(try dao.getSelectedHeroIds().first, knoxID)
        XCTAssertEqual(try dao.getSelectedHeroes().primary.id, knoxID)
        try execute("UPDATE hero SET ranking = 80")
        let tiedIDs = old.ids.sorted { $0.uuidString < $1.uuidString }
        XCTAssertEqual(try dao.getSelectedHeroIds(), tiedIDs)
        for input in [tiedIDs, Array(tiedIDs.reversed())] {
            try dao.setSelectedHeroes(input)
            XCTAssertEqual(try dao.getSelectedHeroes().ids, tiedIDs)
            XCTAssertEqual(try storedSelectionIDs(), tiedIDs)
        }
    }

    func testRemovingAndReplacingHeroesReassignsRoles() throws {
        try execute("INSERT OR IGNORE INTO player_unlocked_hero (id, hero_id) SELECT id, id FROM hero")
        let dao = HeroDAO(conn: conn)
        let pair = try dao.getSelectedHeroes()
        let knox = try XCTUnwrap(pair.secondary)
        let morgan = try XCTUnwrap(dao.getAll().first { $0.shortName == "Daniel Morgan" })
        let onlyKnox = try pair.toggling(pair.primary)
        XCTAssertEqual(onlyKnox.primary.id, knox.id)
        XCTAssertNil(onlyKnox.secondary)
        let upgraded = try onlyKnox.toggling(morgan)
        XCTAssertEqual(upgraded.primary.id, morgan.id)
        XCTAssertEqual(upgraded.secondary?.id, knox.id)
        let replacement = try pair.toggling(morgan)
        XCTAssertEqual(replacement.primary.id, pair.primary.id)
        XCTAssertEqual(replacement.secondary?.id, morgan.id)
        XCTAssertNil(try pair.toggling(knox).secondary)
    }

    func testInvalidChoicesLeavePreviousSelectionIntact() throws {
        let dao = HeroDAO(conn: conn)
        let original = try dao.getSelectedHeroIds()
        let third = try XCTUnwrap(dao.getAll().first { !original.contains($0.id) })
        for input in [[], [original[0], original[0]], original + [third.id], [UUID()]] {
            XCTAssertThrowsError(try dao.setSelectedHeroes(input))
            XCTAssertEqual(try dao.getSelectedHeroIds(), original)
        }
        XCTAssertThrowsError(try HeroSelection(heroes: []))
        XCTAssertThrowsError(try HeroSelection(heroes: Array(dao.getAll().prefix(3))))
        let locked = try XCTUnwrap(dao.getAll().first { !$0.unlocked && !original.contains($0.id) })
        XCTAssertThrowsError(try dao.getSelectedHeroes().toggling(locked))
    }

    func testFailedSecondInsertRollsBackTheEntireChoice() throws {
        let dao = HeroDAO(conn: conn)
        let original = try dao.getSelectedHeroIds()
        try execute("""
            CREATE TRIGGER fail_secondary BEFORE INSERT ON player_selected_hero
            WHEN NEW.selection_slot = 2
            BEGIN SELECT RAISE(ABORT, 'test insertion failure'); END;
            """)
        XCTAssertThrowsError(try dao.setSelectedHeroes(Array(original.reversed())))
        XCTAssertEqual(try dao.getSelectedHeroIds(), original)
        XCTAssertEqual(try storedSelectionIDs(), original)
    }

    func testPreferencesRestoreOneHeroAndNormalizeOldOrder() throws {
        let suite = "HeroSelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let dao = HeroDAO(conn: conn)
        let seeded = try dao.getSelectedHeroes()
        let store = HeroSelectionStore(dao: dao, defaults: defaults)
        defaults.set(seeded.ids.reversed().map(\.uuidString).joined(separator: ","), forKey: HeroSelectionStore.key)
        XCTAssertEqual(try store.load(), seeded)
        XCTAssertEqual(defaults.string(forKey: HeroSelectionStore.key), seeded.ids.map(\.uuidString).joined(separator: ","))
        let one = try HeroSelection(heroes: [XCTUnwrap(seeded.secondary)])
        try store.save(one)
        // Simulate the bundled database restoring its default pair at startup.
        try dao.setSelectedHeroes(seeded.ids)
        XCTAssertEqual(try store.load(), one)
        XCTAssertEqual(try dao.getSelectedHeroes(), one)
        defaults.set("invalid,\(one.primary.id.uuidString.lowercased()),\(one.primary.id.uuidString)", forKey: HeroSelectionStore.key)
        XCTAssertEqual(try store.load(), one, "Old preferences are normalized and deduplicated")
        defaults.set("", forKey: HeroSelectionStore.key)
        try execute("DELETE FROM player_selected_hero")
        let fallback = try store.load()
        XCTAssertEqual(fallback.primary.shortName, "Israel Putnam")
        XCTAssertNil(fallback.secondary)
    }

    private func storedSelectionIDs() throws -> [UUID] {
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(conn, "SELECT hero_id FROM player_selected_hero ORDER BY selection_slot", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var ids: [UUID] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(try XCTUnwrap(UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0)))))
        }
        return ids
    }
}
