import Foundation

public struct EntrancePoint: Sendable, Equatable {
    public let position: Point
    public let pathIndex: Int
}

public class LevelGeoJSONDAO {
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func getEntrancePoints(mapImageName: String) throws -> [EntrancePoint] {
        try points(kind: "spawn_point", mapImageName: mapImageName)
    }

    public func getExitPoints(mapImageName: String) throws -> [EntrancePoint] {
        try points(kind: "goal_point", mapImageName: mapImageName)
    }

    private func points(kind: String, mapImageName: String) throws -> [EntrancePoint] {
        guard let url = bundle.url(forResource: mapImageName, withExtension: "geojson") else {
            throw DbError.Db(message: "\(mapImageName).geojson is not in the app bundle")
        }
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
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
