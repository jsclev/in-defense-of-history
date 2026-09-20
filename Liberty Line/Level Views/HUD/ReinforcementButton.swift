import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false
    var reserveCapacity = 1
    var availableDeployments = 1

    var body: some View {
        Button(action: action) {
            ZStack {
                PaintedHUDButtonFrame(buttonSize: buttonSize)
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
            .overlay(alignment: .bottom) {
                if reserveCapacity > 1 {
                    HStack(spacing: 3) {
                        ForEach(0..<reserveCapacity, id: \.self) { index in
                            Circle().fill(index < availableDeployments ? Color.yellow : Color.black)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(3).background(.black.opacity(0.85), in: Capsule())
                    .padding(.bottom, 3)
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
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
        .accessibilityValue(cooldown.isReady ? "\(availableDeployments) of \(reserveCapacity) deployments ready" : "\(cooldown.displaySeconds) seconds remaining")
    }

    private var cooldownOverlay: some View {
        // Keep the colored frame exposed. All progress stays inside a fixed
        // image box, so changing the countdown cannot affect menu/map layout.
        let width = buttonSize.width * 0.78
        let height = buttonSize.height * 0.78
        let remainingHeight = height * cooldown.remainingFraction
        let boundary = height - remainingHeight
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55)
                .frame(width: width, height: remainingHeight)
                .offset(y: boundary)
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
