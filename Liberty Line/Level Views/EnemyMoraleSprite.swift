import SwiftUI

/// A compact side cue, subordinate to HP and scaled with the troop.
struct EnemyMoraleSprite: View {
    let assetName: String
    let morale: EnemyMorale
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scale: CGFloat { height / MapSpriteSizing.walker.minimum }
    private var flinch: Double {
        guard !reduceMotion else { return 0 }
        return sin(min(1, morale.impactAge / 0.33) * .pi)
    }

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable().scaledToFit().frame(height: height)
                .rotationEffect(.degrees(flinch * 9 * morale.flinchDirection), anchor: .bottom)
                .offset(x: flinch * 2 * scale * morale.flinchDirection,
                        y: flinch * scale)
            if morale.isVisible {
                EnemyMoraleCrescent(morale: morale, reduceMotion: reduceMotion)
                    .frame(width: 34 * scale, height: 34 * scale)
                    .offset(x: -scale, y: height / 2 - 16 * scale)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

private struct EnemyMoraleCrescent: View {
    let morale: EnemyMorale
    let reduceMotion: Bool
    private static let cyan = Color(red: 54 / 255.0, green: 218 / 255.0, blue: 250 / 255.0)
    private static let navy = Color(red: 16 / 255.0, green: 36 / 255.0, blue: 56 / 255.0)

    var body: some View {
        Canvas { context, size in
            let scale = size.height / 34
            context.translateBy(x: 2 * scale, y: 2 * scale)
            // The fixed dark track shows capacity; one solid blue fill shows morale remaining.
            // Drain from the top toward the fixed bottom. No white flash, gaps, or fragments.
            let fraction = reduceMotion ? morale.remainingFraction : morale.displayedFraction
            context.stroke(arc(125, 235, scale: scale), with: .color(Self.navy),
                           style: StrokeStyle(lineWidth: 3.6 * scale, lineCap: .round))
            if fraction > 0 {
                context.stroke(arc(125, 125 + 110 * fraction, scale: scale), with: .color(Self.cyan),
                               style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round))
            }
        }
    }

    private func arc(_ start: Double, _ end: Double, scale: CGFloat) -> SwiftUI.Path {
        SwiftUI.Path { path in
            path.move(to: CGPoint(x: (11 + 10 * cos(start * .pi / 180)) * scale,
                                 y: (15 + 10 * sin(start * .pi / 180)) * scale))
            path.addArc(center: CGPoint(x: 11 * scale, y: 15 * scale), radius: 10 * scale,
                        startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        }
    }
}

/// Shared by gameplay and the native art review so the HP/morale comparison is exact.
struct UnitHealthBar: View {
    let fraction: CGFloat
    let width: CGFloat
    let height: CGFloat
    var fill: Color = .green

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.red)
            Capsule().fill(fill)
                .frame(width: width * fraction, height: height)
        }
        .frame(width: width, height: height)
        .background {
            Capsule().stroke(Color(red: 16 / 255.0, green: 36 / 255.0, blue: 56 / 255.0),
                             lineWidth: height / MapSpriteSizing.healthBarHeight.minimum)
        }
    }
}

struct ArtilleryImpactView: View {
    let age: Double
    let radius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let t = min(1, age / 0.78)
            guard !reduceMotion, t < 1 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let spread = radius * (1 - pow(1 - t, 3))
            let ring = CGRect(x: center.x - spread, y: center.y - spread * 0.44,
                              width: spread * 2, height: spread * 0.88)
            context.opacity = 1 - t
            context.stroke(SwiftUI.Path(ellipseIn: ring), with: .color(Color(red: 0.95, green: 0.83, blue: 0.57)),
                           lineWidth: 1.5)
            for i in 0..<7 {
                let angle = Double(i) * .pi * 2 / 7
                let puff = radius * (0.10 + 0.14 * t)
                let x = center.x + cos(angle) * spread * 0.28
                let y = center.y + sin(angle) * spread * 0.14 - t * radius * 0.1
                context.fill(SwiftUI.Path(ellipseIn: CGRect(x: x - puff, y: y - puff * 0.7,
                    width: puff * 2, height: puff * 1.4)),
                    with: .color(Color(red: 0.88, green: 0.77, blue: 0.59).opacity(0.45)))
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
    }
}
