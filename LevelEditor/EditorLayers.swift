import SwiftUI

enum EditorLayer: String, CaseIterable, Identifiable {
    case background
    case mapGuide
    case path
    case slots
    case exits
    case entrances
    case occlusion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .background: "Background"
        case .mapGuide: "Guide"
        case .path: "Path"
        case .slots: "Tower Slots"
        case .exits: "Exits"
        case .entrances: "Entrances"
        case .occlusion: "Occlusion"
        }
    }

    var icon: String {
        switch self {
        case .background: "photo"
        case .mapGuide: "map"
        case .path: "point.topleft.down.to.point.bottomright.curvepath"
        case .slots: "circle.grid.cross"
        case .exits: "flag.checkered"
        case .entrances: "arrow.right.circle"
        case .occlusion: "square.2.layers.3d.top.filled"
        }
    }

    static var panelOrder: [EditorLayer] { allCases.reversed() }
}

extension EditorTool {
    var layer: EditorLayer? {
        switch self {
        case .brush: .path
        case .slot: .slots
        case .entrance: .entrances
        case .exitPoint: .exits
        case .select: nil
        }
    }

    var title: String {
        switch self {
        case .select: "Select"
        case .brush: "Path tool"
        case .slot: "Slot placer"
        case .entrance: "Entrance placer"
        case .exitPoint: "Exit placer"
        }
    }
}
