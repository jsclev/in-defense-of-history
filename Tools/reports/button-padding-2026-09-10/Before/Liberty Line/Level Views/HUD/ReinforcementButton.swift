import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image("action_icon_call_reinforcements")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize.width * 0.75, height: buttonSize.height * 0.75)
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
