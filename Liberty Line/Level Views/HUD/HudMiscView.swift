import SwiftUI

struct HudMiscView: View {
    private let iconName = "hud_misc_sack"
    private let buttonSize: CGFloat
    private let isActivated: Bool
    private let action: () -> Void
    
    public init(runtimeCanvas: RuntimeCanvas, location: HudLocation = .southEast,
                isActivated: Bool = false, action: @escaping () -> Void = {}) {
        self.buttonSize = HudButtonRowLayout(area: runtimeCanvas.hudPlayArea,
                                            location: location, count: 1).buttonSize
        self.isActivated = isActivated
        self.action = action
    }

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize,
                      frameName: "hud_misc_sack_blue_frame", action: action)
            .hudActivationHighlight(isActivated, side: buttonSize)
            .accessibilityLabel("Inventory")
            .accessibilityIdentifier("inventory-level")
            .accessibilityValue(isActivated ? "Activated" : "")
    }
}
