import Foundation
import CoreGraphics
import SwiftUI

public struct TowerMenuLayout {
    private let virtualCanvas: VirtualCanvas
    
    private let bgScalingFactor: CGFloat = 0.41
    private let towerButtonScalingFactor: CGFloat = 0.145
    /// One inset for every tower-menu foreground, including upgrade and rally icons.
    public static let iconInsetFraction: CGFloat = 0.17
    private let towerButtonOffsetFactor: CGFloat = 4.0
    private let buttonAngleDegrees: [TowerKind: CGFloat] = [
        TowerKind.supply: 90,
        TowerKind.melee: 18,
        TowerKind.areaOfEffect: -54,
        TowerKind.special: -126,
        TowerKind.ranged: -198
    ]
    
    public init(virtualCanvas: VirtualCanvas) {
        self.virtualCanvas = virtualCanvas
    }

    private let bgArtWidthScalingFactor: CGFloat = 0.29334
    private let bgArtHeightScalingFactor: CGFloat = 0.29414
    private let bgArtLineCenterFactor: CGFloat = 0.4733

    public func getBgSize(playAreaScalingFactor: CGFloat) -> CGSize {
        let playAreaHeight = virtualCanvas.playAreaRect.height * playAreaScalingFactor
        return CGSize(width: playAreaHeight * bgArtWidthScalingFactor,
                      height: playAreaHeight * bgArtHeightScalingFactor)
    }

    public func getButtonRingRadius(playAreaScalingFactor: CGFloat) -> CGFloat {
        virtualCanvas.playAreaRect.height * playAreaScalingFactor * bgScalingFactor / 2
    }

    public func getButtonSeatRadius(playAreaScalingFactor: CGFloat) -> CGFloat {
        getBgSize(playAreaScalingFactor: playAreaScalingFactor).height * bgArtLineCenterFactor
    }

    public func getButtonSeatCenterPoint(index: Int, count: Int,
                                         menuCenterPoint: CGPoint,
                                         playAreaScalingFactor: CGFloat) -> CGPoint {
        let degrees = 90 - 360 * CGFloat(index) / CGFloat(max(count, 1))
        let radians = degrees * .pi / 180
        let radius = getButtonSeatRadius(playAreaScalingFactor: playAreaScalingFactor)
        return CGPoint(x: menuCenterPoint.x + radius * cos(radians),
                       y: menuCenterPoint.y - radius * sin(radians))
    }

    public func getTowerButtonSize(playAreaScalingFactor: CGFloat) -> CGSize {
        let side = virtualCanvas.playAreaRect.height * playAreaScalingFactor * towerButtonScalingFactor
        return CGSize(width: side, height: side)
    }
    
    public func getTowerIconSize(towerButtonSize: CGFloat) -> CGFloat {
        towerButtonSize * (1 - 2 * Self.iconInsetFraction)
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

    /// Keep the abatis placement control at bottom center while specializations
    /// occupy the remaining cardinal seats, including the full three-branch menu.
    public func getEngineerUpgradeButtonCenterPoint(index: Int, offerCount: Int,
                                                    menuCenterPoint: CGPoint,
                                                    playAreaScalingFactor: CGFloat,
                                                    towerButtonSize: CGFloat) -> CGPoint {
        precondition((1...3).contains(offerCount) && (0..<offerCount).contains(index))
        let seat: Int
        switch offerCount {
        case 1: seat = 0
        case 2: seat = index == 0 ? 3 : 1
        default: seat = [3, 0, 1][index]
        }
        return getButtonCenterPoint(index: seat, count: 4, menuCenterPoint: menuCenterPoint,
                                    playAreaScalingFactor: playAreaScalingFactor,
                                    towerButtonSize: towerButtonSize)
    }

    private func getButtonCenterPoint(degrees: CGFloat,
                                             menuCenterPoint: CGPoint,
                                             playAreaScalingFactor: CGFloat,
                                             towerButtonSize: CGFloat) -> CGPoint {
        let menuRadius = getButtonRingRadius(playAreaScalingFactor: playAreaScalingFactor)
        let distanceFromCenter = menuRadius - (towerButtonSize / towerButtonOffsetFactor)
        let radians = degrees * .pi / 180
        return CGPoint(x: menuCenterPoint.x + distanceFromCenter * cos(radians),
                       y: menuCenterPoint.y - distanceFromCenter * sin(radians))
    }

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

    /// Covers every seat angle used by build, upgrade and rally/charge menus,
    /// including the complete square touch target at the outside of the ring.
    public var interactionExtent: CGFloat {
        let halfButton = getTowerButtonSize(playAreaScalingFactor: 1).width / 2
        let ring = getButtonRingRadius(playAreaScalingFactor: 1) - halfButton / 2
        return max(ring, getButtonSeatRadius(playAreaScalingFactor: 1)) + halfButton
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
        max(virtualCanvas.towerMenuTotalSize.height / 2, interactionExtent)
            - virtualCanvas.towerSlotSize.height / 2
    }

    public func slotSafeInset(_ edge: HorizontalEdge) -> CGFloat {
        max(virtualCanvas.towerMenuTotalSize.width / 2, interactionExtent)
            - virtualCanvas.towerSlotSize.width / 2
    }

    public var slotMenuSafeShape: CGPath { virtualCanvas.towerSlotValidFootprint }
}
