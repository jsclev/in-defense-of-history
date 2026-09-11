import SwiftUI

struct HeroHUDButton: View {
    let iconName: String
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("tower_menu_square_frame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.75, height: buttonSize * 0.75)
                    .grayscale(isAvailable ? 0 : 1)
            }
            .frame(width: buttonSize, height: buttonSize)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HeroHUDButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private struct HeroHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
