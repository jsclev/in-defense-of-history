import SwiftUI

struct LevelMapProjection {
    /// The virtual canvas, from canvas_spec. Map artwork is required to be
    /// exactly this size, so the projection never asks the image.
    var canvasSize: CGSize { CanvasSpec.size }
    let playArea: CGRect
    let fitRect: CGRect

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

    var imageFrameSize: CGSize {
        CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    var imageCenter: CGPoint {
        viewPoint(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
    }
}

typealias RadialMenu = RadialMenuLayout

struct LevelMapView: View {
    var node: CampaignNode
    var difficulty: Difficulty
    var onExit: () -> Void

    @StateObject private var runner: LevelRunner
    @State private var towerSlotCount: Int = 0

    /// Slots whose debug ring the player has dismissed by tapping its legend.
    /// Tapping the slot itself brings it back. Debug mode only, and not
    /// persisted — a fresh level starts with every ring showing.
    @State private var hiddenRangeSlots: Set<Int> = []

    @AppStorage("debugMode") private var debugMode = true
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage(SafeAreaOverlay.defaultsKey) private var showSafeAreaOverlay = false

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

    /// The per-slot tap-size readout is parked, not resolved: John wants to
    /// come back to the tap-target question, so the display is switched off
    /// here while everything that computes it stays live. Flip to true to see
    /// the capsules under each slot again in debug mode.
    private static let showSlotTapInfo = false

    /// The entrance icon's box: the slot tap target's smaller side, so the
    /// icon scales with the map yet never drops below Apple's 44pt minimum.
    private func entranceIconSize(projection: LevelMapProjection) -> CGFloat {
        let tap = slotTapSize(projection: projection)
        return min(tap.width, tap.height)
    }

    /// A path mouth can sit in the canvas bleed outside the play area — past
    /// the screen edge on some devices — so the icon stays centred on its
    /// entrance whenever that fits and otherwise pulls the minimum distance
    /// needed to sit whole inside the safe rect.
    private func entranceIconPosition(for entrance: CGPoint, size: CGFloat,
                                      projection: LevelMapProjection,
                                      safe: CGRect) -> CGPoint {
        let p = projection.viewPoint(entrance)
        let half = size / 2
        return CGPoint(x: min(max(p.x, safe.minX + half), safe.maxX - half),
                       y: min(max(p.y, safe.minY + half), safe.maxY - half))
    }

    /// One icon position per held-wave entrance, clamped into the safe
    /// rect. Mouths that land within an icon of one another collapse to a
    /// single icon: double-tapping any icon starts the whole wave, so
    /// near-coincident mouths never need a stack of pulsing bubbles.
    private func entranceIconPositions(iconSize: CGFloat,
                                       projection: LevelMapProjection,
                                       safe: CGRect) -> [CGPoint] {
        var placed: [CGPoint] = []
        for entrance in runner.entrancePositions {
            let p = entranceIconPosition(for: entrance, size: iconSize,
                                         projection: projection, safe: safe)
            if placed.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) >= iconSize }) {
                placed.append(p)
            }
        }
        return placed
    }

    private static func debugRangeTint(for range: CGFloat) -> Color {
        debugRangeBands.first { range < $0.upperBound }?.tint
            ?? debugRangeBands[debugRangeBands.count - 1].tint
    }

    /// Display tuning for slot-canvas tower art, judged on device. Scale is
    /// relative to the slot box the art would otherwise fit exactly; lift is
    /// a fraction of the drawn tower height, moving it up the screen. Render
    /// tuning for the art pipeline, like `usesSlotCanvasArt` — not level
    /// content, which is why it lives here and not in the database.
    private static let slotTowerScale: CGFloat = 1.270
    private static let slotTowerLift: CGFloat = 0.11

    init(node: CampaignNode, difficulty: Difficulty, onExit: @escaping () -> Void) {
        self.node = node
        self.difficulty = difficulty
        self.onExit = onExit
        _runner = StateObject(wrappedValue: LevelRunner(
            levelInfoID: node.levelInfoID,
            mapImageName: node.mapImageName,
            enemyHPMultiplier: difficulty.enemyHPMultiplier
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            let screen = ScreenGeometry(proxy: geometry)
            let fullSize = screen.physical.size
            let metrics = HudMetrics(viewSize: fullSize)
            ZStack(alignment: .topLeading) {
                GeometryReader { gameGeometry in
                    content(in: gameGeometry.size, screen: screen)
                }
                .ignoresSafeArea()

                if showSafeAreaOverlay {
                    SafeAreaOverlayView(screen: screen)
                        .ignoresSafeArea()
                }

                if runner.isDefeated {
                    failBanner(metrics: metrics)
                        .ignoresSafeArea()
                }

                topBar(metrics: metrics,
                       isPortrait: geometry.size.height > geometry.size.width,
                       screen: screen)
                    .ignoresSafeArea()
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { runner.start() }
        .onDisappear { runner.stop() }
    }

    /// The single top-of-screen HUD entity. Everything that sits along the
    /// top — counters, wave readout, speed/pause buttons — renders inside
    /// this one container, vertically positioned by one TopBarLayout, whose
    /// margin is the one number in HudSizing.topBarMargin.
    private func topBar(metrics: HudMetrics, isPortrait: Bool,
                        screen: ScreenGeometry) -> some View {
        let bar = TopBarLayout(screen: screen)
        return ZStack(alignment: .topLeading) {
            hud(metrics: metrics, isPortrait: isPortrait,
                screen: screen, topBar: bar)
            cornerButtons(screen: screen, topBar: bar)
        }
    }

    private func cornerButtons(screen: ScreenGeometry,
                               topBar: TopBarLayout) -> some View {
        let layout = CornerButtonsLayout(screen: screen, topBar: topBar)
        return ZStack(alignment: .topLeading) {
            cornerButton(asset: "speed_up_icon", frame: layout.speed,
                         in: screen) { runner.speedUp() }
            cornerButton(asset: "pause_icon", frame: layout.pause,
                         in: screen, action: onExit)
        }
    }

    private func cornerButton(asset: String, frame: CGRect,
                              in screen: ScreenGeometry,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // The composed square tower-style controls: glyph baked into the
            // same ashwood frame the tower menu's choices sit on. The explicit
            // frame pins the tap rect to the layout box, not the fitted image.
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hudFrame(frame, in: screen)
    }

    private func content(in viewSize: CGSize, screen: ScreenGeometry) -> some View {
        // Full-bleed map: fit the 16:9 playable rect, not safe — HUD only.
        let safe = screen.safe
        let projection = LevelMapProjection(
            playArea: runner.playArea,
            fitRect: screen.playable
        )
        let metrics = HudMetrics(viewSize: viewSize)
        let sprites = MapSpriteScale(playArea: runner.playArea,
                                     viewSize: viewSize)
        let art = runner.mapArt
        return ZStack(alignment: .topLeading) {
            Color.black

            Group {
                Image(RadialMenu.backgroundAssetName(count: TowerKind.allCases.count))
                Image(RadialMenu.backgroundAssetName(count: 1))
                Image(RadialMenu.backgroundAssetName(count: 2))
                Image(RadialMenu.backgroundAssetName(count: 3))
                Image("radial_menu_bubble")
                Image("tower_menu_square_frame")
                ForEach(TowerKind.allCases) { kind in
                    Image(kind.menuIconName)
                }
                Image("tower_locked_icon")
            }
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)

            art.underlay
                .frame(width: projection.imageFrameSize.width,
                       height: projection.imageFrameSize.height)
                .position(projection.imageCenter)

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
                        // that fits the play area to the screen —
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

            // A path can begin and end close to the play area's side
            // boundaries.  This full-canvas alpha layer contains only
            // compact forest clusters at those GeoJSON endpoints.  Rendering
            // it after walkers makes soldiers enter from and disappear into
            // foliage on wide iPhones; interactive controls remain above it.
            if let forestName = art.forestOcclusionName {
                Image(forestName)
                    .resizable()
                    .frame(width: projection.imageFrameSize.width,
                           height: projection.imageFrameSize.height)
                    .position(projection.imageCenter)
                    .allowsHitTesting(false)
            }

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

            // The occlusion overlay: level art that covers the entrances and
            // exits, hiding enemies before they enter and after they leave.
            // Above every playable layer, below the menus and the HUD, and
            // transparent to touches so the slots under it stay tappable.
            if let occlusionName = art.occlusionName {
                Image(occlusionName)
                    .resizable()
                    .frame(width: projection.imageFrameSize.width,
                           height: projection.imageFrameSize.height)
                    .position(projection.imageCenter)
                    .allowsHitTesting(false)
            }

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
                                                    safe: safe).enumerated()),
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

            if let buildSlot = runner.selectedSlotIndex,
               runner.slotPositions.indices.contains(buildSlot) {
                if let armed = runner.armedBuildKind,
                   let radius = runner.buildPreviewRadius(for: armed) {
                    rangeOverlay(
                        center: projection.viewPoint(runner.slotPositions[buildSlot]),
                        diameter: projection.viewLength(radius) * 2)
                }
                dismissCatcher(viewSize: viewSize)
                radialBuildMenu(around: projection.viewPoint(runner.slotPositions[buildSlot]),
                                scale: metrics.scale)
            }
            if let upgradeSlot = runner.selectedTowerSlotIndex,
               runner.slotPositions.indices.contains(upgradeSlot),
               let tower = runner.placedTower(atSlot: upgradeSlot) {
                // Armed upgrade previews the upgraded tier's range; otherwise
                // the overlay shows the tower's current range.
                let previewRadius = runner.armedUpgradeBranch
                    .flatMap { runner.upgradePreviewRadius(branch: $0) }
                if let radius = previewRadius ?? runner.rangeOverlayRadius(for: tower) {
                    rangeOverlay(
                        center: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                        diameter: projection.viewLength(radius) * 2)
                }
                dismissCatcher(viewSize: viewSize)
                upgradeMenu(for: tower, around: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                            scale: metrics.scale)
            }

        }
    }

    /// Rows in `debugRangeLegend`. Used to size the panel before it is laid
    /// out, so keep it in step with the `GridRow`s below.
    private static let debugLegendRowCount: CGFloat = 5

    /// What `debugRangeLegend` will stand, before SwiftUI lays it out — needed
    /// to choose a side, which has to be decided while building the view. The
    /// line-height factor deliberately runs high: overestimating flips the
    /// legend below a touch early, underestimating clips it off screen.
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
        let diameter: CGFloat
        let tint: Color
        let gap: CGFloat
        let legendAbove: Bool
    }

    private func debugRingGeometry(for tower: PlacedTower,
                                   range: CGFloat,
                                   projection: LevelMapProjection,
                                   safe: CGRect,
                                   metrics: HudMetrics) -> DebugRingGeometry {
        let diameter = projection.viewLength(range) * 2
        let center = projection.viewPoint(tower.position)
        let gap = 6 * metrics.scale

        // The legend sits above the ring by default. A tower high on the map
        // puts that off the top of the screen, so when it will not clear the
        // safe area it flips to the far side of the circle instead.
        let above = center.y - diameter / 2 - gap
            - debugLegendHeight(metrics: metrics) >= safe.minY

        return DebugRingGeometry(center: center, diameter: diameter,
                                 tint: Self.debugRangeTint(for: range),
                                 gap: gap, legendAbove: above)
    }

    /// The ring itself, drawn under the tower sprites and never hit-tested so
    /// it cannot swallow taps meant for the slot buttons beneath it.
    private func debugRangeRing(_ ring: DebugRingGeometry) -> some View {
        Circle()
            .fill(ring.tint.opacity(0.12))
            .overlay(
                ZStack {
                    Circle().stroke(.black.opacity(0.45), lineWidth: 4)
                    Circle().stroke(ring.tint, lineWidth: 2)
                }
            )
            .frame(width: ring.diameter, height: ring.diameter)
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
            .frame(width: ring.diameter, height: ring.diameter)
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

    /// Light-green range ring under a radial menu: shown while a build choice
    /// is armed awaiting its confirming second tap, and while a placed
    /// tower's upgrade menu is open. Attack range for shooting towers, rally
    /// radius for melee. Never hit-tested, so it cannot swallow the
    /// confirming or cancelling tap.
    private func rangeOverlay(center: CGPoint, diameter: CGFloat) -> some View {
        Circle()
            .fill(Color.green.opacity(0.16))
            .overlay(
                ZStack {
                    Circle().stroke(.black.opacity(0.35), lineWidth: 4)
                    Circle().stroke(Color.green.opacity(0.8), lineWidth: 2)
                }
            )
            .frame(width: diameter, height: diameter)
            .position(center)
            .allowsHitTesting(false)
    }

    private func dismissCatcher(viewSize: CGSize) -> some View {
        Color.black.opacity(0.001)
            .frame(width: viewSize.width, height: viewSize.height)
            .onTapGesture { runner.dismissMenu() }
    }

    private func radialBuildMenu(around anchor: CGPoint, scale: CGFloat) -> some View {
        let kinds = TowerKind.allCases
        // One adjusted centre for the background and every item, so nothing
        // in the menu can drift from anything else.
        let center = RadialMenu.menuCenter(anchor: anchor, count: kinds.count,
                                           scale: scale)
        return Group {
            radialMenuBackground(count: kinds.count, center: center, scale: scale)
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                let offset = RadialMenu.itemOffset(index: index, count: kinds.count)
                BuildMenuItem(kind: kind, isAvailable: runner.maxLevel(for: kind) >= 1,
                              isArmed: runner.armedBuildKind == kind,
                              scale: scale) {
                    runner.tapBuildButton(kind)
                }
                .position(x: center.x + offset.width * scale,
                          y: center.y + offset.height * scale)
            }
        }
    }

    private func upgradeMenu(for tower: PlacedTower, around anchor: CGPoint,
                             scale: CGFloat) -> some View {
        let offers = runner.upgradeOffers
        let count = max(offers.count, 1)
        // Same shared centre as the build menu: background and items move as
        // one, always.
        let center = RadialMenu.menuCenter(anchor: anchor, count: count,
                                           scale: scale)
        return Group {
            radialMenuBackground(count: count, center: center, scale: scale)
            if offers.isEmpty {
                let offset = RadialMenu.itemOffset(index: 0, count: 1)
                UpgradeMenuItem(iconName: tower.kind.menuIconName,
                                dropKind: tower.kind, cost: nil,
                                isArmed: false, scale: scale) {}
                    .position(x: center.x + offset.width * scale,
                              y: center.y + offset.height * scale)
            } else {
                ForEach(Array(offers.enumerated()), id: \.offset) { index, offer in
                    let offset = RadialMenu.itemOffset(index: index, count: count)
                    let iconName = offers.count > 1
                        ? (tower.kind.assetName(atLevel: offer.nextLevel,
                                                branch: offer.branch) ?? tower.kind.menuIconName)
                        : tower.kind.menuIconName
                    UpgradeMenuItem(iconName: iconName, dropKind: tower.kind,
                                    cost: offer.cost,
                                    isArmed: runner.armedUpgradeBranch == offer.branch,
                                    scale: scale) {
                        runner.tapUpgradeButton(branch: offer.branch)
                    }
                    .position(x: center.x + offset.width * scale,
                              y: center.y + offset.height * scale)
                }
            }
        }
    }

    private func radialMenuBackground(count: Int, center: CGPoint,
                                      scale: CGFloat) -> some View {
        Image(RadialMenu.backgroundAssetName(count: count))
            .resizable()
            .frame(width: RadialMenu.backgroundDiameter(count: count) * scale,
                   height: RadialMenu.backgroundDiameter(count: count) * scale)
            .position(center)
            .allowsHitTesting(false)
    }

    private func hud(metrics: HudMetrics, isPortrait: Bool,
                     screen: ScreenGeometry, topBar: TopBarLayout) -> some View {
        let panel = StatsPanelLayout(
            screen: screen, topBar: topBar, isPortrait: isPortrait,
            livesIconAspect: HudIcon.aspect(of: "lives_icon_05"),
            moneyIconAspect: HudIcon.aspect(of: "money_icon_12"),
            moneyText: goldText)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: metrics.statPlateCorner, style: .continuous)
                .fill(.black.opacity(HudSizing.statPlateOpacity))
                .hudFrame(panel.livesPlate, in: screen)
            RoundedRectangle(cornerRadius: metrics.statPlateCorner, style: .continuous)
                .fill(.black.opacity(HudSizing.statPlateOpacity))
                .hudFrame(panel.moneyPlate, in: screen)

            Image("lives_icon_05").resizable().scaledToFit()
                .hudFrame(panel.lives.icon, in: screen)
            counterText("\(runner.lives)", fontSize: panel.lives.fontSize)
                .hudFrame(panel.lives.valueBox, in: screen, alignment: .topLeading)

            Image("money_icon_12").resizable().scaledToFit()
                .hudFrame(panel.money.icon, in: screen)
            counterText(goldText, fontSize: panel.money.fontSize)
                .hudFrame(panel.money.valueBox, in: screen, alignment: .topLeading)

            counterText("Wave \(runner.currentWaveNumber) of \(runner.waveCount)",
                        fontSize: panel.waveFontSize)
                .padding(.horizontal, metrics.statPlatePadding * 1.4)
                .padding(.vertical, metrics.statPlatePadding * 0.6)
                .background(.black.opacity(HudSizing.statPlateOpacity),
                            in: RoundedRectangle(cornerRadius: metrics.statPlateCorner,
                                                 style: .continuous))
                .hudFrame(panel.waveBox.insetBy(dx: 0, dy: -metrics.statPlatePadding),
                          in: screen, alignment: .top)

            if showDebugInfo {
                Text(runner.status)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                    .hudFrame(CGRect(x: panel.bounds.minX,
                                     y: panel.bounds.maxY + 12 * metrics.scale,
                                     width: 600, height: 60),
                              in: screen, alignment: .topLeading)
            }
        }
    }

    private func counterText(_ value: String, fontSize: CGFloat) -> some View {
        Text(value)
            .font(.system(size: Typography.size(fontSize), weight: .black, design: .rounded)
                .monospacedDigit())
            .lineLimit(1)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var goldText: String {
        let money = runner.money
        return money >= 1000
            ? "\(money / 1000),\(String(format: "%03d", money % 1000))"
            : "\(money)"
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

private struct BuildMenuItem: View {
    let kind: TowerKind
    let isAvailable: Bool
    let isArmed: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) { icon }
            .buttonStyle(.plain)
    }

    private var icon: some View {
        let buttonSide = RadialMenu.buttonSide * scale
        let frameSide = RadialMenu.squareFrameSide * scale
        let iconSize = RadialMenu.menuIconSide * scale
        // The opaque square frame covers the round well baked into the radial
        // art; the pictogram is centred in the tap box, which itemOffset
        // centres on the bubble — no offsets anywhere in between.
        return ZStack {
            Image("tower_menu_square_frame")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSide, height: frameSide)
            Image(isAvailable ? kind.menuIconName : "tower_locked_icon")
                .resizable()
                .scaledToFit()
                .frame(width: isAvailable ? iconSize : iconSize * 0.81,
                       height: isAvailable ? iconSize : iconSize * 0.81)
        }
        .frame(width: buttonSide, height: buttonSide)
        .overlay(alignment: .topTrailing) {
            if isArmed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: iconSize * 0.38, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .shadow(radius: 1 * scale)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct UpgradeMenuItem: View {
    let iconName: String
    let dropKind: TowerKind
    let cost: Int?
    let isArmed: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        let buttonSide = RadialMenu.buttonSide * scale
        let frameSide = RadialMenu.squareFrameSide * scale
        let iconSize = RadialMenu.menuIconSide * scale
        // The button's layout box is exactly the tap box, with the icon
        // centred in it, so positioning the button centres the icon on its
        // parchment bubble. The cost capsule hangs below as an overlay and
        // never shifts the icon — a VStack here would centre the icon+capsule
        // pair instead, riding the icon up off the bubble.
        return Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: frameSide, height: frameSide)
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .opacity(cost != nil ? 1 : 0.5)
            }
            .frame(width: buttonSide, height: buttonSide)
            .overlay(alignment: .bottom) {
                costCapsule
                    .fixedSize()
                    // Sits the capsule's top just under the tap box.
                    .alignmentGuide(.bottom) { $0[.top] - 3 * scale }
            }
            .overlay(alignment: .topTrailing) {
                if isArmed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize * 0.38, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .shadow(radius: 1 * scale)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cost == nil)
    }

    @ViewBuilder private var costCapsule: some View {
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

#Preview {
    LevelMapView(node: CampaignNode.load()[0],
                 difficulty: Difficulty(id: UUID(), level: 4, name: "Hardened",
                                        detail: "", enemyHPMultiplier: 1.75),
                 onExit: {})
}
