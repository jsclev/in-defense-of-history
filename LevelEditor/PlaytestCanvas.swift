import SwiftUI

@MainActor
struct PlaytestCanvas: View {
    let session: SimSession
    let slotArt: TowerSlotImage

    var body: some View {
        GeometryReader { geo in
            let t = DesignTransform(fitting: geo.size, space: CGSize(
                width: session.virtualCanvas.size.width, height: session.virtualCanvas.size.height))
            Canvas { ctx, _ in
                draw(in: &ctx, transform: t)
            }
            .background(Palette.mapBackground)
            .onTapGesture { location in
                handleTap(at: location, transform: t)
            }
        }
        .aspectRatio(session.virtualCanvas.size.width / session.virtualCanvas.size.height, contentMode: .fit)
    }

    private func handleTap(at p: CGPoint, transform t: DesignTransform) {
        let slots = session.level.towerSlots
        let hitRadius = max(26 * t.scale, 20)
        var best: (Int, CGFloat)?
        for (i, slot) in slots.enumerated() {
            let sp = t.view(slot.position)
            let d = hypot(sp.x - p.x, sp.y - p.y)
            if d <= hitRadius, best == nil || d < best!.1 {
                best = (i, d)
            }
        }
        session.selectedSlot = best?.0
    }

    private func draw(in ctx: inout GraphicsContext, transform t: DesignTransform) {
        drawRoads(&ctx, t)
        drawSlots(&ctx, t)
        drawFlashes(&ctx, t)
        drawEnemies(&ctx, t)
        ctx.stroke(SwiftUI.Path(t.frame), with: .color(.white.opacity(0.15)), lineWidth: 1)
    }

    private func drawRoads(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        for (ri, road) in session.level.paths.enumerated() {
            var p = SwiftUI.Path()
            let pts = road.points.map { t.view($0) }
            p.move(to: pts[0])
            for pt in pts.dropFirst() { p.addLine(to: pt) }

            ctx.stroke(p, with: .color(Palette.roadEdge),
                       style: StrokeStyle(lineWidth: 30 * s, lineCap: .round, lineJoin: .round))
            ctx.stroke(p, with: .color(Palette.roadFill),
                       style: StrokeStyle(lineWidth: 24 * s, lineCap: .round, lineJoin: .round))

            var d = 70.0
            while d < road.totalLength {
                let a = road.point(atDistance: d - 8)
                let b = road.point(atDistance: d + 8)
                let va = t.view(a)
                let vb = t.view(b)
                let ang = atan2(vb.y - va.y, vb.x - va.x)
                var chev = SwiftUI.Path()
                let back: CGFloat = 9 * s
                let spread: CGFloat = 0.55
                chev.move(to: CGPoint(x: vb.x - back * cos(ang - spread), y: vb.y - back * sin(ang - spread)))
                chev.addLine(to: vb)
                chev.addLine(to: CGPoint(x: vb.x - back * cos(ang + spread), y: vb.y - back * sin(ang + spread)))
                ctx.stroke(chev, with: .color(.white.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round, lineJoin: .round))
                d += 140
            }

            let spawn = t.view(road.points[0])
            let exitP = t.view(road.points[road.points.count - 1])
            ctx.fill(
                SwiftUI.Path(ellipseIn: CGRect(x: spawn.x - 13 * s, y: spawn.y - 13 * s,
                                               width: 26 * s, height: 26 * s)),
                with: .color(.red.opacity(0.75))
            )
            ctx.draw(
                Text(session.blueprint.roads.indices.contains(ri) ? session.blueprint.roads[ri].name : "Spawn")
                    .font(.system(size: max(11, 12 * s), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85)),
                at: CGPoint(x: spawn.x + 4, y: spawn.y - 22 * s)
            )
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
    }

    private func drawSlots(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        for (i, slot) in session.level.towerSlots.enumerated() {
            let c = t.view(slot.position)
            let r: CGFloat = 16 * s
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)

            if let (type, lvl) = session.towerType(at: i) {
                let color = Palette.color(forTowerID: type.id)
                if session.selectedSlot == i {
                    let range = CGFloat(type.levels[lvl].range) * s
                    let rangeRect = CGRect(x: c.x - range, y: c.y - range,
                                           width: 2 * range, height: 2 * range)
                    ctx.fill(SwiftUI.Path(ellipseIn: rangeRect), with: .color(color.opacity(0.10)))
                    ctx.stroke(SwiftUI.Path(ellipseIn: rangeRect), with: .color(color.opacity(0.5)), lineWidth: 1.5)
                }
                ctx.fill(SwiftUI.Path(ellipseIn: rect), with: .color(color))
                ctx.stroke(SwiftUI.Path(ellipseIn: rect), with: .color(.white.opacity(0.8)),
                           lineWidth: session.selectedSlot == i ? 3 : 1.5)
                ctx.draw(
                    Text(String(repeating: "I", count: lvl + 1))
                        .font(.system(size: max(9, 11 * s), weight: .heavy))
                        .foregroundStyle(.white),
                    at: c
                )
            } else {
                slotArt.draw(&ctx, at: c, index: i, scale: s, selected: session.selectedSlot == i)
            }
        }
    }

    private func drawFlashes(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        for f in session.flashes {
            let color = Palette.towerColors[
                Emplacement.allCases.first { session.arsenal.type($0).id == session.catalog.towerTypes[f.towerTypeIndex].id } ?? .minutemanPost
            ] ?? .white
            var p = SwiftUI.Path()
            p.move(to: t.view(f.from))
            p.addLine(to: t.view(f.to))
            let fade = max(0, (f.until - session.sim.time) / 0.18)
            ctx.stroke(p, with: .color(color.opacity(0.55 * fade)), lineWidth: 2)
        }
    }

    private func drawEnemies(_ ctx: inout GraphicsContext, _ t: DesignTransform) {
        let s = t.scale
        let sim = session.sim
        for e in sim.enemies where !e.removed {
            let type = session.catalog.enemyTypes[e.typeIndex]
            guard e.pathIndex < sim.level.paths.count else { continue }
            let pos = t.view(sim.level.paths[e.pathIndex].point(atDistance: e.distance))
            let baseR: CGFloat = [7.0, 10.0, 12.5][min(2, max(0, type.stats.livesCost - 1))] * s
            var color = Palette.color(forFoeID: type.id)
            if e.state == .broken { color = color.opacity(0.45) }

            let rect = CGRect(x: pos.x - baseR, y: pos.y - baseR, width: 2 * baseR, height: 2 * baseR)
            ctx.fill(SwiftUI.Path(ellipseIn: rect), with: .color(color))

            switch e.state {
            case .shaken:
                ctx.stroke(SwiftUI.Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                           with: .color(.orange), lineWidth: 2)
            case .broken:
                ctx.stroke(SwiftUI.Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)),
                           with: .color(.white.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            case .steady:
                break
            }
            if e.infected {
                ctx.fill(
                    SwiftUI.Path(ellipseIn: CGRect(x: pos.x - 2.5, y: pos.y - 2.5, width: 5, height: 5)),
                    with: .color(Color(red: 0.5, green: 0.9, blue: 0.3))
                )
            }

            let frac = max(0, min(1, e.hp / type.stats.maxHP))
            if frac < 1 {
                let w = 2.4 * baseR
                let y = rect.minY - 5 * s - 2
                ctx.fill(SwiftUI.Path(CGRect(x: pos.x - w / 2, y: y, width: w, height: 3)),
                         with: .color(.black.opacity(0.55)))
                ctx.fill(SwiftUI.Path(CGRect(x: pos.x - w / 2, y: y, width: w * frac, height: 3)),
                         with: .color(frac > 0.5 ? .green : (frac > 0.25 ? .yellow : .red)))
            }
        }
    }
}
