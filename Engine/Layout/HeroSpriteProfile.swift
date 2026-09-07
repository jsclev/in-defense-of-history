import CoreGraphics

/// Historical stature and artwork calibration are separate measurements.
/// Sources, uncertainty, reference poses and landmarks: Tools/hero_physical_scale.json.
public struct HeroSpriteProfile: Equatable {
    public enum Evidence: String {
        case reported
        case approximate
        case provisional
    }

    public let statureInches: CGFloat
    public let evidence: Evidence
    // Standing-equivalent crown-to-sole length / full image height. This can exceed
    // one for a kneeling/lunging pose. Hats, weapons and shadows do not set stature.
    public let standingBodyFraction: CGFloat
    public let groundInsetFraction: CGFloat

    public static let referenceStatureInches: CGFloat = 74
    // Shared additional 5% reduction (40.04 × 0.95).
    public static let referenceBodyMinimumPoints: CGFloat = 38.038

    public var imageHeight: SpriteHeight {
        let bodyAtMinimum = Self.referenceBodyMinimumPoints * statureInches / Self.referenceStatureInches
        return SpriteHeight(mapPixels: bodyAtMinimum * SpriteHeight.referenceMapHeight
                            / SpriteHeight.smallestPlayableHeight / standingBodyFraction)
    }

    // One calibration per hero, shared by all frames, facings and export densities.
    // Provisional values are drawing choices, not claimed historical measurements.
    public static let all: [String: HeroSpriteProfile] = [
        "hero_unit_baron_von_steuben": .init(statureInches: 69, evidence: .provisional, standingBodyFraction: 224.0 / 270, groundInsetFraction: 10.0 / 270),
        "hero_unit_benedict_arnold": .init(statureInches: 68, evidence: .provisional, standingBodyFraction: 275.0 / 270, groundInsetFraction: 2.0 / 270),
        "hero_unit_daniel_morgan": .init(statureInches: 72, evidence: .approximate, standingBodyFraction: 249.0 / 270, groundInsetFraction: 11.0 / 270),
        "hero_unit_francis_marion": .init(statureInches: 61, evidence: .approximate, standingBodyFraction: 222.0 / 270, groundInsetFraction: 10.0 / 270),
        "hero_unit_george_washington": .init(statureInches: 74, evidence: .reported, standingBodyFraction: 252.0 / 270, groundInsetFraction: 6.0 / 270),
        "hero_unit_henry_knox": .init(statureInches: 73, evidence: .provisional, standingBodyFraction: 244.0 / 270, groundInsetFraction: 16.0 / 277),
        "hero_unit_horatio_gates": .init(statureInches: 69, evidence: .provisional, standingBodyFraction: 256.0 / 270, groundInsetFraction: 3.0 / 270),
        "hero_unit_john_glover": .init(statureInches: 66, evidence: .provisional, standingBodyFraction: 226.0 / 270, groundInsetFraction: 10.0 / 270),
        "hero_unit_louis_duportail": .init(statureInches: 69, evidence: .provisional, standingBodyFraction: 300.0 / 270, groundInsetFraction: 2.0 / 270),
        "hero_unit_molly_pitcher": .init(statureInches: 65, evidence: .provisional, standingBodyFraction: 260.0 / 270, groundInsetFraction: 3.0 / 270),
        "hero_unit_nathanael_greene": .init(statureInches: 71.5, evidence: .approximate, standingBodyFraction: 258.0 / 270, groundInsetFraction: 2.0 / 270),
        "hero_unit_old_put": .init(statureInches: 66, evidence: .reported, standingBodyFraction: 234.0 / 270, groundInsetFraction: 11.0 / 270),
        "hero_unit_salem_poor": .init(statureInches: 69, evidence: .provisional, standingBodyFraction: 231.0 / 270, groundInsetFraction: 10.0 / 270),
        "hero_unit_thaddeus_kosciuszko": .init(statureInches: 66, evidence: .provisional, standingBodyFraction: 285.0 / 270, groundInsetFraction: 2.0 / 270),
        "hero_unit_william_prescott": .init(statureInches: 74.5, evidence: .approximate, standingBodyFraction: 264.0 / 270, groundInsetFraction: 5.0 / 270),
    ]
}
