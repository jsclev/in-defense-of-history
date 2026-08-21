import SwiftUI

@available(iOS 26.0, *)
struct EncyclopediaView: View {
    let screen: ScreenGeometry
    let onExit: () -> Void

    enum Category {
        case towers, enemies
    }

    @State private var selectedCategory: Category?

    private static let layoutSize = CGSize(width: 3840, height: 2160)
    private static let titleFrame = CGRect(x: 1220, y: 8, width: 1400, height: 622)
    private static let towersFrame = CGRect(x: 675, y: 620, width: 1138, height: 1420)
    private static let enemiesFrame = CGRect(x: 2027, y: 620, width: 1138, height: 1420)

    var body: some View {
        let scale = screen.playable.width / Self.layoutSize.width
        let origin = screen.playable.origin
        ZStack(alignment: .topLeading) {
            ZStack {
                Image("hero_screen_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.physical.width, height: screen.physical.height)
                    .clipped()

                element("encyclopedia_title_plaque", frame: Self.titleFrame,
                        scale: scale, origin: origin)

                categoryButton(.towers,
                               asset: "encyclopedia_towers_category",
                               frame: Self.towersFrame,
                               scale: scale, origin: origin)
                categoryButton(.enemies,
                               asset: "encyclopedia_enemies_category",
                               frame: Self.enemiesFrame,
                               scale: scale, origin: origin)
            }
            .frame(width: screen.physical.width, height: screen.physical.height)

            DoneButton(action: onExit)
                .hudFrame(DoneButtonLayout(
                    screen: screen,
                    aspect: DoneButton.aspect,
                    scaleOverride: screen.playable.height / HudScale.referencePlayableHeight).frame,
                          in: screen)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
    }

    private func element(_ name: String, frame: CGRect,
                         scale: CGFloat, origin: CGPoint) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: frame.width * scale, height: frame.height * scale)
            .position(x: origin.x + frame.midX * scale,
                      y: origin.y + frame.midY * scale)
    }

    private func categoryButton(_ category: Category, asset: String, frame: CGRect,
                                scale: CGFloat, origin: CGPoint) -> some View {
        Button {
            selectedCategory = selectedCategory == category ? nil : category
        } label: {
            element(selectedCategory == category ? asset + "_selected" : asset,
                    frame: frame, scale: scale, origin: origin)
        }
        .buttonStyle(EncyclopediaButtonStyle())
        .accessibilityLabel(category == .towers ? "Towers" : "Enemies")
    }
}

@available(iOS 26.0, *)
private struct EncyclopediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}
