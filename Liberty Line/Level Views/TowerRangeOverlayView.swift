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
        return Ellipse()
            .fill(Color.green.opacity(isUpgrade ? 0.08 : 0.16))
            .overlay(
                ZStack {
                    Ellipse().stroke(.black.opacity(0.35), lineWidth: 4)
                    Ellipse().stroke(Color.green.opacity(isUpgrade ? 1 : 0.8), style: stroke)
                }
            )
            .frame(width: size.width, height: size.height)
    }
}
