import SwiftUI

struct HeroHUDButton: View {
    let iconName: String
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    private var usesPaintedFrame: Bool { iconName == "hero_icon_henry_knox" }
    private var iconFraction: CGFloat { usesPaintedFrame ? 0.68 : 0.75 }

    var body: some View {
        Button(action: action) {
            ZStack {
                if usesPaintedFrame {
                    PaintedHUDButtonFrame(buttonSize: CGSize(width: buttonSize, height: buttonSize))
                } else {
                    Image("tower_menu_square_frame")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                }
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * iconFraction, height: buttonSize * iconFraction)
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
