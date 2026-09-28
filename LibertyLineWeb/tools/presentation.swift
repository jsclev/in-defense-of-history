import Foundation

// Build-time export of the native artwork calibration and animation selection.
// Keep the authored hero table and frame exceptions in their original Swift files.
@main struct PresentationExport {
    static func height(_ value: SpriteHeight) -> [String: Double] {
        ["fraction": value.fraction, "minimum": value.minimum, "maximum": value.maximum]
    }
    static func main() throws {
        let tiers = try JSONSerialization.jsonObject(with: Data(CommandLine.arguments[1].utf8)) as! [[String: Any]]
        var towers: [String: Any] = [:]
        // Unit-height probe exports native linear geometry, not a second table of constants.
        let unit = VirtualCanvas(size: CGSize(width: 1, height: 1), playAreaRect: CGRect(x: 0, y: 0, width: 1, height: 1),
            pathWidth: 1, towerSlotSize: CGSize(width: 1, height: 1), towerMenuTotalSize: CGSize(width: 1, height: 1),
            statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero, heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
        let menu = TowerMenuLayout(virtualCanvas: unit)
        let side = menu.getTowerButtonSize(playAreaScalingFactor: 1).width
        for kind in TowerKind.allCases {
            var sprites: [String: Any] = [:]
            for tier in tiers where tier["kind"] as! String == kind.rawValue {
                let level = tier["level"] as! Int, branch = tier["branch"] as! Int
                sprites["\(level):\(branch)"] = ["art": kind.assetName(atLevel: level, branch: branch)!,
                    "icon": kind.specializationMenuIconName(atLevel: level, branch: branch) as Any? ?? NSNull(),
                    "atlas": kind.directionalAssetName(atLevel: level, branch: branch) as Any? ?? NSNull()]
            }
            let point = menu.getTowerButtonCenterPoint(towerKind: kind, menuCenterPoint: .zero,
                playAreaScalingFactor: 1, towerButtonSize: side)
            towers[kind.rawValue] = ["height": height(kind.spriteHeight), "icon": kind.menuIconName,
                "projectile": ["asset": kind.projectileAssetName as Any? ?? NSNull(), "height": height(kind.projectileHeight)],
                "frame": kind.menuFrameName, "buildCenter": ["x": point.x, "y": point.y], "tiers": sprites]
        }
        var heroes: [String: Any] = [:]
        for (name, profile) in HeroSpriteProfile.all {
            var idle: [String] = [], walking: [[String]] = []
            let distance = HeroWalkCycle.cycleDistance(for: name)
            for facing in UnitFacing.allCases {
                idle.append(HeroWalkCycle.assetName(baseAssetName: name, facing: facing, walkPhase: 0, isWalking: false))
                var frames: [String] = []
                for frame in 0..<MeleeWalkCycle.frameCount {
                    let key = HeroWalkCycle.assetName(baseAssetName: name, facing: facing,
                        walkPhase: (Double(frame) + 0.5) / Double(MeleeWalkCycle.frameCount) * distance, isWalking: true)
                    if frames.last != key { frames.append(key) }
                }
                walking.append(frames)
            }
            heroes[name] = ["height": height(profile.imageHeight), "groundInset": profile.groundInsetFraction,
                            "cycleDistance": distance, "idle": idle, "walking": walking]
        }
        let militia = UnitFacing.allCases.map { facing in
            (0..<MeleeWalkCycle.frameCount).map { frame in
                MeleeWalkCycle.assetName(facing: facing, walkPhase: (Double(frame) + 0.5)
                    / Double(MeleeWalkCycle.frameCount) * MeleeWalkCycle.cycleDistance, isWalking: true)
            }
        }
        let result: [String: Any] = ["heroes": heroes, "militia": ["height": height(MapSpriteSizing.meleeUnit),
            "cycleDistance": MeleeWalkCycle.cycleDistance, "idle": UnitFacing.allCases.map {
                MeleeWalkCycle.assetName(facing: $0, walkPhase: 0, isWalking: false)
            }, "walking": militia, "groundInset": 0], "walker": height(MapSpriteSizing.walker),
            "healthWidth": height(MapSpriteSizing.healthBarWidth), "healthHeight": height(MapSpriteSizing.healthBarHeight),
            "labelLift": height(MapSpriteSizing.walkerLabelLift),
            "walkingThreshold": MeleeWalkCycle.walkingThreshold,
            "towers": towers,
            "explosion": ["asset": DemolitionExplosion.assetName, "columns": DemolitionExplosion.columns, "rows": DemolitionExplosion.rows,
                "anchor": DemolitionExplosion.groundAnchorY, "frameEnds": DemolitionExplosion.frameEnds],
            "towerGeometry": ["backgroundWidth": menu.getBgSize(playAreaScalingFactor: 1).width,
                "backgroundHeight": menu.getBgSize(playAreaScalingFactor: 1).height,
                "button": side, "ring": menu.getButtonRingRadius(playAreaScalingFactor: 1) - side / 4,
                "seat": menu.getButtonSeatRadius(playAreaScalingFactor: 1), "iconInset": TowerMenuLayout.iconInsetFraction,
                "tapMargin": SlotTapTarget.margin, "tapMinimum": TouchTarget.minimum,
                "artworkLift": MapSpriteSizing.towerArtworkLift, "baseLift": height(MapSpriteSizing.towerBaseLift),
                "atlasColumns": ArtilleryFacing.columns, "atlasRows": ArtilleryFacing.rows]]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
    }
}
