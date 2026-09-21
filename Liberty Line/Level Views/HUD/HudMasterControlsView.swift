import SwiftUI

@available(iOS 26.0, *)
struct HudMasterControlsView: View {
    private let layout: MasterControlsLayout
    private let onSpeedUp: () -> Void
    private let onPause: () -> Void

    public init(runtimeCanvas: RuntimeCanvas,
                location: HudLocation = .northEast,
                onSpeedUp: @escaping () -> Void,
                onPause: @escaping () -> Void) {
        self.onSpeedUp = onSpeedUp
        self.onPause = onPause
        self.layout = MasterControlsLayout(runtimeCanvas: runtimeCanvas, location: location)
    }

    var body: some View {
        HStack(spacing: layout.buttonSpacing) {
            PaintedMasterControlButton(iconName: "speed_up_icon_glyph", label: "Speed up",
                                       buttonSize: layout.buttonSize, action: onSpeedUp)
            PaintedMasterControlButton(iconName: "pause_icon_glyph", label: "Pause level",
                                       buttonSize: layout.buttonSize, action: onPause)
                .accessibilityIdentifier("pause-level")
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}

/// Icon canvases include their own clearance from the shared painted rim.
struct PaintedMasterControlButton: View {
    let iconName: String
    let label: String
    let buttonSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                PaintedHUDButtonFrame(buttonSize: CGSize(width: buttonSize, height: buttonSize))
                Image(iconName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
