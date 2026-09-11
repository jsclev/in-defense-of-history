import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false

    // The blue frame has transparent source margins. Fit its painted rim to
    // the HUD button bounds, matching the neighboring hero frames. These are
    // the rim bounds in the 384 × 384 @3x export, excluding faint stray pixels.
    private static let frameRim = CGRect(x: 14.0 / 384, y: 15.0 / 384,
                                        width: 357.0 / 384, height: 348.0 / 384)

    private var frameSize: CGSize {
        CGSize(width: buttonSize.width / Self.frameRim.width,
               height: buttonSize.height / Self.frameRim.height)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("hud_misc_sack_blue_frame")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: frameSize.width, height: frameSize.height)
                    .offset(x: (0.5 - Self.frameRim.midX) * frameSize.width,
                            y: (0.5 - Self.frameRim.midY) * frameSize.height)
                Image("action_icon_call_reinforcements")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize.width * HudSizing.paintedButtonIconFraction,
                           height: buttonSize.height * HudSizing.paintedButtonIconFraction)
                    .grayscale(cooldown.isReady ? 0 : 1)
                if !cooldown.isReady {
                    cooldownOverlay
                }
            }
            .frame(width: buttonSize.width, height: buttonSize.height)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize.width * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize.width * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ReinforcementButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel("Call reinforcements")
        .accessibilityValue(cooldown.isReady ? "Ready" : "\(cooldown.displaySeconds) seconds remaining")
    }

    private var cooldownOverlay: some View {
        // Keep the colored frame exposed. All progress stays inside a fixed
        // image box, so changing the countdown cannot affect menu/map layout.
        let width = buttonSize.width * 0.78
        let height = buttonSize.height * 0.78
        let remainingHeight = height * cooldown.remainingFraction
        let boundary = height - remainingHeight
        let labelHeight = buttonSize.height * 0.34
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55)
                .frame(width: width, height: remainingHeight)
                .offset(y: boundary)
            Text("\(cooldown.displaySeconds)")
                .font(.system(size: max(12, buttonSize.height * 0.26), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, buttonSize.width * 0.06)
                .frame(height: labelHeight)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: buttonSize.width * 0.06))
                .position(x: width / 2,
                          y: labelHeight / 2 + (height - labelHeight) * (1 - cooldown.remainingFraction))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: buttonSize.width * 0.04))
        .allowsHitTesting(false)
    }
}

private struct ReinforcementButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Availability changes the icon/overlay only, preserving the frame.
        configuration.label
    }
}
