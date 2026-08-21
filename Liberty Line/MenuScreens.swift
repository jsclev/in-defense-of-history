import SwiftUI

enum MenuScreen: String, CaseIterable, Identifiable {
    case heroes, encyclopedia, shop, upgrades, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heroes: return "Heroes"
        case .encyclopedia: return "Encyclopedia"
        case .shop: return "Shop"
        case .upgrades: return "Upgrades"
        case .settings: return "Settings"
        }
    }

    var iconAssetName: String { "main_menu_\(rawValue)" }

    var placeholderSymbol: String {
        switch self {
        case .heroes: return "person.2.fill"
        case .encyclopedia: return "book.fill"
        case .shop: return "diamond.fill"
        case .upgrades: return "arrow.up"
        case .settings: return "gearshape.fill"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .heroes: return "Choose and review campaign heroes."
        case .encyclopedia: return "Review enemies, towers, and battlefield knowledge."
        case .shop: return "Spend rubies on helpful items."
        case .upgrades: return "Improve your forces between battles."
        case .settings: return "Change audio, controls, and game preferences."
        }
    }
}

struct MenuButton: View {
    let screen: MenuScreen
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if UIImage(named: screen.iconAssetName) != nil {
                    Image(screen.iconAssetName)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Circle().fill(.black.opacity(0.55))
                        Circle().strokeBorder(
                            Color(red: 0.85, green: 0.7, blue: 0.3),
                            lineWidth: 3
                        )
                        Image(systemName: screen.placeholderSymbol)
                            .font(.system(size: Typography.size(size * 0.42), weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.48), radius: 2, y: 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(FloatingMenuButtonStyle())
        .accessibilityLabel(screen.title)
        .accessibilityHint(screen.accessibilityHint)
    }
}

struct DoneButton: View {
    static let assetName = "done_button_20"

    static var aspect: CGFloat { HudIcon.aspect(of: assetName) }

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(Self.assetName)
                .resizable()
                .scaledToFit()
        }
        .buttonStyle(DoneButtonStyle())
        .accessibilityLabel("Done")
    }
}

private struct DoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
            .animation(configuration.isPressed
                ? .easeOut(duration: 0.09)
                : .spring(response: 0.28, dampingFraction: 0.55),
                value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

private struct FloatingMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}

struct MenuPlaceholderView: View {
    let menuScreen: MenuScreen
    let screen: ScreenGeometry
    let onExit: () -> Void

    var body: some View {
        let metrics = HudMetrics(screen: screen)
        ZStack(alignment: .topLeading) {
            ZStack {
                Color(red: 0.14, green: 0.11, blue: 0.08)

                VStack(spacing: 20 * metrics.scale) {
                    if UIImage(named: menuScreen.iconAssetName) != nil {
                        Image(menuScreen.iconAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: 150 * metrics.scale,
                                height: 150 * metrics.scale
                            )
                    } else {
                        Image(systemName: menuScreen.placeholderSymbol)
                            .font(.system(size: Typography.size(64 * metrics.scale), weight: .bold))
                            .foregroundStyle(Color(red: 0.85, green: 0.7, blue: 0.3))
                    }
                    Text(menuScreen.title)
                        .font(.custom("Baskerville-Bold", size: 48 * metrics.scale))
                        .foregroundStyle(.white)
                    Text(menuScreen.accessibilityHint)
                        .font(.custom("Baskerville", size: 18 * metrics.scale))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: screen.physical.width, height: screen.physical.height)

            DoneButton(action: onExit)
                .hudFrame(DoneButtonLayout(screen: screen,
                                           aspect: DoneButton.aspect).frame,
                          in: screen)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
    }
}
