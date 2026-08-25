import SwiftUI

/// Light-green range ring under a radial menu: shown while a build choice
/// is armed awaiting its confirming second tap, and while a placed
/// tower's upgrade menu is open. Attack range for shooting towers, rally
/// radius for melee. Never hit-tested, so it cannot swallow the
/// confirming or cancelling tap. The ellipse geometry comes from
/// MapRangeShape; this view only paints it.
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
