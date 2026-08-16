import SwiftUI

enum TowerSlotImage {
    static let towerSlotImage: PlatformImage? = {
        guard let url = EditorResources.url("Images/tower_slot_field.png") else { return nil }
        return PlatformImageLoader.load(path: url.path)?.image
    }()

    static func draw(_ ctx: inout GraphicsContext, at center: CGPoint,
                     index: Int, scale s: CGFloat, selected: Bool) {
        let w = CanvasSpec.slotSize.width * s
        let h = CanvasSpec.slotSize.height * s
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        if let pad = towerSlotImage {
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
