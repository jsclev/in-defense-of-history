import CoreGraphics

public enum TouchTarget {
    public static let minimum: CGFloat = 44
}

/// Global floor for rendered text.
///
/// Every SwiftUI `Text` in the game must pass its point size through
/// `Typography.size(_:)` — or use a `ScaledDimension.text(_:)` dimension, which
/// applies the same floor. Nothing renders smaller than this, at any HUD scale
/// or on any device; below it the smallest phones become unreadable.
public enum Typography {
    public static let minimumFontSize: CGFloat = 11.7

    /// Clamp a point size to the readable floor.
    public static func size(_ requested: CGFloat) -> CGFloat {
        Swift.max(requested, minimumFontSize)
    }
}

public struct HudScale: Equatable {
    public static let referencePlayableHeight: CGFloat = 1210 * 9 / 16

    public static let minimum: CGFloat = 0.66
    public static let maximum: CGFloat = 1.15

    public let value: CGFloat

    public init(playableHeight: CGFloat) {
        let raw = playableHeight / Self.referencePlayableHeight
        value = Swift.min(Swift.max(raw, Self.minimum), Self.maximum)
    }

    public init(viewSize: CGSize) {
        let w = Swift.max(viewSize.width, viewSize.height)
        let h = Swift.min(viewSize.width, viewSize.height)
        self.init(playableHeight: Swift.min(w * 9 / 16, h))
    }
}

public struct ScaledDimension: Equatable {
    public let reference: CGFloat
    public let minimum: CGFloat
    public let maximum: CGFloat

    public init(_ reference: CGFloat, atLeast minimum: CGFloat, atMost maximum: CGFloat) {
        self.reference = reference
        self.minimum = minimum
        self.maximum = maximum
    }

    public init(_ reference: CGFloat, floor: CGFloat = 0.62, ceiling: CGFloat = 1.2) {
        self.init(reference, atLeast: reference * floor, atMost: reference * ceiling)
    }

    public func resolved(at scale: CGFloat) -> CGFloat {
        Swift.min(Swift.max(reference * scale, minimum), maximum)
    }

    public func resolved(_ scale: HudScale) -> CGFloat { resolved(at: scale.value) }

    /// A dimension for text, floored at `Typography.minimumFontSize` so it can
    /// never resolve below the readable minimum however far the HUD scales down.
    public static func text(_ reference: CGFloat,
                            floor: CGFloat = 0.62,
                            ceiling: CGFloat = 1.2) -> ScaledDimension {
        ScaledDimension(reference,
                        atLeast: Swift.max(reference * floor, Typography.minimumFontSize),
                        atMost: reference * ceiling)
    }
}

public enum HudSizing {

    public static let cornerButton = ScaledDimension(81.29, atLeast: TouchTarget.minimum,
                                                     atMost: 81.29 * 1.2)
    public static let cornerButtonSpacing = ScaledDimension(16.8)

    public static let hudMargin = ScaledDimension(12)

    public static let menuButton = ScaledDimension(110.88, atLeast: TouchTarget.minimum,
                                                   atMost: 110.88 * 1.2)
    public static let menuButtonSpacing = ScaledDimension(14)

    public static let livesIcon = ScaledDimension(43.6)
    public static let livesText = ScaledDimension.text(37.1)
    public static let livesValueWidth = ScaledDimension(60)
    public static let livesRowSpacing = ScaledDimension(8)

    public static let moneyIcon = ScaledDimension(43.6)
    public static let moneyText = ScaledDimension.text(37.1)
    public static let moneyValueWidth = ScaledDimension(122)
    public static let moneyRowSpacing = ScaledDimension(8)

    public static let waveText = ScaledDimension.text(28.9)

    /// The debug range overlay's legend. Deliberately small, so the
    /// Typography floor is what keeps it legible on a phone.
    public static let rangeLegendText = ScaledDimension.text(16)

    public static let statSpacing = ScaledDimension(33)
    public static let statRowSpacing = ScaledDimension(6)

    public static let statPlatePadding = ScaledDimension(7)
    public static let statPlateCorner = ScaledDimension(10)
    public static let statPlateOpacity: CGFloat = 0.40

    public static let hudPadding = ScaledDimension(16)

    public static let doneButton = ScaledDimension(57.5)

    public static let titleWidthFraction: CGFloat = 0.3726
    public static let titleMaxWidth: CGFloat = 486
    public static let titleMargin = ScaledDimension(18.5)
}
