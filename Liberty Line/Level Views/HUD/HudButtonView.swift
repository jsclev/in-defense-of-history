import SwiftUI

struct HudButtonView: View {
    private let iconName: String
    private let buttonSize: CGFloat
    
    public init(iconName: String, buttonSize: CGFloat) {
        self.iconName = iconName
        self.buttonSize = buttonSize
    }

    var body: some View {
        ZStack {
            Image("tower_menu_square_frame")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: buttonSize, height: buttonSize)
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: buttonSize * 0.80, height: buttonSize * 0.80)
        }
    }
}
