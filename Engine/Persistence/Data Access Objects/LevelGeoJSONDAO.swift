import Foundation
import CryptoKit

public struct EntrancePoint: Sendable, Equatable {
    public let position: Point
    public let pathIndex: Int
}

public class LevelGeoJSONDAO {
    private let bundle: Bundle
    private let directory: URL?

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.directory = nil
    }

    /// Explicit GeoJSON directory for host tools/tests; never a database fallback.
    public init(directory: URL) {
        self.bundle = .main
        self.directory = directory
    }

    public func getTowerSlots(mapImageName: String) throws -> [TowerSlot] {
        try Self.towerSlots(from: data(mapImageName: mapImageName), mapImageName: mapImageName)
    }

    /// Preserves authored coordinates and numbering, independent of feature order.
    public static func towerSlots(from data: Data, mapImageName: String) throws -> [TowerSlot] {
        struct Collection: Decodable { let features: [Feature] }
        struct Feature: Decodable {
            struct Properties: Decodable {
                let kind: String?
                let category: String?
                let slotIndex: Int?
                let slotNumber: Int?
            }
            struct Geometry: Decodable { let type: String; let coordinates: [Double] }
            let properties: Properties
            let geometry: Geometry?
            enum CodingKeys: CodingKey { case properties, geometry }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                properties = try container.decode(Properties.self, forKey: .properties)
                geometry = properties.kind == "tower_slot"
                    ? try container.decode(Geometry.self, forKey: .geometry) : nil
            }
        }
        let collection = try JSONDecoder().decode(Collection.self, from: data)
        var numbered: [(index: Int, point: Point)] = []
        for feature in collection.features where feature.properties.kind == "tower_slot" {
            let p = feature.properties
            guard p.category == "gameplay", let geometry = feature.geometry,
                  geometry.type == "Point", geometry.coordinates.count == 2,
                  geometry.coordinates.allSatisfy(\.isFinite) else {
                throw DbError.Db(message: "\(mapImageName): tower slots need finite gameplay Point coordinates")
            }
            // Both exported formats number slots. Support legacy one-based-only files.
            guard p.slotNumber.map({ $0 > 0 }) ?? true,
                  let index = p.slotIndex ?? p.slotNumber.map({ $0 - 1 }), index >= 0,
                  p.slotNumber.map({ $0 - 1 == index }) ?? true else {
                throw DbError.Db(message: "\(mapImageName): tower slots need matching nonnegative indices and one-based numbers")
            }
            numbered.append((index, Point(geometry.coordinates[0], geometry.coordinates[1])))
        }
        numbered.sort { $0.index < $1.index }
        guard numbered.map(\.index) == Array(0..<numbered.count) else {
            throw DbError.Db(message: "\(mapImageName): tower slot indices must be unique and contiguous from zero")
        }
        return numbered.map { slot in
            // Stable per-map identities survive reloads, moves and feature reordering.
            var bytes = Array(SHA256.hash(data: Data("\(mapImageName)/tower_slot/\(slot.index)".utf8)).prefix(16))
            bytes[6] = (bytes[6] & 0x0f) | 0x80
            bytes[8] = (bytes[8] & 0x3f) | 0x80
            let id = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
            return TowerSlot(id: id, position: slot.point)
        }
    }

    public func getEntrancePoints(mapImageName: String) throws -> [EntrancePoint] {
        try points(kind: "spawn_point", mapImageName: mapImageName)
    }

    public func getExitPoints(mapImageName: String) throws -> [EntrancePoint] {
        try points(kind: "goal_point", mapImageName: mapImageName)
    }

    /// Explicit routes take precedence over legacy SQL waypoints. A malformed
    /// export fails loading; it must never silently fall back to stale routes.
    public func getEnemyRoutes(mapImageName: String) throws -> [EnemyRoute]? {
        try Self.enemyRoutes(from: data(mapImageName: mapImageName))
    }

    public static func enemyRoutes(from data: Data) throws -> [EnemyRoute]? {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else {
            throw DbError.Db(message: "Level GeoJSON has no features array")
        }
        let routeFeatures = features.filter { ($0["properties"] as? [String: Any])?["kind"] as? String == "enemy_route" }
        guard !routeFeatures.isEmpty else { return nil }
        func marker(_ id: String, kind: String) throws -> Point {
            let matches = features.filter { $0["id"] as? String == id }
            guard matches.count == 1, let f = matches.first,
                  (f["properties"] as? [String: Any])?["kind"] as? String == kind,
                  let geometry = f["geometry"] as? [String: Any], geometry["type"] as? String == "Point",
                  let xy = geometry["coordinates"] as? [Double], xy.count == 2, xy.allSatisfy(\.isFinite) else {
                throw DbError.Db(message: "Enemy route references a missing or invalid \(kind) marker: \(id)")
            }
            return Point(xy[0], xy[1])
        }
        let area = try HeroMovementArea(geoJSON: data, defaultPathWidth: 140)
        var routes: [EnemyRoute] = []
        for f in routeFeatures {
            guard let props = f["properties"] as? [String: Any], props["category"] as? String == "gameplay",
                  let indexValue = props["pathIndex"] else {
                throw DbError.Db(message: "Enemy routes require a gameplay pathIndex")
            }
            let index = try JSONDecoder().decode(Int.self, from: JSONSerialization.data(withJSONObject: indexValue, options: .fragmentsAllowed))
            guard index >= 0, let name = props["name"] as? String,
                  let entranceID = props["entranceID"] as? String, let exitID = props["exitID"] as? String,
                  let geometry = f["geometry"] as? [String: Any], geometry["type"] as? String == "LineString",
                  let xy = geometry["coordinates"] as? [[Double]], xy.count >= 2,
                  xy.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }) else {
                throw DbError.Db(message: "Enemy routes need named LineStrings, finite waypoints and entrance/exit references")
            }
            let points = xy.map { Point($0[0], $0[1]) }
            guard Set(points).count >= 2,
                  points.first == (try marker(entranceID, kind: "spawn_point")),
                  points.last == (try marker(exitID, kind: "goal_point")),
                  zip(points, points.dropFirst()).allSatisfy({ area.containsSegment(from: $0.0, to: $0.1) }) else {
                throw DbError.Db(message: "Enemy route \(index) must start/end at its markers and remain entirely inside the path area")
            }
            routes.append(EnemyRoute(index: index, name: name, entranceID: entranceID, exitID: exitID, points: points))
        }
        routes.sort { $0.index < $1.index }
        guard routes.map(\.index) == Array(0..<routes.count) else {
            throw DbError.Db(message: "Enemy route indices must be unique and contiguous from zero")
        }
        let indices = Set(routes.map(\.index))
        for wave in root["waves"] as? [[String: Any]] ?? [] {
            for line in wave["lines"] as? [[String: Any]] ?? [] {
                guard let index = line["pathIndex"] as? Int, indices.contains(index) else {
                    throw DbError.Db(message: "Wave references an undefined enemy route")
                }
            }
        }
        for feature in features where (feature["properties"] as? [String: Any])?["kind"] as? String == "call_wave_button" {
            if let selected = (feature["properties"] as? [String: Any])?["pathIndices"] as? [Int],
               !Set(selected).isSubset(of: indices) {
                throw DbError.Db(message: "Call wave button references an undefined enemy route")
            }
        }
        return routes
    }

    public func getHeroMovementArea(mapImageName: String, defaultPathWidth: Double) throws -> HeroMovementArea {
        try HeroMovementArea(geoJSON: data(mapImageName: mapImageName), defaultPathWidth: defaultPathWidth)
    }

    public func getHeroConfiguration(mapImageName: String) throws -> LevelHeroConfiguration {
        try Self.heroConfiguration(from: data(mapImageName: mapImageName))
    }

    public static func heroConfiguration(from data: Data) throws -> LevelHeroConfiguration {
        struct Header: Decodable { let heroCount: Int }
        let heroCount = try JSONDecoder().decode(Header.self, from: data).heroCount
        guard let collection = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = collection["features"] as? [[String: Any]] else {
            throw DbError.Db(message: "Level GeoJSON has no features array")
        }
        var spawns: [HeroSpawn] = []
        var spawnIDs = Set<String>()
        for feature in features {
            guard let props = feature["properties"] as? [String: Any] else { continue }
            let rawRoles = props["heroRoles"]
            let kind = props["kind"] as? String
            guard kind == "hero_spawn" else {
                if let rawRoles, (rawRoles as? [String]) != [] {
                    throw DbError.Db(message: "Hero roles require hero_spawn points. Open this map in the level editor and export it again.")
                }
                continue
            }
            guard let id = feature["id"] as? String, !id.isEmpty,
                  spawnIDs.insert(id).inserted,
                  let geometry = feature["geometry"] as? [String: Any],
                  geometry["type"] as? String == "Point",
                  let xy = geometry["coordinates"] as? [Double], xy.count == 2,
                  xy.allSatisfy(\.isFinite) else {
                throw DbError.Db(message: "Hero starts need unique IDs and finite Point coordinates")
            }
            guard let rawRoles else { throw DbError.Db(message: "Hero starting points need exactly one role") }
            guard let rolesArray = rawRoles as? [Any] else {
                throw DbError.Db(message: "heroRoles must be an array of primary/secondary roles")
            }
            let roles = try JSONDecoder().decode([HeroSelection.Role].self,
                from: JSONSerialization.data(withJSONObject: rolesArray))
            if roles.count != 1 {
                throw DbError.Db(message: "Hero starting points need exactly one role")
            }
            spawns += roles.map { HeroSpawn(role: $0, featureID: id, position: Point(xy[0], xy[1])) }
        }
        return try LevelHeroConfiguration(heroCount: heroCount, spawns: spawns)
    }

    public func getCallWaveButtonPositions(mapImageName: String) throws -> [Point] {
        try Self.callWaveButtonPositions(from: data(mapImageName: mapImageName))
    }

    public func getCallWaveButtons(mapImageName: String) throws -> [CallWaveButtonPosition] {
        try Self.callWaveButtons(from: data(mapImageName: mapImageName))
    }

    public static func callWaveButtonPositions(from data: Data) throws -> [Point] {
        try callWaveButtons(from: data).map(\.position)
    }

    public static func callWaveButtons(from data: Data) throws -> [CallWaveButtonPosition] {
        let root = try JSONSerialization.jsonObject(with: data)
        guard let collection = root as? [String: Any],
              let features = collection["features"] as? [[String: Any]] else {
            throw DbError.Db(message: "Level GeoJSON has no features array")
        }
        let positions = try features.compactMap { feature -> CallWaveButtonPosition? in
            guard let props = feature["properties"] as? [String: Any],
                  props["kind"] as? String == "call_wave_button" else { return nil }
            guard let geometry = feature["geometry"] as? [String: Any],
                  geometry["type"] as? String == "Point",
                  let xy = geometry["coordinates"] as? [Double], xy.count == 2,
                  xy.allSatisfy(\.isFinite) else {
                throw DbError.Db(message: "Call wave buttons need finite Point coordinates")
            }
            var pathIndices: [Int]?
            if let raw = props["pathIndices"] {
                guard let array = raw as? [Any] else {
                    throw DbError.Db(message: "Call wave button path indices must be an array")
                }
                pathIndices = try JSONDecoder().decode([Int].self, from: JSONSerialization.data(withJSONObject: array))
                guard let paths = pathIndices, !paths.isEmpty,
                      paths.allSatisfy({ $0 >= 0 }), Set(paths).count == paths.count else {
                    throw DbError.Db(message: "Call wave button path indices must be nonempty, unique and nonnegative")
                }
            }
            return CallWaveButtonPosition(position: Point(xy[0], xy[1]), pathIndices: pathIndices)
        }
        guard !positions.isEmpty else {
            throw DbError.Db(message: "Place a call wave button in the level editor and export the GeoJSON")
        }
        return positions
    }

    private func data(mapImageName: String) throws -> Data {
        if let directory {
            return try Data(contentsOf: directory.appendingPathComponent(mapImageName).appendingPathExtension("geojson"))
        }
        guard let url = bundle.url(forResource: mapImageName, withExtension: "geojson") else {
            throw DbError.Db(message: "\(mapImageName).geojson is not in the app bundle")
        }
        return try Data(contentsOf: url)
    }

    private func points(kind: String, mapImageName: String) throws -> [EntrancePoint] {
        let root = try JSONSerialization.jsonObject(with: data(mapImageName: mapImageName))
        guard let collection = root as? [String: Any],
              let features = collection["features"] as? [[String: Any]] else {
            throw DbError.Db(message: "\(mapImageName).geojson has no features array")
        }
        return features.compactMap { f in
            guard let props = f["properties"] as? [String: Any], props["kind"] as? String == kind,
                  let geometry = f["geometry"] as? [String: Any], geometry["type"] as? String == "Point",
                  let c = geometry["coordinates"] as? [Double], c.count >= 2 else { return nil }
            let pathIndex = (props["pathIndex"] as? NSNumber)?.intValue ?? 0
            return EntrancePoint(position: Point(c[0], c[1]), pathIndex: pathIndex)
        }
    }
}
