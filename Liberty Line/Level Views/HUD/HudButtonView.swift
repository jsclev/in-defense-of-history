import SwiftUI

struct HudButtonView: View {
    let iconName: String?
    let buttonSize: CGSize
    let action: () -> Void

    var body: some View {
        let side = buttonSize.width
        let iconSide = 50.0
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: side, height: side)
                if let iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSide, height: iconSide)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(iconName == nil)
    }
}
