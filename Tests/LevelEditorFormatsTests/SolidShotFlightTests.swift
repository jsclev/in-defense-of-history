import XCTest
@testable import LevelEditorFormats

final class SolidShotFlightTests: XCTestCase {
    func testLongFrameHitsEveryBodyInTravelOrderButNotOffLine() {
        var shot = SolidShotFlight(range: 400)
        let end = shot.advance(from: .zero, heading: 0, speed: 520, seconds: 1)
        XCTAssertEqual(end, CGPoint(x: 400, y: 0))
        XCTAssertEqual(shot.remainingDistance, 0)
        let hits = shot.contacts(from: .zero, to: end, targets: [
            (3, CGPoint(x: 300, y: 0)), (1, CGPoint(x: 80, y: 0)),
            (2, CGPoint(x: 140, y: SolidShotFlight.hitRadius)),
            (4, CGPoint(x: 200, y: SolidShotFlight.hitRadius + 1))])
        XCTAssertEqual(hits, [1, 2, 3])
    }

    func testOverlappingFramesCannotHitSameEnemyTwice() {
        var shot = SolidShotFlight(range: 400)
        let target = [(id: 1, position: CGPoint(x: 60, y: 0))]
        XCTAssertEqual(shot.contacts(from: .zero, to: CGPoint(x: 60, y: 0), targets: target), [1])
        XCTAssertTrue(shot.contacts(from: CGPoint(x: 60, y: 0), to: CGPoint(x: 65, y: 0), targets: target).isEmpty)
        XCTAssertEqual(shot.hitIDs, [1])
    }

    func testTravelEndsAtRangeInEveryDirection() {
        for degrees in stride(from: 0, to: 360, by: 15) {
            let angle = CGFloat(degrees) * .pi / 180
            let start = CGPoint(x: 123, y: -47)
            var shot = SolidShotFlight(range: 478.63)
            let first = shot.advance(from: start, heading: angle, speed: 520, seconds: 0.2)
            let end = shot.advance(from: first, heading: angle, speed: 520, seconds: 100)
            XCTAssertEqual(hypot(end.x - start.x, end.y - start.y), 478.63, accuracy: 0.000001)
            XCTAssertEqual(shot.remainingDistance, 0)
            XCTAssertEqual(shot.advance(from: end, heading: angle, speed: 520, seconds: 1), end)
        }
    }

    func testStationaryPausedOrInvalidTimeCannotConsumeFlight() {
        var shot = SolidShotFlight(range: 100)
        for seconds in [0, -1, .nan, .infinity] {
            XCTAssertEqual(shot.advance(from: .zero, heading: 0, speed: 520, seconds: seconds), .zero)
            XCTAssertEqual(shot.remainingDistance, 100)
        }
        XCTAssertEqual(SolidShotFlight(range: .nan).remainingDistance, 0)
        XCTAssertEqual(SolidShotFlight(range: -5).remainingDistance, 0)
    }
}
