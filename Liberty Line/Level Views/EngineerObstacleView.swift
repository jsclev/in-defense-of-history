import SwiftUI

/// Broad sharpened timbers over a continuous earth footprint. The footprint
/// matches the actual slowdown area; tiny stakes or texture carry no state.
struct EngineerObstacleView: View {
    let radius: CGFloat
    var selected = false

    var body: some View {
        let height = radius * 2 * TowerAttackRange.verticalFraction
        ZStack {
            Ellipse().fill(Color(red: 0.36, green: 0.22, blue: 0.08).opacity(0.30))
                .overlay(Ellipse().stroke(Color(red: 0.96, green: 0.70, blue: 0.27)
                    .opacity(selected ? 0.95 : 0.45), lineWidth: selected ? 2 : 1))
            Canvas { context, size in
                func polygon(_ points: [CGPoint]) -> SwiftUI.Path {
                    var path = SwiftUI.Path()
                    path.addLines(points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                    path.closeSubpath()
                    return path
                }
                func timber(_ points: [CGPoint], light: Color, dark: Color) {
                    let path = polygon(points)
                    context.fill(path, with: .linearGradient(Gradient(colors: [light, dark]),
                        startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
                    context.stroke(path, with: .color(Color(red: 0.20, green: 0.12, blue: 0.08)),
                                   style: StrokeStyle(lineWidth: max(1, size.width * 0.035), lineJoin: .round))
                }
                // One heavy crossbeam and three large cut ends communicate
                // timber barricades even when each stake is only ten points wide.
                timber([CGPoint(x: 0.04, y: 0.64), CGPoint(x: 0.89, y: 0.59),
                        CGPoint(x: 0.96, y: 0.81), CGPoint(x: 0.09, y: 0.88)],
                       light: Color(red: 0.73, green: 0.39, blue: 0.13),
                       dark: Color(red: 0.40, green: 0.21, blue: 0.09))
                for offset in [0.0, 0.30, 0.60] {
                    timber([CGPoint(x: 0.09 + offset, y: 0.81), CGPoint(x: 0.13 + offset, y: 0.28),
                            CGPoint(x: 0.25 + offset, y: 0.07), CGPoint(x: 0.31 + offset, y: 0.30),
                            CGPoint(x: 0.27 + offset, y: 0.80)],
                           light: Color(red: 1, green: 0.74, blue: 0.32),
                           dark: Color(red: 0.65, green: 0.32, blue: 0.10))
                    context.fill(polygon([CGPoint(x: 0.14 + offset, y: 0.29),
                        CGPoint(x: 0.25 + offset, y: 0.10), CGPoint(x: 0.30 + offset, y: 0.31),
                        CGPoint(x: 0.21 + offset, y: 0.40)]),
                        with: .color(Color(red: 1, green: 0.85, blue: 0.53)))
                }
            }
            .frame(width: radius * 1.65, height: height * 0.85)
        }
        .frame(width: radius * 2, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Engineer timber obstacles")
        .accessibilityHint("Slow advancing enemies inside the earth footprint")
        .allowsHitTesting(false)
    }
}
