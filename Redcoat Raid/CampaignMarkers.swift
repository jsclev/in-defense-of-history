import SwiftUI

enum CampaignProgress {
    static let completedThrough = 6

    static func state(forLevel id: Int) -> CampaignMarkers.State {
        if id <= completedThrough { return .completed }
        return id == completedThrough + 1 ? .current : .upcoming
    }
}

enum CampaignMarkers {
    enum State { case completed, current, upcoming }

    struct Placement: Identifiable {
        var id: Int
        var node: CampaignNode
        var state: State
        var anchor: CGPoint
        var center: CGPoint
        var diameter: CGFloat
        var showsTether: Bool

        var rect: CGRect {
            CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                   width: diameter, height: diameter)
        }
    }

    static let referenceHeight: CGFloat = 834

    static func scale(for viewSize: CGSize) -> CGFloat {
        min(max(viewSize.height / referenceHeight, 0.75), 1.35)
    }

    static func diameter(scale: CGFloat, state: State) -> CGFloat {
        let base = max(TouchTarget.minimum, 46 * scale)
        return state == .current ? base * 1.3 : base
    }

    static func numberFont(scale: CGFloat, state: State) -> UIFont {
        let size = (state == .current ? 29.5 : 23.9) * scale
        return UIFont(name: "Baskerville-Bold", size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
    }

    static func placements(for nodes: [CampaignNode], viewSize: CGSize) -> [Placement] {
        guard viewSize.width > 0, viewSize.height > 0, !nodes.isEmpty else { return [] }

        let scale = scale(for: viewSize)
        let states = nodes.map { CampaignProgress.state(forLevel: $0.id) }
        let diameters = states.map { diameter(scale: scale, state: $0) }
        let anchors = nodes.map {
            CampaignMapLayout.viewPoint(
                forImagePoint: $0.imagePosition,
                imageSize: CampaignMapAsset.imageSize,
                safeRect: CampaignMapAsset.safeRect,
                viewSize: viewSize
            )
        }

        let n = nodes.count
        let gap = 5 * scale
        let pull: CGFloat = 0.06
        var centers = anchors

        func separate() {
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let need = (diameters[i] + diameters[j]) / 2 + gap
                    var dx = centers[j].x - centers[i].x
                    var dy = centers[j].y - centers[i].y
                    var dist = hypot(dx, dy)
                    guard dist < need else { continue }
                    if dist < 0.0001 {
                        let angle = CGFloat(i * n + j)
                        dx = cos(angle); dy = sin(angle); dist = 1
                    }
                    let push = (need - dist) / 2
                    let ux = dx / dist, uy = dy / dist
                    centers[i].x -= ux * push; centers[i].y -= uy * push
                    centers[j].x += ux * push; centers[j].y += uy * push
                }
            }
        }

        func clampToView() {
            for i in 0..<n {
                let r = diameters[i] / 2 + 2
                centers[i].x = min(max(centers[i].x, r), viewSize.width - r)
                centers[i].y = min(max(centers[i].y, r), viewSize.height - r)
            }
        }

        for _ in 0..<240 {
            for i in 0..<n {
                centers[i].x += (anchors[i].x - centers[i].x) * pull
                centers[i].y += (anchors[i].y - centers[i].y) * pull
            }
            separate()
            clampToView()
        }
        for _ in 0..<80 {
            separate()
            clampToView()
        }

        return (0..<n).map { i in
            let drift = hypot(centers[i].x - anchors[i].x, centers[i].y - anchors[i].y)
            return Placement(id: nodes[i].id, node: nodes[i], state: states[i],
                             anchor: anchors[i], center: centers[i],
                             diameter: diameters[i],
                             showsTether: drift > diameters[i] * 0.55)
        }
    }
}

enum MarkerPalette {
    static let doneFill = Color(red: 0.373, green: 0.431, blue: 0.329)
    static let doneEdge = Color(red: 0.235, green: 0.282, blue: 0.208)
    static let doneInk = Color(red: 0.918, green: 0.886, blue: 0.784)
    static let brass = Color(red: 0.788, green: 0.643, blue: 0.271)
    static let brassLight = Color(red: 0.910, green: 0.784, blue: 0.408)
    static let navy = Color(red: 0.043, green: 0.141, blue: 0.267)
    static let currentInk = Color(red: 0.949, green: 0.894, blue: 0.737)
    static let upcomingFill = Color(red: 0.863, green: 0.816, blue: 0.682)
    static let upcomingEdge = Color(red: 0.541, green: 0.478, blue: 0.333)
    static let upcomingInk = Color(red: 0.416, green: 0.353, blue: 0.220)
    static let tether = Color(red: 0.353, green: 0.290, blue: 0.165)
}

struct CampaignLevelMarker: View {
    var placement: CampaignMarkers.Placement
    var scale: CGFloat

    var body: some View {
        let d = placement.diameter
        ZStack {
            switch placement.state {
            case .completed:
                Circle().fill(MarkerPalette.doneFill)
                Circle().strokeBorder(MarkerPalette.doneEdge, lineWidth: max(1.5, 2 * scale))
                Text("\(placement.node.id)")
                    .font(Font(CampaignMarkers.numberFont(scale: scale, state: .completed)))
                    .foregroundStyle(MarkerPalette.doneInk)

            case .current:
                Circle().fill(MarkerPalette.brass)
                Circle().fill(MarkerPalette.navy).padding(d * 0.10)
                Circle().strokeBorder(MarkerPalette.brassLight, lineWidth: max(1, 1.2 * scale))
                    .padding(d * 0.10)
                Text("\(placement.node.id)")
                    .font(Font(CampaignMarkers.numberFont(scale: scale, state: .current)))
                    .foregroundStyle(MarkerPalette.currentInk)

            case .upcoming:
                Circle().fill(MarkerPalette.upcomingFill)
                Circle().strokeBorder(MarkerPalette.upcomingEdge, lineWidth: max(1.4, 1.8 * scale))
                Text("\(placement.node.id)")
                    .font(Font(CampaignMarkers.numberFont(scale: scale, state: .upcoming)))
                    .foregroundStyle(MarkerPalette.upcomingInk)
            }
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.45), radius: 2 * scale, y: 1.5 * scale)
        .overlay {
            if placement.state == .current {
                Circle()
                    .stroke(MarkerPalette.brassLight.opacity(0.5),
                            lineWidth: max(1, 1.1 * scale))
                    .frame(width: d * 1.42, height: d * 1.42)
            }
        }
    }
}

struct CampaignMarkerTethers: Shape {
    var placements: [CampaignMarkers.Placement]

    func path(in rect: CGRect) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        for placement in placements where placement.showsTether {
            let dx = placement.anchor.x - placement.center.x
            let dy = placement.anchor.y - placement.center.y
            let length = hypot(dx, dy)
            guard length > 0.001 else { continue }
            let radius = placement.diameter / 2
            path.move(to: CGPoint(x: placement.center.x + dx / length * radius,
                                  y: placement.center.y + dy / length * radius))
            path.addLine(to: placement.anchor)
        }
        return path
    }
}

struct CampaignMarkerAnchors: View {
    var placements: [CampaignMarkers.Placement]
    var scale: CGFloat

    var body: some View {
        ForEach(placements.filter(\.showsTether)) { placement in
            Circle()
                .fill(MarkerPalette.tether)
                .frame(width: 4 * scale, height: 4 * scale)
                .position(placement.anchor)
        }
    }
}
