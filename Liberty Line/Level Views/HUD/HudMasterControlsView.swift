import SwiftUI

@available(iOS 26.0, *)
struct HudMasterControlsView: View {
    private let layout: MasterControlsLayout
    private let onSpeedUp: () -> Void
    private let onExit: () -> Void

    public init(runtimeCanvas: RuntimeCanvas,
                onSpeedUp: @escaping () -> Void,
                onExit: @escaping () -> Void) {
        self.onSpeedUp = onSpeedUp
        self.onExit = onExit
        self.layout = MasterControlsLayout(runtimeCanvas: runtimeCanvas)
    }

    var body: some View {
        HStack(spacing: layout.buttonSpacing) {
            PaintedMasterControlButton(iconName: "hud_speed_up_framed", label: "Speed up",
                                       buttonSize: layout.buttonSize, action: onSpeedUp)
            PaintedMasterControlButton(iconName: "hud_back_to_main_framed", label: "Back to main",
                                       buttonSize: layout.buttonSize, action: onExit)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}

/// The emblem, blue clearance and rim are painted together, like the hero HUD art.
struct PaintedMasterControlButton: View {
    let iconName: String
    let label: String
    let buttonSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(iconName)
                .resizable()
                .interpolation(.high)
                .frame(width: buttonSize, height: buttonSize)
                .clipShape(PaintedMasterControlOutline())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Remove only the generated RGB exterior around the chamfered metal brackets.
/// Coordinates refer to the normalized visible rim, not the source canvas.
private struct PaintedMasterControlOutline: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.060, y: 0.003), CGPoint(x: 0.143, y: 0.003),
            CGPoint(x: 0.157, y: 0.015), CGPoint(x: 0.843, y: 0.015),
            CGPoint(x: 0.857, y: 0.003), CGPoint(x: 0.940, y: 0.003),
            CGPoint(x: 0.997, y: 0.061), CGPoint(x: 0.997, y: 0.155),
            CGPoint(x: 0.984, y: 0.174), CGPoint(x: 0.984, y: 0.814),
            CGPoint(x: 0.997, y: 0.833), CGPoint(x: 0.997, y: 0.940),
            CGPoint(x: 0.940, y: 0.997), CGPoint(x: 0.857, y: 0.997),
            CGPoint(x: 0.843, y: 0.984), CGPoint(x: 0.157, y: 0.984),
            CGPoint(x: 0.143, y: 0.997), CGPoint(x: 0.060, y: 0.997),
            CGPoint(x: 0.003, y: 0.940), CGPoint(x: 0.003, y: 0.833),
            CGPoint(x: 0.016, y: 0.814), CGPoint(x: 0.016, y: 0.174),
            CGPoint(x: 0.003, y: 0.155), CGPoint(x: 0.003, y: 0.061)
        ]
        var path = SwiftUI.Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width,
                                          y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}
