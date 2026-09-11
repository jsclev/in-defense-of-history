import SwiftUI

struct HudMiscView: View {
    private let iconName = "hud_misc_sack"
    private let buttonSize: CGFloat
    
    public init(runtimeCanvas: RuntimeCanvas) {
        let width = runtimeCanvas.miscViewSize.width
        let height = runtimeCanvas.miscViewSize.height
        self.buttonSize = min(width, height)
    }

    var body: some View {
        HudButtonView(iconName: iconName, buttonSize: buttonSize,
                      frameName: "hud_misc_sack_blue_frame") {}
    }
}
