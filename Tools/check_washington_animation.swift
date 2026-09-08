import Foundation

// Compile alongside Engine/Models/UnitFacing.swift; run from the project root.
@main
enum WashingtonAnimationCheck {
    struct Manifest: Decodable {
        let frame_count: Int
        let assets: [Asset]
        struct Asset: Decodable { let name: String }
    }

    static func main() throws {
        let manifest = try JSONDecoder().decode(Manifest.self, from:
            Data(contentsOf: URL(fileURLWithPath: "Tools/washington_asset_manifest.json")))
        let names = Set(manifest.assets.map(\.name))
        let pitch = HeroWalkCycle.cycleDistance / Double(manifest.frame_count)
        var selected: Set<String> = []
        for facing in UnitFacing.allCases {
            for frame in 0..<manifest.frame_count {
                let name = HeroWalkCycle.assetName(
                    baseAssetName: HeroWalkCycle.georgeWashingtonAssetName,
                    facing: facing, walkPhase: (Double(frame) + 0.5) * pitch, isWalking: true)
                precondition(name == "hero_unit_george_washington_walk_\(facing.assetSuffix)_\(frame)")
                precondition(names.contains(name), "Runtime requested a missing catalog image")
                selected.insert(name)
            }
            let looped = HeroWalkCycle.assetName(
                baseAssetName: HeroWalkCycle.georgeWashingtonAssetName,
                facing: facing, walkPhase: HeroWalkCycle.cycleDistance + pitch * 0.5, isWalking: true)
            precondition(looped == "hero_unit_george_washington_walk_\(facing.assetSuffix)_0")
        }
        precondition(selected.count == 128)
        print("PASS: runtime selects all 128 sword-up walk images and wraps each 16-frame cycle.")
    }
}
