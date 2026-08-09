import SwiftUI

@MainActor
struct EditorCanvas: View {
    @ObservedObject var document: MapDocument
    var state: EditorState
    @Environment(\.undoManager) private var undoManager
    @FocusState private var focused: Bool

    @State private var preDrag: MapDraft?
    @State private var dragTarget: DragTarget?
    @State private var dragMoved = false
    @State private var pinchBase: Double?

    private enum DragTarget: Equatable {
        case slot(Int)
        case waypoint(road: Int, point: Int)
    }

    var body: some View {
        GeometryReader { geo in
            let fit = Double(min(geo.size.width / CanvasSpec.width,
                                 geo.size.height / CanvasSpec.height))
            let s = CGFloat(state.zoom ?? fit)
            let t = DesignTransform(scale: s, space: CanvasSpec.size)
            Group {
                if state.zoom == nil {
                    canvasContent(t)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        canvasContent(t)
                    }
                    .defaultScrollAnchor(.center)
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
        .frame(width: CanvasSpec.width * t.scale, height: CanvasSpec.height * t.scale)
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
    }

    @ViewBuilder
    private func brushInputOverlay(_ t: DesignTransform) -> some View {
        #if os(iOS)
        if state.tool == .brush {
            BrushInputView(
                onBegan: { p, force in beginStroke(at: p, force: force, t) },
                onMoved: { p, force in extendStroke(to: p, force: force, t) },
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
        }
        #else
        EmptyView()
        #endif
    }

    private func pressureHalfWidth(_ force: Double) -> Double {
        guard state.brushPressureEnabled, force > 0 else { return state.brushSize }
        return state.brushSize * (0.35 + 0.65 * min(force, 1.0))
    }

    private func beginStroke(at p: CGPoint, force: Double, _ t: DesignTransform) {
        state.stroke = BrushStroke()
        extendStroke(to: p, force: force, t)
    }

    private func extendStroke(to p: CGPoint, force: Double, _ t: DesignTransform) {
        let canvasPoint = clampToCanvas(t.design(p))
        state.stroke.add(
            BrushSample(point: canvasPoint, halfWidth: pressureHalfWidth(force)),
            minSpacing: max(2, 4 / max(t.scale, 0.05))
        )
    }

    private func commitStroke() {
        defer { state.stroke = BrushStroke() }
        guard let road = BrushGeometry.commit(state.stroke, spacing: state.brushSpacing) else {
            return
        }
        document.addPaintedRoad(points: road.points,
                                halfWidths: road.halfWidths,
                                undoManager)
        state.selection = .road(document.draft.roads.count - 1)
        state.flash("Painted road: \(road.points.count) waypoints, "
                    + "\(road.points.count * 2) outer-edge points")
    }

    private func clampToCanvas(_ p: Point) -> Point {
        Point(min(max(p.x, 0), CanvasSpec.width), min(max(p.y, 0), CanvasSpec.height))
    }

    private func dragGesture(_ t: DesignTransform) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                focused = true
                #if !os(iOS)
                if state.tool == .brush {
                    if state.stroke.isEmpty {
                        beginStroke(at: v.startLocation, force: 0, t)
                    }
                    extendStroke(to: v.location, force: 0, t)
                    return
                }
                #endif
                if preDrag == nil {
                    preDrag = document.draft
                    dragMoved = false
                    dragTarget = state.tool == .select ? hitHandle(at: v.startLocation, t) : nil
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
                }
            }
            .onEnded { v in
                defer { preDrag = nil; dragTarget = nil; dragMoved = false }
                #if !os(iOS)
                if state.tool == .brush {
                    commitStroke()
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
            } else if let (ri, _) = hitRoad(at: t.design(p), tolerance: 18) {
                state.selection = .road(ri)
            } else {
                state.selection = .none
            }

        case .road:
            document.edit(undoManager) { d in
                guard !d.roads.isEmpty else {
                    d.roads.append(.init(name: "Road 1", points: [dp]))
                    state.selection = .waypoint(road: 0, point: 0)
                    return
                }
                let r = activeRoad(in: d)
                let raw = t.design(p)
                if let seg = nearestSegment(of: d.roads[r].points, to: raw, within: 14) {
                    d.roads[r].points.insert(dp, at: seg + 1)
                    state.selection = .waypoint(road: r, point: seg + 1)
                } else {
                    d.roads[r].points.append(dp)
                    state.selection = .waypoint(road: r, point: d.roads[r].points.count - 1)
                }
            }

        case .slot:
            document.edit(undoManager) { $0.slots.append(dp) }
            state.selection = .slot(document.draft.slots.count - 1)

        case .brush:
            break
        }
    }

    private func selection(for target: DragTarget) -> EditorSelection {
        switch target {
        case let .slot(i): .slot(i)
        case let .waypoint(r, i): .waypoint(road: r, point: i)
        }
    }

    private func activeRoad(in d: MapDraft) -> Int {
        switch state.selection {
        case let .road(r) where d.roads.indices.contains(r): return r
        case let .waypoint(r, _) where d.roads.indices.contains(r): return r
        default: return d.roads.count - 1
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
            default:
                break
            }
        }
    }

    private func snap(_ p: Point) -> Point {
        var out = p
        if state.snapToGrid {
            out = Point((p.x / 12).rounded() * 12, (p.y / 12).rounded() * 12)
        }
        out.x = min(max(out.x, 0), CanvasSpec.width)
        out.y = min(max(out.y, 0), CanvasSpec.height)
        return out
    }

    private func hitHandle(at p: CGPoint, _ t: DesignTransform) -> DragTarget? {
        var best: (DragTarget, CGFloat)?
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

        let slotRadius = max(14, MapGeometry.slotRadius * t.scale + 4)
        for (i, slot) in document.draft.slots.enumerated() {
            let vp = t.view(slot)
            let d = hypot(vp.x - p.x, vp.y - p.y)
            if d <= slotRadius, best == nil || d < best!.1 {
                best = (.slot(i), d)
            }
        }
        return best?.0
    }

    private func hitRoad(at p: Point, tolerance: Double) -> (Int, Double)? {
        var best: (Int, Double)?
        for (ri, road) in document.draft.roads.enumerated() where road.points.count >= 2 {
            let d = MapGeometry.distance(p, polyline: road.points)
            if d <= tolerance + MapGeometry.roadHalfWidth, best == nil || d < best!.1 {
                best = (ri, d)
            }
        }
        return best
    }

    private func nearestSegment(of pts: [Point], to p: Point, within tolerance: Double) -> Int? {
        guard pts.count >= 2 else { return nil }
        var best: (Int, Double)?
        for i in 0..<(pts.count - 1) {
            let d = MapGeometry.distance(p, segment: pts[i], pts[i + 1])
            if d <= tolerance, best == nil || d < best!.1 {
                best = (i, d)
            }
        }
        return best?.0
    }

    private func draw(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let draft = document.draft
        let frame = t.frame

        if let img = state.background {
            var bg = ctx
            bg.opacity = draft.backgroundOpacity
            bg.clip(to: SwiftUI.Path(frame))
            bg.draw(Image(platformImage: img), in: t.view(backgroundCanvasRect(draft)))
        }
        if state.showGrid { drawGrid(&ctx, t, frame) }
        drawRoads(&ctx, t)
        drawSlots(&ctx, t)
        drawLiveStroke(&ctx, t)
        if state.showPlayable { drawPlayableOverlay(&ctx, t) }
        ctx.stroke(SwiftUI.Path(frame), with: .color(.white.opacity(0.2)), lineWidth: 1)
    }

    private func drawLiveStroke(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let samples = state.stroke.samples
        guard samples.count >= 2 else { return }
        let pts = samples.map(\.point)
        let widths = samples.map(\.halfWidth)
        let ring = BrushGeometry.outerEdge(points: pts, halfWidths: widths)
        guard ring.count >= 4 else { return }

        var body = SwiftUI.Path()
        body.move(to: t.view(ring[0]))
        for p in ring.dropFirst() { body.addLine(to: t.view(p)) }
        body.closeSubpath()
        ctx.fill(body, with: .color(.cyan.opacity(0.28)))
        ctx.stroke(body, with: .color(.cyan.opacity(0.75)), lineWidth: 1.5)

        var spine = SwiftUI.Path()
        spine.move(to: t.view(pts[0]))
        for p in pts.dropFirst() { spine.addLine(to: t.view(p)) }
        ctx.stroke(spine, with: .color(.white.opacity(0.7)),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    private func drawOuterEdge(_ ctx: inout GraphicsContext,
                               _ t: DesignTransform,
                               road: MapDraft.Road,
                               highlighted: Bool) {
        let ring = road.outerEdge
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
        let px = state.backgroundPixelSize ?? CanvasSpec.size
        return CGRect(
            x: (CanvasSpec.width - px.width) / 2,
            y: (CanvasSpec.height - px.height) / 2,
            width: px.width,
            height: px.height
        )
    }

    private func drawPlayableOverlay(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let playable = t.view(CanvasSpec.playable)
        var dim = SwiftUI.Path(t.frame)
        dim.addRect(playable)
        ctx.fill(dim, with: .color(.black.opacity(0.38)), style: FillStyle(eoFill: true))
        ctx.stroke(SwiftUI.Path(playable), with: .color(.green.opacity(0.85)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
        ctx.draw(
            Text("playable 1920×1080")
                .font(.system(size: max(10, 11 * t.scale), weight: .medium))
                .foregroundStyle(.green.opacity(0.85)),
            at: CGPoint(x: playable.minX + 60 * t.scale, y: playable.minY - 10),
            anchor: .leading
        )
    }

    private func drawGrid(_ ctx: inout GraphicsContext, _ t: DesignTransform, _ frame: CGRect) {
        var minor = SwiftUI.Path()
        var major = SwiftUI.Path()
        var x = 0.0
        while x <= CanvasSpec.width {
            let vx = t.view(Point(x, 0)).x
            var p = SwiftUI.Path()
            p.move(to: CGPoint(x: vx, y: frame.minY))
            p.addLine(to: CGPoint(x: vx, y: frame.maxY))
            if x.truncatingRemainder(dividingBy: 120) == 0 { major.addPath(p) } else { minor.addPath(p) }
            x += 15
        }
        var y = 0.0
        while y <= CanvasSpec.height {
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
        for (ri, road) in draft.roads.enumerated() {
            let pts = road.points.map { t.view($0) }
            let isSelected: Bool = switch state.selection {
            case let .road(r): r == ri
            case let .waypoint(r, _): r == ri
            default: false
            }

            if pts.count >= 2 {
                var p = SwiftUI.Path()
                p.move(to: pts[0])
                for pt in pts.dropFirst() { p.addLine(to: pt) }

                if road.halfWidths != nil {
                    let ring = road.outerEdge
                    if ring.count >= 4 {
                        var body = SwiftUI.Path()
                        body.move(to: t.view(ring[0]))
                        for pt in ring.dropFirst() { body.addLine(to: t.view(pt)) }
                        body.closeSubpath()
                        if isSelected {
                            ctx.stroke(body, with: .color(.cyan.opacity(0.5)), lineWidth: 6 * s)
                        }
                        ctx.fill(body, with: .color(Palette.roadFill))
                        ctx.stroke(body, with: .color(Palette.roadEdge), lineWidth: max(1, 3 * s))
                    }
                } else {
                    if isSelected {
                        ctx.stroke(p, with: .color(.cyan.opacity(0.45)),
                                   style: StrokeStyle(lineWidth: 43.2 * s, lineCap: .round, lineJoin: .round))
                    }
                    ctx.stroke(p, with: .color(Palette.roadEdge),
                               style: StrokeStyle(lineWidth: 36 * s, lineCap: .round, lineJoin: .round))
                    ctx.stroke(p, with: .color(Palette.roadFill),
                               style: StrokeStyle(lineWidth: 28.8 * s, lineCap: .round, lineJoin: .round))
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
                ctx.draw(
                    Text(road.name)
                        .font(.system(size: max(11, 12 * s), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85)),
                    at: CGPoint(x: first.x + 4, y: first.y - 22 * s)
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

    private func drawSlots(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        let draft = document.draft
        let warnings = MapGeometry.warnings(for: draft)
        var planned: [Int: Emplacement] = [:]
        for step in draft.intendedSolution where step.kind == "place" {
            if planned[step.slot] == nil, let e = step.emplacement.flatMap(Emplacement.init(rawValue:)) {
                planned[step.slot] = e
            }
        }

        for (i, slot) in draft.slots.enumerated() {
            let c = t.view(slot)
            let selected = state.selection == .slot(i)
            let r = MapGeometry.slotRadius * s
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)

            if selected, state.showRanges {
                for (range, label) in [(210.0, "Musketmen 210"), (240.0, "4-pounder 240")] {
                    let rr = range * s
                    let rangeRect = CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr)
                    ctx.stroke(SwiftUI.Path(ellipseIn: rangeRect),
                               with: .color(.cyan.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    ctx.draw(
                        Text(label)
                            .font(.system(size: max(9, 10 * s)))
                            .foregroundStyle(.cyan.opacity(0.7)),
                        at: CGPoint(x: c.x, y: c.y - rr - 8)
                    )
                }
            }

            let ringColor: Color = warnings[i] != nil ? .orange
                : (selected ? .yellow : .white.opacity(0.5))
            ctx.stroke(
                SwiftUI.Path(ellipseIn: rect),
                with: .color(ringColor),
                style: StrokeStyle(lineWidth: selected ? 3 : 2, dash: [5 * s, 4 * s])
            )
            ctx.draw(
                Text("\(i)")
                    .font(.system(size: max(9, 10 * s), weight: .medium))
                    .foregroundStyle(selected ? .yellow : .white.opacity(0.6)),
                at: c
            )
            if let e = planned[i] {
                let dr = 4.0 * s
                ctx.fill(
                    SwiftUI.Path(ellipseIn: CGRect(x: c.x - dr, y: c.y + r - dr * 0.5,
                                                   width: 2 * dr, height: 2 * dr)),
                    with: .color(Palette.towerColors[e] ?? .white)
                )
            }
        }
    }
}
