import Foundation

public enum Emplacement: String, CaseIterable, Sendable {
    case minutemanPost
    case longRifles
    case fieldBattery
    case libertyPole

    public var id: UUID {
        switch self {
        case .minutemanPost: return UUID(uuidString: "a1000000-0000-4000-8000-000000000001")!
        case .longRifles: return UUID(uuidString: "a1000000-0000-4000-8000-000000000002")!
        case .fieldBattery: return UUID(uuidString: "a1000000-0000-4000-8000-000000000003")!
        case .libertyPole: return UUID(uuidString: "a1000000-0000-4000-8000-000000000004")!
        }
    }
}

public struct DesignArsenal: Sendable {
    public let towerTypes: [TowerType]
    private let labels: [Emplacement: Labels]

    public struct Labels: Sendable {
        public let name: String
        public let shortName: String

        public init(name: String, shortName: String) {
            self.name = name
            self.shortName = shortName
        }
    }

    public init(labels: [Emplacement: Labels], levels: [Emplacement: [TowerLevel]]) throws {
        for emplacement in Emplacement.allCases {
            guard let label = labels[emplacement],
                  !label.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !label.shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw DbError.Db(message: "Missing authored tower text for \(emplacement.rawValue)") }
            guard levels[emplacement]?.isEmpty == false else {
                throw DbError.Db(message: "Missing authored tower levels for \(emplacement.rawValue)")
            }
        }
        self.labels = labels
        towerTypes = Emplacement.allCases.map {
            TowerType(id: $0.id, name: labels[$0]!.name, levels: levels[$0]!)
        }
    }

    public func type(_ e: Emplacement) -> TowerType {
        towerTypes.first { $0.id == e.id }!
    }

    public func shortName(_ e: Emplacement) -> String {
        labels[e]!.shortName
    }

    public func emplacement(for persistedValue: String) -> Emplacement? {
        Emplacement(rawValue: persistedValue)
            ?? Emplacement.allCases.first { labels[$0]?.name == persistedValue }
    }

    public func catalog(roster: DesignRoster) -> ContentCatalog {
        ContentCatalog(enemyTypes: roster.enemyTypes, towerTypes: towerTypes)
    }
}
