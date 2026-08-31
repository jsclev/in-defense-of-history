import Foundation

public enum TowerKind: String, CaseIterable, Identifiable, Sendable {
    case ranged
    case melee
    case areaOfEffect
    case special

    public var id: String { rawValue }

    public var categoryName: String {
        switch self {
        case .ranged: return "Ranged"
        case .melee: return "Melee"
        case .areaOfEffect: return "Area of Effect"
        case .special: return "Special"
        }
    }

    public init?(categoryName: String) {
        guard let kind = Self.allCases.first(where: { $0.categoryName == categoryName })
        else { return nil }
        self = kind
    }

    private var assetFamilyName: String {
        switch self {
        case .ranged: return "ranged"
        case .melee: return "melee"
        case .areaOfEffect: return "artillery"
        case .special: return "special"
        }
    }

    public var assetName: String? { assetName(atLevel: 1) }

    public func assetName(atLevel level: Int, branch: Int = 1) -> String? {
        if level >= 4 {
            return "\(assetFamilyName)_tower_level_4_branch_\(branch)"
        }
        let spriteLevel = min(max(level, 1), 3)
        return "\(assetFamilyName)_tower_level_\(spriteLevel)"
    }

    public var menuIconName: String {
        switch self {
        case .ranged: return "tower_menu_ranged_square"
        case .melee: return "tower_menu_melee_square"
        case .areaOfEffect: return "tower_menu_artillery_square"
        case .special: return "tower_menu_special_square"
        }
    }

    public var spriteHeight: SpriteHeight {
        switch self {
        case .ranged: return MapSpriteSizing.tower(mapPixels: 80)
        case .melee: return MapSpriteSizing.tower(mapPixels: 70.81)
        case .areaOfEffect: return MapSpriteSizing.tower(mapPixels: 37.04)
        case .special: return MapSpriteSizing.tower(mapPixels: 70.76)
        }
    }

    public var projectileAssetName: String? {
        switch self {
        case .areaOfEffect: return "cannonball_projectile"
        case .ranged: return "musket_ball_projectile"
        case .melee, .special: return nil
        }
    }

    public var projectileHeight: SpriteHeight {
        self == .areaOfEffect ? MapSpriteSizing.cannonball : MapSpriteSizing.musketBall
    }

    /// Ranged art is drawn on the tower_slot.png canvas; the others are tight-cropped.
    public var usesSlotCanvasArt: Bool { self == .ranged }
}
