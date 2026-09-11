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
        return Ellipse()
            .fill(
                EllipticalGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.92),
                    .init(color: .green.opacity(edgeOpacity * 0.25), location: 0.96),
                    .init(color: .green.opacity(edgeOpacity), location: 1)
                ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            )
            .overlay(
                Ellipse().strokeBorder(Color.green.opacity(0.95), style: stroke)
            )
            .frame(width: size.width, height: size.height)
    }
}
