import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyMoraleResponseTests: XCTestCase {
    func testThresholdIncludesFortyAndRecoversAboveIt() {
        let response = EnemyMoraleResponse()
        for value in [0.0, 20, 39.999, 40] {
            XCTAssertEqual(response.movementMultiplier(morale: value), 2.0 / 3)
            XCTAssertEqual(response.damageMultiplier(morale: value), 2.0 / 3)
        }
        for value in [40.001, 90, 100] {
            XCTAssertEqual(response.movementMultiplier(morale: value), 1)
            XCTAssertEqual(response.damageMultiplier(morale: value), 1)
        }
    }

    func testEnemyThresholdsAreIndependent() {
        let response = EnemyMoraleResponse(speedThreshold: 0.3, attackThreshold: 0.6,
                                          speedMultiplier: 0.5, attackMultiplier: 0.75)
        XCTAssertEqual(response.movementMultiplier(morale: 40), 1)
        XCTAssertEqual(response.damageMultiplier(morale: 40), 0.75)
        XCTAssertEqual(response.movementMultiplier(morale: 30), 0.5)
    }

    func testSlowingBlockingAndRecoveryDoNotRecalculatePastTravel() {
        var morale = EnemyMorale()
        let response = EnemyMoraleResponse()
        var distance = morale.advance(seconds: 10, baseSpeed: 60, response: response, blocked: false)
        XCTAssertEqual(distance, 600)
        morale.apply(loss: 60, direction: 1)
        distance += morale.advance(seconds: 2, baseSpeed: 60, response: response, blocked: false)
        XCTAssertEqual(distance, 680, accuracy: 1e-8)
        distance += morale.advance(seconds: 0, baseSpeed: 60, response: response, blocked: false)
        XCTAssertEqual(distance, 680, accuracy: 1e-8)
        distance += morale.advance(seconds: 4, baseSpeed: 60, response: response, blocked: true)
        XCTAssertEqual(distance, 680, accuracy: 1e-8)
        XCTAssertGreaterThan(morale.value, 40)
        distance += morale.advance(seconds: 1, baseSpeed: 60, response: response, blocked: false)
        XCTAssertEqual(distance, 740, accuracy: 1e-8)
    }

    func testRecoveryCrossingHasTheSameDistanceAtDifferentFrameRates() {
        var once = EnemyMorale()
        once.apply(loss: 61, direction: 1)
        var many = once
        let response = EnemyMoraleResponse()
        let single = once.advance(seconds: 10, baseSpeed: 60, response: response, blocked: false)
        var stepped = 0.0
        for _ in 0..<600 {
            stepped += many.advance(seconds: 1.0 / 60, baseSpeed: 60, response: response, blocked: false)
        }
        XCTAssertEqual(single, 500, accuracy: 1e-8) // Five seconds at 40, five at 60.
        XCTAssertEqual(single, stepped, accuracy: 1e-8)
        XCTAssertEqual(once.value, many.value, accuracy: 1e-8)
    }

    func testDatabaseLoadsEveryEnemyMetricAndPerTypeOverrides() throws {
        let fixture = try AuthoredDatabaseFixture()
        let db = fixture.db
        let all = try db.enemyTypeDao.getAll()
        XCTAssertEqual(all.count, 14)
        XCTAssertTrue(all.allSatisfy { $0.stats.moraleResponse == EnemyMoraleResponse() })
        let connection = fixture.connection
        XCTAssertEqual(sqlite3_exec(connection, "UPDATE enemy_type SET morale_speed_threshold=0.3, morale_attack_threshold=0.6 WHERE enemy_type_key='\(Foe.redcoatRegular.rawValue)'", nil, nil, nil), SQLITE_OK)
        let redcoat = try XCTUnwrap(db.enemyTypeDao.getAll().first { $0.id == Foe.redcoatRegular.id })
        XCTAssertEqual(redcoat.stats.moraleResponse.speedThreshold, 0.3)
        XCTAssertEqual(redcoat.stats.moraleResponse.attackThreshold, 0.6)
    }

    func testPersistedStatsRoundTripAndOlderStatsGetInitialThresholds() throws {
        let original = EnemyStats(maxHP: 90, speed: 60, cover: 0.05, discipline: 0.6,
            hardiness: 0.7, damageMin: 4, damageMax: 7, gold: 15, livesCost: 1,
            breakBand: 0.3...0.45, moraleResponse: EnemyMoraleResponse(speedThreshold: 0.25))
        let bytes = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(EnemyStats.self, from: bytes), original)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        legacy.removeValue(forKey: "moraleResponse")
        let restored = try JSONDecoder().decode(EnemyStats.self,
            from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored.moraleResponse, EnemyMoraleResponse())
        XCTAssertEqual(restored.maxHP, original.maxHP)
    }

    func testMaximumThresholdCannotBeRecoveredPast() {
        var morale = EnemyMorale()
        XCTAssertEqual(morale.advance(seconds: 1, baseSpeed: 60,
            response: EnemyMoraleResponse(speedThreshold: 1), blocked: false), 40, accuracy: 1e-8)
    }
}
