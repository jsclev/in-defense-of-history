import SwiftUI

struct HudButtonView: View {
    private let iconName: String
    private let buttonSize: CGFloat
    private let iconScale: CGFloat
    private let frameName: String
    private let action: () -> Void
    
    public init(iconName: String, buttonSize: CGFloat, iconScale: CGFloat = 0.80,
                frameName: String = "tower_menu_square_frame",
                action: @escaping () -> Void) {
        self.iconName = iconName
        self.buttonSize = buttonSize
        self.iconScale = iconScale
        self.frameName = frameName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(frameName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * iconScale, height: buttonSize * iconScale)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
