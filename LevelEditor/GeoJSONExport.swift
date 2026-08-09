import Foundation
import CoreGraphics
import UniformTypeIdentifiers

extension UTType {
    static let geoJSON = UTType(exportedAs: "com.zippyzen.td.geojson")
}

enum GeoJSONExport {
    static func data(for draft: MapDraft) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document(for: draft))
    }

    static func filename(for draft: MapDraft) -> String {
        let base = draft.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
            .lowercased()
        return (base.isEmpty ? "untitled_map" : base) + ".geojson"
    }

    static func document(for draft: MapDraft) -> FeatureCollection {
        var features: [Feature] = []

        for (ri, road) in draft.roads.enumerated() where road.points.count >= 2 {
            let isPrimary = ri == 0
            features.append(Feature(
                id: isPrimary ? "gameplay.road" : "gameplay.road.\(ri)",
                name: road.name,
                category: "gameplay",
                kind: "enemy_path",
                layer: 40,
                geometry: .lineString(road.points),
                extra: [
                    "widthPx": .number((road.resolvedHalfWidths.reduce(0, +)
                                        / Double(road.points.count)) * 2),
                    "pathIndex": .number(Double(ri)),
                    "painted": .bool(road.halfWidths != nil),
                ]
            ))

            let edge = road.outerEdge
            if edge.count >= 4 {
                features.append(Feature(
                    id: isPrimary ? "gameplay.road_edge" : "gameplay.road_edge.\(ri)",
                    name: "\(road.name) outer edge",
                    category: "gameplay",
                    kind: "enemy_path_edge",
                    layer: 39,
                    geometry: .polygon(edge),
                    extra: ["pathIndex": .number(Double(ri))]
                ))
            }

            if let spawn = road.points.first {
                features.append(Feature(
                    id: isPrimary ? "gameplay.entry" : "gameplay.entry.\(ri)",
                    name: "Spawn",
                    category: "gameplay",
                    kind: "spawn_point",
                    layer: 75,
                    geometry: .point(spawn),
                    extra: ["pathIndex": .number(Double(ri))]
                ))
            }
            if let goal = road.points.last {
                features.append(Feature(
                    id: isPrimary ? "gameplay.exit" : "gameplay.exit.\(ri)",
                    name: "Goal",
                    category: "gameplay",
                    kind: "goal_point",
                    layer: 75,
                    geometry: .point(goal),
                    extra: ["pathIndex": .number(Double(ri))]
                ))
            }
        }

        for (i, slot) in draft.slots.enumerated() {
            features.append(Feature(
                id: "gameplay.tower_slot.\(i + 1)",
                name: "Tower slot \(i + 1)",
                category: "gameplay",
                kind: "tower_slot",
                layer: 75,
                geometry: .point(slot),
                extra: [
                    "slotIndex": .number(Double(i)),
                    "slotNumber": .number(Double(i + 1)),
                ]
            ))
        }

        return FeatureCollection(
            name: SwiftExport.identifier(from: draft.name),
            crs: CRS(),
            features: features
        )
    }

    struct FeatureCollection: Encodable {
        var type = "FeatureCollection"
        var name: String
        var crs: CRS
        var features: [Feature]

        enum CodingKeys: String, CodingKey {
            case type, name, features
            case crs = "coordinateReferenceSystem"
        }
    }

    struct CRS: Encodable {
        struct Size: Encodable {
            var width: Double
            var height: Double
        }
        struct Rect: Encodable {
            var x: Double
            var y: Double
            var width: Double
            var height: Double
        }
        var type = "local-cartesian"
        var note = "NOT WGS84. [x, y] in canonical game units, origin LOWER-LEFT, +y UP. "
            + "The same space the LevelEditor, Simulator and game all use; nothing rescales."
        var canvas = Size(width: CanvasSpec.width, height: CanvasSpec.height)
        var playableRect = Rect(x: CanvasSpec.playable.minX,
                                y: CanvasSpec.playable.minY,
                                width: CanvasSpec.playable.width,
                                height: CanvasSpec.playable.height)
    }

    enum Geometry {
        case point(Point)
        case lineString([Point])
        case polygon([Point])
    }

    enum JSONValue: Encodable {
        case number(Double)
        case string(String)
        case bool(Bool)

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case let .number(v): try c.encode(v)
            case let .string(v): try c.encode(v)
            case let .bool(v): try c.encode(v)
            }
        }
    }

    struct Feature: Encodable {
        var type = "Feature"
        var id: String
        var name: String
        var category: String
        var kind: String
        var layer: Int
        var geometry: Geometry
        var extra: [String: JSONValue] = [:]

        enum CodingKeys: String, CodingKey {
            case type, geometry, properties
        }

        enum PropertyKeys: String, CodingKey {
            case id, name, category, kind, layer, playable, insidePlayableRect
        }

        struct DynamicKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(type, forKey: .type)

            var g = c.nestedContainer(keyedBy: DynamicKey.self, forKey: .geometry)
            switch geometry {
            case let .point(p):
                try g.encode("Point", forKey: DynamicKey(stringValue: "type")!)
                try g.encode(coords(p), forKey: DynamicKey(stringValue: "coordinates")!)
            case let .lineString(pts):
                try g.encode("LineString", forKey: DynamicKey(stringValue: "type")!)
                try g.encode(pts.map(coords), forKey: DynamicKey(stringValue: "coordinates")!)
            case let .polygon(ring):
                try g.encode("Polygon", forKey: DynamicKey(stringValue: "type")!)
                var closed = ring.map(coords)
                if let first = closed.first, closed.last != first { closed.append(first) }
                try g.encode([closed], forKey: DynamicKey(stringValue: "coordinates")!)
            }

            var p = c.nestedContainer(keyedBy: DynamicKey.self, forKey: .properties)
            try p.encode(id, forKey: DynamicKey(stringValue: "id")!)
            try p.encode(name, forKey: DynamicKey(stringValue: "name")!)
            try p.encode(category, forKey: DynamicKey(stringValue: "category")!)
            try p.encode(kind, forKey: DynamicKey(stringValue: "kind")!)
            try p.encode(layer, forKey: DynamicKey(stringValue: "layer")!)
            try p.encode(true, forKey: DynamicKey(stringValue: "playable")!)
            try p.encode(insidePlayableRect,
                         forKey: DynamicKey(stringValue: "insidePlayableRect")!)
            for key in extra.keys.sorted() {
                try p.encode(extra[key]!, forKey: DynamicKey(stringValue: key)!)
            }
        }

        private var insidePlayableRect: Bool {
            let pts: [Point] = switch geometry {
            case let .point(p): [p]
            case let .lineString(ps): ps
            case let .polygon(ps): ps
            }
            return pts.allSatisfy {
                CanvasSpec.playable.contains(CGPoint(x: $0.x, y: $0.y))
            }
        }

        private func coords(_ p: Point) -> [Double] {
            [round(p.x * 100) / 100, round(p.y * 100) / 100]
        }
    }
}
