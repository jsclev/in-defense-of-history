import Foundation
import CoreGraphics

@main struct NavigationExport {
    static func main() throws {
        let width = Double(CommandLine.arguments[1])!
        var maps: [String: [[[Double]]]] = [:]
        for path in CommandLine.arguments.dropFirst(2) {
            let url = URL(fileURLWithPath: path)
            let area = try HeroMovementArea(geoJSON: Data(contentsOf: url), defaultPathWidth: width)
            var rings: [[[Double]]] = [], ring: [[Double]] = []
            area.boundaryPath.applyWithBlock { element in
                let e = element.pointee
                switch e.type {
                case .moveToPoint: ring = [[e.points[0].x, e.points[0].y]]
                case .addLineToPoint: ring.append([e.points[0].x, e.points[0].y])
                case .closeSubpath:
                    if ring.last != ring.first { ring.append(ring[0]) }
                    rings.append(ring)
                default: preconditionFailure("Expected flattened HeroMovementArea")
                }
            }
            maps[url.deletingPathExtension().lastPathComponent] = rings
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: maps, options: [.sortedKeys]))
    }
}
