import SwiftUI

/// Recreating an attempt constructs a fresh runner through the same database load
/// as campaign entry. Returning from pause keeps the current runner intact.
struct LevelMapView: View {
    let db: Db
    let virtualCanvas: VirtualCanvas
    let runtimeCanvas: RuntimeCanvas
    let towerMenuLayout: TowerMenuLayout
    let node: CampaignNode
    let hudLayoutConfig: HudLayoutConfig
    var onVictory: (Int, Int) -> Int = { _, _ in 0 }
    var reviewRunner: LevelRunner? = nil
    var runsAutomatically = true
    let onExit: () -> Void
    @State private var attempt = 0

    var body: some View {
        LevelAttemptView(db: db, virtualCanvas: virtualCanvas, runtimeCanvas: runtimeCanvas,
            towerMenuLayout: towerMenuLayout, node: node,
            hudLayoutConfig: hudLayoutConfig, onVictory: onVictory,
            reviewRunner: attempt == 0 ? reviewRunner : nil, runsAutomatically: runsAutomatically,
            onRestart: { attempt += 1 }, onExit: onExit)
            .id(attempt)
    }
}

private struct LevelAttemptView: View {
    @EnvironmentObject private var settings: PlayerSettingsStore
    private var debugMode: Bool { settings.values.debugMode }
    private var showDebugLayoutGuides: Bool { settings.values.showDebugLayoutGuides }
    private var enemyEscapeHapticsEnabled: Bool { settings.values.enemyEscapeHapticsEnabled }
    @Environment(\.scenePhase) private var scenePhase
    let towerMenuLayout: TowerMenuLayout

    var node: CampaignNode
    var onExit: () -> Void
    private let onRestart: () -> Void

    @StateObject private var runner: LevelRunner
    @State private var towerSlotCount: Int = 0

    @State private var hiddenRangeSlots: Set<Int> = []

    private enum Presentation: Equatable {
        case buildMenu(slot: Int)
        case upgradeMenu(slot: Int)
        case rallyPlacement(slot: Int)
        case demolitionPlacement(slot: Int)
        case engineerObstaclePlacement(slot: Int)
        case reinforcementPlacement
        case heroDestination(index: Int)
        case rallyFlag(id: Int, point: CGPoint)
        case defeat
    }

    @State private var presentationStack = PresentationStack<Presentation>()
    @State private var escapeHapticPolicy = EnemyEscapeHapticPolicy()
    private struct ReviewRequest: Identifiable { let id: UUID }
    @State private var reviewRequest: ReviewRequest?

    private var activePresentations: [Presentation] {
        var active: [Presentation] = []
        if let slot = runner.selectedSlotIndex, runner.slotPositions.indices.contains(slot) {
            active.append(.buildMenu(slot: slot))
        }
        if let slot = runner.selectedTowerSlotIndex, runner.placedTower(atSlot: slot) != nil {
            if runner.isPlacingDemolition { active.append(.demolitionPlacement(slot: slot)) }
            else if runner.isPlacingEngineerObstacles { active.append(.engineerObstaclePlacement(slot: slot)) }
            else { active.append(runner.isPlacingRallyPoint ? .rallyPlacement(slot: slot) : .upgradeMenu(slot: slot)) }
        }
        if runner.isPlacingReinforcements { active.append(.reinforcementPlacement) }
        if let hero = runner.selectedHeroIndex { active.append(.heroDestination(index: hero)) }
        if let flash = runner.rallyFlagFlash { active.append(.rallyFlag(id: flash.id, point: flash.position)) }
        if runner.isDefeated { active.append(.defeat) }
        return active
    }

    private static let debugRangeBands: [(upperBound: CGFloat, tint: Color)] = [
        (350, Color(red: 0.13, green: 0.83, blue: 0.93)),
        (425, Color(red: 0.38, green: 0.65, blue: 0.98)),
        (500, Color(red: 0.75, green: 0.52, blue: 0.99)),
        (.infinity, Color(red: 1.00, green: 0.31, blue: 0.64)),
    ]

    private func slotTapSize(projection: LevelMapProjection) -> CGSize {
        SlotTapTarget.size(slotSize: runner.slotSize,
                           pointsPerMapUnit: projection.scale)
    }

    private static let showSlotTapInfo = false

    private static func debugRangeTint(for range: CGFloat) -> Color {
        debugRangeBands.first { range < $0.upperBound }?.tint
            ?? debugRangeBands[debugRangeBands.count - 1].tint
    }

    private static let rallyButtonScale: CGFloat = 0.9702

    private var db: Db
    private var virtualCanvas: VirtualCanvas
    private var runtimeCanvas: RuntimeCanvas
    private var hudLayoutConfig: HudLayoutConfig
    private let runsAutomatically: Bool

    init(db: Db,
         virtualCanvas: VirtualCanvas,
         runtimeCanvas: RuntimeCanvas,
         towerMenuLayout: TowerMenuLayout,
         node: CampaignNode,
         hudLayoutConfig: HudLayoutConfig,
         onVictory: @escaping (Int, Int) -> Int = { _, _ in 0 }, reviewRunner: LevelRunner? = nil,
         runsAutomatically: Bool = true, onRestart: @escaping () -> Void,
         onExit: @escaping () -> Void) {
        self.db = db
        self.virtualCanvas = virtualCanvas
        self.runtimeCanvas = runtimeCanvas
        self.towerMenuLayout = towerMenuLayout
        self.node = node
        self.hudLayoutConfig = hudLayoutConfig
        self.onExit = onExit
        self.onRestart = onRestart
        self.runsAutomatically = runsAutomatically
        _runner = StateObject(wrappedValue: reviewRunner ?? LevelRunner(
            db: db,
            virtualCanvas: virtualCanvas,
            runtimeCanvas: runtimeCanvas,
            hudLayoutConfig: hudLayoutConfig,
            levelInfoID: node.levelInfoID,
            mapImageName: node.mapImageName,
            onVictory: onVictory
        ))
    }

    var body: some View {
        LevelViewport(size: runtimeCanvas.physicalRect.size) {
            content(runtimeCanvas: runtimeCanvas)
                .border(debugMode ? Color.orange : Color.clear, width: debugMode ? 3 : 0)
        } interface: {
            ZStack(alignment: .topLeading) {
                let projection = runner.sceneSetup.projection(in: runtimeCanvas)

                LevelExitMarkersView(positions: runner.exitPositions,
                                     projection: projection,
                                     spriteSize: MapSpriteScale(runtimeCanvas: runtimeCanvas)
                                        .points(MapSpriteSizing.exitMarker))

                HudView(runtimeCanvas: runtimeCanvas, state: LevelHUDState(engine: runner),
                        hudLayoutConfig: runner.content.hudLayout,
                        input: LevelHUDInput(activate: runner.activateHUD, callWave: runner.tapCallWave),
                        debugStatus: settings.values.showDebugInfo ? runner.status : nil)
                    .border(debugMode ? Color.cyan : Color.clear, width: debugMode ? 3 : 0)

                if showDebugLayoutGuides {
                    DebugLayoutGuidesView(runtimeCanvas: runtimeCanvas)
                }
            }
        } presentations: {
            PresentationLayers(stack: presentationStack) { presentation in
                presentationLayer(presentation, runtimeCanvas: runtimeCanvas)
            }
        }
        .persistentSystemOverlays(.hidden)
        .overlay(alignment: .top) {
            if runner.isCleared && runner.earnedMetaStars > 0 {
                HStack(spacing: 8) {
                    ForEach(0..<runner.earnedMetaStars, id: \.self) { _ in
                        Image(systemName: "star.fill").font(.system(size: 28, weight: .bold))
                    }
                }
                .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.28))
                .padding(12).background(.black.opacity(0.8), in: Capsule())
                .padding(.top, 16)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Victory. Earned \(runner.earnedMetaStars) upgrade stars.")
            }
        }
        .allowsHitTesting(!runner.isPaused)
        .accessibilityHidden(runner.isPaused || reviewRequest != nil)
        .overlay {
            if runner.isPaused {
                LevelPauseView(runtimeCanvas: runtimeCanvas,
                    onResume: {
                        runner.resume()
                        if scenePhase == .active && runsAutomatically { runner.start() }
                    },
                    onRestart: {
                        runner.finishRecording(status: .abandoned)
                        runner.stop()
                        onRestart()
                    },
                    onCampaign: {
                        runner.finishRecording(status: .abandoned)
                        runner.stop()
                        onExit()
                    })
            }
        }
        .onChange(of: runner.escapedEnemyCount) { previous, current in
            guard let cue = escapeHapticPolicy.feedback(previousCount: previous, escapeCount: current,
                                               livesRemaining: runner.lives,
                                               isEnabled: enemyEscapeHapticsEnabled,
                                               isActive: scenePhase == .active,
                                               at: ProcessInfo.processInfo.systemUptime) else { return }
            runner.playEnemyEscapeHaptic(cue)
        }
        .onAppear {
            presentationStack.synchronize(activePresentations)
            runner.bindHeroControls(to: settings)
            #if DEBUG
            if CommandLine.arguments.contains("--capture-launch") {
                Task { await runner.capturePlayableLaunch() }
            }
            if CommandLine.arguments.contains("--reinforcement-slider-review") {
                let layout = HeroBarLayout(runtimeCanvas: runtimeCanvas, location: .southWest)
                Task { await runner.reviewReinforcementSlider(buttonSize: layout.buttonSize) }
            }
            #endif
            runner.updateRuntimeCanvas(runtimeCanvas)
            if scenePhase == .active && runsAutomatically { runner.start() }
        }
        .onChange(of: runtimeCanvas.playAreaRect) { _, _ in
            runner.updateRuntimeCanvas(runtimeCanvas)
        }
        .onDisappear {
            runner.finishRecording(status: .abandoned)
            runner.stop()
            presentationStack.removeAll()
        }
        .onChange(of: activePresentations, initial: true) { _, active in
            presentationStack.synchronize(active)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && runsAutomatically { runner.start() } else { runner.stop() }
        }
        .fullScreenCover(item: $reviewRequest) { request in
            ScreenGeometryGate(virtualCanvas: virtualCanvas) { canvas in
                LevelRunReviewView(dao: db.levelRunDao, runID: request.id, canvas: canvas,
                                   onExit: { reviewRequest = nil })
            }
        }
    }

    private func content(runtimeCanvas: RuntimeCanvas) -> some View {

        let safe = runtimeCanvas.safeInsetsRect
        let projection = runner.sceneSetup.projection(in: runtimeCanvas)
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        return LevelScene(setup: runner.sceneSetup, state: LevelSceneState(engine: runner),
                          canvas: runtimeCanvas, debugMode: debugMode, onSelectHero: runner.selectHero) {
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

        } mapOverlay: {
            ForEach(Array(runner.slotPositions.enumerated()), id: \.offset) { index, slotPosition in
                let slotTap = slotTapSize(projection: projection)
                Button {

                    if debugMode, hiddenRangeSlots.contains(index) {
                        hiddenRangeSlots.remove(index)
                    } else if runner.isSlotOccupied(index) {
                        runner.selectPlacedTower(atSlot: index)
                    } else {
                        runner.selectSlot(index)
                    }
                } label: {

                    Ellipse()
                        .fill(debugMode ? Color.black.opacity(0.35)
                                        : Color.white.opacity(0.001))
                        .frame(width: slotTap.width, height: slotTap.height)
                }
                .position(projection.viewPoint(slotPosition))
                .accessibilityIdentifier("tower-slot-\(index)")
                .accessibilityLabel(runner.isSlotOccupied(index) ? "Select tower" : "Build tower")
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
        let projection = runner.sceneSetup.projection(in: runtimeCanvas)
        let playAreaScalingFactor = runtimeCanvas.scaleFactor
        switch presentation {
        case .buildMenu(let buildSlot):
            if runner.slotPositions.indices.contains(buildSlot) {
                if let radius = runner.armedBuildKind.flatMap({ runner.buildPreviewRadius(for: $0) }) {
                    TowerRangeOverlayView(
                        center: projection.viewPoint(runner.slotPositions[buildSlot]),
                        range: radius, verticalFraction: runner.combatRules.rangeVerticalFraction, runtimeCanvas: runtimeCanvas)
                }
                dismissCatcher(runtimeCanvas: runtimeCanvas)
                towerMenu(around: projection.viewPoint(runner.slotPositions[buildSlot]),
                          playAreaScalingFactor: playAreaScalingFactor)
            }
        case .upgradeMenu(let upgradeSlot), .rallyPlacement(let upgradeSlot), .demolitionPlacement(let upgradeSlot),
             .engineerObstaclePlacement(let upgradeSlot):
            if runner.slotPositions.indices.contains(upgradeSlot),
               let tower = runner.placedTower(atSlot: upgradeSlot) {
                let previewRadius = runner.armedUpgradeBranch
                    .flatMap { runner.upgradePreviewRadius(branch: $0) } ?? runner.upgradePathPreviewRadius
                // Supply camps gain their first local aura at specialization.
                if let radius = runner.rangeOverlayRadius(for: tower) ?? previewRadius {
                    TowerRangeOverlayView(
                        center: projection.viewPoint(runner.slotPositions[upgradeSlot]),
                        range: radius, upgradeRange: previewRadius, verticalFraction: runner.combatRules.rangeVerticalFraction, runtimeCanvas: runtimeCanvas)
                }
                if case .rallyPlacement = presentation {
                    MapDestinationInputView(runtimeCanvas: runtimeCanvas) { runner.placeRallyPoint(at: $0) }
                } else if case .demolitionPlacement = presentation {
                    MapDestinationInputView(runtimeCanvas: runtimeCanvas) { runner.placeDemolition(at: $0) }
                } else if case .engineerObstaclePlacement = presentation {
                    MapDestinationInputView(runtimeCanvas: runtimeCanvas) { runner.placeEngineerObstacles(at: $0) }
                } else {
                    dismissCatcher(runtimeCanvas: runtimeCanvas)
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
            LevelDefeatView(canvas: runtimeCanvas, onReview: {
                // Complete any final impact animation and flush its timeline
                // before the read-only replay opens the run.
                runner.finishRecording(status: .defeat)
                runner.stop()
                guard let id = runner.runID else { fatalError("Defeated player run has no recording") }
                reviewRequest = ReviewRequest(id: id)
            }, onRestart: {
                runner.finishRecording(status: .defeat)
                runner.stop()
                onRestart()
            }, onHome: {
                runner.finishRecording(status: .defeat)
                runner.stop()
                onExit()
            })
        }
    }

    private static let debugLegendRowCount: CGFloat = 5

    private func debugLegendHeight(metrics: HudMetrics) -> CGFloat {
        let rows = Self.debugLegendRowCount
        return rows * metrics.rangeLegendTextSize * 1.35
            + (rows - 1) * (1 * metrics.scale)
            + 2 * (4 * metrics.scale)
    }

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
        let size = TowerRangeOverlay.size(range: range, verticalFraction: runner.combatRules.rangeVerticalFraction, runtimeCanvas: runtimeCanvas)
        let center = projection.viewPoint(tower.position)
        let gap = 6 * metrics.scale

        let above = center.y - size.height / 2 - gap
            - debugLegendHeight(metrics: metrics) >= safe.minY

        return DebugRingGeometry(center: center, size: size,
                                 tint: Self.debugRangeTint(for: range),
                                 gap: gap, legendAbove: above)
    }

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

    private func dismissCatcher(runtimeCanvas: RuntimeCanvas) -> some View {
        // Map presentations sit above the HUD, so their input region must leave
        // the controls exposed. Otherwise the first HUD tap only dismisses a menu.
        MapDestinationInputView(runtimeCanvas: runtimeCanvas) { _ in runner.dismissMenu() }
    }

    private func towerMenu(around anchor: CGPoint,
                                 playAreaScalingFactor: CGFloat) -> some View {
        let menuCenterPoint = towerMenuLayout.getCenterPoint(anchor: anchor, scale: playAreaScalingFactor)
        let buttonSize = towerMenuLayout.getTowerButtonSize(playAreaScalingFactor: playAreaScalingFactor)
        func place(_ kind: TowerKind) -> CGPoint {
            towerMenuLayout.getTowerButtonCenterPoint(towerKind: kind,
                menuCenterPoint: menuCenterPoint, playAreaScalingFactor: playAreaScalingFactor,
                towerButtonSize: buttonSize.width)
        }
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
                .accessibilityLabel(runner.towerName(for: kind, atLevel: 1))
                .accessibilityIdentifier("tower-build-\(kind.rawValue)")
                .position(towerMenuLayout.getTowerButtonCenterPoint(towerKind: kind,
                                                                    menuCenterPoint: menuCenterPoint,
                                                                    playAreaScalingFactor: playAreaScalingFactor,
                                                                    towerButtonSize: buttonSize.width))
            }
            if let kind = runner.armedBuildKind,
               let details = runner.menuDetails(for: kind, atLevel: 1) {
                TowerSelectionLabel(details: details, button: menuButtonFrame(at: place(kind), size: buttonSize),
                    safeBounds: runtimeCanvas.safeInsetsRect,
                    obstacles: towerLabelObstacles + TowerKind.allCases.filter { $0 != kind }.map {
                        menuButtonFrame(at: place($0), size: buttonSize)
                    })
            }
        }
    }

    private func menuButtonFrame(at center: CGPoint, size: CGSize) -> CGRect {

        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
               width: size.width, height: size.height * 1.15)
    }

    private var towerLabelObstacles: [CGRect] {
        runtimeCanvas.hudPlayArea.occlusionAreas + (runner.awaitingWaveStart
                        ? runner.callWaveButtonPositions.map {
                            CallWaveButtonLayout(position: $0, runtimeCanvas: runtimeCanvas).frame
                        } : [])
    }

    @ViewBuilder private func upgradeMenu(for tower: PlacedTower, around anchor: CGPoint,
                                          playAreaScalingFactor: CGFloat) -> some View {
        if runner.upgradePaths.isEmpty {
            tierUpgradeMenu(for: tower, around: anchor, playAreaScalingFactor: playAreaScalingFactor)
        } else {
            specialtyUpgradeMenu(for: tower, around: anchor, playAreaScalingFactor: playAreaScalingFactor)
        }
    }

    private func specialtyUpgradeMenu(for tower: PlacedTower, around anchor: CGPoint,
                                       playAreaScalingFactor: CGFloat) -> some View {
        let paths = runner.upgradePaths
        let center = towerMenuLayout.getCenterPoint(anchor: anchor, scale: playAreaScalingFactor)
        let buttonSize = towerMenuLayout.getTowerButtonSize(playAreaScalingFactor: playAreaScalingFactor)
        let hasRally = runner.rallyPoint(forSlot: tower.slotIndex) != nil
        let hasCharge = tower.demolitionCharge != nil
        let hasObstacles = runner.towerLevel(for: tower)?.engineerObstacles != nil
        let hasPlacement = hasRally || hasCharge || hasObstacles
        let rallySize = CGSize(width: buttonSize.width * Self.rallyButtonScale,
                               height: buttonSize.height * Self.rallyButtonScale)
        let rallyCenter = towerMenuLayout.getButtonSeatCenterPoint(index: 1, count: 2,
            menuCenterPoint: center, playAreaScalingFactor: playAreaScalingFactor)
        func place(_ path: TowerUpgradePath) -> CGPoint {
            towerMenuLayout.getButtonCenterPoint(index: path.slot == 1 ? 3 : 1, count: 4,
                menuCenterPoint: center, playAreaScalingFactor: playAreaScalingFactor,
                towerButtonSize: buttonSize.width)
        }
        return Group {
            towerMenuBgImage(center: center, playAreaScalingFactor: playAreaScalingFactor)
            ForEach(paths) { path in
                let rank = tower.upgrades.rank(for: path.id)
                let next = path.ranks.first { $0.rank == rank + 1 }
                UpgradeMenuItem(towerMenuLayout: towerMenuLayout, iconName: path.iconName, dropKind: tower.kind,
                    cost: next?.cost, isArmed: runner.armedUpgradePathID == path.id && next != nil,
                    isAffordable: next.map { runner.money >= $0.cost } ?? true,
                    buttonSize: buttonSize, canInspect: true,
                    progress: CGFloat(rank) / CGFloat(path.ranks.count)) {
                        runner.tapUpgradePath(path.id)
                    }
                    .accessibilityLabel(path.name)
                    .accessibilityValue("\(rank) of \(path.ranks.count) ranks purchased. " + (next.map {
                        "\($0.cost) coins. \($0.description)"
                    } ?? "Fully upgraded."))
                    .accessibilityIdentifier("tower-path-\(path.id)")
                    .position(place(path))
            }
            if hasPlacement {
                RallyMenuItem(towerMenuLayout: towerMenuLayout, buttonSize: rallySize) {
                    if hasCharge { runner.beginDemolitionPlacement() }
                    else if hasObstacles { runner.beginEngineerObstaclePlacement() }
                    else { runner.toggleRallyPlacement() }
                }
                .accessibilityLabel(hasCharge ? "Place charge" : hasObstacles ? "Move abatis" : "Set rally point")
                .accessibilityIdentifier(hasCharge ? "demolition-placement" : hasObstacles ? "engineer-obstacle-placement" : "rally-placement")
                .position(rallyCenter)
            }
            if let selected = paths.first(where: { $0.id == runner.armedUpgradePathID }) {
                TowerSelectionLabel(details: selected.menuDetails(purchasedRank: tower.upgrades.rank(for: selected.id)),
                    button: menuButtonFrame(at: place(selected), size: buttonSize),
                    safeBounds: runtimeCanvas.safeInsetsRect,
                    obstacles: towerLabelObstacles + paths.filter { $0.id != selected.id }.map {
                        menuButtonFrame(at: place($0), size: buttonSize)
                    } + (hasPlacement ? [menuButtonFrame(at: rallyCenter, size: rallySize)] : []))
            }
        }
    }

    private func tierUpgradeMenu(for tower: PlacedTower, around anchor: CGPoint,
                             playAreaScalingFactor: CGFloat) -> some View {
        let offers = runner.upgradeOffers
        let center = towerMenuLayout.getCenterPoint(anchor: anchor, scale: playAreaScalingFactor)
        let buttonSize = towerMenuLayout.getTowerButtonSize(playAreaScalingFactor: playAreaScalingFactor)
        let hasRally = runner.rallyPoint(forSlot: tower.slotIndex) != nil
        let hasCharge = tower.demolitionCharge != nil
        let hasObstacles = runner.towerLevel(for: tower)?.engineerObstacles != nil
        let rallyButtonSize = CGSize(width: buttonSize.width * Self.rallyButtonScale,
                                     height: buttonSize.height * Self.rallyButtonScale)
        let upgradeCount = hasCharge ? offers.count : max(offers.count, 1)
        let count = upgradeCount + (hasRally || hasCharge || hasObstacles ? 1 : 0)
        func place(_ index: Int) -> CGPoint {
            if hasObstacles && !offers.isEmpty {
                return towerMenuLayout.getEngineerUpgradeButtonCenterPoint(index: index, offerCount: offers.count,
                    menuCenterPoint: center, playAreaScalingFactor: playAreaScalingFactor,
                    towerButtonSize: buttonSize.width)
            }
            return towerMenuLayout.getButtonCenterPoint(
                index: index, count: count, menuCenterPoint: center,
                playAreaScalingFactor: playAreaScalingFactor, towerButtonSize: buttonSize.width)
        }
        let rallyCenter = towerMenuLayout.getButtonSeatCenterPoint(
            index: hasCharge || hasObstacles ? 1 : upgradeCount,
            count: hasCharge || hasObstacles ? 2 : count, menuCenterPoint: center,
            playAreaScalingFactor: playAreaScalingFactor)
        return Group {
            towerMenuBgImage(center: center, playAreaScalingFactor: playAreaScalingFactor)
            if offers.isEmpty && !hasCharge {
                UpgradeMenuItem(towerMenuLayout: towerMenuLayout, iconName: tower.kind.menuIconName, dropKind: tower.kind,
                                cost: nil, isArmed: false, isAffordable: false, buttonSize: buttonSize) {}
                    .position(place(0))
            } else {
                ForEach(Array(offers.enumerated()), id: \.offset) { index, offer in
                    let specializationIcon = tower.kind.specializationMenuIconName(
                        atLevel: offer.nextLevel, branch: offer.branch)
                    let iconName = specializationIcon ?? (offers.count > 1
                        ? (tower.kind.assetName(atLevel: offer.nextLevel,
                                                branch: offer.branch) ?? tower.kind.menuIconName)
                        : tower.kind.menuIconName)
                    UpgradeMenuItem(towerMenuLayout: towerMenuLayout, iconName: iconName, dropKind: tower.kind,
                                    cost: offer.cost,
                                    isArmed: runner.armedUpgradeBranch == offer.branch,
                                    isAffordable: runner.money >= offer.cost,
                                    buttonSize: buttonSize) {
                        runner.tapUpgradeButton(branch: offer.branch)
                    }
                    .accessibilityLabel(runner.towerName(for: tower.kind,
                        atLevel: offer.nextLevel, branch: offer.branch))
                    .accessibilityIdentifier("tower-upgrade-\(tower.kind.rawValue)-\(offer.branch)")
                    .position(place(index))
                }
            }
            if hasRally || hasCharge || hasObstacles {
                RallyMenuItem(towerMenuLayout: towerMenuLayout, buttonSize: rallyButtonSize) {
                    if hasCharge { runner.beginDemolitionPlacement() }
                    else if hasObstacles { runner.beginEngineerObstaclePlacement() }
                    else { runner.toggleRallyPlacement() }
                }
                .accessibilityLabel(hasCharge ? "Place charge" : hasObstacles ? "Move abatis" : "Set rally point")
                .accessibilityIdentifier(hasCharge ? "demolition-placement" : hasObstacles ? "engineer-obstacle-placement" : "rally-placement")

                .position(rallyCenter)
            }
            if let selected = offers.firstIndex(where: { $0.branch == runner.armedUpgradeBranch }),
               let details = runner.menuDetails(for: tower.kind,
                    atLevel: offers[selected].nextLevel, branch: offers[selected].branch) {
                TowerSelectionLabel(details: details,
                    button: menuButtonFrame(at: place(selected), size: buttonSize),
                    safeBounds: runtimeCanvas.safeInsetsRect,
                    obstacles: towerLabelObstacles + offers.indices.filter { $0 != selected }.map {
                        menuButtonFrame(at: place($0), size: buttonSize)
                    } + (hasRally || hasCharge || hasObstacles
                         ? [menuButtonFrame(at: rallyCenter, size: rallyButtonSize)] : []))
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

}

struct TowerMenuIcon: View {
    let towerMenuLayout: TowerMenuLayout
    let name: String
    let buttonSize: CGFloat

    var body: some View {
        let side = towerMenuLayout.getTowerIconSize(towerButtonSize: buttonSize)
        artwork
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: side, height: side)
            .frame(width: buttonSize, height: buttonSize)
    }

    private var artwork: Image {
        if let image = TowerMenuIconArtwork.image(named: name) { return Image(uiImage: image) }
        return Image(name)
    }
}

/// Shared alpha-bounds crop of the canonical artwork, independent of each screen's frame.
@MainActor enum TowerMenuIconArtwork {
    private static var images: [String: UIImage] = [:]

    static func image(named name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let image = UIImage(named: name), let source = image.cgImage else { return nil }
        let width = source.width, height = source.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let bounds: CGRect? = rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let pixels = bytes.bindMemory(to: UInt8.self)
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        let artwork: UIImage
        if let bounds, let cropped = source.cropping(to: bounds) {
            artwork = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        } else {
            artwork = image
        }
        images[name] = artwork
        return artwork
    }
}

struct TowerMenuItem: View {
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
        return ZStack {
            Image(kind.menuFrameName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSize, height: frameSize)
            TowerMenuIcon(towerMenuLayout: towerMenuLayout,
                          name: isAvailable ? kind.menuIconName : "tower_locked_icon",
                          buttonSize: frameSize)
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

struct UpgradeMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let iconName: String
    let dropKind: TowerKind
    let cost: Int?
    let isArmed: Bool
    let isAffordable: Bool
    let buttonSize: CGSize
    var canInspect: Bool = false
    var progress: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(.plain)
            .disabled(cost == nil && !canInspect)
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
        return ZStack {
            Image(dropKind.menuFrameName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSize, height: frameSize)
            TowerMenuIcon(towerMenuLayout: towerMenuLayout, name: iconName, buttonSize: frameSize)
                .grayscale(cost != nil && !isAffordable ? 1 : 0)
                .opacity(cost != nil || canInspect ? 1 : 0.5)
            TowerCostLabel(cost: cost, frameSize: frameSize)
                .grayscale(cost != nil && !isAffordable ? 1 : 0)
            if let progress {
                ZStack(alignment: .leading) {
                    Capsule().fill(.black)
                    Capsule().fill(Color(red: 0.3, green: 0.9, blue: 0.35))
                        .frame(width: frameSize * 0.66 * progress)
                }
                .frame(width: frameSize * 0.66, height: 5)
                .position(x: frameSize / 2, y: frameSize * 0.13)
            }
        }
        .frame(width: frameSize, height: frameSize)
        .contentShape(Rectangle())
    }
}

struct RallyMenuItem: View {
    let towerMenuLayout: TowerMenuLayout
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        let side = buttonSize.width
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: side, height: side)
                TowerMenuIcon(towerMenuLayout: towerMenuLayout, name: "rally_point_icon", buttonSize: side)
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

                }
            }
    }
}
