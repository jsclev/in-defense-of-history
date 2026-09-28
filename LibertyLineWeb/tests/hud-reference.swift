import Foundation
import CoreGraphics

// Host-side reference invokes the actual native geometry. No simulator, copied
// layout implementation, generated source, or compiler substitution is involved.
@main struct HUDReference {
    static func main() throws {
        let input = try JSONSerialization.jsonObject(with: FileHandle.standardInput.readDataToEndOfFile()) as! [[String: Any]]
        func rect(_ r: CGRect) -> [String: Double] { ["x": r.minX, "y": r.minY, "width": r.width, "height": r.height] }
        let output: [[String: Any]] = input.map { item in
            let c = item["canvas"] as! [String: Any]
            func n(_ key: String) -> Double { (c[key] as! NSNumber).doubleValue }
            func fraction(_ section: String) -> CGSize { CGSize(width: n(section + "_width_fraction"), height: n(section + "_height_fraction")) }
            let canvas = VirtualCanvas(size: CGSize(width: n("canvas_width"), height: n("canvas_height")),
                playAreaRect: CGRect(x: n("play_area_x"), y: n("play_area_y"), width: n("play_area_width"), height: n("play_area_height")),
                pathWidth: n("path_width"), towerSlotSize: CGSize(width: n("slot_width"), height: n("slot_height")),
                towerMenuTotalSize: CGSize(width: n("tower_menu_total_width"), height: n("tower_menu_total_height")),
                statsViewSizeFraction: fraction("stats_view"), masterControlsSizeFraction: fraction("master_controls"),
                heroBarSizeFraction: fraction("hero_bar"), miscViewSizeFraction: fraction("misc_view"))
            let width = item["width"] as! Double, height = item["height"] as! Double
            let insets = item["insets"] as! [String: Double]
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: CGRect(x: 0, y: 0, width: width, height: height),
                safeInsetsRect: CGRect(x: insets["left"]!, y: insets["top"]!, width: width - insets["left"]! - insets["right"]!, height: height - insets["top"]! - insets["bottom"]!))
            let rows = HudLocation.corners.flatMap { corner in
                [1, 2, 3].map { count -> [String: Any] in
                    let row = HudButtonRowLayout(area: runtime.hudPlayArea, location: corner, count: count)
                    return ["corner": corner.rawValue, "count": count, "frame": rect(row.frame), "side": row.buttonSize, "gap": row.buttonSpacing]
                }
            }
            let positions = item["positions"] as! [[String: Double]]
            let waves = positions.map { p -> [String: Any] in
                let wave = CallWaveButtonLayout(position: Point(p["x"]!, p["y"]!), runtimeCanvas: runtime)
                return ["frame": rect(wave.frame), "font": wave.countdownFontSize, "horizontalPadding": wave.countdownHorizontalPadding, "verticalPadding": wave.countdownVerticalPadding]
            }
            let menu = TowerMenuLayout(virtualCanvas: canvas)
            let scale = runtime.scaleFactor, size = menu.getTowerButtonSize(playAreaScalingFactor: scale).width
            let projection = LevelMapProjection(playArea: canvas.playAreaRect, fitRect: runtime.playAreaRect, virtualCanvas: canvas)
            let menus = positions.map { p -> [String: Any] in
                let center = projection.viewPoint(CGPoint(x: p["x"]!, y: p["y"]!))
                func point(_ p: CGPoint) -> [String: Double] { ["x": p.x, "y": p.y] }
                let background = menu.getBgSize(playAreaScalingFactor: scale)
                let target = SlotTapTarget.size(slotSize: canvas.towerSlotSize, pointsPerMapUnit: scale)
                let buttons = Dictionary(uniqueKeysWithValues: TowerKind.allCases.map { kind in
                    (kind.rawValue, point(menu.getTowerButtonCenterPoint(towerKind: kind, menuCenterPoint: center, playAreaScalingFactor: scale, towerButtonSize: size)))
                })
                let seats = (0...5).map { count in (0..<max(count,1)).map { i in
                    point(menu.getButtonSeatCenterPoint(index:i,count:count,menuCenterPoint:center,playAreaScalingFactor:scale))
                }}
                let upgrades = (1...3).map { count in (0..<count).map { i in
                    point(menu.getEngineerUpgradeButtonCenterPoint(index:i,offerCount:count,menuCenterPoint:center,playAreaScalingFactor:scale,towerButtonSize:size))
                }}
                let anchor = CGRect(x:center.x-size/2,y:center.y-size/2,width:size,height:size*1.15)
                let labels: [Any] = [20.0,200.0,1000.0,6000.0].map { amount in
                    if let placement = TowerLabelPlacement.resolve(button:anchor,safeBounds:runtime.safeInsetsRect,
                        avoiding:HudLocation.corners.map { runtime.hudPlayArea.occlusion(at:$0) },measure:{ width in ceil(amount / width) * 24 + 56 }) {
                        return ["frame":rect(placement.frame),"contentHeight":placement.contentHeight] as [String:Any]
                    }
                    return NSNull()
                }
                return ["center":point(center),"side":size,"background":["width":background.width,"height":background.height],
                    "target":rect(CGRect(x:center.x-target.width/2,y:center.y-target.height/2,width:target.width,height:target.height)),
                    "buttons":buttons,"seats":seats,"upgrades":upgrades,"labels":labels]
            }
            let points = item["points"] as! [[String: Double]]
            let masks = [runtime.runtimePlayArea, runtime.runtimeTapArea, runtime.towerSlotValidArea]
                .map { path in points.map { p in path.contains(CGPoint(x: p["x"]!, y: p["y"]!)) } }
            return ["bounds": rect(runtime.hudPlayArea.bounds), "corners": Dictionary(uniqueKeysWithValues: HudLocation.corners.map { ($0.rawValue, rect(runtime.hudPlayArea.occlusion(at: $0))) }), "rows": rows, "waves": waves, "masks": masks, "menus":menus]
        }
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]))
    }
}
