import AppKit
import SwiftUI
import LevelEditorFormats
struct LevelMapProjection {
    /// The virtual canvas, from virtual_canvas. Map artwork is required to be
    /// exactly this size, so the projection never asks the image.
    var canvasSize: CGSize { virtualCanvas.size }
    let playArea: CGRect
    let fitRect: CGRect
    let virtualCanvas: VirtualCanvas

    var scale: CGFloat {
        min(fitRect.width / playArea.width, fitRect.height / playArea.height)
    }

    private var origin: CGPoint {
        // y is flipped by viewPoint, so the rect's centre is measured from the
        // top of the canvas here. Written out rather than relying on the rect
        // happening to be vertically centred.
        CGPoint(
            x: fitRect.midX - playArea.midX * scale,
            y: fitRect.midY - (canvasSize.height - playArea.midY) * scale
        )
    }

    /// Canonical (lower-left origin, +y up) to SwiftUI view space (+y down).
    /// The only place the game flips.
    func viewPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale,
                y: origin.y + (canvasSize.height - p.y) * scale)
    }

    func viewLength(_ l: CGFloat) -> CGFloat { l * scale }

    func mapPoint(_ v: CGPoint) -> CGPoint {
        CGPoint(x: (v.x - origin.x) / scale,
                y: canvasSize.height - (v.y - origin.y) / scale)
    }

    var viewTransform: CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
                          tx: origin.x, ty: origin.y + canvasSize.height * scale)
    }

    var imageFrameSize: CGSize {
        CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    var imageCenter: CGPoint {
        viewPoint(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
    }
}
import SwiftUI

struct LevelTowerSlotsView: View {
    let towerSlotImageName = "tower_slot_field"
    
    let debugMode: Bool
    let slotPositions: [CGPoint]
    let size: CGSize
    let projection: LevelMapProjection
    
    var body: some View {
        ForEach(Array(slotPositions.enumerated()), id: \.offset) { index, slotPosition in
            if debugMode {
                ZStack {
                    assetImage(towerSlotImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: projection.viewLength(size.width),
                               height: projection.viewLength(size.height))
                        .allowsHitTesting(false)
                    
                    Text(String(index))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.black)
                        .padding()
                }.position(projection.viewPoint(slotPosition))
            }
            else {
                assetImage(towerSlotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: projection.viewLength(size.width),
                           height: projection.viewLength(size.height))
                    .allowsHitTesting(false)
                    .position(projection.viewPoint(slotPosition))
            }
        }
    }
}
struct CurrentTowers: View {
let runner: Fixture
let projection: LevelMapProjection
let sprites: MapSpriteScale
let size: CGSize
    private static let towerArtworkLift: CGFloat = 12
var body: some View { ZStack(alignment: .topLeading) { Color.clear.frame(width:size.width,height:size.height)
            ForEach(runner.placedTowers) { tower in
                if let assetName = tower.kind.assetName(atLevel: tower.level,
                                                        branch: tower.branch) {
                    let towerHeight = sprites.points(tower.kind.spriteHeight)
                    let basePoint = projection.viewPoint(CGPoint(
                        x: tower.position.x,
                        y: tower.position.y + Self.towerArtworkLift))

                    // All tower families share the same sizing and placement.
                    assetImage(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: towerHeight)
                        .position(
                            x: basePoint.x,
                            y: basePoint.y - towerHeight / 2
                                + sprites.points(MapSpriteSizing.towerBaseLift)
                                + towerHeight * 0.20
                        )
                }
            }

} }
}
struct BeforeTowers: View {
let runner: Fixture
let projection: LevelMapProjection
let sprites: MapSpriteScale
let size: CGSize
    private static let slotTowerScale: CGFloat = 1.443
    private static let slotTowerLift: CGFloat = 0.230
    private static let towerArtworkLift: CGFloat = 12
var body: some View { ZStack(alignment: .topLeading) { Color.clear.frame(width:size.width,height:size.height)
            ForEach(runner.placedTowers) { tower in
                if let assetName = tower.kind.assetName(atLevel: tower.level,
                                                        branch: tower.branch) {
                    let towerHeight = sprites.points(tower.kind.spriteHeight)
                    let basePoint = projection.viewPoint(CGPoint(
                        x: tower.position.x,
                        y: tower.position.y + Self.towerArtworkLift))

                    if tower.kind.usesSlotCanvasArt {
                        let slotBox = runner.slotSize
                        // Drawn on tower_slot.png's canvas, so it starts from
                        // the slot's own box, scaled by the same projection
                        // that fits the play area to the runtimeCanvas —
                        // scaledToFit matches the renderer's `fit: "inside"`.
                        // On device that exact fit read too small and too
                        // sunken, so the art draws scaled up and lifted; both
                        // knobs are the constants below.
                        let towerW = projection.viewLength(slotBox.width)
                            * Self.slotTowerScale
                        let towerH = projection.viewLength(slotBox.height)
                            * Self.slotTowerScale
                        assetImage(assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: towerW, height: towerH)
                            .position(x: basePoint.x,
                                      y: basePoint.y - towerH * Self.slotTowerLift)
                    } else {
                        // Tight-cropped art, sized by its own sprite height and
                        // lifted so the base sits on the slot.
                        ZStack(alignment: .bottom) {
                            assetImage(assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: towerHeight)
                        }
                        .position(
                            x: basePoint.x,
                            y: basePoint.y - towerHeight / 2
                                + sprites.points(MapSpriteSizing.towerBaseLift)
                                + towerHeight * 0.20
                        )
                    }
                }
            }

} }
}
struct FixtureKind {
    let base: TowerKind
    let multiplier: CGFloat
    var spriteHeight: SpriteHeight {
        let configured = base.spriteHeight
        return SpriteHeight(fraction: configured.fraction * multiplier,
                            atLeast: configured.minimum * multiplier,
                            atMost: configured.maximum * multiplier)
    }
    func assetName(atLevel level: Int, branch: Int) -> String? { base.assetName(atLevel: level, branch: branch) }
    // Compatibility solely for rendering the saved, pre-fix branch.
    var usesSlotCanvasArt: Bool { base == .ranged }
}
struct FixtureTower: Identifiable { let id = 0; let kind: FixtureKind; let level: Int; let branch: Int; let position: CGPoint }
struct Fixture { let placedTowers: [FixtureTower]; let slotSize: CGSize }
struct Item: Decodable { let name: String; let kind: String; let level: Int; let branch: Int }
@MainActor func assetImage(_ name: String) -> Image {
    let directory = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets").appendingPathComponent("\(name).imageset")
    let content = try! JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("Contents.json"))) as! [String: Any]
    let available = (content["images"] as! [[String: Any]]).filter { $0["filename"] != nil }
    let entry = available.first { $0["scale"] as? String == "\(Main.density)x" } ?? available[0]
    return Image(nsImage: NSImage(contentsOf: directory.appendingPathComponent(entry["filename"] as! String))!)
}
@main struct Main {
    @MainActor static var density = 1
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
        let out = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history/Tools/reports/tower-sprite-height-2026-09-09")
        let items = try JSONDecoder().decode([Item].self, from: Data(contentsOf: out.appendingPathComponent("items.json")))
        let db = Db(dbPath: "/Users/john/projects/td/in-defense-of-history/Db/in_defense_of_history.sqlite", fullRefresh: false)
        let canvas = try db.virtualCanvasDao.get()
        var metrics: [[String: Any]] = []
        for playable in [340.0, 900.0] {
            let size = playable == 340 ? CGSize(width:128,height:160) : CGSize(width:360,height:400)
            let p = CGPoint(x:canvas.playAreaRect.midX,y:canvas.playAreaRect.midY)
            let s = playable / canvas.playAreaRect.height
            let fit = CGRect(x:size.width/2-canvas.playAreaRect.width*s/2,y:size.height*0.7-playable/2,
                             width:canvas.playAreaRect.width*s,height:playable)
            let projection = LevelMapProjection(playArea:canvas.playAreaRect,fitRect:fit,virtualCanvas:canvas)
            let sprites = MapSpriteScale(playArea:canvas.playAreaRect,viewSize:fit.size)
            for d in (playable == 340 ? [1,2,3] : [1]) {
                density = d
                for item in items {
                    let base = TowerKind(rawValue:item.kind)!
                    for variant in ["current", "double", "wide-slot", "before", "before-double"] {
                        let multiplier: CGFloat = variant == "double" || variant == "before-double" ? 2 : 1
                        let slotMultiplier: CGFloat = variant == "wide-slot" ? 2 : 1
                        let kind = FixtureKind(base:base,multiplier:multiplier)
                        let runner = Fixture(placedTowers:[FixtureTower(kind:kind,level:item.level,branch:item.branch,position:p)],
                                             slotSize:CGSize(width:canvas.towerSlotSize.width*slotMultiplier,height:canvas.towerSlotSize.height*slotMultiplier))
                        let towers = variant.hasPrefix("before") ? AnyView(BeforeTowers(runner:runner,projection:projection,sprites:sprites,size:size)) : AnyView(CurrentTowers(runner:runner,projection:projection,sprites:sprites,size:size))
                        let maps = variant == "current" && playable == 340 ? ["clear","battle-road","great-bridge","trenton"] : ["clear"]
                        for map in maps {
                            let content = ZStack(alignment:.topLeading) {
                                Color.clear.frame(width:size.width,height:size.height)
                                if map != "clear" {
                                    Image(nsImage:NSImage(contentsOf:out.appendingPathComponent("lab/\(map)-under.jpg"))!)
                                        .resizable().frame(width:fit.width,height:fit.height).position(x:fit.midX,y:fit.midY)
                                    LevelTowerSlotsView(debugMode:false,slotPositions:[p],size:canvas.towerSlotSize,projection:projection)
                                }
                                towers
                            }.frame(width:size.width,height:size.height).clipped()
                            let renderer = ImageRenderer(content:content)
                            renderer.scale = CGFloat(d)
                            let image = renderer.cgImage!
                            let filename = "\(item.name)-\(Int(playable))-\(d)x-\(variant)-\(map).png"
                            try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("renders/\(filename)"))
                        }
                        metrics.append(["asset":item.name,"playable":playable,"density":d,"variant":variant,"image_height":sprites.points(kind.spriteHeight)])
                    }
                }
            }
        }
        try JSONSerialization.data(withJSONObject:metrics,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("geometry.json"))
    }
}
