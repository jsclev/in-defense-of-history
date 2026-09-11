import SwiftUI

@MainActor
struct EditorCanvas: View {
    @ObservedObject var document: MapDocument
    @ObservedObject var content: EditorContent
    var state: EditorState

    private var virtualCanvas: VirtualCanvas { state.virtualCanvas }
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focused: Bool

    @State private var preDrag: MapDraft?
    @State private var dragTarget: DragTarget?
    @State private var dragMoved = false
    @State private var pinchBase: Double?
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffset: CGPoint = .zero
    @State private var panOrigin: CGPoint?
    @State private var viewportSize: CGSize = .zero
    @State private var zoomFocusPoint: Point?

    private enum DragTarget: Equatable {
        case slot(Int)
        case waypoint(road: Int, point: Int)
        case entrance(Int)
        case exitPoint(Int)
        case callWaveButton(Int)
        case hero(HeroSelection.Role)
    }

    var body: some View {
        GeometryReader { geo in
            let fit = Double(min(geo.size.width / virtualCanvas.size.width,
                                 geo.size.height / virtualCanvas.size.height))
            let s = CGFloat(state.zoom ?? fit)
            let t = DesignTransform(scale: s, space: virtualCanvas.size)
            ScrollView([.horizontal, .vertical]) {
                canvasContent(t)
                    // Leave room to pan even when the whole map fits on screen.
                    .padding(.horizontal, geo.size.width)
                    .padding(.vertical, geo.size.height)
            }
            .defaultScrollAnchor(.center)
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, offset in
                scrollOffset = offset
            }
            .scrollDisabled(state.tool == .pan || state.tool == .brush || state.tool == .paint || state.tool == .eraser)
            .overlay { panInputOverlay }
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if pinchBase == nil { pinchBase = state.currentScale }
                        state.setZoom(pinchBase! * v.magnification)
                    }
                    .onEnded { _ in pinchBase = nil }
            )
            .onChange(of: geo.size, initial: true) { _, _ in
                state.fitScale = fit
                viewportSize = geo.size
                if state.zoom == nil { centerMap() }
            }
            .onChange(of: state.zoom) { _, _ in
                scrollToZoomFocus()
            }
            .onChange(of: state.fitRequest) { _, _ in
                centerMap()
            }
        }
    }

    @ViewBuilder
    private var panInputOverlay: some View {
        if state.tool == .pan {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if panOrigin == nil { panOrigin = scrollOffset }
                            guard let origin = panOrigin else { return }
                            scrollPosition.scrollTo(point: CGPoint(
                                x: origin.x - value.translation.width,
                                y: origin.y - value.translation.height))
                            #if os(macOS)
                            NSCursor.closedHand.set()
                            #endif
                        }
                        .onEnded { _ in
                            panOrigin = nil
                            applyToolCursor()
                        }
                )
                .onHover { inside in
                    if inside { applyToolCursor() } else { restoreArrowCursor() }
                }
                .onDisappear { panOrigin = nil; restoreArrowCursor() }
        }
    }

    private func centerMap() {
        zoomFocusPoint = nil
        scrollPosition.scrollTo(point: CGPoint(
            x: (virtualCanvas.size.width * state.currentScale + viewportSize.width) / 2,
            y: (virtualCanvas.size.height * state.currentScale + viewportSize.height) / 2))
    }

    private func canvasContent(_ t: DesignTransform) -> some View {
        Canvas { ctx, _ in
            draw(&ctx, t)
        }
        .frame(width: virtualCanvas.size.width * t.scale, height: virtualCanvas.size.height * t.scale)
        .background(Palette.mapBackground)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .overlay { brushInputOverlay(t) }
        .gesture(dragGesture(t))
        .onContinuousHover { phase in
            switch phase {
            case let .active(p):
                state.cursor = t.design(p)
                applyToolCursor()
            case .ended:
                state.cursor = nil
                restoreArrowCursor()
            }
        }
        .onChange(of: state.tool) { _, _ in
            if state.cursor != nil { applyToolCursor() }
        }
        .onChange(of: state.canvasFocusRequest) { _, _ in focused = true }
        .platformEditingCommands(
            canMove: { canNudgeSelection },
            onDelete: { deleteSelection() },
            onCancel: { state.selection = .none },
            onMove: { nudge($0) }
        )
        .overlay(alignment: .topLeading) { activeLayerChip }
    }

    @ViewBuilder
    private var activeLayerChip: some View {
        if let layer = state.activeLayer {
            HStack(spacing: 6) {
                Image(systemName: layer.icon)
                Text("\(state.tool.title) · \(layer.title) layer")
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.cyan.opacity(0.22), in: Capsule())
            .overlay(Capsule().stroke(.cyan.opacity(0.8), lineWidth: 1.5))
            .foregroundStyle(.cyan)
            .padding(10)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func brushInputOverlay(_ t: DesignTransform) -> some View {
        #if os(iOS)
        if state.tool == .brush {
            BrushInputView(
                onBegan: { p, _ in beginStroke(at: p, t) },
                onMoved: { p, _ in extendStroke(to: p, t) },
                onEnded: { commitStroke() },
                onCancelled: { state.stroke = BrushStroke() },
                onPinchBegan: {
                    state.stroke = BrushStroke()
                    state.pinchBase = state.currentScale
                },
                onPinchChanged: { magnification in
                    guard let base = state.pinchBase else { return }
                    state.setZoom(base * magnification)
                },
                onPinchEnded: { state.pinchBase = nil }
            )
        } else if state.tool == .paint || state.tool == .eraser {
            BrushInputView(
                onBegan: { p, _ in beginPaint(at: p, t) },
                onMoved: { p, _ in extendPaint(to: p, t) },
                onEnded: { commitPaint() },
                onCancelled: { state.paintGesture.cancel() },
                onPinchBegan: {
                    state.paintGesture.cancel()
                    state.pinchBase = state.currentScale
                },
                onPinchChanged: { magnification in
                    guard let base = state.pinchBase else { return }
                    state.setZoom(base * magnification)
                },
                onPinchEnded: { state.pinchBase = nil }
            )
        }
        #else
        EmptyView()
        #endif
    }

    private func beginPaint(at p: CGPoint, _ t: DesignTransform) {
        state.paintGesture.begin(at: p, transform: t, width: state.paintWidth,
                                 erases: state.tool == .eraser)
        if let cursor = state.paintGesture.cursor { state.cursor = cursor }
    }

    private func extendPaint(to p: CGPoint, _ t: DesignTransform) {
        state.paintGesture.append(p)
        if let cursor = state.paintGesture.cursor { state.cursor = cursor }
    }

    private func commitPaint(at finalLocation: CGPoint? = nil) {
        let stroke = state.paintGesture.commit(at: finalLocation, to: document,
            mapGeometry: state.mapGeometry, undoManager: undoManager)
        if stroke?.erases == true {
            state.selection = .none
        }
    }

    private func beginStroke(at p: CGPoint, _ t: DesignTransform) {
        state.stroke = BrushStroke()
        extendStroke(to: p, t)
    }

    private func extendStroke(to p: CGPoint, _ t: DesignTransform) {
        state.stroke.add(clampToCanvas(t.design(p)),
                         minSpacing: max(0.5, 1 / max(t.scale, 0.05)))
    }

    private func commitStroke() {
        defer { state.stroke = BrushStroke() }
        guard let points = BrushGeometry.commit(state.stroke, spacing: state.brushSpacing) else {
            return
        }
        document.addPaintedRoad(points: points, undoManager)
        state.selection = .road(document.draft.roads.count - 1)
        state.flash("Painted road: \(points.count) waypoints")
    }

    private func applyToolCursor() {
        #if os(macOS)
        state.tool.nsCursor.set()
        #endif
    }

    private func restoreArrowCursor() {
        #if os(macOS)
        NSCursor.arrow.set()
        #endif
    }

    private func scrollToZoomFocus() {
        guard let focusPoint = zoomFocusPoint else { return }
        zoomFocusPoint = nil
        guard state.zoom != nil else { return }
        let scale = state.currentScale
        let contentPoint = CGPoint(x: focusPoint.x * scale,
                                   y: (virtualCanvas.size.height - focusPoint.y) * scale)
        scrollPosition.scrollTo(point: CGPoint(x: contentPoint.x + viewportSize.width / 2,
                                               y: contentPoint.y + viewportSize.height / 2))
    }

    private func clampToCanvas(_ p: Point) -> Point {
        Point(min(max(p.x, 0), virtualCanvas.size.width), min(max(p.y, 0), virtualCanvas.size.height))
    }

    private func dragGesture(_ t: DesignTransform) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                focused = true
                #if !os(iOS)
                if state.tool == .brush {
                    if state.stroke.isEmpty {
                        beginStroke(at: v.startLocation, t)
                    }
                    extendStroke(to: v.location, t)
                    return
                }
                if state.tool == .paint || state.tool == .eraser {
                    if !state.paintGesture.isActive {
                        beginPaint(at: v.startLocation, t)
                    }
                    extendPaint(to: v.location, t)
                    return
                }
                #endif
                if preDrag == nil {
                    preDrag = document.draft
                    dragMoved = false
                    dragTarget = switch state.tool {
                    case .select: hitHandle(at: v.startLocation, t)
                    // The slot tool moves existing slots too: touch one and
                    // drag, the pad follows, lifting drops it there.
                    case .slot: slotTarget(at: v.startLocation, t)
                    case .entrance: markerTarget(at: v.startLocation, t, exits: false)
                    case .exitPoint: markerTarget(at: v.startLocation, t, entrances: false)
                    case .callWaveButton: callWaveButtonTarget(at: v.startLocation, t)
                    case .primaryHero: heroTarget(at: v.startLocation, t, role: .primary)
                    case .secondaryHero: heroTarget(at: v.startLocation, t, role: .secondary)
                    default: nil
                    }
                }
                if hypot(v.translation.width, v.translation.height) > 3 {
                    dragMoved = true
                }
                guard dragMoved, let target = dragTarget else { return }
                state.selection = selection(for: target)
                let p = snap(t.design(v.location))
                switch target {
                case let .hero(role):
                    if let original = preDrag?.heroMarkerPosition(role) {
                        // The badge is offset from the foot anchor. Preserve that
                        // grab offset, including separated badges at shared starts.
                        let start = t.design(v.startLocation)
                        let current = t.design(v.location)
                        document.draft.placeHero(role, at: snap(Point(
                            original.x + current.x - start.x,
                            original.y + current.y - start.y)))
                    }
                case let .callWaveButton(i):
                    if document.draft.callWaveButtons.indices.contains(i) {
                        document.draft.callWaveButtons[i].position = p
                    }
                case let .slot(i):
                    if document.draft.slots.indices.contains(i) {
                        document.draft.slots[i] = p
                    }
                case let .waypoint(r, i):
                    if document.draft.roads.indices.contains(r),
                       document.draft.roads[r].points.indices.contains(i) {
                        document.draft.roads[r].points[i] = p
                    }
                case let .entrance(i):
                    if document.draft.entrances.indices.contains(i) {
                        document.draft.entrances[i] = p
                    }
                case let .exitPoint(i):
                    if document.draft.exits.indices.contains(i) {
                        document.draft.exits[i] = p
                    }
                }
            }
            .onEnded { v in
                defer { preDrag = nil; dragTarget = nil; dragMoved = false }
                #if !os(iOS)
                if state.tool == .brush {
                    commitStroke()
                    return
                }
                if state.tool == .paint || state.tool == .eraser {
                    commitPaint(at: v.location)
                    return
                }
                #endif
                if dragMoved, dragTarget != nil {
                    if let before = preDrag, before != document.draft {
                        document.registerUndo(from: before, undoManager)
                    }
                } else {
                    click(at: v.location, t)
                }
            }
    }

    private func click(at p: CGPoint, _ t: DesignTransform) {
        let dp = snap(t.design(p))
        switch state.tool {
        case .select:
            if let handle = hitHandle(at: p, t) {
                let target = selection(for: handle)
                if case .slot = target, state.selection == target {
                    state.selection = .none
                } else {
                    state.selection = target
                }
            } else if state.isVisible(.path), let (ri, _) = hitRoad(at: t.design(p), tolerance: 18) {
                state.selection = .road(ri)
            } else {
                state.selection = .none
            }

        case .slot:
            // Tapping an existing slot selects it (dragging moves it); only
            // a tap on open ground adds a new one.
            if let existing = slotTarget(at: p, t) {
                let target = selection(for: existing)
                state.selection = state.selection == target ? .none : target
            } else {
                state.selection = .slot(document.addSlot(at: dp, undoManager))
            }

        case .entrance:
            if let existing = markerTarget(at: p, t, exits: false) {
                state.selection = selection(for: existing)
            } else {
                document.edit(undoManager) { $0.entrances.append(dp) }
                state.selection = .entrance(document.draft.entrances.count - 1)
            }

        case .callWaveButton:
            if let existing = callWaveButtonTarget(at: p, t) {
                state.selection = selection(for: existing)
            } else {
                document.edit(undoManager) { $0.callWaveButtons.append(.init(position: dp)) }
                state.selection = .callWaveButton(document.draft.callWaveButtons.count - 1)
            }

        case .exitPoint:
            if let existing = markerTarget(at: p, t, entrances: false) {
                state.selection = selection(for: existing)
            } else {
                document.edit(undoManager) { $0.exits.append(dp) }
                state.selection = .exitPoint(document.draft.exits.count - 1)
            }

        case .zoomIn:
            zoomFocusPoint = t.design(p)
            state.zoomIn()

        case .primaryHero, .secondaryHero:
            guard let role = state.tool.heroRole else { return }
            if heroTarget(at: p, t, role: role) == nil {
                document.edit(undoManager) { $0.placeHero(role, at: dp) }
            }
            state.selection = .hero(role)

        case .zoomOut:
            zoomFocusPoint = t.design(p)
            state.zoomOut()

        case .pan, .brush, .paint, .eraser:
            break
        }
    }

    private func selection(for target: DragTarget) -> EditorSelection {
        switch target {
        case let .slot(i): .slot(i)
        case let .waypoint(r, i): .waypoint(road: r, point: i)
        case let .entrance(i): .entrance(i)
        case let .exitPoint(i): .exitPoint(i)
        case let .callWaveButton(i): .callWaveButton(i)
        case let .hero(role): .hero(role)
        }
    }

    private func deleteSelection() {
        switch state.selection {
        case let .hero(role):
            document.edit(undoManager) { $0.removeHeroStart(role) }
            state.flash("\(role.title) starting point removed")
        case let .callWaveButton(i):
            document.deleteCallWaveButton(i, undoManager)
        case let .slot(i):
            document.deleteSlot(i, undoManager)
        case let .waypoint(r, i):
            document.deleteWaypoint(road: r, point: i, undoManager)
        case let .road(r):
            document.deleteRoad(r, undoManager)
        case let .entrance(i):
            document.deleteEntrance(i, undoManager)
        case let .exitPoint(i):
            document.deleteExit(i, undoManager)
        case .none:
            return
        }
        state.selection = .none
    }

    private var canNudgeSelection: Bool {
        let draft = document.draft
        switch state.selection {
        case let .hero(role): return draft.heroMarkerPosition(role) != nil
        case let .slot(i): return draft.slots.indices.contains(i)
        case let .waypoint(r, i):
            return draft.roads.indices.contains(r) && draft.roads[r].points.indices.contains(i)
        case let .entrance(i): return draft.entrances.indices.contains(i)
        case let .exitPoint(i): return draft.exits.indices.contains(i)
        case let .callWaveButton(i): return draft.callWaveButtons.indices.contains(i)
        case .none, .road: return false
        }
    }

    private func nudge(_ direction: NudgeDirection) {
        // Map coordinates are y-up; DesignTransform flips them for display.
        let (dx, dy): (Double, Double) = switch direction {
        case .up: (0, 1)
        case .down: (0, -1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
        let moved: (Point) -> Point = state.snapToGrid
            ? { state.grid.step($0, dx: dx, dy: dy) }
            : { Point($0.x + dx, $0.y + dy) }
        document.edit(undoManager) { d in
            switch state.selection {
            case let .hero(role):
                if let p = d.heroMarkerPosition(role) { d.placeHero(role, at: moved(p)) }
            case let .callWaveButton(i) where d.callWaveButtons.indices.contains(i):
                d.callWaveButtons[i].position = moved(d.callWaveButtons[i].position)
            case let .slot(i) where d.slots.indices.contains(i):
                d.slots[i] = moved(d.slots[i])
            case let .waypoint(r, i)
                where d.roads.indices.contains(r) && d.roads[r].points.indices.contains(i):
                d.roads[r].points[i] = moved(d.roads[r].points[i])
            case let .entrance(i) where d.entrances.indices.contains(i):
                d.entrances[i] = moved(d.entrances[i])
            case let .exitPoint(i) where d.exits.indices.contains(i):
                d.exits[i] = moved(d.exits[i])
            default:
                break
            }
        }
    }

    private func snap(_ p: Point) -> Point {
        var out = state.snapped(p)
        out.x = min(max(out.x, 0), virtualCanvas.size.width)
        out.y = min(max(out.y, 0), virtualCanvas.size.height)
        return out
    }

    private func hitHandle(at p: CGPoint, _ t: DesignTransform) -> DragTarget? {
        // Hero badges sit above the map and must win over underlying road handles.
        if let hero = heroTarget(at: p, t) { return hero }
        var best: (DragTarget, CGFloat)?
        if state.isVisible(.path) {
            let wpRadius = max(10, 7 * t.scale)
            for (ri, road) in document.draft.roads.enumerated() {
                for (pi, wp) in road.points.enumerated() {
                    let vp = t.view(wp)
                    let d = hypot(vp.x - p.x, vp.y - p.y)
                    if d <= wpRadius, best == nil || d < best!.1 {
                        best = (.waypoint(road: ri, point: pi), d)
                    }
                }
            }
            if best != nil { return best!.0 }
        }

        if let marker = markerTarget(at: p, t) { return marker }

        if let button = callWaveButtonTarget(at: p, t) { return button }

        return slotTarget(at: p, t)
    }

    private func slotTarget(at p: CGPoint, _ t: DesignTransform) -> DragTarget? {
        guard state.isVisible(.slots) else { return nil }
        let dp = t.design(p)
        let point = CGPoint(x: dp.x, y: dp.y)
        var best: (DragTarget, Double)?
        for (i, slot) in document.draft.slots.enumerated() {
            let center = CGPoint(x: slot.x, y: slot.y)
            guard virtualCanvas.slotFootprintContains(point, slot: center) else { continue }
            let d = hypot(dp.x - slot.x, dp.y - slot.y)
            if best == nil || d < best!.1 { best = (.slot(i), d) }
        }
        return best?.0
    }

    private func callWaveButtonLayout(at point: Point, _ t: DesignTransform) -> CallWaveButtonLayout {
        CallWaveButtonLayout(position: point, runtimeCanvas: RuntimeCanvas(
            virtualCanvas: virtualCanvas, physicalRect: t.frame,
            safeInsetsRect: t.view(virtualCanvas.playAreaRect)))
    }

    private func callWaveButtonTarget(at p: CGPoint, _ t: DesignTransform) -> DragTarget? {
        guard state.isVisible(.callWaveButtons) else { return nil }
        return document.draft.callWaveButtons.enumerated().reversed().first { _, point in
            let frame = callWaveButtonLayout(at: point.position, t).frame
            return hypot(p.x - frame.midX, p.y - frame.midY) <= frame.width / 2
        }.map { .callWaveButton($0.offset) }
    }

    private func markerTarget(at p: CGPoint, _ t: DesignTransform,
                              entrances: Bool = true, exits: Bool = true) -> DragTarget? {
        let markerRadius = max(14, 20 * t.scale)
        var best: (DragTarget, CGFloat)?
        if entrances, state.isVisible(.entrances) {
            for (i, marker) in document.draft.entrances.enumerated() {
                let vp = t.view(marker)
                let d = hypot(vp.x - p.x, vp.y - p.y)
                if d <= markerRadius, best == nil || d < best!.1 { best = (.entrance(i), d) }
            }
        }
        if exits, state.isVisible(.exits) {
            for (i, marker) in document.draft.exits.enumerated() {
                let vp = t.view(marker)
                let d = hypot(vp.x - p.x, vp.y - p.y)
                if d <= markerRadius, best == nil || d < best!.1 { best = (.exitPoint(i), d) }
            }
        }
        return best?.0
    }

    private func heroMarkerFrame(_ role: HeroSelection.Role, _ t: DesignTransform) -> CGRect? {
        guard let point = document.draft.heroMarkerPosition(role) else { return nil }
        let anchor = t.view(point)
        let other: HeroSelection.Role = role == .primary ? .secondary : .primary
        var centerX = anchor.x
        if let otherPoint = document.draft.heroMarkerPosition(other) {
            let otherAnchor = t.view(otherPoint)
            if hypot(anchor.x - otherAnchor.x, anchor.y - otherAnchor.y) < 44 {
                // Keep both roles selectable even when they share a start or exit.
                let groupCenter = min(max((anchor.x + otherAnchor.x) / 2, 42), t.frame.maxX - 42)
                centerX = groupCenter + (role == .primary ? -23 : 23)
            }
        }
        return CGRect(x: min(max(centerX - 19, 0), t.frame.maxX - 38),
                      y: min(max(anchor.y - 46, 0), t.frame.maxY - 32), width: 38, height: 32)
    }

    private func heroTarget(at point: CGPoint, _ t: DesignTransform,
                            role: HeroSelection.Role? = nil) -> DragTarget? {
        guard state.isVisible(.heroStarts) else { return nil }
        return HeroSelection.Role.allCases.first { candidate in
            (role == nil || role == candidate)
                && heroMarkerFrame(candidate, t)?.insetBy(dx: -3, dy: -3).contains(point) == true
        }.map { .hero($0) }
    }

    private func hitRoad(at p: Point, tolerance: Double) -> (Int, Double)? {
        var best: (Int, Double)?
        for (ri, road) in document.draft.roads.enumerated() where road.points.count >= 2 {
            let d = state.mapGeometry.distance(p, polyline: road.points)
            if d <= tolerance + state.mapGeometry.roadHalfWidth, best == nil || d < best!.1 {
                best = (ri, d)
            }
        }
        return best
    }

    private func draw(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let draft = document.draft
        let frame = t.frame

        if state.isVisible(.background), let img = state.background {
            var bg = ctx
            bg.clip(to: SwiftUI.Path(frame))
            bg.draw(Image(platformImage: img), in: t.view(backgroundCanvasRect(draft)))
        }

        if state.isVisible(.mapGuide), let guide = state.guide {
            var layer = ctx
            layer.opacity = draft.guideOpacity
            layer.clip(to: SwiftUI.Path(frame))
            let rect = guideMatchesCanvasAspect
                ? canvasRect(for: state.guidePixelSize)
                : virtualCanvas.playAreaRect
            layer.draw(Image(platformImage: guide), in: t.view(rect))
        }
        if state.isVisible(.path) {
            var layer = ctx
            drawRoads(&layer, t)
        }
        if state.isVisible(.slots) {
            var layer = ctx
            drawSlots(&layer, t)
        }
        if state.isVisible(.callWaveButtons) { drawCallWaveButtons(&ctx, t) }
        if state.isVisible(.exits) {
            var layer = ctx
            drawMarkers(&layer, t, points: draft.exits, isEntrance: false)
        }
        if state.isVisible(.entrances) {
            var layer = ctx
            drawMarkers(&layer, t, points: draft.entrances, isEntrance: true)
        }
        drawLiveStroke(&ctx, t)
        drawPaintCursor(&ctx, t)
        drawSlotPlacementGuide(&ctx, t)
        // The occlusion art sits above every playable layer, exactly as the
        // game will draw it, so entrance and exit cover can be judged here.
        if state.isVisible(.occlusion), let overlay = state.overlay {
            var layer = ctx
            layer.clip(to: SwiftUI.Path(frame))
            layer.draw(Image(platformImage: overlay),
                       in: t.view(canvasRect(for: state.overlayPixelSize)))
        }
        if state.isVisible(.grid) { drawGrid(&ctx, t, frame) }
        if state.showPlayArea { drawPlayAreaOverlay(&ctx, t) }
        drawMenuPreview(&ctx, t)
        if state.isVisible(.heroStarts) { drawHeroStarts(&ctx, t) }
        ctx.stroke(SwiftUI.Path(frame), with: .color(.white.opacity(0.2)), lineWidth: 1)
    }

    private func drawHeroStarts(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        for role in HeroSelection.Role.allCases {
            guard let position = document.draft.heroMarkerPosition(role),
                  let frame = heroMarkerFrame(role, t) else { continue }
            let anchor = t.view(position)
            let color = HeroPlacementIcon.color(for: role)
            let selected = state.selection == .hero(role)
            var leader = SwiftUI.Path()
            leader.move(to: anchor)
            leader.addLine(to: CGPoint(x: frame.midX, y: frame.maxY))
            ctx.stroke(leader, with: .color(.black.opacity(0.8)), lineWidth: 4)
            ctx.stroke(leader, with: .color(color), lineWidth: 2)
            let marker = SwiftUI.Path(roundedRect: frame, cornerRadius: 9)
            ctx.fill(marker, with: .color(color))
            ctx.stroke(marker, with: .color(selected ? .white : .black.opacity(0.85)), lineWidth: selected ? 3 : 2)
            var icon = ctx.resolve(HeroPlacementIcon.image(for: role))
            icon.shading = .color(.black)
            ctx.draw(icon, in: CGRect(x: frame.midX - 13.5, y: frame.midY - 9.5, width: 27, height: 19))
            let foot = SwiftUI.Path(ellipseIn: CGRect(x: anchor.x - 3, y: anchor.y - 3, width: 6, height: 6))
            ctx.fill(foot, with: .color(color))
            ctx.stroke(foot, with: .color(.black), lineWidth: 1)
        }
    }

    private func drawCallWaveButtons(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let button = menuArt(CallWaveButtonLayout.imageName)
        for (i, point) in document.draft.callWaveButtons.enumerated() {
            let layout = callWaveButtonLayout(at: point.position, t)
            let frame = layout.frame
            if let button {
                ctx.draw(Image(platformImage: button), in: frame)
            } else {
                ctx.fill(SwiftUI.Path(ellipseIn: frame), with: .color(.orange))
                ctx.draw(Text(Image(systemName: "megaphone.fill")).foregroundStyle(.black),
                         at: CGPoint(x: frame.midX, y: frame.midY))
            }
            if state.selection == .callWaveButton(i) {
                ctx.stroke(SwiftUI.Path(ellipseIn: frame), with: .color(.yellow), lineWidth: 3)
            }
            ctx.draw(Text("\(i)").font(.system(size: layout.countdownFontSize, weight: .bold))
                .foregroundStyle(.white), at: CGPoint(x: frame.midX, y: frame.maxY + 8))
        }
    }

    private func drawMarkers(_ ctx: inout GraphicsContext, _ t: DesignTransform,
                             points: [Point], isEntrance: Bool) {
        let s = t.scale
        let r = max(11, 20 * s)
        for (i, marker) in points.enumerated() {
            let c = t.view(marker)
            let selected = state.selection == (isEntrance ? .entrance(i) : .exitPoint(i))
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            let fill: Color = isEntrance
                ? Color(red: 0.20, green: 0.55, blue: 0.24)
                : Color(red: 0.67, green: 0.16, blue: 0.16)
            if isEntrance {
                ctx.fill(SwiftUI.Path(ellipseIn: rect), with: .color(fill))
                ctx.stroke(SwiftUI.Path(ellipseIn: rect),
                           with: .color(selected ? .yellow : .white),
                           lineWidth: selected ? 3 : 1.5)
            } else {
                let box = SwiftUI.Path(roundedRect: rect, cornerRadius: r * 0.25)
                ctx.fill(box, with: .color(fill))
                ctx.stroke(box, with: .color(selected ? .yellow : .white),
                           lineWidth: selected ? 3 : 1.5)
            }
            ctx.draw(
                Text("\(Image(systemName: isEntrance ? "arrow.right" : "flag.fill")) \(i)")
                    .font(.system(size: max(9, 11 * s), weight: .bold))
                    .foregroundStyle(.white),
                at: c
            )
        }
    }

    private func drawLiveStroke(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let points = state.stroke.points
        guard points.count >= 2 else { return }
        PathArtist.draw(&ctx, points: BrushGeometry.smooth(points, passes: 1), t, halfWidth: state.mapGeometry.roadHalfWidth, wet: true)
    }

    private func drawPaintCursor(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        guard state.tool == .paint || state.tool == .eraser, let cursor = state.cursor else { return }
        let d = (state.paintGesture.preview?.width ?? state.paintWidth) * t.scale
        let c = t.view(cursor)
        let rect = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
        let tint: Color = state.tool == .eraser ? .red : PathArtist.fillColor
        ctx.fill(SwiftUI.Path(ellipseIn: rect), with: .color(tint.opacity(0.15)))
        ctx.stroke(SwiftUI.Path(ellipseIn: rect), with: .color(tint.opacity(0.9)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }

    private func drawSlotPlacementGuide(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        guard state.tool == .slot, state.isVisible(.slots), let cursor = state.cursor else { return }
        let target = snap(cursor)
        if slotTarget(at: t.view(cursor), t) != nil { return }
        let issue = state.mapGeometry.slotIssue(target,
                                                roads: document.draft.roads,
                                                others: document.draft.slots,
                                                maxTowerRange: content.maxTowerRange)
        if issue?.blocksPlacement == true { return }

        let c = t.view(target)
        let w = virtualCanvas.towerSlotSize.width * t.scale
        let h = virtualCanvas.towerSlotSize.height * t.scale
        let pad = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        let tint: Color = issue == nil ? .green : .orange
        ctx.fill(SwiftUI.Path(ellipseIn: pad), with: .color(tint.opacity(0.18)))
        ctx.stroke(SwiftUI.Path(ellipseIn: pad), with: .color(tint.opacity(0.95)),
                   style: StrokeStyle(lineWidth: max(1.5, 2 * t.scale), dash: [6 * t.scale, 4 * t.scale]))

        let menu = state.towerMenuLayout.getBgSize(playAreaScalingFactor: t.scale)
        ctx.stroke(
            SwiftUI.Path(ellipseIn: CGRect(x: c.x - menu.width / 2, y: c.y - menu.height / 2,
                                           width: menu.width, height: menu.height)),
            with: .color(tint.opacity(0.35)),
            style: StrokeStyle(lineWidth: max(1, 1.5 * t.scale), dash: [3 * t.scale, 5 * t.scale]))
    }

    private func drawOuterEdge(_ ctx: inout GraphicsContext,
                               _ t: DesignTransform,
                               road: MapDraft.Road,
                               highlighted: Bool) {
        let ring = road.outerEdge(halfWidth: state.mapGeometry.roadHalfWidth)
        guard ring.count >= 4 else { return }
        var p = SwiftUI.Path()
        p.move(to: t.view(ring[0]))
        for pt in ring.dropFirst() { p.addLine(to: t.view(pt)) }
        p.closeSubpath()
        ctx.stroke(p, with: .color(.orange.opacity(highlighted ? 0.95 : 0.5)),
                   style: StrokeStyle(lineWidth: highlighted ? 2 : 1.2, dash: [5, 4]))

        guard highlighted else { return }
        let r: CGFloat = max(1.6, 2.6 * t.scale)
        for pt in ring {
            let v = t.view(pt)
            ctx.fill(
                SwiftUI.Path(ellipseIn: CGRect(x: v.x - r, y: v.y - r, width: 2 * r, height: 2 * r)),
                with: .color(.orange.opacity(0.9))
            )
        }
    }

    private func backgroundCanvasRect(_ d: MapDraft) -> CGRect {
        canvasRect(for: state.backgroundPixelSize)
    }

    /// Whether the loaded guide has the virtual canvas's aspect ratio (to
    /// within half a percent, absorbing integer pixel rounding).
    private var guideMatchesCanvasAspect: Bool {
        guard let px = state.guidePixelSize, px.width > 0, px.height > 0 else { return false }
        let canvas = virtualCanvas.size.width / virtualCanvas.size.height
        return abs(px.width / px.height - canvas) / canvas < 0.005
    }

    /// An image's rect on the canvas: centred, at its own pixel size, so a
    /// correctly sized image covers the canvas exactly.
    private func canvasRect(for pixelSize: CGSize?) -> CGRect {
        let px = pixelSize ?? virtualCanvas.size
        return CGRect(
            x: (virtualCanvas.size.width - px.width) / 2,
            y: (virtualCanvas.size.height - px.height) / 2,
            width: px.width,
            height: px.height
        )
    }

    private func drawPlayAreaOverlay(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let runtimeCanvas = RuntimeCanvas(
            virtualCanvas: virtualCanvas,
            physicalRect: t.frame,
            safeInsetsRect: t.view(virtualCanvas.playAreaRect))
        ctx.stroke(SwiftUI.Path(runtimeCanvas.runtimePlayArea),
                   with: .color(Color(red: 1.0, green: 0.0, blue: 1.0)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [7.935, 10]))
        ctx.stroke(SwiftUI.Path(runtimeCanvas.runtimeTapArea),
                   with: .color(Color(red: 0.0, green: 1.0, blue: 1.0)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [7.2, 4.8]))
        ctx.stroke(SwiftUI.Path(runtimeCanvas.towerSlotValidArea),
                   with: .color(.blue.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
    }

    private func drawMenuPreview(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        var slotIndex: Int? = state.menuPreviewSlot
        if case .slot(let i) = state.selection { slotIndex = i }
        guard let i = slotIndex, document.draft.slots.indices.contains(i) else { return }
        let slot = document.draft.slots[i]
        let c = t.view(slot)
        let bgSize = state.towerMenuLayout.getBgSize(playAreaScalingFactor: t.scale)
        let bgRect = CGRect(x: c.x - bgSize.width / 2,
                            y: c.y - bgSize.height / 2,
                            width: bgSize.width, height: bgSize.height)
        if let art = menuArt("tower_menu_bg") {
            ctx.draw(Image(platformImage: art), in: bgRect)
        } else {
            ctx.fill(SwiftUI.Path(ellipseIn: bgRect), with: .color(.white.opacity(0.15)))
            ctx.stroke(SwiftUI.Path(ellipseIn: bgRect), with: .color(.white.opacity(0.85)),
                       lineWidth: max(1, 2 * t.scale))
        }
        let buttonSide = state.towerMenuLayout
            .getTowerButtonSize(playAreaScalingFactor: t.scale).width
        for kind in TowerKind.allCases {
            let iconSide = state.towerMenuLayout.getTowerIconSize(towerButtonSize: buttonSide, for: kind)
            let buttonCenter = state.towerMenuLayout.getTowerButtonCenterPoint(
                towerKind: kind, menuCenterPoint: c,
                playAreaScalingFactor: t.scale, towerButtonSize: buttonSide)
            let frameRect = CGRect(x: buttonCenter.x - buttonSide / 2,
                                   y: buttonCenter.y - buttonSide / 2,
                                   width: buttonSide, height: buttonSide)
            if let frame = menuArt(kind.menuFrameName) {
                ctx.draw(Image(platformImage: frame), in: frameRect)
            } else {
                ctx.stroke(SwiftUI.Path(frameRect), with: .color(.white.opacity(0.85)),
                           lineWidth: max(1, 1.5 * t.scale))
            }
            let iconRect = CGRect(x: buttonCenter.x - iconSide / 2,
                                  y: buttonCenter.y - iconSide / 2,
                                  width: iconSide, height: iconSide)
            if let icon = menuArt(kind.menuIconName) {
                ctx.draw(Image(platformImage: icon), in: iconRect)
            }
        }
    }

    private func menuArt(_ name: String) -> PlatformImage? {
        let path = "../in-defense-of-history-data/LibertyLineAssets.xcassets/"
            + "\(name).imageset/\(name).png"
        guard let url = EditorResources.url(path),
              let art = PlatformImageLoader.load(path: url.path) else { return nil }
        return art.image
    }

    private func drawGrid(_ ctx: inout GraphicsContext, _ t: DesignTransform, _ frame: CGRect) {
        let grid = state.grid
        let spacing = grid.lineSpacing(scale: t.scale, minimumPixels: 6)
        var minor = SwiftUI.Path()
        var major = SwiftUI.Path()
        for line in grid.verticalLines(canvasWidth: virtualCanvas.size.width, spacing: spacing) {
            let vx = t.view(Point(line.position, 0)).x
            var p = SwiftUI.Path()
            p.move(to: CGPoint(x: vx, y: frame.minY))
            p.addLine(to: CGPoint(x: vx, y: frame.maxY))
            if line.isMajor { major.addPath(p) } else { minor.addPath(p) }
        }
        for line in grid.horizontalLines(canvasHeight: virtualCanvas.size.height, spacing: spacing) {
            let vy = t.view(Point(0, line.position)).y
            var p = SwiftUI.Path()
            p.move(to: CGPoint(x: frame.minX, y: vy))
            p.addLine(to: CGPoint(x: frame.maxX, y: vy))
            if line.isMajor { major.addPath(p) } else { minor.addPath(p) }
        }
        ctx.stroke(minor, with: .color(.white.opacity(0.18)), lineWidth: 1)
        ctx.stroke(major, with: .color(.black.opacity(0.35)), lineWidth: 2)
        ctx.stroke(major, with: .color(.white.opacity(0.55)), lineWidth: 1)
    }

    private func drawRoads(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        let draft = document.draft
        let area = SwiftUI.Path(BrushGeometry.roadArea(roads: draft.roads, paint: draft.roadPaint,
            roadHalfWidth: state.mapGeometry.roadHalfWidth, base: draft.flattenedPath,
            preview: state.paintGesture.preview))
            .applying(t.viewTransform)
        PathArtist.drawArea(&ctx, area, t)
        // Keep route guides from redrawing a line through an erased hole.
        let savedContext = ctx
        ctx.clip(to: area)
        defer { ctx = savedContext }
        for (ri, road) in draft.roads.enumerated() {
            let pts = road.points.map { t.view($0) }
            let isSelected: Bool = switch state.selection {
            case let .road(r): r == ri
            case let .waypoint(r, _): r == ri
            default: false
            }

            if pts.count >= 2 {
                if isSelected {
                    let body = PathArtist.bodyPath(points: road.points, t, halfWidth: state.mapGeometry.roadHalfWidth)
                    ctx.stroke(body, with: .color(.cyan.opacity(0.5)), lineWidth: 6 * s)
                }

                if state.showOuterEdge {
                    drawOuterEdge(&ctx, t, road: road, highlighted: isSelected)
                }

                let epath = Path(points: road.points)
                var d = 84.0
                while d < epath.totalLength {
                    let a = t.view(epath.point(atDistance: d - 9.6))
                    let b = t.view(epath.point(atDistance: d + 9.6))
                    let ang = atan2(b.y - a.y, b.x - a.x)
                    var chev = SwiftUI.Path()
                    let back: CGFloat = 9 * s
                    let spread: CGFloat = 0.55
                    chev.move(to: CGPoint(x: b.x - back * cos(ang - spread), y: b.y - back * sin(ang - spread)))
                    chev.addLine(to: b)
                    chev.addLine(to: CGPoint(x: b.x - back * cos(ang + spread), y: b.y - back * sin(ang + spread)))
                    ctx.stroke(chev, with: .color(.white.opacity(0.25)),
                               style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round, lineJoin: .round))
                    d += 168
                }
            }

            if let first = pts.first {
                ctx.fill(
                    SwiftUI.Path(ellipseIn: CGRect(x: first.x - 13 * s, y: first.y - 13 * s,
                                                   width: 26 * s, height: 26 * s)),
                    with: .color(.red.opacity(0.75))
                )
            }

            // The path's identity, sitting inside the band at its midpoint,
            // matching the row shown in the Paths panel.
            if road.points.count >= 2 {
                let arc = Path(points: road.points)
                let mid = t.view(arc.point(atDistance: arc.totalLength / 2))
                ctx.draw(
                    Text("Path \(ri)")
                        .font(.system(size: max(11, 14 * s), weight: .bold))
                        .foregroundStyle(.black.opacity(0.75)),
                    at: mid
                )
            }
            if pts.count >= 2, let exitP = pts.last {
                var star = SwiftUI.Path()
                let r1 = 15 * s, r2 = 6.5 * s
                for k in 0..<10 {
                    let r = k.isMultiple(of: 2) ? r1 : r2
                    let ang = CGFloat(k) * .pi / 5 - .pi / 2
                    let pt = CGPoint(x: exitP.x + r * cos(ang), y: exitP.y + r * sin(ang))
                    if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                ctx.fill(star, with: .color(Color(red: 0.35, green: 0.6, blue: 0.95)))
            }

            if state.tool == .select {
                for (pi, vp) in pts.enumerated() {
                    let selected = state.selection == .waypoint(road: ri, point: pi)
                    let r: CGFloat = (selected ? 6.5 : 4.5) * max(0.7, s)
                    let rect = CGRect(x: vp.x - r, y: vp.y - r, width: 2 * r, height: 2 * r)
                    ctx.fill(SwiftUI.Path(roundedRect: rect, cornerRadius: 1.5),
                             with: .color(selected ? .yellow : .white.opacity(0.85)))
                    ctx.stroke(SwiftUI.Path(roundedRect: rect, cornerRadius: 1.5),
                               with: .color(.black.opacity(0.6)), lineWidth: 1)
                    if isSelected {
                        ctx.draw(
                            Text("\(pi)")
                                .font(.system(size: max(9, 9 * s)))
                                .foregroundStyle(.cyan),
                            at: CGPoint(x: vp.x, y: vp.y - 11 * max(0.7, s))
                        )
                    }
                }
            }
        }
    }

    private func drawSlots(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        let draft = document.draft
        let warnings = state.mapGeometry.warnings(for: draft, maxTowerRange: content.maxTowerRange)
        var planned: [Int: Emplacement] = [:]
        for step in draft.intendedSolution where step.kind == "place" {
            if planned[step.slot] == nil, let e = step.emplacement.flatMap(Emplacement.init(rawValue:)) {
                planned[step.slot] = e
            }
        }

        for (i, slot) in draft.slots.enumerated() {
            let c = t.view(slot)
            let selected = state.selection == .slot(i)
            let w = virtualCanvas.towerSlotSize.width * s
            let h = virtualCanvas.towerSlotSize.height * s
            let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)

            state.towerSlotImage.draw(&ctx, at: c, index: i, scale: s, selected: selected)

            if selected, state.showRanges {
                let runtimeCanvas = RuntimeCanvas(
                    virtualCanvas: virtualCanvas,
                    physicalRect: t.frame,
                    safeInsetsRect: t.view(virtualCanvas.playAreaRect))
                // Ranges come from the tower table. They were hardcoded here as
                // 210 and 240 with tower names copied alongside them, and had
                // already drifted from the real values.
                for ring in content.ringsByName {
                    let label = "\(ring.name) \(Int(ring.range))"
                    let rangeRect = TowerRangeOverlay.rect(center: c, range: ring.range,
                                                           runtimeCanvas: runtimeCanvas)
                    ctx.stroke(SwiftUI.Path(ellipseIn: rangeRect),
                               with: .color(Color(red: 0, green: 1, blue: 0)),
                               style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                    ctx.draw(
                        Text(label)
                            .font(.system(size: max(9, 10 * s)))
                            .foregroundStyle(Color(red: 0, green: 1, blue: 0)),
                        at: CGPoint(x: c.x, y: rangeRect.minY - 8)
                    )
                }
            }

            let ringColor: Color? = switch warnings[i] {
            case .outsideValidArea, .overlapsPath, .overlapsSlot: .red
            case .outOfRange: .orange
            case nil: selected ? .yellow : nil
            }
            if let ringColor {
                ctx.stroke(
                    SwiftUI.Path(ellipseIn: rect),
                    with: .color(ringColor),
                    style: StrokeStyle(lineWidth: selected ? 3 : 2, dash: [5 * s, 4 * s])
                )
            }
            if let e = planned[i] {
                let dr = 4.0 * s
                ctx.fill(
                    SwiftUI.Path(ellipseIn: CGRect(x: c.x - dr, y: c.y + h / 2 - dr * 0.5,
                                                   width: 2 * dr, height: 2 * dr)),
                    with: .color(Palette.towerColors[e] ?? .white)
                )
            }
        }
    }
}
