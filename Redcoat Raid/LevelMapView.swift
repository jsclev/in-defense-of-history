import SwiftUI

struct LevelMapProjection {
    let imageSize: CGSize
    let playableRect: CGRect
    let fitRect: CGRect

    var scale: CGFloat {
        min(fitRect.width / playableRect.width, fitRect.height / playableRect.height)
    }

    private var origin: CGPoint {
        // y is flipped by viewPoint, so the rect's centre is measured from the
        // top of the canvas here. Written out rather than relying on the rect
        // happening to be vertically centred.
        CGPoint(
            x: fitRect.midX - playableRect.midX * scale,
            y: fitRect.midY - (imageSize.height - playableRect.midY) * scale
        )
    }

    /// Canonical (lower-left origin, +y up) to SwiftUI view space (+y down).
    /// The only place the game flips.
    func viewPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale,
                y: origin.y + (imageSize.height - p.y) * scale)
    }

    func viewLength(_ l: CGFloat) -> CGFloat { l * scale }

    var imageFrameSize: CGSize {
        CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    var imageCenter: CGPoint {
        viewPoint(CGPoint(x: imageSize.width / 2, y: imageSize.height / 2))
    }
}

enum RadialMenu {
    static let radius: CGFloat = 91.0

    static let buttonSide: CGFloat = 86.70

    static let iconFraction: CGFloat = 0.5321

    static var iconSide: CGFloat { buttonSide * iconFraction }

    private static let fourChoiceArtScale: CGFloat = (90.5 / 409.5) * 0.9 * 0.92 * 0.96

    private static let variantArtScale: CGFloat = radius / 541

    static let iconDropFraction: CGFloat = 0

    static func iconDropFraction(for _: TowerKind) -> CGFloat {
        iconDropFraction
    }

    private struct Art {
        let assetName: String
        let canvasPx: CGFloat
        let parchmentPx: CGFloat
        let pointsPerPx: CGFloat
        let bubbleOffsetsPx: [CGSize]
    }

    private static let arts: [Int: Art] = [
        1: Art(assetName: "radial_menu_1_choice", canvasPx: 1536,
               parchmentPx: 192, pointsPerPx: variantArtScale,
               bubbleOffsetsPx: [CGSize(width: 0, height: -540)]),
        2: Art(assetName: "radial_menu_2_choices", canvasPx: 1536,
               parchmentPx: 192, pointsPerPx: variantArtScale,
               bubbleOffsetsPx: [CGSize(width: 0, height: -540),
                                 CGSize(width: 0, height: 543)]),
        3: Art(assetName: "radial_menu_3_choices", canvasPx: 1536,
               parchmentPx: 192, pointsPerPx: variantArtScale,
               bubbleOffsetsPx: [CGSize(width: 0, height: -540),
                                 CGSize(width: 469, height: 270),
                                 CGSize(width: -469, height: 271)]),
        4: Art(assetName: "tower_menu_v02", canvasPx: 1536,
               parchmentPx: 251, pointsPerPx: fourChoiceArtScale,
               bubbleOffsetsPx: [CGSize(width: -366, height: -366),
                                 CGSize(width: 366, height: -366),
                                 CGSize(width: 366, height: 366),
                                 CGSize(width: -366, height: 366)]),
    ]

    private static func art(count: Int) -> Art {
        arts[min(max(count, 1), 4)]!
    }

    static func backgroundAssetName(count: Int) -> String {
        art(count: count).assetName
    }

    static func backgroundDiameter(count: Int) -> CGFloat {
        let art = art(count: count)
        return art.canvasPx * art.pointsPerPx
    }

    static func iconWellDiameter(count: Int) -> CGFloat {
        let art = art(count: count)
        return art.parchmentPx * art.pointsPerPx
    }

    static let itemSpread: CGFloat = 1.134

    static func itemOffset(index: Int, count: Int) -> CGSize {
        let art = art(count: count)
        guard art.bubbleOffsetsPx.indices.contains(index) else {
            let angle = Angle.degrees(-90 + Double(index) * 360 / Double(count))
            return CGSize(width: radius * itemSpread * cos(angle.radians),
                          height: radius * itemSpread * sin(angle.radians))
        }
        return CGSize(width: art.bubbleOffsetsPx[index].width * art.pointsPerPx * itemSpread,
                      height: art.bubbleOffsetsPx[index].height * art.pointsPerPx * itemSpread)
    }
}

struct LevelMapView: View {
    var node: CampaignNode
    var onExit: () -> Void

    @StateObject private var runner: LevelRunner

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

    private static func debugRangeTint(for range: CGFloat) -> Color {
        debugRangeBands.first { range < $0.upperBound }?.tint
            ?? debugRangeBands[debugRangeBands.count - 1].tint
    }

    init(node: CampaignNode, onExit: @escaping () -> Void) {
        self.node = node
        self.onExit = onExit
        _runner = StateObject(wrappedValue: LevelRunner(
            levelInfoID: node.levelInfoID,
            mapImageName: node.mapImageName,
            mapImageSize: node.mapImageSize
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            let screen = ScreenGeometry(proxy: geometry)
            let fullSize = screen.physical.size
            let metrics = HudMetrics(viewSize: fullSize)
            ZStack(alignment: .topLeading) {
                GeometryReader { gameGeometry in
                    content(in: gameGeometry.size, safe: screen.safe)
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

                hud(metrics: metrics,
                    isPortrait: geometry.size.height > geometry.size.width,
                    screen: screen)
                    .ignoresSafeArea()

                cornerButtons(screen: screen)
                    .ignoresSafeArea()
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { runner.start() }
        .onDisappear { runner.stop() }
    }

    private static let controlGlyphFraction: CGFloat = 0.66

    private func cornerButtons(screen: ScreenGeometry) -> some View {
        let layout = CornerButtonsLayout(screen: screen)
        return ZStack(alignment: .topLeading) {
            cornerButton(glyph: "speed_up_icon_glyph", frame: layout.speed,
                         in: screen) { runner.speedUp() }
            cornerButton(glyph: "pause_icon_glyph", frame: layout.pause,
                         in: screen, action: onExit)
        }
    }

    private func cornerButton(glyph: String, frame: CGRect,
                              in screen: ScreenGeometry,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(glyph)
                    .resizable()
                    .scaledToFit()
                    .frame(width: frame.width * Self.controlGlyphFraction,
                           height: frame.height * Self.controlGlyphFraction)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hudFrame(frame, in: screen)
    }

    private func content(in viewSize: CGSize, safe: CGRect) -> some View {
        let projection = LevelMapProjection(
            imageSize: runner.mapImageSize,
            playableRect: runner.playableRect,
            fitRect: safe
        )
        let metrics = HudMetrics(viewSize: viewSize)
        let sprites = MapSpriteScale(playableRect: runner.playableRect,
                                     viewSize: viewSize)

        return ZStack(alignment: .topLeading) {
            Color.black

            Group {
                Image(RadialMenu.backgroundAssetName(count: TowerKind.allCases.count))
                Image(RadialMenu.backgroundAssetName(count: 1))
                Image("tower_menu_square_frame")
                ForEach(TowerKind.allCases) { kind in
                    Image(kind.menuIconName)
                }
                Image("tower_locked_icon")
            }
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)

            Image(runner.mapImageName)
                .resizable()
                .frame(width: projection.imageFrameSize.width,
                       height: projection.imageFrameSize.height)
                .position(projection.imageCenter)

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
                    ZStack(alignment: .bottom) {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: towerHeight)
                    }
                    .position(
                        x: basePoint.x,
                        y: basePoint.y - towerHeight / 2 + sprites.points(MapSpriteSizing.towerBaseLift)
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

            ForEach(Array(runner.slotPositions.enumerated()), id: \.offset) { index, slotPosition in
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
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 64, height: 64)
                }
                .position(projection.viewPoint(slotPosition))
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
                dismissCatcher(viewSize: viewSize)
                radialBuildMenu(around: projection.viewPoint(runner.slotPositions[buildSlot]),
                                scale: metrics.scale)
            }
            if let upgradeSlot = runner.selectedTowerSlotIndex,
               runner.slotPositions.indices.contains(upgradeSlot),
               let tower = runner.placedTower(atSlot: upgradeSlot) {
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

    private func dismissCatcher(viewSize: CGSize) -> some View {
        Color.black.opacity(0.001)
            .frame(width: viewSize.width, height: viewSize.height)
            .onTapGesture { runner.dismissMenu() }
    }

    private func radialBuildMenu(around center: CGPoint, scale: CGFloat) -> some View {
        let kinds = TowerKind.allCases
        return Group {
            radialMenuBackground(count: kinds.count, center: center, scale: scale)
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                let offset = RadialMenu.itemOffset(index: index, count: kinds.count)
                BuildMenuItem(kind: kind, isAvailable: runner.maxLevel(for: kind) >= 1,
                              scale: scale) {
                    runner.buildTower(kind)
                }
                .position(x: center.x + offset.width * scale,
                          y: center.y + offset.height * scale)
            }
        }
    }

    private func upgradeMenu(for tower: PlacedTower, around center: CGPoint,
                             scale: CGFloat) -> some View {
        let offers = runner.upgradeOffers
        let count = max(offers.count, 1)
        return Group {
            radialMenuBackground(count: count, center: center, scale: scale)
            if offers.isEmpty {
                let offset = RadialMenu.itemOffset(index: 0, count: 1)
                UpgradeMenuItem(iconName: tower.kind.menuIconName,
                                dropKind: tower.kind, cost: nil, scale: scale) {}
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
                                    cost: offer.cost, scale: scale) {
                        runner.upgradeSelectedTower(branch: offer.branch)
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
                     screen: ScreenGeometry) -> some View {
        let panel = StatsPanelLayout(
            screen: screen, isPortrait: isPortrait,
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

private struct BuildMenuItem: View {
    let kind: TowerKind
    let isAvailable: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) { icon }
            .buttonStyle(.plain)
    }

    private var icon: some View {
        let buttonSide = RadialMenu.buttonSide * scale
        let iconSize = RadialMenu.iconSide * scale
        return ZStack {
            Image("tower_menu_square_frame")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: buttonSide, height: buttonSide)
            Image(isAvailable ? kind.menuIconName : "tower_locked_icon")
                .resizable()
                .scaledToFit()
                .frame(width: isAvailable ? iconSize : iconSize * 0.81,
                       height: isAvailable ? iconSize : iconSize * 0.81)
                .offset(y: iconSize * (isAvailable
                    ? RadialMenu.iconDropFraction(for: kind)
                    : RadialMenu.iconDropFraction))
        }
        .frame(width: buttonSide, height: buttonSide)
        .contentShape(RoundedRectangle(cornerRadius: buttonSide * 0.10))
    }
}

private struct UpgradeMenuItem: View {
    let iconName: String
    let dropKind: TowerKind
    let cost: Int?
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3 * scale) {
                ZStack {
                    let iconSize = RadialMenu.iconSide * scale
                    Image("tower_menu_square_frame")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: RadialMenu.buttonSide * scale,
                               height: RadialMenu.buttonSide * scale)
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .offset(y: iconSize * RadialMenu.iconDropFraction(for: dropKind))
                        .opacity(cost != nil ? 1 : 0.5)
                }
                .frame(width: RadialMenu.buttonSide * scale,
                       height: RadialMenu.buttonSide * scale)

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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cost == nil)
    }
}

#Preview {
    LevelMapView(node: CampaignNode.load()[0], onExit: {})
}
