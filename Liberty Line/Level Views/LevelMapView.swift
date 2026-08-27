import SwiftUI

struct LevelMapProjection {
    /// The virtual canvas, from virtual_canvas. Map artwork is required to be
    /// exactly this size, so the projection never asks the image.
    var canvasSize: CGSize { virtualCanvas.size }
    let playArea: CGRect
    let fitRect: CGRect
    let virtualCanvas: VirtualCanvas

    var scale: CGFloat {
        min(fitRect.width / playArea.width, fitRect.height / playArea.height)
    }

    private var origin: CGPoint {
        // y is flipped by viewPoint, so the rect's centre is measured from the
        // top of the canvas here. Written out rather than relying on the rect
        // happening to be vertically centred.
        CGPoint(
            x: fitRect.midX - playArea.midX * scale,
            y: fitRect.midY - (canvasSize.height - playArea.midY) * scale
        )
    }

    /// Canonical (lower-left origin, +y up) to SwiftUI view space (+y down).
    /// The only place the game flips.
    func viewPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale,
                y: origin.y + (canvasSize.height - p.y) * scale)
    }

    func viewLength(_ l: CGFloat) -> CGFloat { l * scale }

    func mapPoint(_ v: CGPoint) -> CGPoint {
        CGPoint(x: (v.x - origin.x) / scale,
                y: canvasSize.height - (v.y - origin.y) / scale)
    }

    var viewTransform: CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
                          tx: origin.x, ty: origin.y + canvasSize.height * scale)
    }

    var imageFrameSize: CGSize {
        CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    var imageCenter: CGPoint {
        viewPoint(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
    }
}

struct LevelMapView: View {
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

    @AppStorage(Constants.debugModeKey) private var debugMode = false
    @AppStorage(Constants.showDebugLayoutGuidesKey) private var showDebugLayoutGuides = false

    private static let debugRangeBands: [(upperBound: CGFloat, tint: Color)] = [
        (200, Color(red: 0.13, green: 0.83, blue: 0.93)),        // cyan
        (250, Color(red: 0.38, green: 0.65, blue: 0.98)),        // blue
        (285, Color(red: 0.75, green: 0.52, blue: 0.99)),        // violet
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

    private func entranceIconSize(projection: LevelMapProjection) -> CGFloat {
        let tap = slotTapSize(projection: projection)
        return min(tap.width, tap.height)
    }

    private func entranceIconPositions(iconSize: CGFloat,
                                       projection: LevelMapProjection,
                                       runtimeCanvas: RuntimeCanvas) -> [CGPoint] {
        EntranceWaveButtonPlacement(
            entrancePaths: runner.entranceWavePaths.map { $0.map(projection.viewPoint) },
            slotCenters: runner.slotPositions.map(projection.viewPoint),
            slotSize: CGSize(width: projection.viewLength(runner.slotSize.width),
                             height: projection.viewLength(runner.slotSize.height)),
            buttonSize: iconSize,
            runtimeCanvas: runtimeCanvas).positions
    }

    private static func debugRangeTint(for range: CGFloat) -> Color {
        debugRangeBands.first { range < $0.upperBound }?.tint
            ?? debugRangeBands[debugRangeBands.count - 1].tint
    }

    private static let slotTowerScale: CGFloat = 1.270
    private static let slotTowerLift: CGFloat = 0.11
    
    private var db: Db
    private var virtualCanvas: VirtualCanvas
    private var runtimeCanvas: RuntimeCanvas

    init(db: Db,
         virtualCanvas: VirtualCanvas,
         runtimeCanvas: RuntimeCanvas,
         towerMenuLayout: TowerMenuLayout,
         node: CampaignNode,
         difficulty: Difficulty, onExit: @escaping () -> Void) {
        self.db = db
        self.virtualCanvas = virtualCanvas
        self.runtimeCanvas = runtimeCanvas
        self.towerMenuLayout = towerMenuLayout
        self.node = node
        self.difficulty = difficulty
        self.onExit = onExit
        _runner = StateObject(wrappedValue: LevelRunner(
            db: db,
            virtualCanvas: virtualCanvas,
            levelInfoID: node.levelInfoID,
            mapImageName: node.mapImageName,
            enemyHPMultiplier: difficulty.enemyHPMultiplier
        ))
    }

    var body: some View {
        let fullSize = runtimeCanvas.physicalRect.size
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        ZStack(alignment: .topLeading) {
            content(in: fullSize, runtimeCanvas: runtimeCanvas)

            if runner.isDefeated {
                failBanner(metrics: metrics)
            }

            HudView(runtimeCanvas: runtimeCanvas,
                    db: db,
                    runner: runner,
                    towerMenuLayout: towerMenuLayout,
                    onSpeedUp: { runner.speedUp() },
                    onExit: onExit)
                .border(debugMode ? Color.cyan : Color.clear, width: debugMode ? 3 : 0)

            towerMenuLayer(in: fullSize, runtimeCanvas: runtimeCanvas)
            
            if showDebugLayoutGuides {
                DebugLayoutGuidesView(runtimeCanvas: runtimeCanvas)
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { runner.start() }
        .onDisappear { runner.stop() }
        .border(debugMode ? Color.orange : Color.clear, width: debugMode ? 3 : 0)
    }

    private func content(in viewSize: CGSize, runtimeCanvas: RuntimeCanvas) -> some View {
        // Full-bleed map: fit the 16:9 playable rect, not safe — HUD only.
        let safe = runtimeCanvas.safeInsetsRect
        let projection = LevelMapArt.projection(virtualCanvas: virtualCanvas, fitting: runtimeCanvas.playAreaRect)
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        let sprites = MapSpriteScale(playArea: runner.playArea,
                                     viewSize: viewSize)
        let art = runner.mapArt
        return ZStack(alignment: .topLeading) {
            Color.black

            Group {
                Image("tower_menu_bg")
                Image("tower_menu_square_frame")
                ForEach(TowerKind.allCases) { kind in
                    Image(kind.menuIconName)
                }
                Image("tower_locked_icon")
            }
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)

            art.underlay(in: projection)

            LevelTowerSlotsView(
                debugMode: debugMode,
                slotPositions: runner.slotPositions,
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
                    let basePoint = projection.viewPoint(tower.position)

                    if tower.kind.usesSlotCanvasArt {
                        let slotBox = runner.slotSize
                        // Drawn on tower_slot.png's canvas, so it starts from
                        // the slot's own box, scaled by the same projection
                        // that fits the play area to the runtimeCanvas —
                        // scaledToFit matches the renderer's `fit: "inside"`.
                        // On device that exact fit read too small and too
                        // sunken, so the art draws scaled up and lifted; both
                        // knobs are the constants below.
                        let towerW = projection.viewLength(slotBox.width)
                            * Self.slotTowerScale
                        let towerH = projection.viewLength(slotBox.height)
                            * Self.slotTowerScale
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: towerW, height: towerH)
                            .position(x: basePoint.x,
                                      y: basePoint.y - towerH * Self.slotTowerLift)
                    } else {
                        // Tight-cropped art, sized by its own sprite height and
                        // lifted so the base sits on the slot.
                        ZStack(alignment: .bottom) {
                            Image(assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: towerHeight)
                        }
                        .position(
                            x: basePoint.x,
                            y: basePoint.y - towerHeight / 2
                                + sprites.points(MapSpriteSizing.towerBaseLift)
                                + towerHeight * 0.20
                        )
                    }
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
                let spriteHeight = sprites.points(MapSpriteSizing.walker)
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

            // Above every playable layer, below the menus and the HUD.
            art.occlusion(in: projection)

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

            // The entrance icons: one on each mouth the held wave will
            // spawn from. Above the occlusion art that covers the entrances
            // and above the slot buttons — a slot's invisible tap ellipse
            // can reach an entrance, and while the level waits the icon
            // must win that overlap — but below the menus. Double-tapping
            // any one of them starts the wave.
            if runner.awaitingWaveStart {
                let iconSize = entranceIconSize(projection: projection)
                ForEach(Array(entranceIconPositions(iconSize: iconSize,
                                                    projection: projection,
                                                    runtimeCanvas: runtimeCanvas).enumerated()),
                        id: \.offset) { _, position in
                    EntranceWaveButton(size: iconSize) {
                        runner.startNextWave()
                    }
                    .position(position)
                }
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

    private func towerMenuLayer(in viewSize: CGSize, runtimeCanvas: RuntimeCanvas) -> some View {
        let projection = LevelMapArt.projection(virtualCanvas: virtualCanvas, fitting: runtimeCanvas.playAreaRect)
        let playAreaScalingFactor = runtimeCanvas.scaleFactor
        return ZStack(alignment: .topLeading) {
            if let buildSlot = runner.selectedSlotIndex,
               runner.slotPositions.indices.contains(buildSlot) {
                if let radius = runner.armedBuildKind.flatMap({ runner.buildPreviewRadius(for: $0) })
                    ?? runner.defaultBuildPreviewRadius() {
                    TowerRangeOverlayView(
                        center: projection.viewPoint(runner.slotPositions[buildSlot]),
                        range: radius, pointsPerMapUnit: projection.scale)
                }
                dismissCatcher()
                towerMenu(around: projection.viewPoint(runner.slotPositions[buildSlot]),
                          playAreaScalingFactor: playAreaScalingFactor)
            }
            if let upgradeSlot = runner.selectedTowerSlotIndex,
               runner.slotPositions.indices.contains(upgradeSlot),
               let tower = runner.placedTower(atSlot: upgradeSlot) {
                let previewRadius = runner.armedUpgradeBranch
                    .flatMap { runner.upgradePreviewRadius(branch: $0) }
                if let radius = previewRadius ?? runner.rangeOverlayRadius(for: tower) {
                    TowerRangeOverlayView(
                        center: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                        range: radius, pointsPerMapUnit: projection.scale)
                }
                if runner.isPlacingRallyPoint {
                    rallyPlacementCatcher(projection: projection)
                } else {
                    dismissCatcher()
                }
                upgradeMenu(for: tower, around: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                            playAreaScalingFactor: playAreaScalingFactor)
                if let rally = runner.rallyPoint(forSlot: upgradeSlot) {
                    RallyFlag(size: HudSizing.cornerButton.resolved(at: HudMetrics(runtimeCanvas: runtimeCanvas).scale) * 0.6)
                        .position(projection.viewPoint(rally))
                        .allowsHitTesting(false)
                }
            }
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
        let size = TowerRangeOverlay.size(range: range, pointsPerMapUnit: projection.scale)
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
                                cost: nil, isArmed: false, buttonSize: buttonSize) {}
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
                                    buttonSize: buttonSize) {
                        runner.tapUpgradeButton(branch: offer.branch)
                    }
                    .position(place(index))
                }
            }
            if hasRally {
                RallyMenuItem(towerMenuLayout: towerMenuLayout, isArmed: runner.isPlacingRallyPoint, buttonSize: buttonSize) {
                    runner.toggleRallyPlacement()
                }
                .position(place(upgradeCount))
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
/// Double-tap to start the wave — a single tap does nothing, so a stray
/// tap near an entrance never brings the enemy early. The parchment bubble
/// sits on the map itself, apart from the square HUD controls; the redcoat
/// inside says who is coming. The pulse marks it as the thing the level is
/// waiting on.
private struct EntranceWaveButton: View {
    let size: CGFloat
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Image("radial_menu_bubble")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
            Image("redcoat_regular")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.62, height: size * 0.62)
        }
        .frame(width: size, height: size)
        .scaleEffect(isPulsing ? 1.08 : 0.94)
        .contentShape(Circle())
        .onTapGesture(count: 2, perform: action)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct TowerMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let kind: TowerKind
    let isAvailable: Bool
    let isArmed: Bool
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        Button(action: action) { icon }
            .buttonStyle(.plain)
    }

    private var icon: some View {
        let frameSize = buttonSize.width
        let iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: frameSize)
        
        return ZStack {
            Image("tower_menu_square_frame")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSize, height: frameSize)
            Image(isAvailable ? kind.menuIconName : "tower_locked_icon")
                .resizable()
                .scaledToFit()
                .frame(width: isAvailable ? iconSize : iconSize * 0.81,
                       height: isAvailable ? iconSize : iconSize * 0.81)
        }
        .frame(width: frameSize, height: frameSize)
        .overlay(alignment: .topTrailing) {
            if isArmed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: iconSize * 0.38, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .shadow(radius: frameSize * 0.015)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct UpgradeMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let iconName: String
    let dropKind: TowerKind
    let cost: Int?
    let isArmed: Bool
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        let frameSize = buttonSize.width
        let iconSize = towerMenuLayout.getTowerIconSize(towerButtonSize: frameSize)
        
        return Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: frameSize, height: frameSize)
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .opacity(cost != nil ? 1 : 0.5)
            }
            .frame(width: frameSize, height: frameSize)
            .overlay(alignment: .bottom) {
                costCapsule(frameSize: frameSize)
                    .fixedSize()
                    .alignmentGuide(.bottom) { $0[.top] - frameSize * 0.05 }
            }
            .overlay(alignment: .topTrailing) {
                if isArmed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize * 0.38, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .shadow(radius: frameSize * 0.015)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cost == nil)
    }

    @ViewBuilder private func costCapsule(frameSize: CGFloat) -> some View {
        let scale = frameSize / towerMenuLayout.getTowerIconSize(towerButtonSize: frameSize)

        if let cost {
            Label("\(cost)", systemImage: "circle.fill")
                .font(.system(size: Typography.size(12 * scale), weight: .bold))
                .labelStyle(.titleOnly)
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.4))
                .padding(.horizontal, 8 * scale)
                .padding(.vertical, 2 * scale)
                .background(.black.opacity(0.7), in: Capsule())
        } else {
            Text("MAX")
                .font(.system(size: Typography.size(11 * scale), weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 8 * scale)
                .padding(.vertical, 2 * scale)
                .background(.black.opacity(0.55), in: Capsule())
        }
    }
}

private struct RallyMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let isArmed: Bool
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
                RallyFlag(size: iconSize)
            }
            .frame(width: side, height: side)
            .overlay(alignment: .topTrailing) {
                if isArmed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize * 0.38, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .shadow(radius: side * 0.015)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RallyFlag: View {
    let size: CGFloat

    private var pennant: SwiftUI.Path {
        var p = SwiftUI.Path()
        p.move(to: CGPoint(x: size * 0.08, y: 0))
        p.addLine(to: CGPoint(x: size * 0.95, y: size * 0.22))
        p.addLine(to: CGPoint(x: size * 0.08, y: size * 0.44))
        p.closeSubpath()
        return p
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color(red: 0.25, green: 0.2, blue: 0.15))
                .frame(width: size * 0.08, height: size)
            pennant.fill(Color(red: 0.16, green: 0.32, blue: 0.7))
            pennant.stroke(Color.white.opacity(0.85), lineWidth: 1)
        }
        .frame(width: size, height: size, alignment: .bottomLeading)
        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
    }
}
