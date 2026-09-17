import SwiftUI

struct HeroHUDButton: View {
    /// The hero's one canonical portrait. Nil means this slot has no hero.
    let iconName: String?
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    private func requiredPortrait(_ name: String) -> UIImage {
        guard let image = UIImage(named: name), image.size.width > 0, image.size.height > 0 else {
            fatalError("Missing required hero HUD image '\(name)'")
        }
        return image
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if let iconName {
                    // Render the authored icon directly. Missing artwork must
                    // never select another portrait or a legacy frame.
                    Image(uiImage: requiredPortrait(iconName))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: buttonSize, height: buttonSize)
                        .clipShape(PaintedHeroHUDFrameOutline())
                        .grayscale(isAvailable ? 0 : 1)
                } else {
                    // An empty selection is a separate state, not missing art.
                    PaintedHUDButtonFrame(buttonSize: CGSize(width: buttonSize, height: buttonSize))
                    Image("tower_locked_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize * HudSizing.paintedButtonIconFraction,
                               height: buttonSize * HudSizing.paintedButtonIconFraction)
                        .grayscale(1)
                }
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

/// Both complete portraits use the same generated RGB frame. Clip only its
/// exterior, leaving each painted portrait, headroom and background untouched.
private struct PaintedHeroHUDFrameOutline: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        let outline: [CGPoint] = [
            CGPoint(x: 86, y: 2), CGPoint(x: 194, y: 2),
            CGPoint(x: 214, y: 20), CGPoint(x: 1038, y: 20),
            CGPoint(x: 1060, y: 2), CGPoint(x: 1168, y: 2),
            CGPoint(x: 1240, y: 74), CGPoint(x: 1240, y: 188),
            CGPoint(x: 1223, y: 209), CGPoint(x: 1223, y: 998),
            CGPoint(x: 1240, y: 1020), CGPoint(x: 1240, y: 1157),
            CGPoint(x: 1168, y: 1228), CGPoint(x: 1056, y: 1228),
            CGPoint(x: 1034, y: 1207), CGPoint(x: 212, y: 1207),
            CGPoint(x: 194, y: 1228), CGPoint(x: 86, y: 1228),
            CGPoint(x: 14, y: 1157), CGPoint(x: 14, y: 1020),
            CGPoint(x: 33, y: 998), CGPoint(x: 33, y: 210),
            CGPoint(x: 14, y: 188), CGPoint(x: 14, y: 74)
        ]
        var path = SwiftUI.Path()
        path.addLines(outline.map {
            CGPoint(x: rect.minX + ($0.x - 14) / 1226 * rect.width,
                    y: rect.minY + ($0.y - 2) / 1226 * rect.height)
        })
        path.closeSubpath()
        return path
    }
}

private struct HeroHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
