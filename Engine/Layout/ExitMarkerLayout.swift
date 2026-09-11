import CoreGraphics

/// A flat map emblem is centered on the authored goal point. Cropping source
/// padding changes its image dimensions, not the location of its visible center.
struct ExitMarkerLayout {
    let frame: CGRect

    init(position: CGPoint, projection: LevelMapProjection, spriteSize: CGFloat) {
        // Retain the approved face scale of the tightly cropped 89×92 artwork.
        let size = CGSize(width: spriteSize * 89 / 96, height: spriteSize * 92 / 96)
        let center = projection.viewPoint(position)
        frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                       width: size.width, height: size.height)
    }
}
