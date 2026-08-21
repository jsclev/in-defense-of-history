import SwiftUI

struct TowerSlotImage {
    let virtualCanvas: VirtualCanvas
    let image: PlatformImage?

    init(virtualCanvas: VirtualCanvas) {
        self.virtualCanvas = virtualCanvas
        image = EditorResources.url("Images/tower_slot_field.png")
            .flatMap { PlatformImageLoader.load(path: $0.path)?.image }
    }

    func draw(_ ctx: inout GraphicsContext, at center: CGPoint,
              index: Int, scale s: CGFloat, selected: Bool) {
        let w = virtualCanvas.towerSlotSize.width * s
        let h = virtualCanvas.towerSlotSize.height * s
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        if let pad = image {
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
