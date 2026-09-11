import SwiftUI

struct LevelMapView: View {
    @Environment(\.scenePhase) private var scenePhase
    let towerMenuLayout: TowerMenuLayout

    var node: CampaignNode
    var difficulty: Difficulty
    var onExit: () -> Void

    @StateObject private var runner: LevelRunner
    @State private var towerSlotCount: Int = 0

    /// Slots whose debug ring the player has dismissed by tapping its legend.
    /// Tapping the slot itself brings it back. Debug mode only, and not
    /// persisted — a fresh level starts with every ring showing.
    @State private var hiddenRangeSlots: Set<Int> = []

    private enum Presentation: Equatable {
        case buildMenu(slot: Int)
        case upgradeMenu(slot: Int)
        case rallyPlacement(slot: Int)
        case reinforcementPlacement
        case heroDestination(index: Int)
        case rallyFlag(id: Int, point: CGPoint)
        case defeat
    }

    @State private var presentationStack = PresentationStack<Presentation>()
    @State private var escapeHapticPolicy = EnemyEscapeHapticPolicy()

    private var activePresentations: [Presentation] {
        var active: [Presentation] = []
        if let slot = runner.selectedSlotIndex, runner.slotPositions.indices.contains(slot) {
            active.append(.buildMenu(slot: slot))
        }
        if let slot = runner.selectedTowerSlotIndex, runner.placedTower(atSlot: slot) != nil {
            active.append(runner.isPlacingRallyPoint ? .rallyPlacement(slot: slot) : .upgradeMenu(slot: slot))
        }
        if runner.isPlacingReinforcements { active.append(.reinforcementPlacement) }
        if let hero = runner.selectedHeroIndex { active.append(.heroDestination(index: hero)) }
        if let flash = runner.rallyFlagFlash { active.append(.rallyFlag(id: flash.id, point: flash.position)) }
        if runner.isDefeated { active.append(.defeat) }
        return active
    }

    @AppStorage(Constants.debugModeKey) private var debugMode = false
    @AppStorage(Constants.showDebugLayoutGuidesKey) private var showDebugLayoutGuides = false
    @AppStorage(Constants.enemyEscapeHapticsEnabledKey) private var enemyEscapeHapticsEnabled = true

    private static let debugRangeBands: [(upperBound: CGFloat, tint: Color)] = [
        (350, Color(red: 0.13, green: 0.83, blue: 0.93)),        // cyan
        (425, Color(red: 0.38, green: 0.65, blue: 0.98)),        // blue
        (500, Color(red: 0.75, green: 0.52, blue: 0.99)),        // violet
        (.infinity, Color(red: 1.00, green: 0.31, blue: 0.64)),  // magenta
    ]

    /// Tap box for a slot: the slot footprint at this projection, margin past
    /// it, floored at Apple's minimum. One definition for the button and the
    /// debug readout.
    private func slotTapSize(projection: LevelMapProjection) -> CGSize {
        SlotTapTarget.size(slotSize: runner.slotSize,
                           pointsPerMapUnit: projection.scale)
    }

    private static let showSlotTapInfo = false

    private static func debugRangeTint(for range: CGFloat) -> Color {
        debugRangeBands.first { range < $0.upperBound }?.tint
            ?? debugRangeBands[debugRangeBands.count - 1].tint
    }

    private static let rallyButtonScale: CGFloat = 0.495

    /// Visual ground-anchor correction shared by all tower artwork, in virtual units.
    private static let towerArtworkLift: CGFloat = 12
    
    private var db: Db
    private var virtualCanvas: VirtualCanvas
    private var runtimeCanvas: RuntimeCanvas
    private var hudLayoutConfig: HudLayoutConfig

    init(db: Db,
         virtualCanvas: VirtualCanvas,
         runtimeCanvas: RuntimeCanvas,
         towerMenuLayout: TowerMenuLayout,
         node: CampaignNode,
         difficulty: Difficulty,
         hudLayoutConfig: HudLayoutConfig, onExit: @escaping () -> Void) {
        self.db = db
        self.virtualCanvas = virtualCanvas
        self.runtimeCanvas = runtimeCanvas
        self.towerMenuLayout = towerMenuLayout
        self.node = node
        self.difficulty = difficulty
        self.hudLayoutConfig = hudLayoutConfig
        self.onExit = onExit
        _runner = StateObject(wrappedValue: LevelRunner(
            db: db,
            virtualCanvas: virtualCanvas,
            runtimeCanvas: runtimeCanvas,
            hudLayoutConfig: hudLayoutConfig,
            levelInfoID: node.levelInfoID,
            mapImageName: node.mapImageName,
            enemyHPMultiplier: difficulty.enemyHPMultiplier
        ))
    }

    var body: some View {
        LevelViewport(size: runtimeCanvas.physicalRect.size) {
            content(runtimeCanvas: runtimeCanvas)
                .border(debugMode ? Color.orange : Color.clear, width: debugMode ? 3 : 0)
        } interface: {
            ZStack(alignment: .topLeading) {
                HudView(runtimeCanvas: runtimeCanvas,
                        db: db,
                        runner: runner,
                        hudLayoutConfig: hudLayoutConfig,
                        onSpeedUp: { runner.speedUp() },
                        onExit: onExit)
                    .border(debugMode ? Color.cyan : Color.clear, width: debugMode ? 3 : 0)

                if showDebugLayoutGuides {
                    DebugLayoutGuidesView(runtimeCanvas: runtimeCanvas)
                }

                if runner.awaitingWaveStart {
                    CallWaveButtonLayer(runtimeCanvas: runtimeCanvas,
                                        positions: runner.callWaveButtonPositions,
                                        waveNumber: runner.nextWaveNumber,
                                        countdownSeconds: runner.waveCountdownSeconds) {
                        runner.startNextWave()
                    }
                    .id(runner.nextWaveNumber)
                }
            }
        } presentations: {
            PresentationLayers(stack: presentationStack) { presentation in
                presentationLayer(presentation, runtimeCanvas: runtimeCanvas)
            }
        }
        .persistentSystemOverlays(.hidden)
        .onChange(of: runner.escapedEnemyCount) { previous, current in
            guard let cue = escapeHapticPolicy.feedback(previousCount: previous, escapeCount: current,
                                               livesRemaining: runner.lives,
                                               isEnabled: enemyEscapeHapticsEnabled,
                                               isActive: scenePhase == .active,
                                               at: ProcessInfo.processInfo.systemUptime) else { return }
            runner.playEnemyEscapeHaptic(cue)
        }
        .onAppear {
            runner.updateRuntimeCanvas(runtimeCanvas)
            runner.start()
        }
        .onChange(of: runtimeCanvas.playAreaRect) { _, _ in
            runner.updateRuntimeCanvas(runtimeCanvas)
        }
        .onDisappear {
            runner.stop()
            presentationStack.removeAll()
        }
        .onChange(of: activePresentations, initial: true) { _, active in
            presentationStack.synchronize(active)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { runner.start() } else { runner.stop() }
        }
    }

    private func content(runtimeCanvas: RuntimeCanvas) -> some View {
        // Artwork, sprites, ranges, and input share the canvas's safe-area fit.
        let safe = runtimeCanvas.safeInsetsRect
        let projection = LevelMapArt.projection(virtualCanvas: virtualCanvas, fitting: runtimeCanvas.playAreaRect)
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        let sprites = MapSpriteScale(runtimeCanvas: runtimeCanvas)
        let art = runner.mapArt
        return ZStack(alignment: .topLeading) {
            Color.black

            Group {
                Image("tower_menu_bg")
                Image("tower_menu_square_frame")
                ForEach(TowerKind.allCases) { kind in
                    Image(kind.menuFrameName)
                    Image(kind.menuIconName)
                }
                Image("tower_locked_icon")
            }
            .frame(width: 1, height: 1)
            .hidden()
            .allowsHitTesting(false)

            art.underlay(in: projection)

            LevelTowerSlotsView(
                debugMode: debugMode,
                slotPositions: runner.slotPositions,
                occupiedSlotIndices: Set(runner.placedTowers.map(\.slotIndex)),
                size: CGSize(width: runner.slotSize.width, height: runner.slotSize.height),
                projection: projection)

            if debugMode {
                ForEach(runner.placedTowers) { tower in
                    if !hiddenRangeSlots.contains(tower.slotIndex),
                       runner.hasAttackRange(tower),
                       let range = runner.attackRange(for: tower) {
                        debugRangeRing(debugRingGeometry(
                            for: tower, range: range, projection: projection,
                            safe: safe, metrics: metrics))
                    }
                }
            }

            ForEach(runner.placedTowers) { tower in
                if let assetName = tower.kind.assetName(atLevel: tower.level,
                                                        branch: tower.branch) {
                    let towerHeight = sprites.points(tower.kind.spriteHeight)
                    let basePoint = projection.viewPoint(CGPoint(
                        x: tower.position.x,
                        y: tower.position.y + Self.towerArtworkLift))

                    // All tower families share the same sizing and placement.
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: towerHeight)
                        .position(
                            x: basePoint.x,
                            y: basePoint.y - towerHeight / 2
                                + sprites.points(MapSpriteSizing.towerBaseLift)
                                + towerHeight * 0.20
                        )
                }
            }

            ForEach(runner.walkers) { walker in
                let spriteHeight = sprites.points(MapSpriteSizing.walker)
                let footPoint = projection.viewPoint(walker.position)
                Image(walker.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: spriteHeight)
                    .position(x: footPoint.x, y: footPoint.y - spriteHeight / 2)

                if walker.hp < walker.maxHP {
                    let fraction = CGFloat(max(0, walker.hp / walker.maxHP))
                    let barWidth = sprites.points(MapSpriteSizing.healthBarWidth)
                    let barHeight = sprites.points(MapSpriteSizing.healthBarHeight)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.red)
                        Capsule()
                            .fill(Color.green)
                            .frame(width: barWidth * fraction, height: barHeight)
                    }
                    .frame(width: barWidth, height: barHeight)
                    .position(x: footPoint.x,
                              y: footPoint.y - spriteHeight - sprites.points(MapSpriteSizing.walkerLabelLift))
                }
            }

            ForEach(runner.militia) { soldier in
                let spriteHeight = sprites.points(MapSpriteSizing.meleeUnit)
                let footPoint = projection.viewPoint(soldier.position)
                Image(soldier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: spriteHeight)
                    .position(x: footPoint.x, y: footPoint.y - spriteHeight / 2)

                if soldier.hp < soldier.maxHP {
                    let fraction = CGFloat(max(0, soldier.hp / soldier.maxHP))
                    let barWidth = sprites.points(MapSpriteSizing.healthBarWidth)
                    let barHeight = sprites.points(MapSpriteSizing.healthBarHeight)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.red)
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: barWidth * fraction, height: barHeight)
                    }
                    .frame(width: barWidth, height: barHeight)
                    .position(x: footPoint.x,
                              y: footPoint.y - spriteHeight - sprites.points(MapSpriteSizing.walkerLabelLift))
                }
            }

            // Rendered after the walkers so soldiers enter from and disappear
            // into the foliage; interactive controls remain above it.
            art.forestOcclusion(in: projection)

            Group {
                ForEach(runner.projectiles) { projectile in
                    if let assetName = projectile.kind.projectileAssetName {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: sprites.points(projectile.kind.projectileHeight))
                            .rotationEffect(.radians(projectile.heading))
                            .position(projection.viewPoint(projectile.position))
                    }
                }
            }
            .opacity(runner.isDefeated ? 0 : 1)
            .animation(.easeOut(duration: 0.55), value: runner.isDefeated)

            // Above the other units; exit markers and heroes are drawn next.
            art.occlusion(in: projection)

            // One layer above the finished map, including endpoint foliage.
            // Exit symbols must stay visible where soldiers disappear into the art.
            LevelExitMarkersView(positions: runner.exitPositions,
                                 projection: projection,
                                 spriteSize: sprites.points(MapSpriteSizing.exitMarker))

            // Heroes, selection rings and health bars stay above exit symbols.
            HeroMapLayer(heroes: runner.heroes, runtimeCanvas: runtimeCanvas,
                         projection: projection, onSelect: runner.selectHero)


            ForEach(Array(runner.slotPositions.enumerated()), id: \.offset) { index, slotPosition in
                let slotTap = slotTapSize(projection: projection)
                Button {
                    // Restoring a dismissed ring takes the whole tap, so
                    // bringing one back never also opens the upgrade menu.
                    if debugMode, hiddenRangeSlots.contains(index) {
                        hiddenRangeSlots.remove(index)
                    } else if runner.isSlotOccupied(index) {
                        runner.selectPlacedTower(atSlot: index)
                    } else {
                        runner.selectSlot(index)
                    }
                } label: {
                    // In debug mode the hit area shows itself; the fill IS the
                    // tappable shape, so what you see is exactly what taps.
                    // Sized by SlotTapTarget: the slot's own footprint at this
                    // projection, a margin past it, floored at Apple's 44pt.
                    Ellipse()
                        .fill(debugMode ? Color.black.opacity(0.35)
                                        : Color.white.opacity(0.001))
                        .frame(width: slotTap.width, height: slotTap.height)
                }
                .position(projection.viewPoint(slotPosition))
            }

            if debugMode, Self.showSlotTapInfo {
                ForEach(Array(runner.slotPositions.enumerated()), id: \.offset) { index, slotPosition in
                    let p = projection.viewPoint(slotPosition)
                    let slotTap = slotTapSize(projection: projection)
                    Text("tap \(Int(slotTap.width.rounded()))×\(Int(slotTap.height.rounded()))pt · Apple min \(Int(TouchTarget.minimum))×\(Int(TouchTarget.minimum))")
                        .font(.system(size: Typography.size(11 * metrics.scale),
                                      weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5 * metrics.scale)
                        .padding(.vertical, 2 * metrics.scale)
                        .background(Capsule().fill(.black.opacity(0.6)))
                        .fixedSize()
                        .position(x: p.x,
                                  y: p.y + slotTap.height / 2 + 11 * metrics.scale)
                        .allowsHitTesting(false)
                }
            }

            if debugMode {
                ForEach(runner.placedTowers) { tower in
                    if !hiddenRangeSlots.contains(tower.slotIndex),
                       runner.hasAttackRange(tower),
                       let range = runner.attackRange(for: tower) {
                        debugRangeLegendLayer(
                            for: tower, range: range,
                            ring: debugRingGeometry(
                                for: tower, range: range, projection: projection,
                                safe: safe, metrics: metrics),
                            metrics: metrics)
                    }
                }
            }

        }
    }

    @ViewBuilder
    private func presentationLayer(_ presentation: Presentation, runtimeCanvas: RuntimeCanvas) -> some View {
        let projection = LevelMapArt.projection(virtualCanvas: virtualCanvas, fitting: runtimeCanvas.playAreaRect)
        let playAreaScalingFactor = runtimeCanvas.scaleFactor
        switch presentation {
        case .buildMenu(let buildSlot):
            if runner.slotPositions.indices.contains(buildSlot) {
                if let radius = runner.armedBuildKind.flatMap({ runner.buildPreviewRadius(for: $0) }) {
                    TowerRangeOverlayView(
                        center: projection.viewPoint(runner.slotPositions[buildSlot]),
                        range: radius, runtimeCanvas: runtimeCanvas)
                }
                dismissCatcher()
                towerMenu(around: projection.viewPoint(runner.slotPositions[buildSlot]),
                          playAreaScalingFactor: playAreaScalingFactor)
            }
        case .upgradeMenu(let upgradeSlot), .rallyPlacement(let upgradeSlot):
            if runner.slotPositions.indices.contains(upgradeSlot),
               let tower = runner.placedTower(atSlot: upgradeSlot) {
                let previewRadius = runner.armedUpgradeBranch
                    .flatMap { runner.upgradePreviewRadius(branch: $0) }
                if let radius = runner.rangeOverlayRadius(for: tower) {
                    TowerRangeOverlayView(
                        center: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                        range: radius, upgradeRange: previewRadius, runtimeCanvas: runtimeCanvas)
                }
                if case .rallyPlacement = presentation {
                    rallyPlacementCatcher(projection: projection)
                } else {
                    dismissCatcher()
                    upgradeMenu(for: tower, around: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                                playAreaScalingFactor: playAreaScalingFactor)
                }
            }
        case .reinforcementPlacement:
            MapDestinationInputView(runtimeCanvas: runtimeCanvas) { runner.placeReinforcements(at: $0) }
        case .heroDestination:
            HeroDestinationView(runner: runner, runtimeCanvas: runtimeCanvas)
        case .rallyFlag(let id, let point):
            TemporaryRallyFlag(
                size: HudSizing.cornerButton.resolved(
                    at: HudMetrics(runtimeCanvas: runtimeCanvas).scale) * 0.45,
                plantPoint: projection.viewPoint(point)) {
                    runner.dismissRallyFlag(id: id)
                }
        case .defeat:
            failBanner(metrics: HudMetrics(runtimeCanvas: runtimeCanvas))
        }
    }

    /// Rows in `debugRangeLegend`. Used to size the panel before it is laid
    /// out, so keep it in step with the `GridRow`s below.
    private static let debugLegendRowCount: CGFloat = 5

    /// What `debugRangeLegend` will stand, before SwiftUI lays it out — needed
    /// to choose a side, which has to be decided while building the view. The
    /// line-height factor deliberately runs high: overestimating flips the
    /// legend below a touch early, underestimating clips it off runtimeCanvas.
    private func debugLegendHeight(metrics: HudMetrics) -> CGFloat {
        let rows = Self.debugLegendRowCount
        return rows * metrics.rangeLegendTextSize * 1.35
            + (rows - 1) * (1 * metrics.scale)
            + 2 * (4 * metrics.scale)
    }

    /// Shared by the ring pass and the legend pass, which draw at different
    /// depths in the stack but must agree on size and on which side the legend
    /// sits.
    private struct DebugRingGeometry {
        let center: CGPoint
        let size: CGSize
        let tint: Color
        let gap: CGFloat
        let legendAbove: Bool
    }

    private func debugRingGeometry(for tower: PlacedTower,
                                   range: CGFloat,
                                   projection: LevelMapProjection,
                                   safe: CGRect,
                                   metrics: HudMetrics) -> DebugRingGeometry {
        let size = TowerRangeOverlay.size(range: range, runtimeCanvas: runtimeCanvas)
        let center = projection.viewPoint(tower.position)
        let gap = 6 * metrics.scale

        // The legend sits above the ring by default. A tower high on the map
        // puts that off the top of the runtimeCanvas, so when it will not clear the
        // safe area it flips to the far side of the circle instead.
        let above = center.y - size.height / 2 - gap
            - debugLegendHeight(metrics: metrics) >= safe.minY

        return DebugRingGeometry(center: center, size: size,
                                 tint: Self.debugRangeTint(for: range),
                                 gap: gap, legendAbove: above)
    }

    /// The ring itself, drawn under the tower sprites and never hit-tested so
    /// it cannot swallow taps meant for the slot buttons beneath it.
    private func debugRangeRing(_ ring: DebugRingGeometry) -> some View {
        Ellipse()
            .fill(ring.tint.opacity(0.12))
            .overlay(
                ZStack {
                    Ellipse().stroke(.black.opacity(0.45), lineWidth: 4)
                    Ellipse().stroke(ring.tint, lineWidth: 2)
                }
            )
            .frame(width: ring.size.width, height: ring.size.height)
            .position(ring.center)
            .allowsHitTesting(false)
    }

    /// The legend, drawn above the slot buttons so its tap target is never
    /// covered. The clear circle is only a layout anchor, matching the ring so
    /// the legend hangs off the right edge of it; it is not hit-tested, so the
    /// slot button underneath still works.
    private func debugRangeLegendLayer(for tower: PlacedTower,
                                       range: CGFloat,
                                       ring: DebugRingGeometry,
                                       metrics: HudMetrics) -> some View {
        let edge: VerticalAlignment = ring.legendAbove ? .top : .bottom

        return Color.clear
            .frame(width: ring.size.width, height: ring.size.height)
            .allowsHitTesting(false)
            .overlay(alignment: Alignment(horizontal: .center, vertical: edge)) {
                debugRangeLegend(for: tower, range: range,
                                 tint: ring.tint, metrics: metrics)
                    .fixedSize()
                    // Clears the ring rather than overlapping it, which is what
                    // either edge alignment would do on its own.
                    .alignmentGuide(edge) {
                        ring.legendAbove ? $0[.bottom] + ring.gap : $0[.top] - ring.gap
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { hiddenRangeSlots.insert(tower.slotIndex) }
            }
            .position(ring.center)
    }

    private func debugRangeLegend(for tower: PlacedTower,
                                  range: CGFloat,
                                  tint: Color,
                                  metrics: HudMetrics) -> some View {
        let size = metrics.rangeLegendTextSize
        let area = runner.pathAreaInRange(for: tower)
        let rof = runner.rateOfFire(for: tower)
        let totalDamage = runner.totalDamageBySlot[tower.slotIndex] ?? 0
        let targeting = runner.targetingTimeBySlot[tower.slotIndex] ?? 0

        // A Grid sizes each column to its widest cell, so the rows line up
        // without a fixed width forcing the longer labels to wrap. Column
        // alignment is declared once, on the first row's cells: labels flush
        // left, numbers flush right.
        return Grid(alignment: .leading,
                    horizontalSpacing: 6 * metrics.scale,
                    verticalSpacing: 1 * metrics.scale) {
            GridRow {
                Text("Range").foregroundStyle(.white.opacity(0.75))
                    .gridColumnAlignment(.leading)
                Text("\(Int(range))").foregroundStyle(tint)
                    .gridColumnAlignment(.trailing)
            }
            GridRow {
                Text("Path coverage").foregroundStyle(.white.opacity(0.75))
                // Thousands dropped: the figure only matters for comparing
                // slots on the same level, so 68000 reads as 68.
                Text("\(Int((area / 1000).rounded()))").foregroundStyle(tint)
            }
            GridRow {
                Text("Rate of fire").foregroundStyle(.white.opacity(0.75))
                Text(String(format: "%.2f/s", rof)).foregroundStyle(tint)
            }
            GridRow {
                Text("Time targeting").foregroundStyle(.white.opacity(0.75))
                Text(String(format: "%.1fs", targeting)).foregroundStyle(tint)
            }
            GridRow {
                Text("Total damage").foregroundStyle(.white.opacity(0.75))
                Text("\(Int(totalDamage.rounded()))").foregroundStyle(tint)
            }
        }
        .lineLimit(1)
        .monospacedDigit()
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .padding(.horizontal, 6 * metrics.scale)
        .padding(.vertical, 4 * metrics.scale)
        .background(RoundedRectangle(cornerRadius: 5 * metrics.scale)
            .fill(.black.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 5 * metrics.scale)
            .stroke(tint.opacity(0.8), lineWidth: 1))
    }

    private func rallyPlacementCatcher(projection: LevelMapProjection) -> some View {
        Color.black.opacity(0.001)
            .gesture(SpatialTapGesture().onEnded { value in
                runner.placeRallyPoint(at: projection.mapPoint(value.location))
            })
    }

    private func dismissCatcher() -> some View {
        Color.black.opacity(0.001)
            .onTapGesture { runner.dismissMenu() }
    }

    private func towerMenu(around anchor: CGPoint,
                                 playAreaScalingFactor: CGFloat) -> some View {
        let menuCenterPoint = towerMenuLayout.getCenterPoint(anchor: anchor, scale: playAreaScalingFactor)
        let buttonSize = towerMenuLayout.getTowerButtonSize(playAreaScalingFactor: playAreaScalingFactor)
        return Group {
            towerMenuBgImage(center: menuCenterPoint, playAreaScalingFactor: playAreaScalingFactor)
            ForEach(TowerKind.allCases) { kind in
                TowerMenuItem(towerMenuLayout: towerMenuLayout,
                              kind: kind,
                              isAvailable: runner.maxLevel(for: kind) >= 1,
                              isArmed: runner.armedBuildKind == kind,
                              isAffordable: runner.buildCost(for: kind)
                                  .map { runner.money >= $0 } ?? false,
                              cost: runner.buildCost(for: kind),
                              buttonSize: buttonSize) {
                    runner.tapBuildButton(kind)
                }
                .position(towerMenuLayout.getTowerButtonCenterPoint(towerKind: kind,
                                                                    menuCenterPoint: menuCenterPoint,
                                                                    playAreaScalingFactor: playAreaScalingFactor,
                                                                    towerButtonSize: buttonSize.width))
            }
        }
    }

    private func upgradeMenu(for tower: PlacedTower, around anchor: CGPoint,
                             playAreaScalingFactor: CGFloat) -> some View {
        let offers = runner.upgradeOffers
        let center = towerMenuLayout.getCenterPoint(anchor: anchor, scale: playAreaScalingFactor)
        let buttonSize = towerMenuLayout.getTowerButtonSize(playAreaScalingFactor: playAreaScalingFactor)
        let hasRally = runner.rallyPoint(forSlot: tower.slotIndex) != nil
        let rallyButtonSize = CGSize(width: buttonSize.width * Self.rallyButtonScale,
                                     height: buttonSize.height * Self.rallyButtonScale)
        let upgradeCount = max(offers.count, 1)
        let count = upgradeCount + (hasRally ? 1 : 0)
        func place(_ index: Int) -> CGPoint {
            towerMenuLayout.getButtonCenterPoint(
                index: index, count: count, menuCenterPoint: center,
                playAreaScalingFactor: playAreaScalingFactor, towerButtonSize: buttonSize.width)
        }
        return Group {
            towerMenuBgImage(center: center, playAreaScalingFactor: playAreaScalingFactor)
            if offers.isEmpty {
                UpgradeMenuItem(towerMenuLayout: towerMenuLayout, iconName: tower.kind.menuIconName, dropKind: tower.kind,
                                cost: nil, isArmed: false, isAffordable: false, buttonSize: buttonSize) {}
                    .position(place(0))
            } else {
                ForEach(Array(offers.enumerated()), id: \.offset) { index, offer in
                    let iconName = offers.count > 1
                        ? (tower.kind.assetName(atLevel: offer.nextLevel,
                                                branch: offer.branch) ?? tower.kind.menuIconName)
                        : tower.kind.menuIconName
                    UpgradeMenuItem(towerMenuLayout: towerMenuLayout, iconName: iconName, dropKind: tower.kind,
                                    cost: offer.cost,
                                    isArmed: runner.armedUpgradeBranch == offer.branch,
                                    isAffordable: runner.money >= offer.cost,
                                    buttonSize: buttonSize) {
                        runner.tapUpgradeButton(branch: offer.branch)
                    }
                    .position(place(index))
                }
            }
            if hasRally {
                RallyMenuItem(towerMenuLayout: towerMenuLayout, buttonSize: rallyButtonSize) {
                    runner.toggleRallyPlacement()
                }
                .position(towerMenuLayout.getButtonSeatCenterPoint(
                    index: upgradeCount, count: count, menuCenterPoint: center,
                    playAreaScalingFactor: playAreaScalingFactor))
            }
        }
    }

    private func towerMenuBgImage(center: CGPoint, playAreaScalingFactor: CGFloat) -> some View {
        let size = towerMenuLayout.getBgSize(playAreaScalingFactor: playAreaScalingFactor)
        
        return Image("tower_menu_bg")
            .resizable()
            .frame(width: size.width, height: size.height)
            .position(center)
            .allowsHitTesting(false)
    }

    private func failBanner(metrics: HudMetrics) -> some View {
        ZStack {
            Color.black.opacity(0.45)
            Text("Done")
                .font(.system(size: Typography.size(104 * metrics.scale), weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.87, green: 0.09, blue: 0.09))
                .shadow(color: .black.opacity(0.85), radius: 7 * metrics.scale,
                        y: 3 * metrics.scale)
        }
        .allowsHitTesting(false)
    }

}

/// The icon on a path entrance while a wave is waiting to be called.
/// Double-tap to start the wave. A single tap does nothing.
/// Later waves show their automatic-start countdown.
/// The parchment bubble
/// sits on the map itself, apart from the square HUD controls; the redcoat
/// inside says who is coming. The pulse marks it as the thing the level is
/// waiting on.
private struct TowerMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let kind: TowerKind
    let isAvailable: Bool
    let isArmed: Bool
    let isAffordable: Bool
    let cost: Int?
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
    }

    @ViewBuilder private var content: some View {
        if isArmed {
            BuildConfirmButton(buttonSize: buttonSize, isAffordable: isAffordable)
        } else {
            icon
        }
    }

    private var icon: some View {
        let frameSize = buttonSize.width
        let iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: frameSize,
                                                       for: isAvailable ? kind : nil)

        return ZStack {
            Image(kind.menuFrameName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSize, height: frameSize)
            Image(isAvailable ? kind.menuIconName : "tower_locked_icon")
                .resizable()
                .scaledToFit()
                .frame(width: isAvailable ? iconSize : iconSize * 0.81,
                       height: isAvailable ? iconSize : iconSize * 0.81)
                .grayscale(isAvailable && !isAffordable ? 1 : 0)
            if isAvailable, let cost {
                TowerCostLabel(cost: cost, frameSize: frameSize)
                    .grayscale(isAffordable ? 0 : 1)
            }
        }
        .frame(width: frameSize, height: frameSize)
        .contentShape(Rectangle())
    }
}

private struct TowerCostLabel: View {
    let cost: Int?
    let frameSize: CGFloat

    private static let frameBottomEdgeCenter: CGFloat = 0.9568

    var body: some View {
        capsule
            .fixedSize()
            .position(x: frameSize / 2, y: frameSize * Self.frameBottomEdgeCenter)
    }

    @ViewBuilder private var capsule: some View {
        if let cost {
            pill(Text("\(cost)"), tint: Color(red: 1.0, green: 0.85, blue: 0.4))
        } else {
            pill(Text("MAX"), tint: .white.opacity(0.8))
        }
    }

    private func pill(_ text: Text, tint: Color) -> some View {
        text
            .font(.system(size: Typography.size(frameSize * 0.25), weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, frameSize * 0.089)
            .padding(.vertical, frameSize * 0.0254)
            .background(.black.opacity(0.78), in: Capsule())
    }
}

private struct BuildConfirmButton: View {
    let buttonSize: CGSize
    let isAffordable: Bool

    var body: some View {
        let side = buttonSize.width
        // This asset includes its frame. Desaturate just the inset green
        // panel/checkmark, preserving the original gold and metal border.
        return artwork
            .overlay {
                if !isAffordable {
                    artwork
                        .grayscale(1)
                        .mask {
                            RoundedRectangle(cornerRadius: side * 0.045)
                                .padding(side * 0.087)
                        }
                }
            }
            .contentShape(Rectangle())
    }

    private var artwork: some View {
        Image("tower_build_confirm")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: buttonSize.width, height: buttonSize.height)
    }
}

private struct UpgradeMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let iconName: String
    let dropKind: TowerKind
    let cost: Int?
    let isArmed: Bool
    let isAffordable: Bool
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(.plain)
            .disabled(cost == nil)
    }

    @ViewBuilder private var content: some View {
        if isArmed {
            BuildConfirmButton(buttonSize: buttonSize, isAffordable: isAffordable)
        } else {
            icon
        }
    }

    private var icon: some View {
        let frameSize = buttonSize.width
        let iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: frameSize, for: dropKind)

        return ZStack {
            Image(dropKind.menuFrameName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSize, height: frameSize)
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .grayscale(cost != nil && !isAffordable ? 1 : 0)
                .opacity(cost != nil ? 1 : 0.5)
            TowerCostLabel(cost: cost, frameSize: frameSize)
                .grayscale(cost != nil && !isAffordable ? 1 : 0)
        }
        .frame(width: frameSize, height: frameSize)
        .contentShape(Rectangle())
    }
}

private struct RallyMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        let side = buttonSize.width
        let iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: side)
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: side, height: side)
                Image("rally_point_icon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TemporaryRallyFlag: View {
    private static let targetCenterFraction: CGFloat = 0.69

    let size: CGFloat
    let plantPoint: CGPoint
    let onFinished: () -> Void

    @State private var faded = false

    var body: some View {
        Image("rally_point_icon")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .position(x: plantPoint.x,
                      y: plantPoint.y + size * (0.5 - Self.targetCenterFraction))
            .opacity(faded ? 0 : 1)
            .allowsHitTesting(false)
            .task {
                do {
                    try await Task.sleep(for: .seconds(3))
                    withAnimation(.easeOut(duration: 1)) { faded = true }
                    try await Task.sleep(for: .seconds(1))
                    onFinished()
                } catch {
                    // Removing this presentation cancels its lifetime task.
                }
            }
    }
}
