import Foundation
import CoreGraphics

public enum HudLocation: String, CaseIterable, Sendable {
    case northWest = "north_west"
    case north = "north"
    case northEast = "north_east"
    case west = "west"
    case east = "east"
    case southWest = "south_west"
    case south = "south"
    case southEast = "south_east"
}

public enum HudSection: String, CaseIterable, Sendable {
    case heroBar = "hero_bar"
    case statsView = "stats_view"
    case miscView = "misc_view"
    case masterControls = "master_controls"
}

public struct HudLayoutConfig: Equatable, Sendable {
    public let heroBar: HudLocation
    public let statsView: HudLocation
    public let miscView: HudLocation
    public let masterControls: HudLocation

    public static let standard = HudLayoutConfig(heroBar: .northEast,
                                                 statsView: .north,
                                                 miscView: .northWest,
                                                 masterControls: .southWest)

    public init(heroBar: HudLocation, statsView: HudLocation,
                miscView: HudLocation, masterControls: HudLocation) {
        precondition(Set([heroBar, statsView, miscView, masterControls]).count
                     == HudSection.allCases.count,
                     "Every HUD section needs its own location")
        self.heroBar = heroBar
        self.statsView = statsView
        self.miscView = miscView
        self.masterControls = masterControls
    }

    public func section(at hudLocation: HudLocation) -> HudSection? {
        if hudLocation == heroBar { return .heroBar }
        if hudLocation == statsView { return .statsView }
        if hudLocation == miscView { return .miscView }
        if hudLocation == masterControls { return .masterControls }
        return nil
    }

    public func location(of hudSection: HudSection) -> HudLocation {
        switch hudSection {
        case .heroBar: return heroBar
        case .statsView: return statsView
        case .miscView: return miscView
        case .masterControls: return masterControls
        }
    }

    /// Matches HudView's independent overlay anchors, for sprite avoidance.
    public func frame(for section: HudSection, size: CGSize, in hud: CGRect) -> CGRect {
        let location = location(of: section)
        let x: CGFloat
        let y: CGFloat
        switch location {
        case .northWest, .west, .southWest: x = hud.minX
        case .north, .south: x = hud.midX - size.width / 2
        case .northEast, .east, .southEast: x = hud.maxX - size.width
        }
        switch location {
        case .northWest, .north, .northEast: y = hud.minY
        case .west, .east: y = hud.midY - size.height / 2
        case .southWest, .south, .southEast: y = hud.maxY - size.height
        }
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    public func moving(_ hudSection: HudSection, to hudLocation: HudLocation) -> HudLayoutConfig {
        let vacated = location(of: hudSection)
        guard vacated != hudLocation else { return self }

        let displaced = section(at: hudLocation)
        func relocated(_ candidate: HudSection) -> HudLocation {
            if candidate == hudSection { return hudLocation }
            if candidate == displaced { return vacated }
            return location(of: candidate)
        }

        return HudLayoutConfig(heroBar: relocated(.heroBar),
                               statsView: relocated(.statsView),
                               miscView: relocated(.miscView),
                               masterControls: relocated(.masterControls))
    }
}
