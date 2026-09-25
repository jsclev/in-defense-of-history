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

/// Campaign artwork has one required catalog entry at all three pixel densities.
struct CampaignButtonArt: View {
    let name: String

    var body: some View {
        Image(uiImage: Self.requiredImage(named: name))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }

    static func requiredImage(named name: String) -> UIImage {
        guard let image = UIImage(named: name) else {
            fatalError("Missing required campaign button asset: \(name)")
        }
        return image
    }
}

struct MenuButton: View {
    let menuScreen: MenuScreen
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CampaignButtonArt(name: menuScreen.iconAssetName)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.48), radius: size * 0.018, y: size * 0.027)
            .contentShape(Rectangle())
        }
        .buttonStyle(FloatingMenuButtonStyle())
        .accessibilityLabel(menuScreen.title)
        .accessibilityHint(menuScreen.accessibilityHint)
    }
}

struct DoneButton: View {
    static let assetName = "done_button_20"

    static var aspect: CGFloat { HudIcon.aspect(of: assetName) }

    let runtimeCanvas: RuntimeCanvas
    let action: () -> Void
    var frame: CGRect? = nil

    var body: some View {
        let frame = frame ?? DoneButtonLayout(runtimeCanvas: runtimeCanvas, aspect: Self.aspect).frame
        Button(action: action) {
            Image(Self.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: frame.width, height: frame.height)
        }
        .buttonStyle(DoneButtonStyle())
        .position(x: frame.midX, y: frame.midY)
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
    let runtimeCanvas: RuntimeCanvas
    let onExit: () -> Void

    var body: some View {
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        ZStack(alignment: .topLeading) {
            ZStack {
                Color(red: 0.14, green: 0.11, blue: 0.08)

                VStack(spacing: 20 * metrics.scale) {
                    CampaignButtonArt(name: menuScreen.iconAssetName)
                        .frame(width: 150 * metrics.scale, height: 150 * metrics.scale)
                    Text(menuScreen.title)
                        .font(.custom("Baskerville-Bold", size: 48 * metrics.scale))
                        .foregroundStyle(.white)
                    Text(menuScreen.accessibilityHint)
                        .font(.custom("Baskerville", size: 18 * metrics.scale))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)

            DoneButton(runtimeCanvas: runtimeCanvas, action: onExit)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
    }
}
