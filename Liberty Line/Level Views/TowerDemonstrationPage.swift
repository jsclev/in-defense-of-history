import SwiftUI

@available(iOS 26.0, *)
struct TowerDemonstrationPage: View {
    let demonstration: TowerDemonstration
    let tier: DesignArsenal.Tier
    let kind: TowerKind
    let isActive: Bool
    var reviewElapsed: Double? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var began = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60,
                                    paused: !isActive || scenePhase != .active)) { timeline in
            TowerDemonstrationScene(demo: demonstration,
                elapsed: reviewElapsed ?? timeline.date.timeIntervalSince(began))
        }
        .accessibilityLabel("\(tier.details.name). \(tier.details.description) Animated demonstration. Repeats automatically.")
        .accessibilityIdentifier("tower-demonstration-animation")
        .clipped()
        .onChange(of: isActive) { _, active in if active { began = Date() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { began = Date() } }
    }
}

/// Pure presentation of shared-engine snapshots at normal game speed.
@available(iOS 26.0, *)
struct TowerDemonstrationScene: View {
    let demo: TowerDemonstration
    let elapsed: Double
    private let gold = Color(red: 1, green: 0.77, blue: 0.32)
    private let green = Color(red: 0.45, green: 0.95, blue: 0.43)
    private var index: Int { demo.frameIndex(at: elapsed) }
    private var frame: TowerDemonstration.Frame { demo.frames[index] }
    private var phase: Double { max(0, elapsed).truncatingRemainder(dividingBy: demo.loopDuration) }

    var body: some View {
        GeometryReader { geometry in
            let projection = DemonstrationProjection(bounds: demo.bounds, size: geometry.size, virtualCanvas: demo.virtualCanvas)
            ZStack {
                Canvas { context, size in
                    drawGround(context, size: size, projection: projection)
                    drawTowers(context, projection: projection)
                }
                ForEach(frame.towers) { tower in
                    if let charge = tower.demolitionCharge, let site = charge.position,
                       charge.isReady {
                        DemolitionGroundChargeSymbol(lightIsOn:
                            phase.truncatingRemainder(dividingBy: DemolitionGroundChargeSymbol.blinkPeriod)
                                < DemolitionGroundChargeSymbol.lightOnDuration)
                            .position(projection.point(site))
                    }
                }
                ForEach(frame.impacts) { impact in
                    Group {
                        if impact.isDemolition {
                            DemolitionBlastView(age: impact.age, radius: impact.radius * projection.scale)
                        } else {
                            ArtilleryImpactView(age: impact.age, radius: impact.radius * projection.scale)
                        }
                    }
                    .position(projection.point(impact.position))
                }
                GroundTroopLayer(presentation: frame.presentation, interpolation: demo.interpolation(at: elapsed),
                                 militia: frame.soldiers, sprites: projection.sprites, projection: projection.projection)
                ProjectileLayer(presentation: frame.presentation, interpolation: demo.interpolation(at: elapsed),
                                sprites: projection.sprites, projection: projection.projection)
                Canvas { context, _ in drawSupport(context, projection: projection) }
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private func drawGround(_ context: GraphicsContext, size: CGSize, projection p: DemonstrationProjection) {
        context.fill(SwiftUI.Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.17, green: 0.29, blue: 0.23)))
        for (x, y, w, h, opacity) in [(0.05, 0.16, 0.65, 0.42, 0.12),
                                      (0.58, 0.63, 0.65, 0.52, 0.16),
                                      (-0.15, 0.80, 0.65, 0.55, 0.14)] {
            let patch = CGRect(x: x * size.width, y: y * size.height, width: w * size.width, height: h * size.height)
            context.fill(SwiftUI.Path(ellipseIn: patch), with: .color(Color(red: 0.57, green: 0.65, blue: 0.31).opacity(opacity)))
        }
        var road = SwiftUI.Path()
        for (i, point) in demo.road.enumerated() {
            if i == 0 { road.move(to: p.point(point)) } else { road.addLine(to: p.point(point)) }
        }
        let width = demo.roadWidth * p.scale
        for (strokeWidth, color) in [(width + 5, Color(red: 0.26, green: 0.22, blue: 0.13)),
                                    (width, Color(red: 0.69, green: 0.57, blue: 0.36)),
                                    (width * 0.65, Color(red: 0.84, green: 0.72, blue: 0.48))] {
            context.stroke(road, with: .color(color),
                           style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        let origin = p.point(demo.tower.position)
        let reach: TowerAttackRange
        if let melee = demo.tower.tuning.meleeUnit {
            reach = TowerAttackRange(melee.rallyPointRadius,
                                    verticalFraction: demo.tower.tuning.combatRules.rangeVerticalFraction)
        } else { reach = demo.tower.tuning.attackRange }
        if reach.radius > 0 && !demo.usesEncounterFraming {
            let size = reach.size
            let boundary = SwiftUI.Path(ellipseIn: CGRect(x: origin.x - size.width * p.scale / 2,
                y: origin.y - size.height * p.scale / 2, width: size.width * p.scale, height: size.height * p.scale))
            let color = demo.tower.tuning.support.hasAura ? green : Color(red: 0.60, green: 0.69, blue: 1)
            context.fill(boundary, with: .color(color.opacity(0.1)))
            context.stroke(boundary, with: .color(color.opacity(0.8)), lineWidth: 1.5)
        }
        for obstacle in frame.obstacles {
            var layer = context
            layer.clip(to: road.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)))
            let site = p.point(obstacle.position)
            layer.translateBy(x: site.x, y: site.y)
            layer.rotate(by: .radians(-obstacle.heading))
            let size = obstacle.size
            layer.draw(Image(uiImage: DemonstrationArtwork.image("engineer_rough_ground")),
                in: CGRect(x: -size.width * p.scale / 2, y: -size.height * p.scale / 2,
                           width: size.width * p.scale, height: size.height * p.scale))
        }
        for tower in frame.towers {
            if let charge = tower.demolitionCharge, let site = charge.position, charge.isReady {
                let center = p.point(site), radius = demo.tower.tuning.aoeRadius * p.scale
                let area = SwiftUI.Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2))
                context.fill(area, with: .color(gold.opacity(0.1)))
                context.stroke(area, with: .color(gold.opacity(0.8)), lineWidth: 1.5)
            }
        }
        if !demo.usesEncounterFraming {
            let entrance = p.point(demo.road[0])
            drawArrow(context, from: CGPoint(x: entrance.x - 14, y: entrance.y + 10),
                      to: CGPoint(x: entrance.x + 5, y: entrance.y + 10), color: .white.opacity(0.85))
        }
        if phase < 1.65 {
            for (_, rally) in frame.rallies {
                let site = p.point(rally)
                symbol("flag.fill", context: context, at: CGPoint(x: site.x, y: site.y - 13), size: 20, color: gold)
            }
            if let site = frame.obstacles.first?.position ?? frame.towers.first?.demolitionCharge?.position {
                let target = p.point(site)
                symbol("hand.point.up.fill", context: context,
                       at: CGPoint(x: target.x + 12, y: target.y + 10), size: 21, color: gold)
            }
        }
    }

    private func drawTowers(_ context: GraphicsContext, projection p: DemonstrationProjection) {
        for tower in frame.towers {
            let origin = p.point(tower.position)
            let asset = DemonstrationArtwork.tower(tower)
            var height = p.towerHeight
            if tower.demolitionCharge?.isReadyForPlacement == true {
                height *= 1 + DemolitionTowerView.pulseScaleAmplitude * DemolitionTowerView.readinessPulse(at: phase)
            }
            sprite(asset, context: context, at: origin, height: height)
            if let charge = tower.demolitionCharge, !charge.isReady {
                preparationBar(context, origin: CGPoint(x: origin.x, y: origin.y + 6),
                    width: 32, height: 4, fraction: charge.progress, color: green)
            }
            let previous = demo.frames[max(0, index - 7)].shotsBySlot[tower.slotIndex, default: 0]
            if frame.shotsBySlot[tower.slotIndex, default: 0] > previous {
                let muzzle = CGPoint(x: origin.x + height * 0.12, y: origin.y - height * 0.52)
                context.fill(SwiftUI.Path(ellipseIn: CGRect(x: muzzle.x - 5, y: muzzle.y - 4, width: 10, height: 8)),
                             with: .color(Color(red: 1, green: 0.88, blue: 0.5)))
            }
            if tower.slotIndex != demo.tower.slot && demo.lesson == .attackSupport {
                symbol("bolt.fill", context: context, at: CGPoint(x: origin.x, y: origin.y + 12), size: 18, color: green)
            }
        }
    }

    private func drawSupport(_ context: GraphicsContext, projection p: DemonstrationProjection) {
        let source = p.point(demo.tower.position)
        if frame.waveIncome > 0 {
            // The amount is the engine's actual wave-call receipt, never a
            // guessed reward. Keep it beside the supply tower that earned it.
            let receipt = CGPoint(x: source.x - 75, y: source.y - 17)
            let badge = CGRect(x: receipt.x - 34, y: receipt.y - 12, width: 68, height: 24)
            context.fill(SwiftUI.Path(roundedRect: badge, cornerRadius: 12), with: .color(.black.opacity(0.78)))
            symbol("dollarsign.circle.fill", context: context,
                   at: CGPoint(x: receipt.x - 21, y: receipt.y), size: 18, color: gold)
            context.draw(Text("+\(frame.waveIncome)").font(.system(size: 15, weight: .bold)).foregroundStyle(gold),
                         at: CGPoint(x: receipt.x + 8, y: receipt.y))
        }
        if demo.lesson == .attackSupport, let helper = demo.supportingTowers.first {
            let target = p.point(helper.position)
            let from = CGPoint(x: source.x + 27, y: source.y - 15)
            let to = CGPoint(x: target.x - 26, y: target.y - 15)
            drawArrow(context, from: from, to: to, color: green.opacity(0.8))
            let fraction = phase.truncatingRemainder(dividingBy: 0.75) / 0.75
            let point = CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
            context.fill(SwiftUI.Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(green))
        }
    }

    private func sprite(_ image: UIImage, context: GraphicsContext, at point: CGPoint,
                        height: CGFloat) {
        let width = height * image.size.width / image.size.height
        var layer = context
        layer.translateBy(x: point.x, y: point.y)
        layer.draw(Image(uiImage: image), in: CGRect(x: -width / 2, y: -height, width: width, height: height))
    }

    private func preparationBar(_ context: GraphicsContext, origin: CGPoint, width: CGFloat, height: CGFloat,
                     fraction: Double, color: Color) {
        let rect = CGRect(x: origin.x - width / 2, y: origin.y, width: width, height: height)
        context.fill(SwiftUI.Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: 2), with: .color(.black.opacity(0.85)))
        context.fill(SwiftUI.Path(roundedRect: CGRect(x: rect.minX, y: rect.minY,
            width: width * min(1, max(0, fraction)), height: height), cornerRadius: 1), with: .color(color))
    }

    private func symbol(_ name: String, context: GraphicsContext, at point: CGPoint, size: CGFloat, color: Color) {
        let configuration = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        guard let artwork = UIImage(systemName: name, withConfiguration: configuration) else {
            fatalError("Missing demonstration symbol: \(name)")
        }
        var image = context.resolve(Image(uiImage: artwork))
        image.shading = .color(color)
        context.draw(image, at: point)
    }

    private func drawArrow(_ context: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
        var line = SwiftUI.Path(); line.move(to: start); line.addLine(to: end)
        let heading = atan2(end.y - start.y, end.x - start.x)
        for turn in [-0.65, 0.65] {
            line.move(to: end)
            line.addLine(to: CGPoint(x: end.x - cos(heading + turn) * 7, y: end.y - sin(heading + turn) * 7))
        }
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
    }
}

/// Canonical assets only, decoded once. A missing image or malformed atlas is
/// a content error, never permission to show a different tower illustration.
@MainActor enum DemonstrationArtwork {
    static var images: [String: UIImage] = [:]

    static func image(_ name: String) -> UIImage {
        if let image = images[name] { return image }
        guard let image = UIImage(named: name) else { fatalError("Missing canonical demonstration artwork: \(name)") }
        images[name] = image
        return image
    }

    static func tower(_ tower: PlacedTower) -> UIImage {
        self.tower(kind: tower.kind, level: tower.level, branch: tower.branch, facing: tower.artilleryFacing)
    }

    static func tower(kind: TowerKind, level: Int, branch: Int, facing: ArtilleryFacing) -> UIImage {
        if let sheetName = kind.directionalAssetName(atLevel: level, branch: branch) {
            let key = "\(sheetName):\(facing.frameIndex)"
            if let cached = images[key] { return cached }
            let sheet = image(sheetName)
            guard let source = sheet.cgImage, source.width % ArtilleryFacing.columns == 0,
                  source.height % ArtilleryFacing.rows == 0,
                  let crop = source.cropping(to: facing.frameRect(
                    sheetSize: CGSize(width: source.width, height: source.height))) else {
                fatalError("Malformed canonical demonstration atlas: \(sheetName)")
            }
            let frame = UIImage(cgImage: crop, scale: sheet.scale, orientation: .up)
            images[key] = frame
            return frame
        }
        guard let name = kind.assetName(atLevel: level, branch: branch) else {
            fatalError("Missing demonstration tower asset identity")
        }
        return image(name)
    }
}
