import SwiftUI

struct HeroHUDButton: View {
    let iconName: String
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    private var usesPaintedFrame: Bool { iconName == "hero_icon_henry_knox" }
    private var iconFraction: CGFloat { usesPaintedFrame ? 0.64 : 0.75 }

    var body: some View {
        Button(action: action) {
            ZStack {
                if usesPaintedFrame {
                    PaintedHUDButtonFrame(buttonSize: CGSize(width: buttonSize, height: buttonSize))
                    knoxPortraitBackground
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
                    // Hold Knox's lower edge in place as the portrait shrinks,
                    // putting the added space above his hair.
                    .offset(y: usesPaintedFrame ? buttonSize * 0.02 : 0)
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

    private var knoxPortraitBackground: some View {
        // Recolor only the inset panel: Knox's baked-in orange backdrop must
        // continue through the padding, while the approved rim stays intact.
        Color(red: 0.88, green: 0.36, blue: 0.025)
            .overlay {
                PaintedHUDButtonFrame(buttonSize: CGSize(width: buttonSize, height: buttonSize))
                    .grayscale(1)
                    .brightness(0.35)
                    .blendMode(.softLight)
            }
            .compositingGroup()
            .mask {
                SwiftUI.Path { path in
                    // Inner panel bounds in the frame's 384px source, mapped
                    // through the same visible-rim normalization as the frame.
                    let corners: [CGPoint] = [
                        CGPoint(x: 61, y: 44), CGPoint(x: 322, y: 44),
                        CGPoint(x: 343, y: 65), CGPoint(x: 343, y: 312),
                        CGPoint(x: 323, y: 334), CGPoint(x: 61, y: 334),
                        CGPoint(x: 42, y: 313), CGPoint(x: 42, y: 65)
                    ]
                    path.addLines(corners.map {
                        CGPoint(x: ($0.x - 14) / 357 * buttonSize,
                                y: ($0.y - 15) / 348 * buttonSize)
                    })
                    path.closeSubpath()
                }
            }
            .grayscale(isAvailable ? 0 : 1)
            .frame(width: buttonSize, height: buttonSize)
    }
}

private struct HeroHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
