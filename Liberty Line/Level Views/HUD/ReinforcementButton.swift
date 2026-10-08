import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false
    var isActivated = false

    var body: some View {
        Button {
            // Keep tracking a finger that lands just before the cooldown ends.
            // A disabled Button discards that press even if it is ready when
            // the finger lifts. Check eligibility on release; never queue calls.
            if isAvailable { action() }
        } label: {
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
            .hudActivationHighlight(isSelected, side: buttonSize.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(ReinforcementButtonStyle(isAvailable: isAvailable, isActivated: isActivated))
        .accessibilityLabel("Call reinforcements")
        .accessibilityIdentifier("call-reinforcements")
        .accessibilityValue(isSelected ? "Selected" : cooldown.isReady ? "Ready" : "\(cooldown.displaySeconds) seconds remaining")
    }

    private var cooldownOverlay: some View {
        ReinforcementCooldownOverlay(buttonSize: buttonSize, remainingFraction: cooldown.remainingFraction)
    }
}

private struct ReinforcementButtonStyle: ButtonStyle {
    let isAvailable: Bool
    let isActivated: Bool

    func makeBody(configuration: Configuration) -> some View {
        // A press is visible immediately; only selection owns the white border,
        // so cancelling does not leave a misleading selected outline behind.
        configuration.label
            .brightness(isAvailable && (configuration.isPressed || isActivated) ? 0.12 : 0)
    }
}
