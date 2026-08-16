import Foundation
import CoreGraphics
import SwiftUI

public enum TowerMenuLayout {
    public static let radius: CGFloat = 75.0
    public static let buttonSide: CGFloat = 95.37
    public static let towerFrameSize: CGFloat = 65.0
    public static var towerIconSize: CGFloat { towerFrameSize * towerIconFraction }
    public static let centerDropFraction: CGFloat = 0
    private static let bgScalingFactor = 0.25
    private static let towerButtonScalingFactor = 0.05
    
    public static func getBgSize(playAreaSize: CGSize) -> CGSize {
        return CGSize(width: playAreaSize.height * bgScalingFactor,
                      height: playAreaSize.height * bgScalingFactor)
    }
    
    public static func getTowerButtonSize(playAreaSize: CGSize) -> CGSize {
        return CGSize(width: playAreaSize.height * towerButtonScalingFactor,
                      height: playAreaSize.height * towerButtonScalingFactor)
    }

    public static func getCenterPoint(anchor: CGPoint, count: Int, scale: CGFloat) throws -> CGPoint {
        CGPoint(x: anchor.x,
                y: anchor.y)
    }

    private static let towerIconFraction: CGFloat = 0.625
    private static let variantArtScale: CGFloat = radius / 541

    /// The 4-choice build menu's frame is `tower_menu_bg`, whose geometry is
    /// derived from the image itself in BackgroundFrameLayout; the 1–3
    /// choice upgrade variants keep their measured tables below. Everything
    /// public here that takes `count` routes 4 to BackgroundFrameLayout.
    private static let backgroundFrameCount = 4

    private struct Art {
        let assetName: String
        let canvasPx: CGFloat
        let parchmentPx: CGFloat
        let pointsPerPx: CGFloat
        let bubbleOffsetsPx: [CGSize]
        let visualBoundsPx: CGRect
    }

    private static let variantArts: [Int: Art] = [
        1: Art(assetName: "radial_menu_1_choice", canvasPx: 1536,
               parchmentPx: 192, pointsPerPx: variantArtScale,
               bubbleOffsetsPx: [CGSize(width: 0, height: -540)],
               visualBoundsPx: CGRect(x: 204, y: 69, width: 1129, height: 1265)),
        2: Art(assetName: "radial_menu_2_choices", canvasPx: 1536,
               parchmentPx: 192, pointsPerPx: variantArtScale,
               bubbleOffsetsPx: [CGSize(width: 0, height: -540),
                                 CGSize(width: 0, height: 543)],
               visualBoundsPx: CGRect(x: 204, y: 69, width: 1129, height: 1402)),
        3: Art(assetName: "radial_menu_3_choices", canvasPx: 1536,
               parchmentPx: 192, pointsPerPx: variantArtScale,
               bubbleOffsetsPx: [CGSize(width: 0, height: -540),
                                 CGSize(width: 469, height: 270),
                                 CGSize(width: -469, height: 271)],
               visualBoundsPx: CGRect(x: 147, y: 69, width: 1244, height: 1265)),
    ]

    public static var menuAnchorLift: CGFloat {
        CanvasSpec.slotSize.height / 2
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
