import SwiftUI

/// The ONE renderer for a tower slot in the editor's canvases. The edit
/// canvas and the playtest canvas both call this, so a slot always looks
/// the same everywhere: the real pad art at CanvasSpec.slotSize with its
/// number in black, slightly above centre. Nothing else may draw a slot.
enum SlotArt {
    /// The slot pad art, from the repo's version-controlled Images folder
    /// on a Mac running from the repo, or the app bundle on iPad.
    static let padImage: PlatformImage? = {
        guard let url = EditorResources.url("Images/tower_slot_field.png") else { return nil }
        return PlatformImageLoader.load(path: url.path)?.image
    }()

    static func draw(_ ctx: inout GraphicsContext, at center: CGPoint,
                     index: Int, scale s: CGFloat, selected: Bool) {
        let w = CanvasSpec.slotSize.width * s
        let h = CanvasSpec.slotSize.height * s
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        if let pad = padImage {
            ctx.draw(Image(platformImage: pad), in: rect)
        } else {
            ctx.stroke(SwiftUI.Path(ellipseIn: rect), with: .color(.white.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2, dash: [5 * s, 4 * s]))
        }
        ctx.draw(
            Text("\(index)")
                .font(.system(size: max(10.5, 11.5 * s), weight: .medium))
                .foregroundStyle(selected ? .yellow : .black.opacity(0.8)),
            at: CGPoint(x: center.x, y: center.y - 8 * s)
        )
    }
}
