import Foundation

enum GeoJSONImport {
    struct Feature: Decodable {
        struct Geometry: Decodable {
            let type: String
            let coordinates: Coordinates
        }
        
        enum Coordinates: Decodable {
            case point([Double])
            case line([[Double]])
            case other

            init(from decoder: Decoder) throws {
                let c = try decoder.singleValueContainer()
                if let p = try? c.decode([Double].self) { self = .point(p); return }
                if let l = try? c.decode([[Double]].self) { self = .line(l); return }
                self = .other
            }
        }
        struct Properties: Decodable {
            let category: String?
            let kind: String?
            let name: String?
            let slotNumber: Int?
            let widthPx: Double?
            let erases: Bool?
            let pathIndices: [Int]?
        }
        let id: String?
        let geometry: Geometry
        let properties: Properties
    }

    struct SpawnLine: Decodable {
        let foe: String
        let count: Int
        let every: Double
        let delay: Double
        let pathIndex: Int
    }

    struct Wave: Decodable {
        let breather: Double
        let lines: [SpawnLine]
    }

    struct Collection: Decodable {
        let name: String?
        let features: [Feature]
        let waves: [Wave]?
    }

    /// Roads and tower slots from `data`, in canonical coordinates.
    ///
    /// Slots come back in `slotNumber` order so the editor's slot indices match
    /// the numbering the level was authored and balanced against.
    static func geometry(from data: Data) throws
        -> (roads: [MapDraft.Road], slots: [Point],
            entrances: [Point], exits: [Point], callWaveButtons: [CallWaveButtonPosition]) {
        let collection = try JSONDecoder().decode(Collection.self, from: data)

        var roads: [MapDraft.Road] = []
        var numberedSlots: [(number: Int, point: Point)] = []
        var entrances: [Point] = []
        var exits: [Point] = []
        var callWaveButtons: [CallWaveButtonPosition] = []

        for feature in collection.features {
            let props = feature.properties
            guard props.category == "gameplay" else { continue }

            switch (props.kind, feature.geometry.coordinates) {
            case let ("enemy_path", .line(points)),
                 let ("road", .line(points)):
                let waypoints = points.compactMap { xy -> Point? in
                    xy.count >= 2 ? Point(xy[0], xy[1]) : nil
                }
                guard waypoints.count >= 2 else { continue }
                roads.append(MapDraft.Road(name: props.name ?? "Road", points: waypoints))

            case let ("tower_slot", .point(xy)) where xy.count >= 2:
                numberedSlots.append((props.slotNumber ?? numberedSlots.count + 1,
                                      Point(xy[0], xy[1])))

            case let ("spawn_point", .point(xy)) where xy.count >= 2:
                entrances.append(Point(xy[0], xy[1]))

            case let ("goal_point", .point(xy)) where xy.count >= 2:
                exits.append(Point(xy[0], xy[1]))

            case let ("call_wave_button", .point(xy)) where xy.count >= 2:
                callWaveButtons.append(.init(position: Point(xy[0], xy[1]), pathIndices: props.pathIndices))

            default:
                continue
            }
        }

        numberedSlots.sort { $0.number < $1.number }
        return (roads, numberedSlots.map(\.point), entrances, exits, callWaveButtons)
    }

    /// A full draft from a GeoJSON, for opening one directly in the editor.
    static func draft(from data: Data) throws -> MapDraft {
        let data = try migrateHeroExits(in: data)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if root?["formatVersion"] != nil {
            let collection = try LevelGeoJSON(data: data).collection
            var draft = MapDraft.starter
            draft.name = collection.name
            draft.startingGold = collection.startingGold
            draft.lives = collection.lives
            draft.enemyRoutes = try LevelGeoJSONDAO.enemyRoutes(from: data) ?? []
            draft.flattenedPath = collection.features.first { $0.properties.kind == .path }?.geometry
            func points(_ kind: LevelGeoJSON.Kind) -> [Point] {
                var features = collection.features.filter { $0.properties.kind == kind }
                if kind == .towerSlot { features.sort { ($0.properties.slotIndex ?? 0) < ($1.properties.slotIndex ?? 0) } }
                return features.compactMap {
                        guard case let .point(p) = $0.geometry else { return nil }
                        return Point(p[0], p[1])
                    }
            }
            draft.entrances = points(.entrance)
            draft.exits = points(.exit)
            try applyHeroConfiguration(from: data, to: &draft)
            draft.callWaveButtons = collection.features.compactMap {
                guard $0.properties.kind == .callWaveButton,
                      case let .point(p) = $0.geometry else { return nil }
                return CallWaveButtonPosition(position: Point(p[0], p[1]), pathIndices: $0.properties.pathIndices)
            }
            draft.slots = points(.towerSlot)
            draft.waves = collection.waves.map { w in
                .init(breather: w.breather, lines: w.lines.map {
                    .init(foe: $0.foe, count: $0.count, every: $0.every, delay: $0.delay, road: $0.pathIndex)
                }, callButtonDelay: w.callButtonDelay, autoStartCountdown: w.autoStartCountdown,
                      earlyCallBonus: w.earlyCallBonus)
            }
            return draft
        }
        let (roads, slots, entrances, exits, callWaveButtons) = try geometry(from: data)
        guard !roads.isEmpty else {
            throw DbError.Db(message: "GeoJSON has no gameplay road to edit")
        }
        let collection = try JSONDecoder().decode(Collection.self, from: data)
        var draft = MapDraft.starter
        draft.name = collection.name ?? "Imported Level"
        draft.roads = roads
        draft.slots = slots
        draft.entrances = entrances
        draft.exits = exits
        try applyHeroConfiguration(from: data, to: &draft)
        draft.callWaveButtons = callWaveButtons

        draft.roadPaint = collection.features.compactMap { f in
            guard f.properties.kind == "road_paint", f.properties.erases != true,
                  case let .line(coords) = f.geometry.coordinates,
                  let width = f.properties.widthPx else { return nil }
            let points = coords.compactMap { xy -> Point? in
                xy.count >= 2 ? Point(xy[0], xy[1]) : nil
            }
            guard !points.isEmpty else { return nil }
            return MapDraft.PaintStroke(points: points, width: width, erases: false)
        }
        if let waves = collection.waves, !waves.isEmpty {
            draft.waves = waves.map { w in
                MapDraft.Wave(breather: w.breather, lines: w.lines.map { l in
                    MapDraft.SpawnLine(foe: l.foe, count: l.count, every: l.every,
                                       delay: l.delay, road: l.pathIndex)
                })
            }
        }
        draft.coordinateSpace = MapDraft.canvasSpace
        return draft
    }

    private static func applyHeroConfiguration(from data: Data, to draft: inout MapDraft) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["heroCount"] != nil else { return } // Old editor files remain importable.
        let configuration = try LevelGeoJSONDAO.heroConfiguration(from: data)
        draft.heroCount = configuration.heroCount
        for spawn in configuration.spawns {
            if spawn.role == .primary { draft.primaryHeroPosition = spawn.position }
            else { draft.secondaryHeroPosition = spawn.position }
        }
    }

    /// Editor-only compatibility: preserve old authored exit coordinates as
    /// independent points. The game accepts only explicit hero_spawn features.
    private static func migrateHeroExits(in data: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var features = root["features"] as? [[String: Any]] else { return data }
        var starts: [[String: Any]] = []
        for i in features.indices {
            guard var properties = features[i]["properties"] as? [String: Any],
                  properties["kind"] as? String == "goal_point",
                  let roles = properties["heroRoles"] as? [String], !roles.isEmpty,
                  let id = features[i]["id"] as? String else { continue }
            for role in roles {
                let spawnID = "\(id).hero.\(role)"
                var spawn = features[i]
                var spawnProperties = properties
                spawn["id"] = spawnID
                spawnProperties["id"] = spawnID
                spawnProperties["kind"] = "hero_spawn"
                spawnProperties["heroRoles"] = [role]
                spawnProperties.removeValue(forKey: "pathIndex")
                spawn["properties"] = spawnProperties
                starts.append(spawn)
            }
            properties.removeValue(forKey: "heroRoles")
            features[i]["properties"] = properties
        }
        guard !starts.isEmpty else { return data }
        root["features"] = features + starts
        return try JSONSerialization.data(withJSONObject: root)
    }
}
