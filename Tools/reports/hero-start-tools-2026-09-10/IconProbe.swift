import AppKit
import SwiftUI
import LevelEditorFormats

typealias HeroSelection = LevelEditorFormats.HeroSelection
typealias PlatformImage = NSImage
extension Image {
    init(platformImage: NSImage) { self.init(nsImage: platformImage) }
}

@main struct IconProbe {
    @MainActor static func main() throws {
        // Render the actual production icon code at its 27 x 19 point toolbar box.
        // This is an offscreen SwiftUI rendering check, not UI automation.
        for scale in [CGFloat(1), 2] {
            let view = VStack(spacing: 0) {
                row(dark: false)
                row(dark: true)
            }.frame(width: 232, height: 112)
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            guard let cg = renderer.cgImage else { fatalError("No icon render") }
            let rep = NSBitmapImageRep(cgImage: cg)
            try rep.representation(using: .png, properties: [:])!.write(to:
                URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("hero-icons-\(Int(scale))x.png"))
        }
    }

    @MainActor static func row(dark: Bool) -> some View {
        HStack(spacing: 24) {
            ForEach(HeroSelection.Role.allCases, id: \.self) { role in
                HeroPlacementIcon.image(for: role)
                    .foregroundStyle(dark ? .white : .black)
                    .frame(width: 42, height: 30)
                    .background((dark ? Color.white : .black).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                HeroPlacementIcon.image(for: role)
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 32)
                    .background(HeroPlacementIcon.color(for: role), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .frame(width: 232, height: 56)
        .background(dark ? Color(white: 0.12) : Color(white: 0.94))
    }
}
