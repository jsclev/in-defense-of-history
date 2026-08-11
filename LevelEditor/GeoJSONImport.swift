import Foundation

/// Reads a level's geographic data out of its GeoJSON.
///
/// The GeoJSON is the single source of truth for level geometry. The editor
/// reads roads and tower slots from it directly rather than from a second file
/// carrying its own copy of the same coordinates — a copy is how a render
/// source ended up describing a map that had already moved on.
///
/// Coordinates are used verbatim: the file is already in the canonical space
/// (`CanvasSpec`), which is the space the editor, the simulator and the game all
/// work in, so there is nothing to convert.
enum GeoJSONImport {
    struct Feature: Decodable {
        struct Geometry: Decodable {
            let type: String
            let coordinates: Coordinates
        }
        /// Point is `[x, y]`, LineString is `[[x, y], …]`. Only those two shapes
        /// carry gameplay geometry, so anything else decodes to `.other`.
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
        }
        let id: String?
        let geometry: Geometry
        let properties: Properties
    }

    struct Collection: Decodable {
        let name: String?
        let features: [Feature]
    }

    /// Roads and tower slots from `data`, in canonical coordinates.
    ///
    /// Slots come back in `slotNumber` order so the editor's slot indices match
    /// the numbering the level was authored and balanced against.
    static func geometry(from data: Data) throws -> (roads: [MapDraft.Road], slots: [Point]) {
        let collection = try JSONDecoder().decode(Collection.self, from: data)

        var roads: [MapDraft.Road] = []
        var numberedSlots: [(number: Int, point: Point)] = []

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

            default:
                continue
            }
        }

        numberedSlots.sort { $0.number < $1.number }
        return (roads, numberedSlots.map(\.point))
    }

    /// A full draft from a GeoJSON, for opening one directly in the editor.
    static func draft(from data: Data) throws -> MapDraft {
        let (roads, slots) = try geometry(from: data)
        guard !roads.isEmpty else {
            throw DbError.Db(message: "GeoJSON has no gameplay road to edit")
        }
        let collection = try JSONDecoder().decode(Collection.self, from: data)
        var draft = MapDraft.starter
        draft.name = collection.name ?? "Imported Level"
        draft.roads = roads
        draft.slots = slots
        draft.coordinateSpace = MapDraft.canvasSpace
        return draft
    }
}
