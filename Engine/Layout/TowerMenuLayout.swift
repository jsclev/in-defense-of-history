import Foundation
import CoreGraphics
import SwiftUI

public struct TowerMenuLayout {
    private let virtualCanvas: VirtualCanvas
    
    private let bgScalingFactor: CGFloat = 0.41
    private let towerButtonScalingFactor: CGFloat = 0.145
    private let towerIconScalingFactor: CGFloat = 0.66
    private let towerButtonOffsetFactor: CGFloat = 4.0
    private let buttonAngleDegrees: [TowerKind: CGFloat] = [
        TowerKind.ranged: 140,
        TowerKind.melee: 40,
        TowerKind.special: 220,
        TowerKind.areaOfEffect: 320
    ]
    
    public init(virtualCanvas: VirtualCanvas) {
        self.virtualCanvas = virtualCanvas
    }

    public func getBgSize(playAreaScalingFactor: CGFloat) -> CGSize {
        let side = virtualCanvas.playAreaRect.height * playAreaScalingFactor * bgScalingFactor
        return CGSize(width: side, height: side)
    }

    public func getTowerButtonSize(playAreaScalingFactor: CGFloat) -> CGSize {
        let side = virtualCanvas.playAreaRect.height * playAreaScalingFactor * towerButtonScalingFactor
        return CGSize(width: side, height: side)
    }
    
    public func getTowerIconSize(towerButtonSize: CGFloat) -> CGFloat {
        return towerButtonSize * towerIconScalingFactor
    }

    public func getCenterPoint(anchor: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: anchor.x,
                y: anchor.y)
    }

    public func getTowerButtonCenterPoint(towerKind: TowerKind,
                                                 menuCenterPoint: CGPoint,
                                                 playAreaScalingFactor: CGFloat,
                                                 towerButtonSize: CGFloat) -> CGPoint {
        getButtonCenterPoint(degrees: buttonAngleDegrees[towerKind]!,
                             menuCenterPoint: menuCenterPoint,
                             playAreaScalingFactor: playAreaScalingFactor,
                             towerButtonSize: towerButtonSize)
    }

    public func getButtonCenterPoint(index: Int, count: Int,
                                            menuCenterPoint: CGPoint,
                                            playAreaScalingFactor: CGFloat,
                                            towerButtonSize: CGFloat) -> CGPoint {
        let degrees = 90 - 360 * CGFloat(index) / CGFloat(max(count, 1))
        return getButtonCenterPoint(degrees: degrees,
                                    menuCenterPoint: menuCenterPoint,
                                    playAreaScalingFactor: playAreaScalingFactor,
                                    towerButtonSize: towerButtonSize)
    }

    private func getButtonCenterPoint(degrees: CGFloat,
                                             menuCenterPoint: CGPoint,
                                             playAreaScalingFactor: CGFloat,
                                             towerButtonSize: CGFloat) -> CGPoint {
        let menuRadius = getBgSize(playAreaScalingFactor: playAreaScalingFactor).width / 2
        let distanceFromCenter = menuRadius - (towerButtonSize / towerButtonOffsetFactor)
        let radians = degrees * .pi / 180
        return CGPoint(x: menuCenterPoint.x + distanceFromCenter * cos(radians),
                       y: menuCenterPoint.y - distanceFromCenter * sin(radians))
    }

    private static let towerIconFraction: CGFloat = 0.625

    public var menuAnchorLift: CGFloat {
        virtualCanvas.towerSlotSize.height / 2
    }

    public var menuMapExtent: (x: CGFloat, y: CGFloat) {
        let bg = getBgSize(playAreaScalingFactor: 1)
        let button = getTowerButtonSize(playAreaScalingFactor: 1).width
        var x = bg.width / 2, y = bg.height / 2
        for kind in TowerKind.allCases {
            let c = getTowerButtonCenterPoint(towerKind: kind, menuCenterPoint: .zero,
                                              playAreaScalingFactor: 1, towerButtonSize: button)
            x = max(x, abs(c.x) + button / 2)
            y = max(y, abs(c.y) + button / 2)
        }
        return (x, y)
    }

    public enum VerticalEdge {
        case top
        case bottom
    }

    public enum HorizontalEdge {
        case left
        case right
    }

    public func slotSafeInset(_ edge: VerticalEdge) -> CGFloat {
        switch edge {
        case .top, .bottom:
            menuMapExtent.y - virtualCanvas.towerSlotSize.height / 2
        }
    }

    public func slotSafeInset(_ edge: HorizontalEdge) -> CGFloat {
        switch edge {
        case .left, .right:
            menuMapExtent.x - virtualCanvas.towerSlotSize.width / 2
        }
    }

    public var slotMenuSafeShape: CGPath {
        let play = virtualCanvas.playAreaRect
        let left = play.minX + slotSafeInset(.left)
        let right = play.maxX - slotSafeInset(.right)
        let bottom = play.minY + slotSafeInset(.bottom)
        let top = play.maxY - slotSafeInset(.top)
        let shape = CGMutablePath()
        shape.addRect(CGRect(x: left, y: bottom,
                             width: right - left, height: top - bottom))
        let standoff = CGMutablePath()
        for corner in virtualCanvas.cornerOcclusionAreas {
            standoff.addRect(CGRect(
                x: corner.minX - slotSafeInset(.left),
                y: corner.minY - slotSafeInset(.top),
                width: corner.width + slotSafeInset(.left) + slotSafeInset(.right),
                height: corner.height + slotSafeInset(.top) + slotSafeInset(.bottom)))
        }
        return shape.subtracting(standoff, using: .winding)
    }
}
