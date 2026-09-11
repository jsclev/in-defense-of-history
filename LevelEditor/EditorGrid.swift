import Foundation

struct EditorGrid {
    struct Line {
        let position: Double
        let isMajor: Bool
    }

    let unit: Double
    let major: Double
    let origin: Point
    let lineSpacings: [Double]

    init(unit: Double, major: Double, origin: Point) {
        self.unit = unit
        self.major = major
        self.origin = origin
        lineSpacings = stride(from: unit, through: major, by: unit)
            .filter { major.truncatingRemainder(dividingBy: $0) == 0 }
    }

    func snap(_ point: Point) -> Point {
        Point(snap(point.x, origin: origin.x), snap(point.y, origin: origin.y))
    }

    func step(_ point: Point, dx: Double, dy: Double) -> Point {
        let snapped = snap(point)
        return Point(snapped.x + dx * unit, snapped.y + dy * unit)
    }

    func lineSpacing(scale: Double, minimumPixels: Double) -> Double {
        lineSpacings.first { $0 * scale >= minimumPixels } ?? major
    }

    func verticalLines(canvasWidth: Double, spacing: Double) -> [Line] {
        lines(through: canvasWidth, origin: origin.x, spacing: spacing)
    }

    func horizontalLines(canvasHeight: Double, spacing: Double) -> [Line] {
        lines(through: canvasHeight, origin: origin.y, spacing: spacing)
    }

    private func lines(through length: Double, origin: Double, spacing: Double) -> [Line] {
        var lines: [Line] = []
        var position = origin.truncatingRemainder(dividingBy: spacing)
        while position <= length {
            lines.append(Line(position: position,
                              isMajor: (position - origin).truncatingRemainder(dividingBy: major) == 0))
            position += spacing
        }
        return lines
    }

    private func snap(_ value: Double, origin: Double) -> Double {
        origin + ((value - origin) / unit).rounded() * unit
    }
}
