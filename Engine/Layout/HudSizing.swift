import CoreGraphics

/// Apple's Human Interface Guidelines: "a button needs a hit region of at
/// least 44x44 pt".
public enum TouchTarget {
    public static let minimum: CGFloat = 44
}

/// First pass of HUD sizing: one scale taken from the playable rect, which is
/// always 16:9 and fully visible, so its on-screen height is
/// `min(width * 9/16, height)`.
///
/// The raw ratio alone makes the HUD unusably small on the shortest phones —
/// an iPhone SE lands at 0.55, an iPhone 13 mini at 0.53 — so the scale is
/// held between a floor and a ceiling. The floor is the main control over how
/// large the HUD reads on a small phone; the ceiling stops it ballooning on a
/// display larger than any shipping iPad.
public struct HudScale: Equatable {
    /// Playable height of the device the reference sizes were tuned on
    /// (iPad Pro 11", 1210pt on its long edge).
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

/// One HUD dimension: a size tuned on the reference device, scaled to this
/// one, then clamped to an absolute range in points.
///
/// The clamp is a guarantee rather than the usual path — `HudScale` is already
/// bounded, so for shipping devices most dimensions resolve to
/// `reference * scale` untouched. The range matters for touch targets, where
/// the floor has to hold whatever the scale does.
public struct ScaledDimension: Equatable {
    public let reference: CGFloat
    public let minimum: CGFloat
    public let maximum: CGFloat

    public init(_ reference: CGFloat, atLeast minimum: CGFloat, atMost maximum: CGFloat) {
        self.reference = reference
        self.minimum = minimum
        self.maximum = maximum
    }

    /// Range expressed as a fraction of the reference size.
    public init(_ reference: CGFloat, floor: CGFloat = 0.62, ceiling: CGFloat = 1.2) {
        self.init(reference, atLeast: reference * floor, atMost: reference * ceiling)
    }

    public func resolved(at scale: CGFloat) -> CGFloat {
        Swift.min(Swift.max(reference * scale, minimum), maximum)
    }

    public func resolved(_ scale: HudScale) -> CGFloat { resolved(at: scale.value) }
}

/// Every sized element of the HUD, in one table.
public enum HudSizing {
    // Touch targets. The floor is the HIG hit region, so these can never
    // resolve to something too small to hit, whatever the scale does.

    /// Speed-up and back-to-campaign buttons.
    public static let cornerButton = ScaledDimension(81.29, atLeast: TouchTarget.minimum,
                                                     atMost: 81.29 * 1.2)
    public static let cornerButtonSpacing = ScaledDimension(16.8)

    /// The one margin every HUD group is placed with, so the counters and the
    /// corner buttons resolve to the same top edge. Splitting this was what
    /// let them drift apart.
    public static let hudMargin = ScaledDimension(12)

    // The campaign map's menu bar. Sized and clamped exactly like the corner
    // buttons, and placed by the same solver; 110.88 is the original 92.4
    // tuning taken up 20%.
    public static let menuButton = ScaledDimension(110.88, atLeast: TouchTarget.minimum,
                                                   atMost: 110.88 * 1.2)
    public static let menuButtonSpacing = ScaledDimension(14)

    // Counters. Every element sizes on its own so artwork can be swapped and
    // retuned one piece at a time; only placement is shared.
    //
    // Icon numbers are the RENDERED height in points. HudIcon frames each
    // image to its own aspect, so a wide coin stack is no longer squeezed into
    // a square frame and no longer needs a fudge factor to look right.

    public static let livesIcon = ScaledDimension(43.6)
    public static let livesText = ScaledDimension(37.1)
    public static let livesValueWidth = ScaledDimension(60)
    public static let livesRowSpacing = ScaledDimension(8)

    /// Both numbers are the true drawn height: the imagesets are trimmed, so
    /// no transparent padding eats into them and the frame is the artwork.
    public static let moneyIcon = ScaledDimension(43.6)
    public static let moneyText = ScaledDimension(37.1)
    public static let moneyValueWidth = ScaledDimension(122)
    public static let moneyRowSpacing = ScaledDimension(8)

    public static let waveText = ScaledDimension(28.9)

    /// Gap between the lives group and the money group.
    public static let statSpacing = ScaledDimension(33)
    /// Gap between the counter row and the wave line beneath it.
    public static let statRowSpacing = ScaledDimension(6)

    // Backing plates: one box behind each counter group and one behind the
    // wave line, each just a little larger than its content.
    public static let statPlatePadding = ScaledDimension(7)
    public static let statPlateCorner = ScaledDimension(10)
    /// Not a size, so it does not scale.
    public static let statPlateOpacity: CGFloat = 0.40


    public static let hudPadding = ScaledDimension(16)

    /// Done button height on menu screens.
    public static let doneButton = ScaledDimension(57.5)

    // Campaign title graphic: width is a share of the physical screen, capped
    // for very wide displays; only the margin scales.
    public static let titleWidthFraction: CGFloat = 0.3726
    public static let titleMaxWidth: CGFloat = 486
    public static let titleMargin = ScaledDimension(18.5)
}
