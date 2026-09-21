import SwiftUI

/// The same cooldown shading is rendered by the game and native rendering tests.
public struct ReinforcementCooldownOverlay: View {
    let buttonSize: CGSize
    let remainingFraction: Double

    public init(buttonSize: CGSize, remainingFraction: Double) {
        self.buttonSize = buttonSize
        self.remainingFraction = remainingFraction
    }

    public var body: some View {
        // Keep the colored frame exposed. All progress stays inside a fixed
        // image box, so changing the countdown cannot affect menu/map layout.
        let width = buttonSize.width * 0.78
        let height = buttonSize.height * 0.78
        let remainingHeight = height * remainingFraction
        // Anchor the shade itself to the bottom. Centering a shorter stack and
        // then offsetting it clips the shade before the cooldown has finished.
        return Color.black.opacity(0.55)
            .frame(width: width, height: remainingHeight)
            .frame(width: width, height: height, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: buttonSize.width * 0.04))
            .allowsHitTesting(false)
    }
}
