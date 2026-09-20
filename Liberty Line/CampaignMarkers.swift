import SwiftUI

extension CampaignProgress.State {
    var assetName: String { "campaign_marker_\(rawValue)" }

    var accessibilityValue: String {
        switch self {
        case .completed: return "Completed"
        case .current: return "Current battle"
        case .upcoming: return "Upcoming battle"
        }
    }
}

enum CampaignMarkers {
    typealias State = CampaignProgress.State

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

    static func placements(for nodes: [CampaignNode], bestStarsByLevel: [UUID: Int], viewSize: CGSize) -> [Placement] {
        guard viewSize.width > 0, viewSize.height > 0, !nodes.isEmpty else { return [] }

        let scale = scale(for: viewSize)
        let states: [State]
        do {
            let levelIDs = try nodes.map { node in
                guard let id = node.levelInfoID else {
                    throw DbError.Db(message: "campaign node[\(node.id)]: missing level_info_id")
                }
                return id
            }
            states = try CampaignProgress.states(orderedLevelIDs: levelIDs, bestStarsByLevel: bestStarsByLevel)
        } catch {
            fatalError("Campaign progress database error: \(error)")
        }
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
    static let lightInk = Color(red: 1, green: 0.956, blue: 0.792)
    static let darkInk = Color(red: 0.208, green: 0.141, blue: 0.078)
    static let tether = Color(red: 0.353, green: 0.290, blue: 0.165)
}

struct CampaignLevelMarker: View {
    var placement: CampaignMarkers.Placement
    var scale: CGFloat

    var body: some View {
        let d = placement.diameter
        ZStack {
            CampaignButtonArt(name: placement.state.assetName)
            Text("\(placement.node.id)")
                .font(Font(CampaignMarkers.numberFont(scale: scale, state: placement.state)))
                .foregroundStyle(placement.state == .upcoming
                    ? MarkerPalette.darkInk : MarkerPalette.lightInk)
        }
        .frame(width: d, height: d)
        .contentShape(Circle())
        .shadow(color: .black.opacity(0.45), radius: 2 * scale, y: 1.5 * scale)
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
