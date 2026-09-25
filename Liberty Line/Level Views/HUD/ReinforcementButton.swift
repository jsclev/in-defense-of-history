import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false
    var isActivated = false

    var body: some View {
        Button(action: action) {
            ZStack {
                PaintedHUDButtonFrame(buttonSize: buttonSize)
                Image("action_icon_call_reinforcements")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize.width * HudSizing.paintedButtonIconFraction,
                           height: buttonSize.height * HudSizing.paintedButtonIconFraction)
                if !cooldown.isReady {
                    cooldownOverlay
                }
            }
            .frame(width: buttonSize.width, height: buttonSize.height)
            .hudActivationHighlight(isSelected || isActivated, side: buttonSize.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(HUDButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel("Call reinforcements")
        .accessibilityIdentifier("call-reinforcements")
        .accessibilityValue(isSelected ? "Selected" : cooldown.isReady ? "Ready" : "\(cooldown.displaySeconds) seconds remaining")
    }

    private var cooldownOverlay: some View {
        ReinforcementCooldownOverlay(buttonSize: buttonSize, remainingFraction: cooldown.remainingFraction)
    }
}
