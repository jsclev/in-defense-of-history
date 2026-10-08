import SwiftUI

/// A translucent black shade clears downward as the cooldown elapses.
public struct ReinforcementCooldownOverlay: View {
    let buttonSize: CGSize
    let remainingFraction: Double

    public init(buttonSize: CGSize, remainingFraction: Double) {
        self.buttonSize = buttonSize
        self.remainingFraction = remainingFraction
    }

    public var body: some View {
        // Keep the lower edge fixed so the icon is revealed from top to bottom.
        let width = buttonSize.width * 0.78
        let height = buttonSize.height * 0.78
        return Color.black.opacity(0.55)
            .frame(width: width, height: height * remainingFraction)
            .frame(width: width, height: height, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: buttonSize.width * 0.04))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
