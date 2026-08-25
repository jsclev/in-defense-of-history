import SwiftUI

struct TowerRangeOverlayView: View {
    let center: CGPoint
    let size: CGSize

    init(center: CGPoint, range: CGFloat, pointsPerMapUnit: CGFloat) {
        self.center = center
        self.size = TowerRangeOverlay.size(range: range, pointsPerMapUnit: pointsPerMapUnit)
    }

    var body: some View {
        Ellipse()
            .fill(Color.green.opacity(0.16))
            .overlay(
                ZStack {
                    Ellipse().stroke(.black.opacity(0.35), lineWidth: 4)
                    Ellipse().stroke(Color.green.opacity(0.8), lineWidth: 2)
                }
            )
            .frame(width: size.width, height: size.height)
            .position(center)
            .allowsHitTesting(false)
    }
}
