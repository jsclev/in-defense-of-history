import Foundation
import CoreGraphics
import SwiftUI

public enum TowerMenuLayout {
    private static let bgScalingFactor: CGFloat = 0.41
    private static let towerButtonScalingFactor: CGFloat = 0.145
    private static let towerIconScalingFactor: CGFloat = 0.66
    private static let towerButtonOffsetFactor: CGFloat = 4.0
    private static let buttonAngleDegrees: [TowerKind: CGFloat] = [
        TowerKind.ranged: 145,
        TowerKind.melee: 40,
        TowerKind.special: 220,
        TowerKind.areaOfEffect: 320
    ]

    public static func getBgSize(playAreaScalingFactor: CGFloat) -> CGSize {
        let side = CanvasSpec.playArea.height * playAreaScalingFactor * bgScalingFactor
        return CGSize(width: side, height: side)
    }

    public static func getTowerButtonSize(playAreaScalingFactor: CGFloat) -> CGSize {
        let side = CanvasSpec.playArea.height * playAreaScalingFactor * towerButtonScalingFactor
        return CGSize(width: side, height: side)
    }
    
    public static func getTowerIconSize(towerButtonSize: CGFloat) -> CGFloat {
        return towerButtonSize * towerIconScalingFactor
    }

    public static func getCenterPoint(anchor: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: anchor.x,
                y: anchor.y)
    }

    public static func getTowerButtonCenterPoint(towerKind: TowerKind,
                                                 menuCenterPoint: CGPoint,
                                                 playAreaScalingFactor: CGFloat,
                                                 towerButtonSize: CGFloat) -> CGPoint {
        let menuSize = getBgSize(playAreaScalingFactor: playAreaScalingFactor)
        let menuRadius = getBgSize(playAreaScalingFactor: playAreaScalingFactor).width / 2
        let distanceFromCenter = menuRadius - (towerButtonSize / towerButtonOffsetFactor)
        let degrees = buttonAngleDegrees[towerKind]!
        let radians = degrees * .pi / 180
        
        return CGPoint(x: menuCenterPoint.x + distanceFromCenter * cos(radians),
                       y: menuCenterPoint.y - distanceFromCenter * sin(radians))
    }

    private static let towerIconFraction: CGFloat = 0.625

    public static var menuAnchorLift: CGFloat {
        CanvasSpec.slotSize.height / 2
    }

    public static var menuMapRadius: CGFloat {
        getBgSize(playAreaScalingFactor: 1).width / 2
    }

    public enum VerticalEdge {
        case top
        case bottom
    }

    public enum HorizontalEdge {
        case left
        case right
    }

    public static func slotSafeInset(_ edge: VerticalEdge) -> CGFloat {
        switch edge {
        case .top, .bottom:
            menuMapRadius - CanvasSpec.slotSize.height / 2
        }
    }

    public static func slotSafeInset(_ edge: HorizontalEdge) -> CGFloat {
        switch edge {
        case .left, .right:
            menuMapRadius - CanvasSpec.slotSize.width / 2
        }
    }

    public static var slotMenuSafeShape: CGPath {
        let play = CanvasSpec.playArea
        let left = play.minX + slotSafeInset(.left)
        let right = play.maxX - slotSafeInset(.right)
        let bottom = play.minY + slotSafeInset(.bottom)
        let top = play.maxY - slotSafeInset(.top)
        let shape = CGMutablePath()
        shape.addRect(CGRect(x: left, y: bottom,
                             width: right - left, height: top - bottom))
        let standoff = CGMutablePath()
        for corner in CanvasSpec.cornerOcclusionAreas {
            standoff.addRect(CGRect(
                x: corner.minX - slotSafeInset(.left),
                y: corner.minY - slotSafeInset(.top),
                width: corner.width + slotSafeInset(.left) + slotSafeInset(.right),
                height: corner.height + slotSafeInset(.top) + slotSafeInset(.bottom)))
        }
        return shape.subtracting(standoff, using: .winding)
    }
}
