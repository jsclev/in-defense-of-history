import XCTest
@testable import LevelEditorFormats

final class DemolitionExplosionTests: XCTestCase {
    func testIgnitionSmokeAndCompletionNeverLoop() {
        XCTAssertEqual(DemolitionExplosion.frame(at: 0), 0)
        XCTAssertEqual(DemolitionExplosion.frame(at: 0.18), 3)
        XCTAssertEqual(DemolitionExplosion.frame(at: 0.7), 7)
        for (index, end) in DemolitionExplosion.frameEnds.enumerated() {
            XCTAssertEqual(DemolitionExplosion.frame(at: end - 0.0001), index)
            XCTAssertEqual(DemolitionExplosion.frame(at: end), index == 11 ? nil : index + 1)
        }
        for age in [-1, Double.nan, Double.infinity, 1.3, 8, 100] {
            XCTAssertNil(DemolitionExplosion.frame(at: age))
            XCTAssertEqual(DemolitionExplosion.opacity(at: age), 0)
        }
    }

    func testSmokeFadesWithoutAnotherFlash() {
        XCTAssertEqual(DemolitionExplosion.opacity(at: 0.18), 1)
        var previous = 1.0
        for age in stride(from: 0.24, through: 1.3, by: 0.01) {
            let opacity = DemolitionExplosion.opacity(at: age)
            XCTAssertLessThanOrEqual(opacity, previous)
            XCTAssertGreaterThanOrEqual(opacity, 0)
            previous = opacity
        }
        XCTAssertLessThan(DemolitionExplosion.opacity(at: 1.29), 0.04)
    }

    func testAtlasCellsKeepSharedBoundsAndGroundAnchorAtEveryDensity() throws {
        for density in 1...3 {
            let side = CGFloat(160 * density)
            let sheet = CGSize(width: side * 4, height: side * 3)
            for index in 0..<12 {
                let rect = try XCTUnwrap(DemolitionExplosion.frameRect(index: index, sheetSize: sheet))
                XCTAssertEqual(rect.size, CGSize(width: side, height: side))
                XCTAssertEqual(rect.minX, CGFloat(index % 4) * side)
                XCTAssertEqual(rect.minY, CGFloat(index / 4) * side)
                XCTAssertTrue(CGRect(origin: .zero, size: sheet).contains(rect))
            }
        }
        XCTAssertEqual(DemolitionExplosion.groundAnchorY, 0.8)
        XCTAssertNil(DemolitionExplosion.frameRect(index: 12, sheetSize: CGSize(width: 640, height: 480)))
    }
}
