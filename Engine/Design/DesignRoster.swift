import Foundation

public enum Foe: String, CaseIterable, Sendable {
    case loyalistMilitia = "loyalist_militia"
    case regimentalDrummer = "regimental_drummer"
    case redcoatRegular = "redcoat_regular"
    case lightInfantry = "light_infantry"
    case hessianJager = "hessian_jager"
    case hessianFusilier = "hessian_fusilier"
    case nativeWarrior = "native_warrior"
    case highlander = "highlander"
    case lightDragoon = "light_dragoon"
    case spy = "spy"
    case grenadier = "grenadier"
    case royalArtillery = "royal_artillery"
    case mountedOfficer = "mounted_officer"
    case footGuards = "foot_guards"

    public var id: UUID {
        switch self {
        case .loyalistMilitia: return UUID(uuidString: "c972308d-7313-45ae-8cb4-04d2d5b78046")!
        case .regimentalDrummer: return UUID(uuidString: "369e4cb5-38dc-4857-8701-e6c1320c52bc")!
        case .redcoatRegular: return UUID(uuidString: "86175b06-0f08-4407-bac0-0aa95cde3f52")!
        case .lightInfantry: return UUID(uuidString: "59cffa58-a230-4b83-b6e4-00cd84175ad1")!
        case .hessianJager: return UUID(uuidString: "e8e182d1-c209-4cdd-8f8d-8d95de3fe167")!
        case .hessianFusilier: return UUID(uuidString: "7c014dae-5896-4b32-896e-f95555833e1e")!
        case .nativeWarrior: return UUID(uuidString: "b3e0cd5e-0128-46eb-a2c3-fe193d728228")!
        case .highlander: return UUID(uuidString: "414fd1af-c633-4780-b513-b70f13018cd3")!
        case .lightDragoon: return UUID(uuidString: "ef3a782a-58db-4ac8-b372-0745a27669b0")!
        case .spy: return UUID(uuidString: "9ba1961d-cb79-4e0b-a6cd-6806d115813e")!
        case .grenadier: return UUID(uuidString: "5392e3d1-c1c6-40d0-b54d-2be8aa4dc277")!
        case .royalArtillery: return UUID(uuidString: "f00dd278-0466-4bd5-b454-9c5a3dc964ec")!
        case .mountedOfficer: return UUID(uuidString: "48cf0732-a2a6-4271-b631-232a70c263ce")!
        case .footGuards: return UUID(uuidString: "8dc553a0-c688-470d-ae0a-f2a0cfa04f45")!
        }
    }
}

/// Uses the same authored roster as the game; no separate display copy or stats.
public struct DesignRoster: Sendable {
    public let enemyTypes: [EnemyType]

    public init(enemyTypes: [EnemyType]) throws {
        self.enemyTypes = try Foe.allCases.map { foe in
            let matches = enemyTypes.filter { $0.id == foe.id && $0.key == foe.rawValue }
            guard matches.count == 1, let type = matches.first else {
                throw DbError.Db(message: "Missing or ambiguous authored enemy key '\(foe.rawValue)' (id '\(foe.id)')")
            }
            return type
        }
    }

    public func type(_ foe: Foe) -> EnemyType {
        enemyTypes.first { $0.id == foe.id }!
    }
}
