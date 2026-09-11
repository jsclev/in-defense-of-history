import SwiftUI

/// Editor symbols: a person plus a large role number, readable without color.
@MainActor
enum HeroPlacementIcon {
    private static let primary = render(number: "1")
    private static let secondary = render(number: "2")

    static func platformImage(for role: HeroSelection.Role) -> PlatformImage? {
        role == .primary ? primary : secondary
    }

    static func image(for role: HeroSelection.Role) -> Image {
        guard let icon = platformImage(for: role) else {
            return Image(systemName: role == .primary ? "1.circle.fill" : "2.circle.fill")
        }
        return Image(platformImage: icon).renderingMode(.template)
    }

    static func color(for role: HeroSelection.Role) -> Color {
        role == .primary ? .yellow : .cyan
    }

    private static func render(number: String) -> PlatformImage? {
        let content = HStack(alignment: .center, spacing: 2) {
            Image(systemName: "person.fill").font(.system(size: 15, weight: .semibold))
            Text(number).font(.system(size: 13, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.black)
        .frame(width: 27, height: 19)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        #if os(macOS)
        let image = renderer.nsImage
        image?.isTemplate = true
        return image
        #else
        return renderer.uiImage
        #endif
    }
}
