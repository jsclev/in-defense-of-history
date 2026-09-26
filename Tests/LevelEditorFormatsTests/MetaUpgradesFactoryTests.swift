import XCTest
import SQLite3
@testable import LevelEditorFormats

final class MetaUpgradesFactoryTests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    private func bits(_ selected: Set<MetaUpgrade>) -> UInt64 {
        MetaUpgradeProgression.bitOrder.enumerated().reduce(0) { value, entry in
            selected.contains(entry.element) ? value | (UInt64(1) << entry.offset) : value
        }
    }

    /// Independent oracle: exhaust all masks within each authored track, then
    /// take their Cartesian product. No factory enumeration or purchase API.
    private func expectedSelections(_ player: PlayerMetaUpgradeState) -> Set<Set<MetaUpgrade>> {
        let catalog = player.loadout.catalog
        var selections: [Set<MetaUpgrade>] = [[]]
        for track in catalog.tracks {
            let nodes = catalog.upgrades(in: track.id)
            let valid = (0..<(1 << nodes.count)).compactMap { mask -> Set<MetaUpgrade>? in
                let selected = Set(nodes.enumerated().filter { mask & (1 << $0.offset) != 0 }.map { $0.element.id })
                return selected.allSatisfy { catalog[$0].prerequisite.map(selected.contains) ?? true } ? selected : nil
            }
            selections = selections.flatMap { prior in valid.map { prior.union($0) } }
        }
        return Set(selections)
    }

    private func assertValid(_ progression: MetaUpgradeProgression, player: PlayerMetaUpgradeState,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let selection = progression.selected
        for upgrade in selection {
            if let prerequisite = player.loadout.catalog[upgrade].prerequisite {
                XCTAssertTrue(selection.contains(prerequisite), "\(upgrade) is missing \(prerequisite)", file: file, line: line)
            }
        }
        let loadout = try MetaUpgradeLoadout(catalog: player.loadout.catalog,
            starBudget: player.loadout.catalog.upgrades.reduce(0) { $0 + $1.cost }, selected: selection)
        XCTAssertEqual(loadout.spentStars, progression.spentStars, file: file, line: line)
        XCTAssertEqual(progression.rawValue, bits(selection), file: file, line: line)
    }

    func testBitIdentitiesRoundTripAndDistinguishEqualCostSelections() throws {
        let fixture = try AuthoredDatabaseFixture()
        let factory = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        let range = try factory.make(selected: [.rangeEstimation])
        let discount = try factory.make(selected: [.artificerCorps])
        XCTAssertEqual(range.rawValue, 1)
        XCTAssertEqual(discount.rawValue, 1 << 20)
        XCTAssertEqual(try factory.make(selected: [.artificerCorps, .modelCompany, .frenchContracts]).rawValue, 7 << 20)
        XCTAssertEqual(try factory.loadout(for: range).spentStars, try factory.loadout(for: discount).spentStars)
        XCTAssertNotEqual(range, discount)
        XCTAssertEqual(Set([range, discount]).count, 2)
        XCTAssertEqual(try factory.make(rawValue: range.rawValue), range)
        XCTAssertEqual(try factory.make(rawValue: discount.rawValue), discount)
        XCTAssertEqual(try factory.make(rawValue: 0).selected, [])
        XCTAssertEqual(Set(MetaUpgradeProgression.bitOrder), Set(MetaUpgrade.allCases))
        // Lock every existing storage identity independently of enum/SQL order.
        XCTAssertEqual(MetaUpgradeProgression.bitOrder.map(\.rawValue), [
            "rangeEstimation", "cartridgeDrill", "crossfire", "twoGoodVolleys",
            "campaignVeterans", "reliefCompanies", "fieldDressings", "bayonetCounterstroke",
            "gunCarriages", "thunderousReport", "ammunitionWagons", "batteryDoctrine",
            "forwardWorks", "preparedFireLanes", "workingParties", "powderWorks",
            "localSuppliers", "supplyConvoys", "forwardMagazines", "fieldHospitals",
            "artificerCorps", "modelCompany", "frenchContracts"
        ])
    }

    func testEveryGeneratedProgressionIsLegalAndEveryLegalSelectionIsGeneratedExactlyOnce() throws {
        let fixture = try AuthoredDatabaseFixture()
        let player = try fixture.db.playerMetaUpgradeDao.get()
        let factory = try MetaUpgradesFactory(catalog: player.loadout.catalog)
        XCTAssertEqual(Set(factory.progressions.map(\.selected)), expectedSelections(player))
        XCTAssertEqual(Set(factory.progressions).count, factory.progressions.count)
        XCTAssertEqual(factory.progressionsBySpentStars.values.reduce(0) { $0 + $1.count }, factory.progressions.count)
        for (spend, choices) in factory.progressionsBySpentStars {
            for progression in choices {
                try assertValid(progression, player: player)
                XCTAssertEqual(try factory.loadout(for: progression).spentStars, spend)
                XCTAssertEqual(try factory.make(rawValue: progression.rawValue), progression)
            }
        }
        let search = try GeneticMetaSearch(player: player)
        XCTAssertEqual(search.choicesByStars.mapValues { Set($0.map(\.selected)) },
                       factory.progressionsBySpentStars.filter { $0.key <= player.loadout.starBudget }.mapValues { Set($0.map(\.selected)) })
        XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get(), player)
    }

    func testRejectsEveryBrokenTrackMaskUnknownBitsAndOverBudgetImports() throws {
        let fixture = try AuthoredDatabaseFixture()
        let player = try fixture.db.playerMetaUpgradeDao.get()
        let factory = try MetaUpgradesFactory(catalog: player.loadout.catalog)
        for track in player.loadout.catalog.tracks {
            let nodes = player.loadout.catalog.upgrades(in: track.id)
            for mask in 0..<(1 << nodes.count) {
                let selected = Set(nodes.enumerated().filter { mask & (1 << $0.offset) != 0 }.map { $0.element.id })
                let valid = selected.allSatisfy { player.loadout.catalog[$0].prerequisite.map(selected.contains) ?? true }
                if valid {
                    XCTAssertEqual(try factory.make(rawValue: bits(selected)).selected, selected)
                } else {
                    XCTAssertThrowsError(try factory.make(selected: selected))
                    XCTAssertThrowsError(try factory.make(rawValue: bits(selected)))
                }
            }
        }
        for index in MetaUpgradeProgression.bitOrder.count..<UInt64.bitWidth {
            XCTAssertThrowsError(try factory.make(rawValue: UInt64(1) << index)) {
                XCTAssertTrue(String(describing: $0).contains("unknown upgrade bits"))
            }
        }
        XCTAssertThrowsError(try factory.make(rawValue: UInt64.max))
        let full = try factory.make(selected: Set(MetaUpgrade.allCases))
        XCTAssertEqual(try factory.make(rawValue: bits(Set(MetaUpgrade.allCases))), full)
        XCTAssertThrowsError(try factory.loadout(for: full, starBudget: player.loadout.starBudget))
    }

    func testSeededGenerationMutationAndCrossoverCannotProduceInvalidProgressions() throws {
        let fixture = try AuthoredDatabaseFixture()
        let player = try fixture.db.playerMetaUpgradeDao.get()
        let factory = try MetaUpgradesFactory(catalog: player.loadout.catalog)
        var rng = SeededRNG(seed: 4201), replayRNG = SeededRNG(seed: 4201)
        var samples: Set<MetaUpgradeProgression> = []
        for _ in 0..<300 {
            let stars = factory.progressionsBySpentStars.keys.sorted()[Int.random(in: 0..<factory.progressionsBySpentStars.count, using: &rng)]
            _ = Int.random(in: 0..<factory.progressionsBySpentStars.count, using: &replayRNG)
            let a = try factory.make(stars: stars, using: &rng)
            XCTAssertEqual(a, try factory.make(stars: stars, using: &replayRNG))
            let b = try factory.make(stars: stars, using: &rng)
            XCTAssertEqual(b, try factory.make(stars: stars, using: &replayRNG))
            let mutant = try factory.mutate(a, using: &rng)
            XCTAssertEqual(mutant, try factory.mutate(a, using: &replayRNG))
            if factory.progressionsBySpentStars[stars]!.count > 1 { XCTAssertNotEqual(a, mutant) }
            XCTAssertEqual(mutant.spentStars, stars)
            let child = try factory.crossover(a, b, using: &rng)
            XCTAssertEqual(child, try factory.crossover(a, b, using: &replayRNG))
            XCTAssertTrue(child.selected.isSubset(of: a.selected.union(b.selected)))
            for progression in [a, b, mutant, child] {
                try assertValid(progression, player: player)
                samples.insert(progression)
            }
        }
        XCTAssertGreaterThan(samples.count, 100)
        var singleStar: Set<MetaUpgradeProgression> = []
        for _ in 0..<100 { singleStar.insert(try factory.make(stars: 1, using: &rng)) }
        XCTAssertEqual(singleStar, Set(try XCTUnwrap(factory.progressionsBySpentStars[1])))
        XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get(), player)
    }

    func testStarInputDoesNotRequirePlayerStateAndRejectsUnreachableOrExhaustedSpends() throws {
        let fixture = try AuthoredDatabaseFixture()
        try fixture.db.playerMetaUpgradeDao.reset()
        try execute("UPDATE player_meta_upgrade_level_stars SET best_stars=0 WHERE profile_key='active'", in: fixture)
        let factory = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        var rng = SeededRNG(seed: 1)
        let empty = try factory.make(stars: 0)
        XCTAssertEqual(empty.rawValue, 0)
        XCTAssertEqual(try factory.make(stars: 0, using: &rng), empty)
        XCTAssertEqual(try factory.mutate(empty, using: &rng), empty)
        XCTAssertEqual(try factory.crossover(empty, empty, using: &rng), empty)
        for spend in [-1, Int.max] { XCTAssertThrowsError(try factory.make(stars: spend, using: &rng)) }
        let purchased = try factory.make(stars: 1, using: &rng)
        XCTAssertEqual(purchased.spentStars, 1)
        XCTAssertThrowsError(try fixture.db.playerMetaUpgradeDao.get().selecting(purchased.selected))
        XCTAssertThrowsError(try factory.loadout(for: purchased, starBudget: 0))
        XCTAssertThrowsError(try factory.crossover(empty, purchased, using: &rng))
        XCTAssertThrowsError(try factory.crossover(purchased, empty, using: &rng))
        var seen: Set<MetaUpgradeProgression> = []
        for _ in factory.progressionsBySpentStars[1]! {
            XCTAssertTrue(seen.insert(try factory.make(stars: 1, excluding: seen, using: &rng)).inserted)
        }
        XCTAssertThrowsError(try factory.make(stars: 1, excluding: seen, using: &rng))
        XCTAssertThrowsError(try factory.mutate(purchased, excluding: seen, using: &rng))
        try execute("UPDATE meta_upgrade SET star_cost=2*star_cost", in: fixture)
        let evenCosts = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        XCTAssertThrowsError(try evenCosts.make(stars: 1))
        XCTAssertEqual(try evenCosts.make(stars: 2).spentStars, 2)
        XCTAssertThrowsError(try evenCosts.loadout(for: purchased))
    }

    func testDatabaseCostsPrerequisitesAndDisplayOrderDriveFactoryWithoutChangingBitIdentities() throws {
        let fixture = try AuthoredDatabaseFixture()
        let original = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        XCTAssertThrowsError(try original.make(selected: [.rangeEstimation, .crossfire]))
        try execute("""
            UPDATE meta_upgrade SET star_cost=2 WHERE upgrade_key='rangeEstimation';
            UPDATE meta_upgrade SET prerequisite_key='rangeEstimation' WHERE upgrade_key='crossfire';
            UPDATE meta_upgrade_track SET display_order=20 WHERE track_key='marksmanship';
            UPDATE meta_upgrade_track SET display_order=1 WHERE track_key='command';
            UPDATE meta_upgrade_track SET display_order=6 WHERE track_key='marksmanship';
            """, in: fixture)
        let player = try fixture.db.playerMetaUpgradeDao.get()
        let factory = try MetaUpgradesFactory(catalog: player.loadout.catalog)
        let branch = try factory.make(selected: [.rangeEstimation, .crossfire])
        XCTAssertEqual(branch.rawValue, 5)
        XCTAssertEqual(try factory.loadout(for: branch).spentStars, 5)
        XCTAssertFalse(try XCTUnwrap(factory.progressionsBySpentStars[1]).contains { $0.selected == [.rangeEstimation] })
        XCTAssertTrue(try XCTUnwrap(factory.progressionsBySpentStars[2]).contains { $0.selected == [.rangeEstimation] })
        XCTAssertEqual(Set(factory.progressions.map(\.selected)), expectedSelections(player))
        XCTAssertThrowsError(try original.loadout(for: branch), "DNA must be revalidated against each factory's snapshot")
        try execute("UPDATE meta_upgrade SET prerequisite_key=NULL WHERE upgrade_key='cartridgeDrill'", in: fixture)
        let relaxed = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        XCTAssertEqual(try relaxed.make(selected: [.cartridgeDrill]).rawValue, 2)
        XCTAssertThrowsError(try factory.make(selected: [.cartridgeDrill]))
    }

    func testMissingMalformedAndCyclicDatabaseDefinitionsCannotConstructFactory() throws {
        let mutations: [(String, String)] = [
            ("PRAGMA foreign_keys=OFF; DELETE FROM meta_upgrade WHERE upgrade_key='powderWorks'", "powderWorks"),
            ("UPDATE meta_upgrade SET prerequisite_key='twoGoodVolleys' WHERE upgrade_key='rangeEstimation'", "prerequisite_key"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE meta_upgrade SET prerequisite_key='powderWorks' WHERE upgrade_key='powderWorks'", "prerequisite_key"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE meta_upgrade SET star_cost=0 WHERE upgrade_key='powderWorks'", "star_cost"),
            ("PRAGMA foreign_keys=OFF; UPDATE meta_upgrade SET prerequisite_key='missing' WHERE upgrade_key='powderWorks'", "prerequisite_key")
        ]
        for (sql, field) in mutations {
            let fixture = try AuthoredDatabaseFixture()
            try execute(sql, in: fixture)
            XCTAssertThrowsError(try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get()), sql) {
                XCTAssertTrue(String(describing: $0).contains(field), String(describing: $0))
            }
        }
    }
}
