import Foundation

public struct CombatRules: Codable, Sendable, Equatable {
    public let killBountyMultiplier: Double
    public let routBountyMultiplier: Double
    public let captureBountyMultiplier: Double
    public let moraleMax: Double
    public let baseMoraleRegenPerSecond: Double
    public let breakMoraleSplash: Double
    public let breakSplashRadius: Double
    public let waveringSplashMultiplier: Double
    public let shakenSpeedMultiplier: Double
    public let routSpeedMultiplier: Double
    public let steadyAdvanceHPGate: Double
    public let contagionTickInterval: Double
    public let diseaseHPPerSecond: Double
    public let diseaseHPFloorFraction: Double
    public let diseaseMoralePerSecond: Double
    public let contagionSpreadRadius: Double
    public let contagionSpreadChance: Double
    public let meleeAttackSpread: Double
    public let meleeMoveSpeed: Double
    public let meleeEngageScanRadiusFraction: Double
    public let meleeReach: Double
    public let meleeCombatSpacing: Double
    public let meleeLeashRadiusFraction: Double
    public let enemySwingInterval: Double
    public let heroEngageScanRadius: Double
    public let heroLeashRadius: Double
    public let meleePostSpread: Double
    public let meleeSpawnSpread: Double
    public let arrivalRadius: Double
    public let rangeVerticalFraction: Double
    public let projectileHitRadius: Double
    public let grapeshotHitRadius: Double
    public let solidShotHitRadius: Double
    public let firingToleranceDegrees: Double
    public let initialHeadingDegrees: Double
    public let enemyBodyOffsetX: Double
    public let enemyBodyOffsetY: Double
    public let moraleVisibilityThreshold: Double
    public let moraleResponseDuration: Double
    public let moraleRecoveryDelay: Double
    public let moraleDisplayDuration: Double
    public let reinforcementSoldierCount: Int
    public let grapeshotSpreadDegrees: [Double]

    public var grapeshotSpread: [Double] { grapeshotSpreadDegrees.map { $0 * .pi / 180 } }
    public var firingTolerance: Double { firingToleranceDegrees * .pi / 180 }
    public var initialHeading: Double { initialHeadingDegrees * .pi / 180 }
}
