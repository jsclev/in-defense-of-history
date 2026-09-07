import Foundation

// Compile alongside Engine/Models/UnitFacing.swift and run the resulting binary.
@main
enum HeroIdleFacingCheck {
    static func main() {
        let heroes = [
            HeroWalkCycle.henryKnoxAssetName,
            HeroWalkCycle.georgeWashingtonAssetName,
            HeroWalkCycle.danielMorganAssetName,
            HeroWalkCycle.salemPoorAssetName,
            HeroWalkCycle.johnGloverAssetName,
            HeroWalkCycle.francisMarionAssetName,
            HeroWalkCycle.oldPutAssetName,
            HeroWalkCycle.baronVonSteubenAssetName,
        ]
        let rearArrivals: [(UnitFacing, String)] = [
            (.north, "e"), (.northEast, "e"), (.northWest, "w"),
        ]
        for hero in heroes {
            for (arrival, side) in rearArrivals {
                let walking = HeroWalkCycle.assetName(baseAssetName: hero,
                    facing: arrival, walkPhase: 0, isWalking: true)
                precondition(walking == "\(hero)_walk_\(arrival.assetSuffix)_0",
                             "Walking must still face its travel direction")

                let stopped = HeroWalkCycle.assetName(baseAssetName: hero,
                    facing: arrival, walkPhase: 37, isWalking: false)
                let expected = hero == HeroWalkCycle.henryKnoxAssetName
                    ? "\(hero)_walk_\(side)_\(MeleeWalkCycle.standingFrame)"
                    : "\(hero)_idle_\(side)"
                precondition(stopped == expected, "Rear arrival must reveal the face")
                precondition(stopped == HeroWalkCycle.assetName(baseAssetName: hero,
                    facing: arrival, walkPhase: 0, isWalking: false),
                    "Resting direction must remain stable regardless of walk phase")
                precondition(walking == HeroWalkCycle.assetName(baseAssetName: hero,
                    facing: arrival, walkPhase: 0, isWalking: true),
                    "Moving again must immediately restore the travel direction")
            }

            for facing in [UnitFacing.east, .southEast, .south, .southWest, .west] {
                let expected = hero == HeroWalkCycle.henryKnoxAssetName
                    ? "\(hero)_walk_\(facing.assetSuffix)_\(MeleeWalkCycle.standingFrame)"
                    : "\(hero)_idle_\(facing.assetSuffix)"
                precondition(HeroWalkCycle.assetName(baseAssetName: hero,
                    facing: facing, walkPhase: 0, isWalking: false) == expected,
                    "Already-visible faces must retain their resting direction")
            }
        }
        for facing in UnitFacing.allCases {
            precondition(HeroWalkCycle.assetName(baseAssetName: "hero_unit_molly_pitcher",
                facing: facing, walkPhase: 0, isWalking: false) == "hero_unit_molly_pitcher",
                "Static heroes must keep their existing asset")
            precondition(MeleeWalkCycle.assetName(facing: facing,
                walkPhase: 0, isWalking: false) == "militia_soldier_walk_\(facing.assetSuffix)_16",
                "Militia facing must remain unchanged")
        }
        print("PASS: all 8 animated heroes settle rear arrivals left/right; walking, front idles, static heroes, and militia retain their behavior.")
    }
}
