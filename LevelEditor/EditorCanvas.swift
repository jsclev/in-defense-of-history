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

    private enum DragTarget: Equatable {
        case slot(Int)
        case waypoint(road: Int, point: Int)
        case entrance(Int)
        case exitPoint(Int)
    }

    var body: some View {
        GeometryReader { geo in
            let fit = Double(min(geo.size.width / virtualCanvas.size.width,
                                 geo.size.height / virtualCanvas.size.height))
            let s = CGFloat(state.zoom ?? fit)
            let t = DesignTransform(scale: s, space: virtualCanvas.size)
            Group {
                if state.zoom == nil {
                    canvasContent(t)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        canvasContent(t)
                    }
                    .defaultScrollAnchor(.center)
                    .scrollDisabled(state.tool == .brush || state.tool == .paint || state.tool == .eraser)
                }
            }
            .onChange(of: geo.size, initial: true) { _, _ in
                state.fitScale = fit
            }
        }
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
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    if pinchBase == nil { pinchBase = state.currentScale }
                    state.setZoom(pinchBase! * v.magnification)
                }
                .onEnded { _ in pinchBase = nil }
        )
        .onContinuousHover { phase in
            switch phase {
            case let .active(p): state.cursor = t.design(p)
            case .ended: state.cursor = nil
            }
        }
        .platformEditingCommands(
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
                onCancelled: { state.paintStroke = BrushStroke() },
                onPinchBegan: {
                    state.paintStroke = BrushStroke()
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
        state.paintStroke = BrushStroke()
        extendPaint(to: p, t)
    }

    private func extendPaint(to p: CGPoint, _ t: DesignTransform) {
        state.paintStroke.add(clampToCanvas(t.design(p)),
                              minSpacing: max(0.5, 1 / max(t.scale, 0.05)))
    }

    private func commitPaint() {
        defer { state.paintStroke = BrushStroke() }
        let points = state.paintStroke.points
        guard !points.isEmpty else { return }
        let stroke = MapDraft.PaintStroke(points: points, width: state.paintWidth,
                                          erases: state.tool == .eraser)
        if stroke.erases {
            document.edit(undoManager) { $0.applyErase(stroke, geometry: state.geometry) }
            // A split renumbers the roads, and selection is held by index.
            state.selection = .none
        } else {
            document.edit(undoManager) { $0.roadPaint.append(stroke) }
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
                    if state.paintStroke.isEmpty {
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
                    default: nil
                    }
                    if let target = dragTarget {
                        state.selection = selection(for: target)
                    }
                }
                if hypot(v.translation.width, v.translation.height) > 3 {
                    dragMoved = true
                }
                guard dragMoved, let target = dragTarget else { return }
                let p = snap(t.design(v.location))
                switch target {
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
                    commitPaint()
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
                state.selection = selection(for: handle)
            } else if state.isVisible(.path), let (ri, _) = hitRoad(at: t.design(p), tolerance: 18) {
                state.selection = .road(ri)
            } else {
                state.selection = .none
            }

        case .slot:
            // Tapping an existing slot selects it (dragging moves it); only
            // a tap on open ground adds a new one.
            if let existing = slotTarget(at: p, t) {
                state.selection = selection(for: existing)
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

        case .exitPoint:
            if let existing = markerTarget(at: p, t, entrances: false) {
                state.selection = selection(for: existing)
            } else {
                document.edit(undoManager) { $0.exits.append(dp) }
                state.selection = .exitPoint(document.draft.exits.count - 1)
            }

        case .brush, .paint, .eraser:
            break
        }
    }

    private func selection(for target: DragTarget) -> EditorSelection {
        switch target {
        case let .slot(i): .slot(i)
        case let .waypoint(r, i): .waypoint(road: r, point: i)
        case let .entrance(i): .entrance(i)
        case let .exitPoint(i): .exitPoint(i)
        }
    }

    private func deleteSelection() {
        switch state.selection {
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

    private func nudge(_ direction: NudgeDirection) {
        let step = 1.0
        let (dx, dy): (Double, Double) = switch direction {
        case .up: (0, -step)
        case .down: (0, step)
        case .left: (-step, 0)
        case .right: (step, 0)
        }
        document.edit(undoManager) { d in
            switch state.selection {
            case let .slot(i) where d.slots.indices.contains(i):
                d.slots[i] = Point(d.slots[i].x + dx, d.slots[i].y + dy)
            case let .waypoint(r, i)
                where d.roads.indices.contains(r) && d.roads[r].points.indices.contains(i):
                let p = d.roads[r].points[i]
                d.roads[r].points[i] = Point(p.x + dx, p.y + dy)
            case let .entrance(i) where d.entrances.indices.contains(i):
                d.entrances[i] = Point(d.entrances[i].x + dx, d.entrances[i].y + dy)
            case let .exitPoint(i) where d.exits.indices.contains(i):
                d.exits[i] = Point(d.exits[i].x + dx, d.exits[i].y + dy)
            default:
                break
            }
        }
    }

    private func snap(_ p: Point) -> Point {
        var out = p
        if state.snapToGrid {
            out = Point((p.x / 6).rounded() * 6, (p.y / 6).rounded() * 6)
        }
        out.x = min(max(out.x, 0), virtualCanvas.size.width)
        out.y = min(max(out.y, 0), virtualCanvas.size.height)
        return out
    }

    private func hitHandle(at p: CGPoint, _ t: DesignTransform) -> DragTarget? {
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

    private func hitRoad(at p: Point, tolerance: Double) -> (Int, Double)? {
        var best: (Int, Double)?
        for (ri, road) in document.draft.roads.enumerated() where road.points.count >= 2 {
            let d = state.geometry.distance(p, polyline: road.points)
            if d <= tolerance + state.geometry.roadHalfWidth, best == nil || d < best!.1 {
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
        // The map guide - typically a Kingdom Rush screenshot traced by hand.
        // A guide cut to the canvas's own aspect ratio IS canvas-space art,
        // so it lands 1:1 on the canvas like the background does, unscaled;
        // any other shape is fitted to the play area, the space the traced
        // geometry must land in.
        if state.isVisible(.mapGuide), let guide = state.guide {
            var layer = ctx
            layer.opacity = draft.guideOpacity
            layer.clip(to: SwiftUI.Path(frame))
            let rect = guideMatchesCanvasAspect
                ? canvasRect(for: state.guidePixelSize)
                : virtualCanvas.playAreaRect
            layer.draw(Image(platformImage: guide), in: t.view(rect))
        }
        if state.showGrid { drawGrid(&ctx, t, frame) }
        if state.isVisible(.path) {
            var layer = ctx
            drawRoads(&layer, t)
        }
        if state.isVisible(.slots) {
            var layer = ctx
            drawSlots(&layer, t)
        }
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
        // The occlusion art sits above every playable layer, exactly as the
        // game will draw it, so entrance and exit cover can be judged here.
        if state.isVisible(.occlusion), let overlay = state.overlay {
            var layer = ctx
            layer.clip(to: SwiftUI.Path(frame))
            layer.draw(Image(platformImage: overlay),
                       in: t.view(canvasRect(for: state.overlayPixelSize)))
        }
        if state.showPlayArea { drawPlayAreaOverlay(&ctx, t) }
        drawMenuPreview(&ctx, t)
        ctx.stroke(SwiftUI.Path(frame), with: .color(.white.opacity(0.2)), lineWidth: 1)
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
        PathArtist.draw(&ctx, points: BrushGeometry.smooth(points, passes: 1), t, halfWidth: state.geometry.roadHalfWidth, wet: true)
    }

    private func drawPaintCursor(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        guard state.tool == .paint || state.tool == .eraser, let cursor = state.cursor else { return }
        let d = state.paintWidth * t.scale
        let c = t.view(cursor)
        let rect = CGRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)
        let tint: Color = state.tool == .eraser ? .red : PathArtist.fillColor
        ctx.fill(SwiftUI.Path(ellipseIn: rect), with: .color(tint.opacity(0.15)))
        ctx.stroke(SwiftUI.Path(ellipseIn: rect), with: .color(tint.opacity(0.9)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }

    private func drawOuterEdge(_ ctx: inout GraphicsContext,
                               _ t: DesignTransform,
                               road: MapDraft.Road,
                               highlighted: Bool) {
        let ring = road.outerEdge(halfWidth: state.geometry.roadHalfWidth)
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
        let play = virtualCanvas.playAreaRect
        let notched = SwiftUI.Path(virtualCanvas.playAreaShape).applying(t.viewTransform)
        var dim = SwiftUI.Path(t.frame)
        dim.addPath(notched)
        ctx.fill(dim, with: .color(.black.opacity(0.38)), style: FillStyle(eoFill: true))
        let lineColor = Color(red: 0.75, green: 0.15, blue: 1.0)
        ctx.stroke(notched, with: .color(lineColor),
                   style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))

        let toView = CGAffineTransform(a: t.scale, b: 0, c: 0, d: t.scale,
                                       tx: t.offset.x, ty: t.offset.y)
        let slotShape = SwiftUI.Path(state.towerMenuLayout.slotMenuSafeShape).applying(toView)
        ctx.stroke(slotShape, with: .color(.blue.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

        let font = Font.system(size: max(10, 11 * t.scale), weight: .semibold)
        let playTopView = t.view(Point(play.midX, play.maxY))
        ctx.draw(
            Text("play top y \(Int(play.maxY.rounded()))")
                .font(font).foregroundStyle(lineColor),
            at: CGPoint(x: playTopView.x, y: playTopView.y - 10)
        )
        let topInset = state.towerMenuLayout.slotSafeInset(.top)
        let topY = play.maxY - topInset
        let topView = t.view(Point(play.midX, topY))
        ctx.draw(
            Text("slot top y \(Int(topY.rounded())) = \(Int(play.maxY)) − \(Int(topInset.rounded()))")
                .font(font).foregroundStyle(.blue.opacity(0.9)),
            at: CGPoint(x: topView.x, y: topView.y - 10)
        )
        let bottomInset = state.towerMenuLayout.slotSafeInset(.bottom)
        let bottomY = play.minY + bottomInset
        let bottomView = t.view(Point(play.midX, bottomY))
        ctx.draw(
            Text("slot bottom y \(Int(bottomY.rounded())) = \(Int(play.minY)) + \(Int(bottomInset.rounded()))")
                .font(font).foregroundStyle(.blue.opacity(0.9)),
            at: CGPoint(x: bottomView.x, y: bottomView.y + 12)
        )
        let leftInset = state.towerMenuLayout.slotSafeInset(.left)
        let leftX = play.minX + leftInset
        let leftView = t.view(Point(leftX, play.midY))
        ctx.draw(
            Text("slot left x \(Int(leftX.rounded())) = \(Int(play.minX)) + \(Int(leftInset.rounded()))")
                .font(font).foregroundStyle(.blue.opacity(0.9)),
            at: CGPoint(x: leftView.x + 8, y: leftView.y),
            anchor: .leading
        )
    }

    private func drawMenuPreview(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        guard let i = state.menuPreviewSlot,
              document.draft.slots.indices.contains(i) else { return }
        let slot = document.draft.slots[i]
        let c = t.view(slot)
        let size = state.towerMenuLayout.getBgSize(playAreaScalingFactor: 1)
        let rect = CGRect(x: c.x - size.width * t.scale / 2,
                          y: c.y - size.height * t.scale / 2,
                          width: size.width * t.scale,
                          height: size.height * t.scale)
        let artPath = "../in-defense-of-history-data/LibertyLineAssets.xcassets/"
            + "tower_menu_bg.imageset/tower_menu_bg.png"
        if let url = EditorResources.url(artPath),
           let art = PlatformImageLoader.load(path: url.path) {
            ctx.draw(Image(platformImage: art.image), in: rect)
        } else {
            ctx.fill(SwiftUI.Path(ellipseIn: rect), with: .color(.white.opacity(0.15)))
            ctx.stroke(SwiftUI.Path(ellipseIn: rect), with: .color(.white.opacity(0.85)),
                       lineWidth: max(1, 2 * t.scale))
        }
    }

    private func drawGrid(_ ctx: inout GraphicsContext, _ t: DesignTransform, _ frame: CGRect) {
        var minor = SwiftUI.Path()
        var major = SwiftUI.Path()
        var x = 0.0
        while x <= virtualCanvas.size.width {
            let vx = t.view(Point(x, 0)).x
            var p = SwiftUI.Path()
            p.move(to: CGPoint(x: vx, y: frame.minY))
            p.addLine(to: CGPoint(x: vx, y: frame.maxY))
            if x.truncatingRemainder(dividingBy: 120) == 0 { major.addPath(p) } else { minor.addPath(p) }
            x += 15
        }
        var y = 0.0
        while y <= virtualCanvas.size.height {
            let vy = t.view(Point(0, y)).y
            var p = SwiftUI.Path()
            p.move(to: CGPoint(x: frame.minX, y: vy))
            p.addLine(to: CGPoint(x: frame.maxX, y: vy))
            if y.truncatingRemainder(dividingBy: 120) == 0 { major.addPath(p) } else { minor.addPath(p) }
            y += 15
        }
        ctx.stroke(minor, with: .color(.white.opacity(0.04)), lineWidth: 1)
        ctx.stroke(major, with: .color(.white.opacity(0.08)), lineWidth: 1)
    }

    private func drawRoads(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        let draft = document.draft
        let area = SwiftUI.Path(BrushGeometry.roadArea(roads: draft.roads, paint: draft.roadPaint, roadHalfWidth: state.geometry.roadHalfWidth))
            .applying(t.viewTransform)
        PathArtist.drawArea(&ctx, area, t)
        if !state.paintStroke.isEmpty {
            let wet = SwiftUI.Path(BrushGeometry.strokeArea(points: state.paintStroke.points,
                                                            width: state.paintWidth))
                .applying(t.viewTransform)
            let tint: Color = state.tool == .eraser ? .red : PathArtist.fillColor
            ctx.fill(wet, with: .color(tint.opacity(0.45)))
        }
        for (ri, road) in draft.roads.enumerated() {
            let pts = road.points.map { t.view($0) }
            let isSelected: Bool = switch state.selection {
            case let .road(r): r == ri
            case let .waypoint(r, _): r == ri
            default: false
            }

            if pts.count >= 2 {
                if isSelected {
                    let body = PathArtist.bodyPath(points: road.points, t, halfWidth: state.geometry.roadHalfWidth)
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
        let warnings = state.geometry.warnings(for: draft, maxTowerRange: content.maxTowerRange)
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
                // Ranges come from the tower table. They were hardcoded here as
                // 210 and 240 with tower names copied alongside them, and had
                // already drifted from the real values.
                for ring in content.ringsByName {
                    let label = "\(ring.name) \(Int(ring.range))"
                    let rangeRect = MapRangeShape.rect(center: c, range: ring.range,
                                                       pointsPerMapUnit: s)
                    ctx.stroke(SwiftUI.Path(ellipseIn: rangeRect),
                               with: .color(.cyan.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    ctx.draw(
                        Text(label)
                            .font(.system(size: max(9, 10 * s)))
                            .foregroundStyle(.cyan.opacity(0.7)),
                        at: CGPoint(x: c.x, y: rangeRect.minY - 8)
                    )
                }
            }

            let ringColor: Color? = switch warnings[i] {
            case .overlapsPath, .overlapsSlot: .red
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
