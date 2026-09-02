import CoreGraphics

public struct MapSpriteScale: Equatable {
    public let projectionScale: CGFloat
    public let playableHeightOnScreen: CGFloat

    public init(playArea: CGRect, viewSize: CGSize) {
        guard playArea.width > 0, playArea.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            projectionScale = 0
            playableHeightOnScreen = 0
            return
        }
        projectionScale = Swift.min(viewSize.width / playArea.width,
                                    viewSize.height / playArea.height)
        playableHeightOnScreen = playArea.height * projectionScale
    }

    public func points(_ height: SpriteHeight) -> CGFloat {
        height.resolved(playableHeightOnScreen: playableHeightOnScreen)
    }

    public func mapUnits(_ length: CGFloat) -> CGFloat { length * projectionScale }
}

public struct SpriteHeight: Equatable {
    public static let referenceMapHeight: CGFloat = 655

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

public enum SlotTapTarget {
    public static let margin: CGFloat = 1.15

    public static let legacyDiameter: CGFloat = 64

    public static func size(slotSize: CGSize,
                            pointsPerMapUnit: CGFloat) -> CGSize {
        guard slotSize.width > 0, slotSize.height > 0, pointsPerMapUnit > 0 else {
            return CGSize(width: legacyDiameter, height: legacyDiameter)
        }
        return CGSize(
            width: Swift.max(slotSize.width * pointsPerMapUnit * margin,
                             TouchTarget.minimum),
            height: Swift.max(slotSize.height * pointsPerMapUnit * margin,
                              TouchTarget.minimum)
        )
    }
}

public enum MapSpriteSizing {
    public static func tower(mapPixels: CGFloat) -> SpriteHeight {
        SpriteHeight(mapPixels: mapPixels, atLeast: TouchTarget.minimum)
    }

    public static let walker = SpriteHeight(mapPixels: 58.04)
    public static let meleeUnit = SpriteHeight(mapPixels: 55.26)
    public static let heroMapHeight: CGFloat = 87.06
    public static let hero = SpriteHeight(mapPixels: heroMapHeight)
    public static let cannonball = SpriteHeight(mapPixels: 20.8)
    public static let musketBall = SpriteHeight(mapPixels: 13.66)

    public static let healthBarWidth = SpriteHeight(mapPixels: 30)
    public static let healthBarHeight = SpriteHeight(mapPixels: 4, atLeast: 3, atMost: 9)

    public static let towerBaseLift = SpriteHeight(mapPixels: 14)
    public static let walkerLabelLift = SpriteHeight(mapPixels: 3.5)
}
