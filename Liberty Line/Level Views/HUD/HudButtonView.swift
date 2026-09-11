import SwiftUI

/// Fits the painted blue rim, rather than its transparent source canvas, to a
/// HUD button. Shared by portrait and reinforcement buttons so their sizes match.
struct PaintedHUDButtonFrame: View {
    let buttonSize: CGSize

    // Painted rim bounds in the 384 × 384 @3x export, excluding faint stray pixels.
    private static let frameRim = CGRect(x: 14.0 / 384, y: 15.0 / 384,
                                        width: 357.0 / 384, height: 348.0 / 384)

    private var frameSize: CGSize {
        CGSize(width: buttonSize.width / Self.frameRim.width,
               height: buttonSize.height / Self.frameRim.height)
    }

    var body: some View {
        Image("hud_misc_sack_blue_frame")
            .resizable()
            .interpolation(.high)
            .frame(width: frameSize.width, height: frameSize.height)
            .offset(x: (0.5 - Self.frameRim.midX) * frameSize.width,
                    y: (0.5 - Self.frameRim.midY) * frameSize.height)
    }
}

struct HudButtonView: View {
    private let iconName: String
    private let buttonSize: CGFloat
    private let iconScale: CGFloat
    private let frameName: String
    private let action: () -> Void
    
    public init(iconName: String, buttonSize: CGFloat, iconScale: CGFloat = HudSizing.paintedButtonIconFraction,
                frameName: String = "tower_menu_square_frame",
                action: @escaping () -> Void) {
        self.iconName = iconName
        self.buttonSize = buttonSize
        self.iconScale = iconScale
        self.frameName = frameName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(frameName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * iconScale, height: buttonSize * iconScale)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
