// DesignArsenal.swift
// The Patriot tower archetypes for design-time simulation, one per damage
// role: cheap shot DPS, sniper alpha, area denial, and the terror/rout
// economy. Stats live here in code while tuning; the DB gets them when they
// stabilize.
import Foundation

public enum Emplacement: String, CaseIterable, Sendable {
    case minutemanPost = "Minuteman Post"
    case longRifles = "Long Rifle Perch"
    case fieldBattery = "Field Battery"
    case libertyPole = "Liberty Pole"

    public var id: UUID { DesignArsenal.ids[self]! }
}

public enum DesignArsenal {
    static let ids: [Emplacement: UUID] = [
        .minutemanPost: UUID(uuidString: "a1000000-0000-4000-8000-000000000001")!,
        .longRifles: UUID(uuidString: "a1000000-0000-4000-8000-000000000002")!,
        .fieldBattery: UUID(uuidString: "a1000000-0000-4000-8000-000000000003")!,
        .libertyPole: UUID(uuidString: "a1000000-0000-4000-8000-000000000004")!,
    ]

    public static let towerTypes: [TowerType] = [
        TowerType(id: Emplacement.minutemanPost.id, name: Emplacement.minutemanPost.rawValue, levels: [
            TowerLevel(cost: 70, range: 140, fireInterval: 0.9, shotMin: 16, shotMax: 22),
            TowerLevel(cost: 110, range: 150, fireInterval: 0.8, shotMin: 26, shotMax: 36),
            TowerLevel(cost: 160, range: 160, fireInterval: 0.7, shotMin: 40, shotMax: 55),
        ]),
        TowerType(id: Emplacement.longRifles.id, name: Emplacement.longRifles.rawValue, levels: [
            TowerLevel(cost: 100, range: 220, fireInterval: 2.2, shotMin: 45, shotMax: 65, targeting: .strongest),
            TowerLevel(cost: 150, range: 240, fireInterval: 2.0, shotMin: 75, shotMax: 105, targeting: .strongest),
            TowerLevel(cost: 210, range: 260, fireInterval: 1.8, shotMin: 115, shotMax: 160, targeting: .strongest),
        ]),
        TowerType(id: Emplacement.fieldBattery.id, name: Emplacement.fieldBattery.rawValue, levels: [
            TowerLevel(cost: 125, range: 170, fireInterval: 3.0, shotMin: 20, shotMax: 40,
                       aoeRadius: 95, splashCoverPierce: 0.5),
            TowerLevel(cost: 165, range: 180, fireInterval: 2.8, shotMin: 31, shotMax: 62,
                       aoeRadius: 95, splashCoverPierce: 0.5),
            TowerLevel(cost: 230, range: 190, fireInterval: 2.6, shotMin: 45, shotMax: 90,
                       aoeRadius: 99, splashCoverPierce: 0.5),
        ]),
        TowerType(id: Emplacement.libertyPole.id, name: Emplacement.libertyPole.rawValue, levels: [
            TowerLevel(cost: 90, range: 170, fireInterval: 1.2, terrorMin: 22, terrorMax: 32, targeting: .shakiest),
            TowerLevel(cost: 130, range: 180, fireInterval: 1.1, terrorMin: 33, terrorMax: 46, targeting: .shakiest),
            TowerLevel(cost: 180, range: 190, fireInterval: 1.0, terrorMin: 46, terrorMax: 64, targeting: .shakiest),
        ]),
    ]

    public static func type(_ e: Emplacement) -> TowerType {
        towerTypes.first { $0.id == e.id }!
    }

    public static func catalog() -> ContentCatalog {
        ContentCatalog(enemyTypes: DesignRoster.enemyTypes, towerTypes: towerTypes)
    }
}
