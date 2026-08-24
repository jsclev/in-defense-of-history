import SwiftUI

struct HudButtonView: View {
    private let iconName: String
    private let buttonSize: CGFloat
    private let action: () -> Void
    
    public init(iconName: String, buttonSize: CGFloat,
                action: @escaping () -> Void) {
        self.iconName = iconName
        self.buttonSize = buttonSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
