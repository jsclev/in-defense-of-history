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
            entrances: [Point], exits: [Point]) {
        let collection = try JSONDecoder().decode(Collection.self, from: data)

        var roads: [MapDraft.Road] = []
        var numberedSlots: [(number: Int, point: Point)] = []
        var entrances: [Point] = []
        var exits: [Point] = []

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

            default:
                continue
            }
        }

        numberedSlots.sort { $0.number < $1.number }
        return (roads, numberedSlots.map(\.point), entrances, exits)
    }

    /// A full draft from a GeoJSON, for opening one directly in the editor.
    static func draft(from data: Data) throws -> MapDraft {
        let (roads, slots, entrances, exits) = try geometry(from: data)
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
}
