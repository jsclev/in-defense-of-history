import Foundation

enum HudLocation: CaseIterable {
    case northWest, north, northEast
    case west, east
    case southWest, south, southEast
}

enum HudSection: CaseIterable {
    case heroBar, statsView, miscView, masterControls
}

struct HudLayoutConfig {
    let heroBar: HudLocation
    let statsView: HudLocation
    let miscView: HudLocation
    let masterControls: HudLocation

    static let standard = HudLayoutConfig(heroBar: .northEast,
                                          statsView: .north,
                                          miscView: .northWest,
                                          masterControls: .southWest)

    init(heroBar: HudLocation, statsView: HudLocation,
         miscView: HudLocation, masterControls: HudLocation) {
        precondition(Set([heroBar, statsView, miscView, masterControls]).count
                     == HudSection.allCases.count,
                     "Every HUD section needs its own location")
        self.heroBar = heroBar
        self.statsView = statsView
        self.miscView = miscView
        self.masterControls = masterControls
    }

    func section(at hudLocation: HudLocation) -> HudSection? {
        if hudLocation == heroBar { return .heroBar }
        if hudLocation == statsView { return .statsView }
        if hudLocation == miscView { return .miscView }
        if hudLocation == masterControls { return .masterControls }
        return nil
    }
}
