import XCTest
@testable import LevelEditorFormats

final class HeroWalkCycleTests: XCTestCase {
    func testKnoxSkipsBlendedImagesAcrossInterpolatedMovementAndWraps() {
        var seen = Set<Int>()
        for facing in UnitFacing.allCases {
            for tick in 0..<120 {
                for alpha in [0.0, 0.25, 0.5, 0.75, 1.0] {
                    let phase = MeleeWalkCycle.interpolatedPhase(
                        currentPhase: Double(tick) * 6, stepDistance: 6,
                        alpha: alpha, cycleDistance: HeroWalkCycle.cycleDistance)
                    let name = HeroWalkCycle.assetName(
                        baseAssetName: "hero_unit_henry_knox", facing: facing,
                        walkPhase: phase, isWalking: true)
                    let frame = Int(name.split(separator: "_").last!)!
                    XCTAssertTrue([0, 16, 32, 48].contains(frame), "Blended artwork selected: \(name)")
                    XCTAssertTrue(name.hasPrefix("hero_unit_henry_knox_walk_\(facing.assetSuffix)_"))
                    seen.insert(frame)
                }
            }
        }
        XCTAssertEqual(seen, [0, 16, 32, 48])
    }

    func testKnoxSourcePosesPlayInOrder() {
        let samples: [(Double, Int)] = [(0, 0), (9, 0), (19, 16), (38, 32), (57, 48), (75.6, 0)]
        for (phase, frame) in samples {
            XCTAssertEqual(HeroWalkCycle.assetName(baseAssetName: "hero_unit_henry_knox",
                facing: .east, walkPhase: phase, isWalking: true),
                "hero_unit_henry_knox_walk_e_\(frame)")
        }
    }

    func testKnoxStopsAtStandingPoseWithExistingArrivalFacing() {
        let expected = ["e", "e", "e", "se", "s", "sw", "w", "w"]
        for (facing, suffix) in zip(UnitFacing.allCases, expected) {
            XCTAssertEqual(HeroWalkCycle.assetName(baseAssetName: "hero_unit_henry_knox",
                facing: facing, walkPhase: 40, isWalking: false),
                "hero_unit_henry_knox_walk_\(suffix)_16")
        }
    }

    func testOtherHeroAndMilitiaPlaybackRemainIndependent() {
        XCTAssertEqual(HeroWalkCycle.assetName(baseAssetName: "hero_unit_daniel_morgan",
            facing: .east, walkPhase: 9.45, isWalking: true), "hero_unit_daniel_morgan_walk_e_2")
        XCTAssertEqual(MeleeWalkCycle.assetName(facing: .east, walkPhase: 6, isWalking: true),
            "militia_soldier_walk_e_8")
        XCTAssertEqual(HeroWalkCycle.assetName(baseAssetName: "hero_unit_nathanael_greene",
            facing: .east, walkPhase: 20, isWalking: true), "hero_unit_nathanael_greene")
    }

    func testWashingtonUsesRigFramesInEastAndExistingFramesElsewhere() {
        for facing in UnitFacing.allCases {
            let count = facing == .east ? 32 : 16
            let pitch = HeroWalkCycle.cycleDistance / Double(count)
            for frame in 0..<count {
                XCTAssertEqual(HeroWalkCycle.assetName(
                    baseAssetName: "hero_unit_george_washington", facing: facing,
                    walkPhase: (Double(frame) + 0.5) * pitch, isWalking: true),
                    "hero_unit_george_washington_walk_\(facing.assetSuffix)_\(frame)")
            }
            XCTAssertEqual(HeroWalkCycle.assetName(
                baseAssetName: "hero_unit_george_washington", facing: facing,
                walkPhase: HeroWalkCycle.cycleDistance, isWalking: true),
                "hero_unit_george_washington_walk_\(facing.assetSuffix)_0")
        }
    }

    func testWashingtonTurningAndStoppingPreservePhaseAndArrivalPose() {
        for (facing, frame) in [(UnitFacing.east, 24), (.southEast, 12), (.west, 12)] {
            XCTAssertEqual(HeroWalkCycle.assetName(
                baseAssetName: "hero_unit_george_washington", facing: facing,
                walkPhase: HeroWalkCycle.cycleDistance * 0.76, isWalking: true),
                "hero_unit_george_washington_walk_\(facing.assetSuffix)_\(frame)")
        }
        for (facing, suffix) in zip(UnitFacing.allCases, ["e", "e", "e", "se", "s", "sw", "w", "w"]) {
            XCTAssertEqual(HeroWalkCycle.assetName(
                baseAssetName: "hero_unit_george_washington", facing: facing,
                walkPhase: 70, isWalking: false), "hero_unit_george_washington_idle_\(suffix)")
        }
    }
}
