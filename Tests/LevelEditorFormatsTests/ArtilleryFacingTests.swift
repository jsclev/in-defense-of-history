import XCTest
@testable import LevelEditorFormats

final class ArtilleryFacingTests: XCTestCase {
    func testMapAxesMatchClockwiseAtlasWithoutFlippingNorthAndSouth() {
        let origin = CGPoint(x: 450, y: 600)
        for (offset, expected) in [(CGPoint(x: 100, y: 0), 0),
                                   (CGPoint(x: 0, y: -100), 8),
                                   (CGPoint(x: -100, y: 0), 16),
                                   (CGPoint(x: 0, y: 100), 24)] {
            let target = CGPoint(x: origin.x + offset.x, y: origin.y + offset.y)
            XCTAssertEqual(ArtilleryFacing.aiming(from: origin, at: target,
                           previous: .initial).frameIndex, expected)
        }
    }

    func testEveryFrameAndHalfStepBoundaryIncludingWrap() {
        for index in 0..<32 {
            let angle = -Double(index) * ArtilleryFacing.angleStep
            for revolution in -3...3 {
                let heading = angle + Double(revolution) * 2 * .pi
                XCTAssertEqual(ArtilleryFacing(heading: heading).frameIndex, index)
                XCTAssertEqual(ArtilleryFacing(heading: heading + 0.49 * ArtilleryFacing.angleStep).frameIndex, index)
                XCTAssertEqual(ArtilleryFacing(heading: heading - 0.51 * ArtilleryFacing.angleStep).frameIndex, (index + 1) % 32)
            }
        }
    }

    func testAimUsesBodyPointInsteadOfEnemyFeet() {
        let origin = CGPoint(x: 50, y: 50)
        XCTAssertEqual(ArtilleryFacing.aiming(from: origin, at: CGPoint(x: 65, y: 38),
                       previous: .initial).frameIndex, 3)
        XCTAssertEqual(ArtilleryFacing.aiming(from: origin, at: origin,
                       previous: .initial), .initial)
        XCTAssertEqual(ArtilleryFacing.aiming(from: origin, at: CGPoint(x: CGFloat.nan, y: 0),
                       previous: .initial), .initial)
    }

    func testSixGunTiersUseSheetsWhileSappersUseTheirStationaryArt() {
        let configurations = [(1, 1), (2, 1), (3, 1), (4, 1), (4, 2), (4, 4)]
        let names = configurations.compactMap { level, branch in
            TowerKind.areaOfEffect.directionalAssetName(atLevel: level, branch: branch)
        }
        XCTAssertEqual(Set(names).count, 6)
        XCTAssertTrue(names.allSatisfy { $0.hasSuffix("_directions_32") })
        XCTAssertNil(TowerKind.special.directionalAssetName(atLevel: 4, branch: 3))
        XCTAssertEqual(TowerKind.special.assetName(atLevel: 4, branch: 3), "special_tower_level_4_branch_3")
        XCTAssertEqual(TowerKind.special.specializationMenuIconName(atLevel: 4, branch: 3), "tower_menu_engineer_sapper")
        XCTAssertEqual(TowerKind.areaOfEffect.specializationMenuIconName(atLevel: 4, branch: 4), "tower_menu_artillery_siege")
        for kind in [TowerKind.ranged, .melee, .special] {
            XCTAssertNil(kind.directionalAssetName(atLevel: 4, branch: 2))
        }
    }

    func testAtlasCropsPartitionTheSheetAtEveryDensity() {
        for density in 1...3 {
            let side = CGFloat(96 * density)
            let size = CGSize(width: side * 8, height: side * 4)
            var rects = Set<String>()
            for index in 0..<32 {
                let facing = ArtilleryFacing(heading: -Double(index) * ArtilleryFacing.angleStep)
                let rect = facing.frameRect(sheetSize: size)
                XCTAssertEqual(rect.size, CGSize(width: side, height: side))
                XCTAssertTrue(CGRect(origin: .zero, size: size).contains(rect))
                rects.insert("\(rect.origin.x),\(rect.origin.y)")
            }
            XCTAssertEqual(rects.count, 32)
        }
    }
}
