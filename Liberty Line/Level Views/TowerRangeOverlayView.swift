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
        // Blue-violet separates friendly reach from the dominant yellow-green
        // terrain. Use one hue and one border, with only an inward alpha fade.
        let rangeColor = Color(.sRGB, red: 88 / 255, green: 66 / 255, blue: 199 / 255, opacity: 1)
        // Keep the blend short even on large maps: at most six vertical points.
        let fadeFraction = min(0.10, 6 / max(size.height / 2, 1))
        return Ellipse()
            .fill(
                EllipticalGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: rangeColor.opacity(0), location: 1 - fadeFraction),
                    .init(color: rangeColor.opacity(edgeOpacity * 0.35), location: 1 - fadeFraction / 2),
                    .init(color: rangeColor.opacity(edgeOpacity), location: 1)
                ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            )
            .overlay(
                Ellipse().strokeBorder(rangeColor, style: stroke)
            )
            .frame(width: size.width, height: size.height)
    }
}
