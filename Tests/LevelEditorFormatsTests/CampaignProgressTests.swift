import XCTest
import SQLite3
@testable import LevelEditorFormats

final class CampaignProgressTests: XCTestCase {
    @MainActor func testAuthoredLedgerShowsFourteenVictoriesAndCurrentCharleston() throws {
        let fixture = try AuthoredDatabaseFixture()
        let levels = try fixture.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
        let store = try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao)
        let states = try CampaignProgress.states(orderedLevelIDs: levels.map(\.id), bestStarsByLevel: store.bestStarsByLevel)
        XCTAssertEqual(levels.count, 15)
        XCTAssertEqual(Array(states.prefix(14)), Array(repeating: .completed, count: 14))
        XCTAssertEqual(states[14], .current)
        XCTAssertEqual(levels[14].name, "Charleston")

        // A victory updates the observable map snapshot; restoring the authored
        // profile returns the final marker to current without a Swift preset.
        try store.recordVictory(levelID: levels[14].id, lives: 20, startingLives: 20)
        XCTAssertTrue(try CampaignProgress.states(orderedLevelIDs: levels.map(\.id), bestStarsByLevel: store.bestStarsByLevel).allSatisfy { $0 == .completed })
        try store.restoreLevel15()
        XCTAssertEqual(try CampaignProgress.states(orderedLevelIDs: levels.map(\.id), bestStarsByLevel: store.bestStarsByLevel), states)
    }

    @MainActor func testDatabaseEditsMoveCurrentMarkerAndMissingResultsFail() throws {
        let fixture = try AuthoredDatabaseFixture()
        let levels = try fixture.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
        let store = try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao)
        // Refund first so reducing earned stars leaves the upgrade ledger valid.
        try store.reset()
        let id = levels[13].id.uuidString.lowercased()
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE player_meta_upgrade_level_stars SET best_stars=0 WHERE profile_key='active' AND level_info_id='\(id)'", nil, nil, nil), SQLITE_OK)
        try store.reload()
        let states = try CampaignProgress.states(orderedLevelIDs: levels.map(\.id), bestStarsByLevel: store.bestStarsByLevel)
        XCTAssertEqual(states[13], .current)
        XCTAssertEqual(states[14], .upcoming)

        XCTAssertEqual(sqlite3_exec(fixture.connection, "DELETE FROM player_meta_upgrade_level_stars WHERE profile_key='active' AND level_info_id='\(id)'", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try store.reload()) {
            XCTAssertTrue(String(describing: $0).lowercased().contains(id))
            XCTAssertTrue(String(describing: $0).contains("best_stars"))
        }
        for invalid in [-1, 4] {
            XCTAssertThrowsError(try CampaignProgress.states(orderedLevelIDs: [levels[13].id], bestStarsByLevel: [levels[13].id: invalid]))
        }
        XCTAssertThrowsError(try CampaignProgress.states(orderedLevelIDs: [levels[13].id], bestStarsByLevel: [:]))
    }
}
