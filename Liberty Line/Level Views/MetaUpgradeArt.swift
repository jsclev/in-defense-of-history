import SwiftUI
import UIKit

enum CouncilPalette {
    static let gold = Color(red: 0.98, green: 0.76, blue: 0.32)
    static let cream = Color(red: 1, green: 0.94, blue: 0.79)
    static let ink = Color(red: 0.035, green: 0.085, blue: 0.13)
}

/// Every upgrade is authored in SQLite and resolves to exactly one catalog painting.
struct MetaUpgradeIcon: View {
    let upgrade: MetaUpgradeDefinition
    var body: some View {
        Image(uiImage: Self.requiredImage(for: upgrade))
            .resizable().interpolation(.high).scaledToFit()
    }
    static func requiredImage(for upgrade: MetaUpgradeDefinition) -> UIImage {
        guard let image = UIImage(named: upgrade.iconAssetName) else {
            fatalError("meta_upgrade[\(upgrade.id.rawValue)].icon_name: missing required image asset '\(upgrade.iconAssetName)'")
        }
        return image
    }
}

/// Fixed painted corners keep the frame's brushwork intact on both slim tracks and wide panels.
struct CouncilPanel: View {
    var body: some View {
        Image(uiImage: CampaignButtonArt.requiredImage(named: "meta_council_panel"))
            .resizable(capInsets: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18),
                       resizingMode: .stretch)
            .interpolation(.high)
            .accessibilityHidden(true)
    }
}

struct CouncilNodeArt: View {
    let upgrade: MetaUpgradeDefinition
    let learned: Bool
    let locked: Bool
    let focused: Bool
    var body: some View {
        MetaUpgradeIcon(upgrade: upgrade)
            .saturation(learned ? 1 : 0.5)
            .brightness(learned ? 0 : -0.06)
            .frame(width: 44, height: 44)
            .overlay {
                if focused {
                    CouncilCutCorner().stroke(CouncilPalette.cream, lineWidth: 2.5)
                        .padding(-2)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if learned || locked {
                    CouncilGlyph(kind: learned ? .check : .lock)
                        .padding(3).frame(width: 18, height: 18)
                        .background(learned ? Color(red: 0.08, green: 0.32, blue: 0.25) : CouncilPalette.ink,
                                    in: CouncilCutCorner())
                        .overlay(CouncilCutCorner().stroke(CouncilPalette.gold, lineWidth: 1))
                        .offset(x: 4, y: 3)
                }
            }
            .frame(width: 48, height: 44)
            .accessibilityHidden(true)
    }
}

struct CouncilCutCorner: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        let cut = min(rect.width, rect.height) * 0.14
        return SwiftUI.Path { path in
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLines([
                CGPoint(x: rect.maxX - cut, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + cut),
                CGPoint(x: rect.maxX, y: rect.maxY - cut), CGPoint(x: rect.maxX - cut, y: rect.maxY),
                CGPoint(x: rect.minX + cut, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - cut),
                CGPoint(x: rect.minX, y: rect.minY + cut)])
            path.closeSubpath()
        }
    }
}

/// Broad, faceted control marks. Their silhouette carries the action at 12–24 points.
struct CouncilGlyph: View {
    enum Kind { case star, check, lock, reset, flag, close, link }
    let kind: Kind
    var body: some View {
        Canvas { context, size in
            func polygon(_ points: [(Double, Double)]) -> SwiftUI.Path {
                SwiftUI.Path { path in
                    for (index, point) in points.enumerated() {
                        let p = CGPoint(x: point.0 * size.width, y: point.1 * size.height)
                        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    path.closeSubpath()
                }
            }
            var shape = SwiftUI.Path()
            switch kind {
            case .star:
                shape = polygon((0..<10).map { index in
                    let angle = Double(index) * .pi / 5 - .pi / 2
                    let radius = index.isMultiple(of: 2) ? 0.49 : 0.23
                    return (0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius)
                })
            case .check:
                shape = polygon([(0.03,0.51),(0.21,0.35),(0.42,0.56),(0.82,0.08),
                                 (0.99,0.24),(0.44,0.91)])
            case .lock:
                shape.addRoundedRect(in: CGRect(x: size.width * 0.12, y: size.height * 0.43,
                    width: size.width * 0.76, height: size.height * 0.54), cornerSize: CGSize(width: 1, height: 1))
                var arch = SwiftUI.Path()
                arch.move(to: CGPoint(x: size.width * 0.28, y: size.height * 0.48))
                arch.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.28))
                arch.addQuadCurve(to: CGPoint(x: size.width * 0.72, y: size.height * 0.28),
                                 control: CGPoint(x: size.width * 0.5, y: -size.height * 0.13))
                arch.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.48))
                context.stroke(arch, with: .color(CouncilPalette.gold), lineWidth: size.width * 0.16)
            case .reset:
                var arc = SwiftUI.Path()
                arc.addArc(center: CGPoint(x: size.width * 0.51, y: size.height * 0.53),
                    radius: size.width * 0.33, startAngle: .degrees(-85), endAngle: .degrees(210), clockwise: false)
                context.stroke(arc, with: .color(CouncilPalette.gold), style: StrokeStyle(lineWidth: size.width * 0.17, lineCap: .square))
                shape = polygon([(0.54,0.01),(0.16,0.17),(0.49,0.39)])
            case .flag:
                shape = polygon([(0.1,0.04),(0.24,0.04),(0.24,0.96),(0.1,0.96)])
                shape.addPath(polygon([(0.23,0.08),(0.58,0.08),(0.68,0.17),(0.95,0.17),
                                      (0.84,0.4),(0.95,0.62),(0.6,0.62),(0.49,0.51),(0.23,0.51)]))
            case .close:
                shape = polygon([(0.13,0.03),(0.5,0.37),(0.87,0.03),(0.99,0.17),(0.64,0.5),
                                 (0.99,0.83),(0.86,0.98),(0.5,0.63),(0.13,0.98),(0.01,0.83),
                                 (0.36,0.5),(0.01,0.17)])
            case .link:
                shape = polygon([(0.1,0.77),(0.62,0.25),(0.29,0.25),(0.29,0.06),
                                 (0.95,0.06),(0.95,0.71),(0.75,0.71),(0.75,0.39),(0.25,0.91)])
            }
            context.fill(shape, with: .linearGradient(
                Gradient(colors: [CouncilPalette.cream, CouncilPalette.gold, Color(red: 0.76, green: 0.39, blue: 0.1)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        }
        .accessibilityHidden(true)
    }
}

struct CouncilButtonLabel: View {
    let title: String
    let glyph: CouncilGlyph.Kind
    var body: some View {
        HStack(spacing: 7) {
            CouncilGlyph(kind: glyph).frame(width: 19, height: 19)
            Text(title).font(.custom("Baskerville-Bold", size: 15))
        }
        .foregroundStyle(CouncilPalette.cream)
        .padding(.horizontal, 15).frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .background(CouncilPanel())
        .contentShape(Rectangle())
    }
}
