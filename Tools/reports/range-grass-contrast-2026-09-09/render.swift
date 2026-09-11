import AppKit
import SwiftUI
import SwiftUI

struct TowerRangeOverlayView: View {
    let center: CGPoint
    let size: CGSize
    let upgradeSize: CGSize?

    init(center: CGPoint, range: CGFloat, upgradeRange: CGFloat? = nil,
         runtimeCanvas: RuntimeCanvas) {
        self.center = center
        self.size = TowerRangeOverlay.size(range: range, runtimeCanvas: runtimeCanvas)
        // Equal ranges share a boundary; avoid darkening it with a duplicate.
        self.upgradeSize = upgradeRange.flatMap { upgraded in
            upgraded == range ? nil : TowerRangeOverlay.size(range: upgraded, runtimeCanvas: runtimeCanvas)
        }
    }

    var body: some View {
        ZStack {
            if let upgradeSize {
                ring(size: upgradeSize, isUpgrade: true)
            }
            ring(size: size, isUpgrade: false)
        }
        .position(center)
        .allowsHitTesting(false)
    }

    private func ring(size: CGSize, isUpgrade: Bool) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, dash: isUpgrade ? [6, 4] : [])
        let edgeOpacity = isUpgrade ? 0.4 : 0.7
        // Friendly reach needs to separate from both yellow-green grass and
        // jade shadows. Keep the bright boundary green and its contrast inside.
        let green = Color(.sRGB, red: 127 / 255, green: 1, blue: 173 / 255, opacity: 1)
        let separator = Color(.sRGB, red: 16 / 255, green: 56 / 255, blue: 43 / 255, opacity: 1)
        let boundary = Ellipse().inset(by: stroke.lineWidth / 2)
        return Ellipse()
            .fill(
                EllipticalGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.92),
                    .init(color: green.opacity(edgeOpacity * 0.25), location: 0.96),
                    .init(color: green.opacity(edgeOpacity), location: 1)
                ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            )
            .overlay(
                ZStack {
                    // Both strokes follow the same path so upgrade dashes align.
                    boundary.stroke(separator, style: StrokeStyle(lineWidth: 5, dash: stroke.dash))
                    boundary.stroke(green, style: stroke)
                }
                .clipShape(Ellipse())
            )
            .frame(width: size.width, height: size.height)
    }
}
import SwiftUI

struct BeforeTowerRangeOverlayView: View {
    let center: CGPoint
    let size: CGSize
    let upgradeSize: CGSize?

    init(center: CGPoint, range: CGFloat, upgradeRange: CGFloat? = nil,
         runtimeCanvas: RuntimeCanvas) {
        self.center = center
        self.size = TowerRangeOverlay.size(range: range, runtimeCanvas: runtimeCanvas)
        // Equal ranges share a boundary; avoid darkening it with a duplicate.
        self.upgradeSize = upgradeRange.flatMap { upgraded in
            upgraded == range ? nil : TowerRangeOverlay.size(range: upgraded, runtimeCanvas: runtimeCanvas)
        }
    }

    var body: some View {
        ZStack {
            if let upgradeSize {
                ring(size: upgradeSize, isUpgrade: true)
            }
            ring(size: size, isUpgrade: false)
        }
        .position(center)
        .allowsHitTesting(false)
    }

    private func ring(size: CGSize, isUpgrade: Bool) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, dash: isUpgrade ? [6, 4] : [])
        let edgeOpacity = isUpgrade ? 0.4 : 0.7
        return Ellipse()
            .fill(
                EllipticalGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.92),
                    .init(color: .green.opacity(edgeOpacity * 0.25), location: 0.96),
                    .init(color: .green.opacity(edgeOpacity), location: 1)
                ], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            )
            .overlay(
                Ellipse().strokeBorder(Color.green.opacity(0.95), style: stroke)
            )
            .frame(width: size.width, height: size.height)
    }
}

@main struct Review {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
        let virtual = VirtualCanvas(size:CGSize(width:2868.0,height:2064.0),
playAreaRect:CGRect(x:474.0,y:492.0,width:1920.0,height:1080.0),
pathWidth:140.0,towerSlotSize:CGSize(width:176.6,height:96.55),towerMenuTotalSize:CGSize(width:435.9,height:390.9),
statsViewSizeFraction:CGSize(width:0.3,height:0.19),masterControlsSizeFraction:CGSize(width:0.15,height:0.17),
heroBarSizeFraction:CGSize(width:0.258,height:0.17),miscViewSizeFraction:CGSize(width:0.09,height:0.17))
        let out = URL(fileURLWithPath:"/Users/john/projects/td/in-defense-of-history/Tools/reports/range-grass-contrast-2026-09-09")
        var geometry: [[String: Any]] = []
        for height in [221.0625,340,900] {
            let physical = CGRect(x:0,y:0,width:height*virtual.playAreaRect.width/virtual.playAreaRect.height,height:height)
            let canvas = RuntimeCanvas(virtualCanvas:virtual,physicalRect:physical,safeInsetsRect:physical)
            for variant in ["current","before","upgrade","equal","maximum"] {
                let range: CGFloat = variant == "maximum" ? 535.61 : 319.08
                let upgrade: CGFloat? = variant == "upgrade" ? 364.67 : (variant == "equal" ? range : nil)
                let ellipse = TowerRangeOverlay.size(range:upgrade ?? range,runtimeCanvas:canvas)
                let box = CGSize(width:ceil(ellipse.width)+8,height:ceil(ellipse.height)+8)
                let center = CGPoint(x:box.width/2,y:box.height/2)
                for density in [1,2,3] {
                    let content = ZStack {
                        if variant == "before" {
                            BeforeTowerRangeOverlayView(center:center,range:range,upgradeRange:upgrade,runtimeCanvas:canvas)
                        } else {
                            TowerRangeOverlayView(center:center,range:range,upgradeRange:upgrade,runtimeCanvas:canvas)
                        }
                    }.frame(width:box.width,height:box.height)
                    let renderer = ImageRenderer(content:content)
                    renderer.scale = CGFloat(density)
                    let image = renderer.cgImage!
                    let name = "\(Int(height))-\(variant)-\(density)x.png"
                    try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(name))
                    geometry.append(["file":name,"playable_height":height,"density":density,
                                     "ellipse_width":ellipse.width,"ellipse_height":ellipse.height,
                                     "box_width":box.width,"box_height":box.height])
                }
            }
        }
        try JSONSerialization.data(withJSONObject:geometry,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
    }
}
