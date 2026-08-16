import Foundation
import CoreGraphics

public enum TowerMenuLayout {
    public static let radius: CGFloat = 91.0
    public static let buttonSide: CGFloat = 95.37
    public static let towerFrameSize: CGFloat = 80
    public static var towerIconSize: CGFloat { towerFrameSize * towerIconFraction }
    public static let centerDropFraction: CGFloat = 0

    public static func menuCenter(anchor: CGPoint, count: Int, scale: CGFloat) -> CGPoint {
        CGPoint(x: anchor.x,
                y: anchor.y + backgroundDiameter(count: count) * centerDropFraction * scale)
    }

    private static let fourChoiceArtScale: CGFloat = (90.5 / 409.5) * 0.9 * 0.92 * 0.96
    private static let towerIconFraction: CGFloat = 0.525
    private static let variantArtScale: CGFloat = radius / 541

    private struct Art {
        let assetName: String
        let canvasPx: CGFloat
        let parchmentPx: CGFloat
        let pointsPerPx: CGFloat
        let bubbleOffsetsPx: [CGSize]
        let visualBoundsPx: CGRect
    }

    private static let arts: [Int: Art] = [
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
        4: Art(assetName: "tower_menu_v02", canvasPx: 1536,
               parchmentPx: 251, pointsPerPx: fourChoiceArtScale,
               bubbleOffsetsPx: [CGSize(width: -366, height: -366),
                                 CGSize(width: 366, height: -366),
                                 CGSize(width: 366, height: 366),
                                 CGSize(width: -366, height: 366)],
               visualBoundsPx: CGRect(x: 175, y: 171, width: 1187, height: 1203)),
    ]

    private static func art(count: Int) -> Art {
        arts[min(max(count, 1), 4)]!
    }

    public static func backgroundAssetName(count: Int) -> String {
        art(count: count).assetName
    }

    public static func backgroundDiameter(count: Int) -> CGFloat {
        let art = art(count: count)
        return art.canvasPx * art.pointsPerPx
    }

    public static func iconWellDiameter(count: Int) -> CGFloat {
        let art = art(count: count)
        return art.parchmentPx * art.pointsPerPx
    }

    /// Menu icons sit dead-centre on the parchment bubbles baked into the
    /// radial background art, so item positions are exactly the art's bubble
    /// offsets — no spread factor. (`itemSpread` existed to push the old
    /// framed buttons outward; with the frames gone it only displaced icons
    /// off their bubbles.)
    public static func itemOffset(index: Int, count: Int) -> CGSize {
        let art = art(count: count)
        guard art.bubbleOffsetsPx.indices.contains(index) else {
            let angle = (-90.0 + Double(index) * 360.0 / Double(count)) * .pi / 180
            return CGSize(width: radius * cos(angle), height: radius * sin(angle))
        }
        return CGSize(width: art.bubbleOffsetsPx[index].width * art.pointsPerPx,
                      height: art.bubbleOffsetsPx[index].height * art.pointsPerPx)
    }

    private static func axisExtentsPt(_ art: Art) -> (x: CGFloat, y: CGFloat) {
        let b = art.visualBoundsPx
        let mid = art.canvasPx / 2
        let x = max(mid - b.minX, b.maxX - mid) * art.pointsPerPx
        let y = max(mid - b.minY, b.maxY - mid) * art.pointsPerPx
        return (x, y)
    }

    public static var visualExtentPt: (x: CGFloat, y: CGFloat) {
        arts.values.reduce((x: CGFloat(0), y: CGFloat(0))) { widest, art in
            let extents = axisExtentsPt(art)
            return (max(widest.x, extents.x), max(widest.y, extents.y))
        }
    }

    public static func visualDiameterPt(count: Int) -> CGSize {
        let art = art(count: count)
        return CGSize(width: art.visualBoundsPx.width * art.pointsPerPx,
                      height: art.visualBoundsPx.height * art.pointsPerPx)
    }

    public static let referenceScreen = ScreenGeometry(
        fullSize: CGSize(width: 1194, height: 834),
        leading: 0, top: 0, trailing: 0, bottom: 20)

    public static var referenceMapScale: CGFloat {
        min(referenceScreen.safe.width / CanvasSpec.playArea.width,
            referenceScreen.safe.height / CanvasSpec.playArea.height)
    }

    public static var referenceHudScale: CGFloat {
        HudScale(viewSize: referenceScreen.physical.size).value
    }

    public static var mapUnitsPerMenuPoint: CGFloat {
        referenceHudScale / referenceMapScale
    }

    public static func menuMapSize(count: Int) -> CGSize {
        let d = visualDiameterPt(count: count)
        return CGSize(width: d.width * mapUnitsPerMenuPoint,
                      height: d.height * mapUnitsPerMenuPoint)
    }

    public static func menuMapCanvasSide(count: Int) -> CGFloat {
        let art = art(count: count)
        return art.canvasPx * art.pointsPerPx * mapUnitsPerMenuPoint
    }

    public static func bubbleMapOffset(index: Int, count: Int) -> CGSize {
        let o = itemOffset(index: index, count: count)
        return CGSize(width: o.width * mapUnitsPerMenuPoint,
                      height: o.height * mapUnitsPerMenuPoint)
    }

    public static func bubbleMapDiameter(count: Int) -> CGFloat {
        iconWellDiameter(count: count) * mapUnitsPerMenuPoint
    }

    public static var menuMapRadius: CGFloat {
        let size = menuMapSize(count: 4)
        return max(size.width, size.height) / 2
    }

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
