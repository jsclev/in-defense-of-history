import Foundation
import CoreGraphics

/// The full image canvas, including transparent padding and shadow. The renderer
/// uses these dimensions and the ground anchor when drawing a hero.
public struct HeroSpriteFootprint: Equatable {
    public let size: CGSize
    public let groundInset: CGFloat

    public init(baseAssetName: String, aspectRatio: CGFloat, playableHeight: CGFloat) {
        let height = MapSpriteSizing.hero(baseAssetName: baseAssetName)
            .resolved(playableHeightOnScreen: playableHeight)
        size = CGSize(width: height * aspectRatio, height: height)
        groundInset = MapSpriteSizing.heroGroundInset(baseAssetName: baseAssetName, spriteHeight: height)
    }

    /// Screen coordinates (+Y down), anchored at the hero's feet.
    public func frame(at foot: CGPoint) -> CGRect {
        CGRect(x: foot.x - size.width / 2, y: foot.y - size.height + groundInset,
               width: size.width, height: size.height)
    }
}

