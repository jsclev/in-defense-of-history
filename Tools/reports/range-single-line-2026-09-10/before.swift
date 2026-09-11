import SwiftUI

struct TowerRangeOverlayView: View {
    let center: CGPoint
    let size: CGSize
    let upgradeSize: CGSize?

    init(center: CGPoint, range: CGFloat, upgradeRange: CGFloat? = nil,
         runtimeCanvas: RuntimeCanvas) {
        self.center = center
        self.size = TowerRangeOverlay.size(range: range, runtimeCanvas: runtimeCanvas)
        // Equal ranges share a boundary; avoid darkening it with a duplicate.
        self.upgradeSize = upgradeRange.flatMap { upgraded in
            upgraded == range ? nil : TowerRangeOverlay.size(range: upgraded, runtimeCanvas: runtimeCanvas)
        }
    }

    var body: some View {
        ZStack {
            if let upgradeSize {
                ring(size: upgradeSize, isUpgrade: true)
            }
            ring(size: size, isUpgrade: false)
        }
        .position(center)
        .allowsHitTesting(false)
    }

    private func ring(size: CGSize, isUpgrade: Bool) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, dash: isUpgrade ? [6, 4] : [])
        let edgeOpacity = isUpgrade ? 0.4 : 0.7
        // Friendly reach needs to separate from both yellow-green grass and
        // jade shadows. Keep the bright boundary green and its contrast inside.
        let green = Color(.sRGB, red: 127 / 255, green: 1, blue: 173 / 255, opacity: 1)
        let separator = Color(.sRGB, red: 16 / 255, green: 56 / 255, blue: 43 / 255, opacity: 1)
        let boundary = Ellipse().inset(by: stroke.lineWidth / 2)
        return Ellipse()
            .fill(
                EllipticalGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.92),
                    .init(color: green.opacity(edgeOpacity * 0.25), location: 0.96),
                    .init(color: green.opacity(edgeOpacity), location: 1)
                ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            )
            .overlay(
                ZStack {
                    // Both strokes follow the same path so upgrade dashes align.
                    boundary.stroke(separator, style: StrokeStyle(lineWidth: 5, dash: stroke.dash))
                    boundary.stroke(green, style: stroke)
                }
                .clipShape(Ellipse())
            )
            .frame(width: size.width, height: size.height)
    }
}
