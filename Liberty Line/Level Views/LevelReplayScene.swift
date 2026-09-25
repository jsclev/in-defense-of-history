#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

/// The existing game's artwork receives stored poses, impacts and metrics.
/// Animation time is the recorded tick, independent of export wall-clock speed.
struct LevelReplayScene: View {
    let setup: LevelReplaySetup
    let frame: LevelReplayFrame
    let road: CGPath
    let canvas: RuntimeCanvas

    private var seconds: Double { Double(frame.tick) / Double(setup.ticksPerSecond) }

    var body: some View {
        let projection = LevelMapArt.projection(virtualCanvas: setup.virtualCanvas, fitting: canvas.playAreaRect)
        let sprites = MapSpriteScale(runtimeCanvas: canvas)
        let art = LevelMapArt(mapImageName: setup.level.mapImageName)
        ZStack(alignment: .topLeading) {
            Color.black
            art.underlay(in: projection)
            LevelTowerSlotsView(debugMode: false,
                slotPositions: setup.level.towerSlots.map { CGPoint(x: $0.position.x, y: $0.position.y) },
                occupiedSlotIndices: Set(frame.towers.map(\.slotIndex)),
                size: setup.virtualCanvas.towerSlotSize, projection: projection)
            ForEach(Array(frame.obstacles.enumerated()), id: \.offset) { _, field in
                EngineerObstacleView(field: field, roadSurface: road, scale: projection.scale,
                    selected: false, isSlowingEnemies: frame.slowingTowerSlots.contains(where: { slot in
                        frame.towers.contains { $0.slotIndex == slot && $0.engineerObstaclePosition == field.position }
                    }))
                    .position(projection.viewPoint(field.position))
            }
            ForEach(frame.towers) { tower in
                towerArtwork(tower, sprites: sprites, projection: projection)
            }
            ForEach(frame.impacts) { impact in
                Group {
                    if impact.isDemolition { DemolitionBlastView(age: impact.age, radius: impact.radius * projection.scale) }
                    else { ArtilleryImpactView(age: impact.age, radius: impact.radius * projection.scale) }
                }.position(projection.viewPoint(impact.position))
            }
            GroundTroopLayer(presentation: frame.presentation, interpolation: 1,
                militia: frame.militia, sprites: sprites, projection: projection)
            art.forestOcclusion(in: projection)
            ProjectileLayer(presentation: frame.presentation, interpolation: 1, sprites: sprites, projection: projection)
            HeroMapLayer(heroes: renderedHeroes, runtimeCanvas: canvas, projection: projection, onSelect: { _ in })
            ForEach(frame.towers) { tower in
                if let charge = tower.demolitionCharge, charge.isReady, let point = charge.position {
                    DemolitionGroundChargeSymbol(lightIsOn: seconds.truncatingRemainder(dividingBy:
                        DemolitionGroundChargeSymbol.blinkPeriod) < DemolitionGroundChargeSymbol.lightOnDuration)
                        .position(projection.viewPoint(point))
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func towerArtwork(_ tower: PlacedTower, sprites: MapSpriteScale,
                                           projection: LevelMapProjection) -> some View {
        if let assetName = tower.kind.assetName(atLevel: tower.level, branch: tower.branch) {
            let height = tower.demolitionCharge != nil
                ? DemolitionTowerView.artworkHeight(slotWidth: projection.viewLength(setup.virtualCanvas.towerSlotSize.width), assetName: assetName)
                : sprites.points(tower.kind.spriteHeight)
            let base = projection.viewPoint(CGPoint(x: tower.position.x, y: tower.position.y + MapSpriteSizing.towerArtworkLift))
            Group {
                if let charge = tower.demolitionCharge {
                    DemolitionTowerView(assetName: assetName, charge: charge, height: height)
                        .artwork(readinessPulse: DemolitionTowerView.readinessPulse(at: seconds))
                } else if let sheet = tower.kind.directionalAssetName(atLevel: tower.level, branch: tower.branch) {
                    ArtilleryTowerSprite(sheetName: sheet, fallbackName: assetName, facing: tower.artilleryFacing)
                } else { Image(assetName).resizable().scaledToFit() }
            }
            .frame(height: height)
            .position(x: base.x, y: base.y - height / 2 + sprites.points(MapSpriteSizing.towerBaseLift) + height * 0.20)
        }
    }

    private var renderedHeroes: [BattleEngine.HeroSoldier] {
        frame.heroes.map { hero in
            guard let image = UIImage(named: hero.baseAssetName), image.size.height > 0 else {
                preconditionFailure("Missing recorded hero artwork \(hero.baseAssetName)")
            }
            return BattleEngine.HeroSoldier(id: hero.id, assetName: hero.assetName,
                baseAssetName: hero.baseAssetName, imageAspectRatio: image.size.width / image.size.height,
                position: hero.position, hp: hero.hp, maxHP: hero.maxHP, isSelected: hero.isSelected)
        }
    }
}
#endif
