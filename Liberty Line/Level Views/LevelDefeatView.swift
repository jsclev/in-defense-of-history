import SwiftUI

/// A roomy result panel, with space for future post-battle actions.
struct LevelDefeatView: View {
    let canvas: RuntimeCanvas
    let onReview: () -> Void
    let onRestart: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.68)
                .contentShape(Rectangle()).onTapGesture { }
                .accessibilityHidden(true)
            VStack(spacing: 20) {
                Text("DEFEAT")
                    .font(.custom("Baskerville-Bold", size: 30))
                    .foregroundStyle(CouncilPalette.cream)
                Spacer(minLength: 12)
                HStack(spacing: 24) {
                    ReplaySymbolButton(symbol: "house.fill", label: "Home",
                                       side: 72, action: onHome)
                        .accessibilityHint("Return to the campaign map")
                        .accessibilityIdentifier("defeat-home")
                    ReplaySymbolButton(symbol: "arrow.counterclockwise", label: "Restart level",
                                       side: 72, action: onRestart)
                        .accessibilityHint("Play this level again from the beginning")
                        .accessibilityIdentifier("defeat-restart")
                    ReplaySymbolButton(symbol: "questionmark", label: "Review recorded game",
                                       side: 72, action: onReview)
                        .accessibilityHint("Watch the recorded attempt")
                        .accessibilityIdentifier("defeat-review")
                }
                Spacer(minLength: 12)
            }
            .padding(24)
            .frame(width: min(480, canvas.safeInsetsRect.width - 32),
                   height: min(300, canvas.safeInsetsRect.height - 32))
            .background(CouncilPanel())
            .shadow(color: .black.opacity(0.6), radius: 16, y: 8)
            .position(x: canvas.safeInsetsRect.midX, y: canvas.safeInsetsRect.midY)
        }
        .frame(width: canvas.physicalRect.width, height: canvas.physicalRect.height)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onHome)
    }
}

/// Large, solid symbols inside the existing painted HUD rim.
struct ReplaySymbolButton: View {
    let symbol: String
    let label: String
    let side: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                PaintedHUDButtonFrame(buttonSize: CGSize(width: side, height: side))
                Image(systemName: symbol)
                    .font(.system(size: side * 0.43, weight: .bold))
                    .foregroundStyle(CouncilPalette.cream)
                    .shadow(color: CouncilPalette.ink, radius: 1, y: 2)
            }
            .frame(width: side, height: side).contentShape(Rectangle())
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
