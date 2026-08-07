import CoreGraphics

/// Converts a sprite's authored size into points, for one level on one screen.
///
/// Sizes are given as a fraction of the playable rect's *height* rather than in
/// map-image pixels. Levels are authored at different pixel scales — 26 use a
/// 1164x655 playable rect, 15 use 3840x2160 — so a fixed pixel height draws the
/// same tower 3.3x smaller on one than on the other. A fraction of the playable
/// rect means the same thing on every level, and it is the basis the map image
/// itself is scaled by.
public struct MapSpriteScale: Equatable {
    /// Points per unit of this level's own map coordinates.
    public let projectionScale: CGFloat
    /// The playable rect's height on screen, in points.
    public let playableHeightOnScreen: CGFloat

    public init(playableRect: CGRect, viewSize: CGSize) {
        guard playableRect.width > 0, playableRect.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            projectionScale = 0
            playableHeightOnScreen = 0
            return
        }
        projectionScale = Swift.min(viewSize.width / playableRect.width,
                                    viewSize.height / playableRect.height)
        playableHeightOnScreen = playableRect.height * projectionScale
    }

    public func points(_ height: SpriteHeight) -> CGFloat {
        height.resolved(playableHeightOnScreen: playableHeightOnScreen)
    }

    /// For lengths that are genuinely in the level's own map units — a
    /// position or a gameplay distance — rather than a sprite size.
    public func mapUnits(_ length: CGFloat) -> CGFloat { length * projectionScale }
}

/// One sprite dimension: a fraction of the playable rect's on-screen height,
/// clamped to an absolute range so it stays legible on the smallest phone and
/// does not dominate the largest tablet.
public struct SpriteHeight: Equatable {
    /// Playable-rect height the artwork's pixel sizes were tuned against, so
    /// existing numbers can be carried over unchanged.
    public static let referenceMapHeight: CGFloat = 655

    /// Playable-rect heights on screen at the extremes of the device range,
    /// used to derive a default clamp for each dimension.
    public static let smallestPlayableHeight: CGFloat = 340
    public static let largestPlayableHeight: CGFloat = 900

    public let fraction: CGFloat
    public let minimum: CGFloat
    public let maximum: CGFloat

    public init(fraction: CGFloat, atLeast minimum: CGFloat, atMost maximum: CGFloat) {
        self.fraction = fraction
        self.minimum = minimum
        self.maximum = maximum
    }

    /// From a size authored in the reference level's map pixels.
    public init(mapPixels: CGFloat,
                atLeast minimum: CGFloat? = nil,
                atMost maximum: CGFloat? = nil) {
        let fraction = mapPixels / Self.referenceMapHeight
        self.init(fraction: fraction,
                  atLeast: minimum ?? fraction * Self.smallestPlayableHeight,
                  atMost: maximum ?? fraction * Self.largestPlayableHeight)
    }

    public func resolved(playableHeightOnScreen: CGFloat) -> CGFloat {
        Swift.min(Swift.max(fraction * playableHeightOnScreen, minimum), maximum)
    }
}

/// Every sprite dimension drawn on a level map, in one table.
public enum MapSpriteSizing {
    /// Towers are tapped to select and upgrade, so they never resolve below
    /// the HIG hit region however small the screen.
    public static func tower(mapPixels: CGFloat) -> SpriteHeight {
        SpriteHeight(mapPixels: mapPixels, atLeast: TouchTarget.minimum)
    }

    /// 58.04 is the original 33.5 tuning taken up 25%, 20%, 10%, then 5%.
    public static let walker = SpriteHeight(mapPixels: 58.04)
    public static let cannonball = SpriteHeight(mapPixels: 40)
    public static let musketBall = SpriteHeight(mapPixels: 28)

    public static let healthBarWidth = SpriteHeight(mapPixels: 30)
    public static let healthBarHeight = SpriteHeight(mapPixels: 4, atLeast: 3, atMost: 9)

    /// Vertical nudges that keep a sprite's feet on its pad.
    public static let towerBaseLift = SpriteHeight(mapPixels: 14)
    public static let walkerLabelLift = SpriteHeight(mapPixels: 5)
}
