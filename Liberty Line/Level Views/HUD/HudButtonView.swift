import SwiftUI

struct HudButtonView: View {
    let iconName: String?
    let buttonSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
                if let iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize * 0.9, height: buttonSize * 0.9)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(iconName == nil)
    }
}
