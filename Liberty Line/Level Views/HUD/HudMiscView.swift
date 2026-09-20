import SwiftUI

struct HudMiscView: View {
    private let iconName = "hud_misc_sack"
    private let buttonSize: CGFloat
    
    public init(runtimeCanvas: RuntimeCanvas, location: HudLocation = .southEast) {
        self.buttonSize = HudButtonRowLayout(area: runtimeCanvas.hudPlayArea,
                                            location: location, count: 1).buttonSize
    }

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize,
                      frameName: "hud_misc_sack_blue_frame") {}
    }
}
