import Foundation

public enum Foe: String, CaseIterable, Sendable {
    case loyalistMilitia = "Loyalist Militia"
    case regimentalDrummer = "Regimental Drummer"
    case redcoatRegular = "Redcoat Regular"
    case lightInfantry = "Light Infantry"
    case hessianJager = "Hessian Jäger"
    case hessianFusilier = "Hessian Fusilier"
    case nativeWarrior = "Native Warrior"
    case highlander = "Highlander"
    case lightDragoon = "Light Dragoon"
    case spy = "Spy"
    case grenadier = "Grenadier"
    case royalArtillery = "Royal Artillery"
    case mountedOfficer = "Mounted Officer"
    case footGuards = "Foot Guards"

    public var id: UUID { DesignRoster.ids[self]! }
}

public enum DesignRoster {
    static let ids: [Foe: UUID] = [
        .loyalistMilitia: UUID(uuidString: "c972308d-7313-45ae-8cb4-04d2d5b78046")!,
        .regimentalDrummer: UUID(uuidString: "369e4cb5-38dc-4857-8701-e6c1320c52bc")!,
        .redcoatRegular: UUID(uuidString: "86175b06-0f08-4407-bac0-0aa95cde3f52")!,
        .lightInfantry: UUID(uuidString: "59cffa58-a230-4b83-b6e4-00cd84175ad1")!,
        .hessianJager: UUID(uuidString: "e8e182d1-c209-4cdd-8f8d-8d95de3fe167")!,
        .hessianFusilier: UUID(uuidString: "7c014dae-5896-4b32-896e-f95555833e1e")!,
        .nativeWarrior: UUID(uuidString: "b3e0cd5e-0128-46eb-a2c3-fe193d728228")!,
        .highlander: UUID(uuidString: "414fd1af-c633-4780-b513-b70f13018cd3")!,
        .lightDragoon: UUID(uuidString: "ef3a782a-58db-4ac8-b372-0745a27669b0")!,
        .spy: UUID(uuidString: "9ba1961d-cb79-4e0b-a6cd-6806d115813e")!,
        .grenadier: UUID(uuidString: "5392e3d1-c1c6-40d0-b54d-2be8aa4dc277")!,
        .royalArtillery: UUID(uuidString: "f00dd278-0466-4bd5-b454-9c5a3dc964ec")!,
        .mountedOfficer: UUID(uuidString: "48cf0732-a2a6-4271-b631-232a70c263ce")!,
        .footGuards: UUID(uuidString: "8dc553a0-c688-470d-ae0a-f2a0cfa04f45")!,
    ]

    public static let enemyTypes: [EnemyType] = [
        make(.loyalistMilitia, hp: 50, speed: 60, cover: 0.35, discipline: 0.20, hardiness: 0.30,
             dmg: 2...4, gold: 8, lives: 1, band: 0.45...0.65, traits: [.wavering]),
        make(.regimentalDrummer, hp: 60, speed: 60, cover: 0.10, discipline: 0.55, hardiness: 0.60,
             dmg: 0...0, gold: 20, lives: 1, band: 0.35...0.50,
             traits: [.rallyBeat(radius: 90, moralePerSecond: 6)]),
        make(.redcoatRegular, hp: 90, speed: 60, cover: 0.05, discipline: 0.60, hardiness: 0.70,
             dmg: 4...7, gold: 15, lives: 1, band: 0.30...0.45, traits: []),
        make(.lightInfantry, hp: 70, speed: 85, cover: 0.45, discipline: 0.50, hardiness: 0.60,
             dmg: 3...6, gold: 18, lives: 1, band: 0.30...0.45, traits: [.skirmish]),
        make(.hessianJager, hp: 65, speed: 85, cover: 0.55, discipline: 0.45, hardiness: 0.55,
             dmg: 6...9, gold: 22, lives: 1, band: 0.30...0.45, traits: [.mercenary, .marksman]),
        make(.hessianFusilier, hp: 110, speed: 60, cover: 0.05, discipline: 0.70, hardiness: 0.65,
             dmg: 5...8, gold: 20, lives: 1, band: 0.28...0.40, traits: [.mercenary]),
        make(.nativeWarrior, hp: 60, speed: 120, cover: 0.60, discipline: 0.35, hardiness: 0.75,
             dmg: 5...8, gold: 20, lives: 1, band: 0.35...0.55, traits: [.skirmish, .tag("ambush")]),
        make(.highlander, hp: 130, speed: 85, cover: 0.10, discipline: 0.75, hardiness: 0.75,
             dmg: 8...12, gold: 30, lives: 1, band: 0.25...0.35, traits: [.highlandCharge]),
        make(.lightDragoon, hp: 140, speed: 120, cover: 0.15, discipline: 0.65, hardiness: 0.60,
             dmg: 7...11, gold: 35, lives: 1, band: 0.28...0.40, traits: [.rideDown, .falter]),
        make(.spy, hp: 45, speed: 85, cover: 0.70, discipline: 0.40, hardiness: 0.50,
             dmg: 1...2, gold: 25, lives: 0, band: 0.35...0.50, traits: [.disguised, .saboteur]),
        make(.grenadier, hp: 240, speed: 40, cover: 0.0, discipline: 0.85, hardiness: 0.75,
             dmg: 10...15, gold: 45, lives: 2, band: 0.22...0.30, traits: [.steadyAdvance]),
        make(.royalArtillery, hp: 300, speed: 25, cover: 0.10, discipline: 0.70, hardiness: 0.65,
             dmg: 15...25, gold: 60, lives: 2, band: 0.25...0.35, traits: [.bombard, .crewed]),
        make(.mountedOfficer, hp: 180, speed: 85, cover: 0.10, discipline: 0.90, hardiness: 0.70,
             dmg: 6...10, gold: 50, lives: 2, band: 0.20...0.30,
             traits: [.commandAura(radius: 120, disciplineBonus: 0.25, deathShock: 25)]),
        make(.footGuards, hp: 500, speed: 40, cover: 0.0, discipline: 1.0, hardiness: 0.85,
             dmg: 12...20, gold: 75, lives: 3, band: 0.15...0.25,
             traits: [.steadyAdvance, .tag("unbreakable")]),
    ]

    public static func type(_ foe: Foe) -> EnemyType {
        enemyTypes.first { $0.id == foe.id }!
    }

    private static func make(
        _ foe: Foe, hp: Double, speed: Double, cover: Double, discipline: Double,
        hardiness: Double, dmg: ClosedRange<Double>, gold: Int, lives: Int,
        band: ClosedRange<Double>, traits: [Trait]
    ) -> EnemyType {
        EnemyType(
            id: foe.id,
            name: foe.rawValue,
            stats: EnemyStats(
                maxHP: hp, speed: speed, cover: cover, discipline: discipline,
                hardiness: hardiness, damageMin: dmg.lowerBound, damageMax: dmg.upperBound,
                gold: gold, livesCost: lives, breakBand: band
            ),
            traits: traits
        )
    }
}
