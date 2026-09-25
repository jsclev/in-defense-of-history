import SwiftUI
import UIKit

/// Prepared once per level. Live play and recordings supply their authored
/// inputs to the same setup; neither screen loads or arranges its own artwork.
struct LevelSceneSetup {
    let virtualCanvas: VirtualCanvas
    let roadSurface: CGPath
    let slotPositions: [CGPoint]
    let mapArt: LevelMapArt
    private let heroAspectRatios: [String: CGFloat]

    init(content: BattleContent) throws {
        try self.init(level: content.level, virtualCanvas: content.virtualCanvas,
            roadSurface: content.movementArea.boundaryPath, heroes: content.deployments.map(\.hero))
    }

    init(recording: LevelReplaySetup) throws {
        try self.init(level: recording.level, virtualCanvas: recording.virtualCanvas,
            roadSurface: recording.roadSurface(), heroes: recording.heroes)
    }

    private init(level: LevelInfo, virtualCanvas: VirtualCanvas, roadSurface: CGPath, heroes: [Hero]) throws {
        self.virtualCanvas = virtualCanvas
        self.roadSurface = roadSurface
        slotPositions = level.towerSlots.map { CGPoint(x: $0.position.x, y: $0.position.y) }
        mapArt = LevelMapArt(mapImageName: level.mapImageName)
        var ratios: [String: CGFloat] = [:]
        for hero in heroes {
            guard let image = UIImage(named: hero.unitImageName), image.size.width > 0, image.size.height > 0 else {
                throw DbError.Db(message: "hero[\(hero.id)].unitImageName: missing sprite dimensions for '\(hero.unitImageName)'")
            }
            ratios[hero.unitImageName] = image.size.width / image.size.height
        }
        heroAspectRatios = ratios
    }

    func heroAspectRatio(for asset: String) -> CGFloat {
        guard let ratio = heroAspectRatios[asset] else {
            preconditionFailure("Level scene has no prepared hero artwork '\(asset)'")
        }
        return ratio
    }

    static func validateHeroAsset(_ name: String) {
        guard UIImage(named: name) != nil else { preconditionFailure("Missing hero animation image '\(name)'") }
    }

    func projection(in canvas: RuntimeCanvas) -> LevelMapProjection {
        LevelMapArt.projection(virtualCanvas: virtualCanvas, fitting: canvas.playAreaRect)
    }
}

/// Input adapters only. Rendering and layer order belong exclusively to LevelScene.
struct LevelSceneState {
    let presentation: BattlePresentation
    let interpolation: Double
    let towers: [PlacedTower]
    let towerTuning: [Int: TowerLevel]
    let militia: [BattleEngine.MilitiaSoldier]
    let heroes: [BattleEngine.HeroSoldier]
    let impacts: [BattleEngine.ArtilleryImpact]
    let obstacles: [EngineerObstacleField]
    let slowingTowerSlots: Set<Int>
    let selectedTower: Int?
    let isDefeated: Bool
    let seconds: Double

    struct Obstacle: Identifiable {
        let id: Int
        let field: EngineerObstacleField
    }

    /// Saved fields retain tower order. Keep their owners even when multiple
    /// engineers place identical obstacles at the same point on the road.
    var ownedObstacles: [Obstacle] {
        let owners = towers.filter {
            $0.engineerObstaclePosition != nil && towerTuning[$0.slotIndex]?.engineerObstacles != nil
        }
        precondition(owners.count == obstacles.count, "Level scene obstacle fields do not match their towers")
        return zip(owners, obstacles).map { tower, field in
            precondition(tower.engineerObstaclePosition == field.position,
                         "Level scene obstacle order differs from tower order")
            return Obstacle(id: tower.slotIndex, field: field)
        }
    }

    @MainActor init(engine: BattleEngine) {
        presentation = engine.presentation
        interpolation = engine.presentationAlpha
        towers = engine.placedTowers
        towerTuning = Dictionary(uniqueKeysWithValues: towers.map { ($0.slotIndex, engine.towerLevel(for: $0)!) })
        militia = engine.militia
        heroes = engine.heroes
        impacts = engine.artilleryImpacts
        obstacles = engine.engineerObstacleFields
        slowingTowerSlots = engine.engineerObstacleFeedback.towerSlots
        selectedTower = engine.selectedTowerSlotIndex
        isDefeated = engine.isDefeated
        seconds = max(0, Double(engine.timer.tick) - 1 + interpolation) * SimClock.dt
    }

    init(frame: LevelReplayFrame, setup: LevelSceneSetup, ticksPerSecond: Int) {
        presentation = frame.presentation
        interpolation = 1
        towers = frame.towers
        towerTuning = frame.towerTuning
        militia = frame.militia
        heroes = frame.heroes.map { hero in
            LevelSceneSetup.validateHeroAsset(hero.assetName)
            return BattleEngine.HeroSoldier(id: hero.id, assetName: hero.assetName,
                baseAssetName: hero.baseAssetName, imageAspectRatio: setup.heroAspectRatio(for: hero.baseAssetName),
                position: hero.position, hp: hero.hp, maxHP: hero.maxHP, isSelected: hero.isSelected)
        }
        impacts = frame.impacts
        obstacles = frame.obstacles
        slowingTowerSlots = frame.slowingTowerSlots
        selectedTower = frame.selectedTower
        isDefeated = frame.outcome == .defeat
        seconds = Double(frame.tick) / Double(ticksPerSecond)
    }
}

/// The single battlefield for live play, player review, and movie export.
/// Hosts supply controls and optional debug overlays, never map-art tiers or units.
struct LevelScene<GroundOverlay: View, MapOverlay: View>: View {
    let setup: LevelSceneSetup
    let state: LevelSceneState
    let canvas: RuntimeCanvas
    var debugMode = false
    var onSelectHero: ((Int) -> Void)? = nil
    @ViewBuilder var groundOverlay: () -> GroundOverlay
    @ViewBuilder var mapOverlay: () -> MapOverlay

    var body: some View {
        let projection = setup.projection(in: canvas)
        let sprites = MapSpriteScale(runtimeCanvas: canvas)
        ZStack(alignment: .topLeading) {
            Color.black
            setup.mapArt.underlay(in: projection)
            LevelTowerSlotsView(debugMode: debugMode, slotPositions: setup.slotPositions,
                occupiedSlotIndices: Set(state.towers.map(\.slotIndex)),
                size: setup.virtualCanvas.towerSlotSize, projection: projection)
            groundOverlay()
            obstacles(in: projection)
            ForEach(state.towers) { tower in
                towerArtwork(tower, sprites: sprites, projection: projection)
            }
            ForEach(state.impacts) { impact in
                Group {
                    if impact.isDemolition { DemolitionBlastView(age: impact.age, radius: impact.radius * projection.scale) }
                    else { ArtilleryImpactView(age: impact.age, radius: impact.radius * projection.scale) }
                }.position(projection.viewPoint(impact.position))
            }
            GroundTroopLayer(presentation: state.presentation, interpolation: state.interpolation,
                militia: state.militia, sprites: sprites, projection: projection)
            setup.mapArt.forestOcclusion(in: projection)
            ProjectileLayer(presentation: state.presentation, interpolation: state.interpolation,
                sprites: sprites, projection: projection)
                .opacity(state.isDefeated ? 0 : 1)
                .animation(.easeOut(duration: 0.55), value: state.isDefeated)
            mapOverlay()
            demolitionSites(in: projection)
            HeroMapLayer(heroes: state.heroes, runtimeCanvas: canvas, projection: projection,
                onSelect: { onSelectHero?($0) })
                .allowsHitTesting(onSelectHero != nil)
            setup.mapArt.occlusion(in: projection)
        }
        .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height, alignment: .topLeading)
    }

    private func obstacles(in projection: LevelMapProjection) -> some View {
        ForEach(state.ownedObstacles) { obstacle in
            EngineerObstacleView(field: obstacle.field, roadSurface: setup.roadSurface, scale: projection.scale,
                selected: state.selectedTower == obstacle.id,
                isSlowingEnemies: state.slowingTowerSlots.contains(obstacle.id))
                .accessibilityValue("\(Int(obstacle.field.stats.slowFraction * 100)) percent slowdown")
                .position(projection.viewPoint(obstacle.field.position))
        }
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
                    DemolitionTowerView(assetName: assetName, charge: charge, height: height, virtualSeconds: state.seconds)
                } else if let sheet = tower.kind.directionalAssetName(atLevel: tower.level, branch: tower.branch) {
                    ArtilleryTowerSprite(sheetName: sheet, fallbackName: assetName, facing: tower.artilleryFacing)
                } else { Image(assetName).resizable().scaledToFit() }
            }
            .frame(height: height)
            .position(x: base.x, y: base.y - height / 2 + sprites.points(MapSpriteSizing.towerBaseLift) + height * 0.20)
        }
    }

    private func demolitionSites(in projection: LevelMapProjection) -> some View {
        ForEach(state.towers) { tower in
            if let charge = tower.demolitionCharge, let position = charge.position,
               let tuning = state.towerTuning[tower.slotIndex] {
                DemolitionSiteView(charge: charge, radius: tuning.aoeRadius * projection.scale,
                    showBlastRadius: state.selectedTower == tower.slotIndex, virtualSeconds: state.seconds)
                    .accessibilityIdentifier("demolition-charge-\(tower.slotIndex)")
                    .position(projection.viewPoint(position))
            }
        }
    }
}

extension LevelScene where GroundOverlay == EmptyView, MapOverlay == EmptyView {
    init(setup: LevelSceneSetup, frame: LevelReplayFrame, ticksPerSecond: Int, canvas: RuntimeCanvas) {
        self.init(setup: setup, state: LevelSceneState(frame: frame, setup: setup, ticksPerSecond: ticksPerSecond),
            canvas: canvas, groundOverlay: { EmptyView() }, mapOverlay: { EmptyView() })
    }
}

/// Both player review and movie export mount the same battlefield and HUD.
/// Old recordings without HUD channels keep their original battlefield view.
struct RecordedLevelView: View {
    let setup: LevelSceneSetup
    let recording: LevelReplaySetup
    let frame: LevelReplayFrame
    let canvas: RuntimeCanvas

    var body: some View {
        ZStack(alignment: .topLeading) {
            LevelScene(setup: setup, frame: frame, ticksPerSecond: recording.ticksPerSecond, canvas: canvas)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Recorded battlefield")
                .accessibilityValue("Tick \(frame.tick)")
                .accessibilityIdentifier("replay-battlefield")
            if let hud = frame.hud, let layout = recording.hudLayout {
                HudView(runtimeCanvas: canvas, state: hud, hudLayoutConfig: layout)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recorded level")
    }
}
