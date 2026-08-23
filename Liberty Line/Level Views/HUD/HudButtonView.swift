import SwiftUI

struct HudButtonView: View {
    private let screenGeometry: ScreenGeometry
    private let iconName: String
    private let frameScaleFactor = 0.16
    private let frameSize: CGFloat
    
    public init(screenGeometry: ScreenGeometry, iconName: String) {
        self.screenGeometry = screenGeometry
        self.iconName = iconName
        
        self.frameSize = screenGeometry.safeInsetsRect.height * frameScaleFactor
    }

    var body: some View {
        ZStack {
            Image("tower_menu_square_frame")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: frameSize, height: frameSize)
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: frameSize * 0.7, height: frameSize * 0.7)
        }
    }
}
