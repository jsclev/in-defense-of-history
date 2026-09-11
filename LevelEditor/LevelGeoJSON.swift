import Foundation

/// The flattened interchange format. Construction and decoding both validate;
/// immutable storage means a valid instance cannot later acquire a second path.
final class LevelGeoJSON: Codable {
    struct ValidationError: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    enum Geometry: Codable, Equatable, Sendable {
        typealias Position = [Double]
        typealias Ring = [Position]
        typealias Polygon = [Ring]
        case point(Position)
        case lineString([Position])
        case polygon(Polygon)
        case multiPolygon([Polygon])

        enum CodingKeys: String, CodingKey { case type, coordinates }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(String.self, forKey: .type) {
            case "LineString": self = .lineString(try c.decode([Position].self, forKey: .coordinates))
            case "Point": self = .point(try c.decode(Position.self, forKey: .coordinates))
            case "Polygon": self = .polygon(try c.decode(Polygon.self, forKey: .coordinates))
            case "MultiPolygon": self = .multiPolygon(try c.decode([Polygon].self, forKey: .coordinates))
            default: throw ValidationError(message: "Expected Point, LineString, Polygon or MultiPolygon geometry.")
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .lineString(p):
                try c.encode("LineString", forKey: .type)
                try c.encode(p, forKey: .coordinates)
            case let .point(p):
                try c.encode("Point", forKey: .type)
                try c.encode(p, forKey: .coordinates)
            case let .polygon(p):
                try c.encode("Polygon", forKey: .type)
                try c.encode(p, forKey: .coordinates)
            case let .multiPolygon(p):
                try c.encode("MultiPolygon", forKey: .type)
                try c.encode(p, forKey: .coordinates)
            }
        }

        var polygons: [Polygon] {
            switch self {
            case .point, .lineString: []
            case let .polygon(p): [p]
            case let .multiPolygon(p): p
            }
        }

        var positions: [Position] {
            if case let .point(p) = self { return [p] }
            if case let .lineString(p) = self { return p }
            return polygons.flatMap { $0.flatMap { $0 } }
        }

        func validate() throws {
            guard !positions.isEmpty,
                  positions.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }) else {
                throw ValidationError(message: "Geometry needs finite [x, y] coordinates.")
            }
            if case .point = self { return }
            if case let .lineString(points) = self {
                guard points.count >= 2, Set(points).count >= 2 else {
                    throw ValidationError(message: "Enemy routes need at least two distinct waypoints.")
                }
                return
            }
            guard !polygons.isEmpty else {
                throw ValidationError(message: "The path area is empty.")
            }
            for polygon in polygons {
                guard !polygon.isEmpty else {
                    throw ValidationError(message: "A path polygon needs an exterior ring.")
                }
                for ring in polygon {
                    let area = Self.signedArea(ring)
                    guard ring.count >= 4, ring.first == ring.last,
                          Set(ring.dropLast()).count >= 3,
                          area.isFinite, abs(area) > 0 else {
                        throw ValidationError(message: "Path rings must be closed and enclose a nonzero area.")
                    }
                }
            }
        }

        static func signedArea(_ ring: Ring) -> Double {
            zip(ring, ring.dropFirst()).reduce(0) { sum, pair in
                sum + pair.0[0] * pair.1[1] - pair.1[0] * pair.0[1]
            } / 2
        }
    }

    enum Kind: String, Codable, Sendable {
        case path = "enemy_path"
        case enemyRoute = "enemy_route"
        case entrance = "spawn_point"
        case exit = "goal_point"
        case towerSlot = "tower_slot"
        case callWaveButton = "call_wave_button"
        case heroSpawn = "hero_spawn"
    }

    struct Properties: Codable, Equatable, Sendable {
        var id: String
        var name: String
        var category = "gameplay"
        var kind: Kind
        var layer: Int
        var playable = true
        var insidePlayArea: Bool
        var pathIndex: Int?
        var slotIndex: Int?
        var slotNumber: Int?
        var pathIndices: [Int]?
        var heroRoles: [HeroSelection.Role]?
        var entranceID: String?
        var exitID: String?
    }

    struct Feature: Codable, Equatable, Sendable {
        var type = "Feature"
        var id: String
        var geometry: Geometry
        var properties: Properties
    }

    struct CoordinateReferenceSystem: Codable, Equatable, Sendable {
        struct Size: Codable, Equatable, Sendable { var width: Double; var height: Double }
        struct Rect: Codable, Equatable, Sendable {
            var x: Double; var y: Double; var width: Double; var height: Double
        }
        var type = "local-cartesian"
        var note = "NOT WGS84. [x, y] in canonical game units, origin LOWER-LEFT, +y UP."
        var canvas: Size
        var playArea: Rect
    }

    struct SpawnLine: Codable, Equatable, Sendable {
        var foe: String
        var count: Int
        var every: Double
        var delay: Double
        var pathIndex: Int
    }

    struct Wave: Codable, Equatable, Sendable {
        var breather: Double
        var lines: [SpawnLine]
        var callButtonDelay: Double? = nil
        var autoStartCountdown: Double? = nil
        var earlyCallBonus: Int? = nil
    }

    struct Collection: Codable, Equatable, Sendable {
        var type = "FeatureCollection"
        var formatVersion = 2
        var name: String
        var coordinateReferenceSystem: CoordinateReferenceSystem
        var startingGold: Int
        var lives: Int
        var features: [Feature]
        var waves: [Wave]
        var heroCount: Int?
    }

    let collection: Collection

    init(collection: Collection) throws {
        try Self.validate(collection)
        self.collection = collection
    }

    convenience init(from decoder: Decoder) throws {
        try self.init(collection: Collection(from: decoder))
    }

    convenience init(data: Data) throws {
        try self.init(collection: JSONDecoder().decode(Collection.self, from: data))
    }

    func encode(to encoder: Encoder) throws { try collection.encode(to: encoder) }

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    func dump(to url: URL) throws {
        try data().write(to: url, options: .atomic)
    }

    private static func validate(_ c: Collection) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw ValidationError(message: message) }
        }
        try require(c.type == "FeatureCollection" && c.formatVersion == 2,
                    "Unsupported level GeoJSON format.")
        try require(!c.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "Give the level a name before exporting.")
        try require(c.startingGold >= 0 && c.lives > 0,
                    "Starting gold must be nonnegative and lives must be positive.")
        let crs = c.coordinateReferenceSystem, size = crs.canvas, rect = crs.playArea
        try require(crs.type == "local-cartesian"
                    && [size.width, size.height, rect.x, rect.y, rect.width, rect.height].allSatisfy(\.isFinite)
                    && size.width > 0 && size.height > 0 && rect.width > 0 && rect.height > 0
                    && rect.x >= 0 && rect.y >= 0
                    && rect.x + rect.width <= size.width && rect.y + rect.height <= size.height,
                    "Canvas and play area must be finite, positive, and fit the canvas.")
        try require(c.features.filter { $0.properties.kind == .path }.count == 1,
                    "GeoJSON must contain exactly one flattened path object.")
        try require(c.features.contains { $0.properties.kind == .entrance },
                    "Place at least one entrance before exporting GeoJSON.")
        try require(c.features.contains { $0.properties.kind == .exit },
                    "Place at least one exit before exporting GeoJSON.")
        var ids = Set<String>()
        var slots = Set<Int>()
        var heroSpawns: [HeroSpawn] = []
        for feature in c.features {
            let p = feature.properties
            if let roles = p.heroRoles {
                try require(p.kind == .heroSpawn || roles.isEmpty,
                            "Hero roles require explicit hero starting points.")
                if case let .point(xy) = feature.geometry, xy.count == 2 {
                    heroSpawns += roles.map { .init(role: $0, featureID: feature.id, position: Point(xy[0], xy[1])) }
                }
            }
            try require(feature.type == "Feature" && !feature.id.isEmpty
                        && feature.id == p.id && ids.insert(feature.id).inserted,
                        "Every feature must have a unique, matching ID.")
            try require(p.category == "gameplay" && p.playable,
                        "Level features must be playable gameplay features.")
            try feature.geometry.validate()
            if p.kind == .path {
                try require(!feature.geometry.polygons.isEmpty && p.pathIndex == 0,
                            "The single path must be a Polygon or MultiPolygon with pathIndex 0.")
            } else if p.kind == .enemyRoute {
                if case .lineString = feature.geometry {} else {
                    throw ValidationError(message: "Enemy routes must be LineStrings.")
                }
            } else {
                if case .point = feature.geometry {} else {
                    throw ValidationError(message: "Entrances, exits, hero starts, tower slots and call wave buttons must be Points.")
                }
                if p.kind == .towerSlot {
                    try require(p.slotIndex.map { $0 >= 0 && slots.insert($0).inserted } == true,
                                "Tower slot indices must be unique and nonnegative.")
                    try require(p.slotNumber == p.slotIndex.map { $0 + 1 },
                                "Tower slot numbers must match their indices.")
                } else if p.kind == .heroSpawn {
                    try require(p.heroRoles?.count == 1 && p.pathIndex == nil,
                                "Each hero starting point needs exactly one role and no pathIndex.")
                } else if p.kind == .callWaveButton {
                    try require(p.pathIndex == nil, "Call wave buttons use pathIndices to select incoming routes.")
                    if let paths = p.pathIndices {
                        try require(!paths.isEmpty && paths.allSatisfy { $0 >= 0 }
                                    && Set(paths).count == paths.count,
                                    "Call wave button path indices must be nonempty, unique and nonnegative.")
                    }
                } else {
                    try require(p.pathIndex == 0, "Every entrance and exit must reference pathIndex 0.")
                }
            }
        }
        try require(slots == Set(0..<slots.count), "Tower slot indices must be contiguous from zero.")
        do {
            _ = try LevelHeroConfiguration(heroCount: c.heroCount ?? 0, spawns: heroSpawns)
        } catch let DbError.Db(message) {
            throw ValidationError(message: message)
        }
        let declaredRouteCount = c.features.filter { $0.properties.kind == .enemyRoute }.count
        let routeCount: Int? = declaredRouteCount > 0 ? declaredRouteCount : nil
        for wave in c.waves {
            try require(wave.breather.isFinite && wave.breather >= 0,
                        "Wave breathers must be finite and nonnegative.")
            if wave.callButtonDelay != nil || wave.autoStartCountdown != nil || wave.earlyCallBonus != nil {
                try require(wave.callButtonDelay.map { $0.isFinite && $0 >= 0 } == true
                            && wave.autoStartCountdown.map { $0.isFinite && $0 >= 0 } == true
                            && wave.earlyCallBonus.map { $0 >= 0 } == true,
                            "Wave timing needs a nonnegative call delay, countdown, and early-call bonus.")
            }
            for line in wave.lines {
                try require(!line.foe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && line.count > 0 && line.every.isFinite && line.every > 0
                            && line.delay.isFinite && line.delay >= 0
                            && (0..<(routeCount ?? c.features.filter { $0.properties.kind == .entrance }.count)).contains(line.pathIndex),
                            "Spawn lines need a foe, positive count and interval, nonnegative delay, and a valid entrance route index.")
            }
        }
        // Run after scalar checks so invalid nonfinite data produces a useful
        // validation error instead of failing JSON encoding first.
        if declaredRouteCount > 0 {
            _ = try LevelGeoJSONDAO.enemyRoutes(from: JSONEncoder().encode(c))
        }
    }
}
