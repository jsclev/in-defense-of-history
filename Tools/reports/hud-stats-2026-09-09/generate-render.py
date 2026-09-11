"""Render the production HUD view with explicit value fixtures on macOS."""
from pathlib import Path
import hashlib, json, re, shutil, subprocess
OUT = Path(__file__).resolve().parent
GAME = OUT.parents[2]
ART = GAME.parent / 'in-defense-of-history-data'
BUILD = Path('/tmp/td-master-controls-tests/arm64-apple-macosx/debug')
source = GAME / 'Liberty Line/Level Views/HUD/HudStatsView.swift'
views = source.read_text() + (GAME / 'Liberty Line/HudMetrics.swift').read_text()
views = views.replace('UIImage(named: name)', 'Optional(Proof.art(name))')
views = re.sub(r'\bImage\(([^)\n]+)\)', r'Image(nsImage: Proof.art(\1))', views)
shutil.copy2(GAME / 'Db/in_defense_of_history.sqlite', OUT / 'fixture.sqlite')
main = r'''
@MainActor final class LevelRunner: ObservableObject {
    @Published var lives = 20
    @Published var money = 500
    @Published var currentWaveNumber = 1
    var waveCount = 15
    var status = "HUD value fixture"
}
@main struct Proof {
    @MainActor static var density = 1
    @MainActor static func art(_ name: String) -> NSImage {
        let folder = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
        let contents = try! JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String: Any]
        let entries = (contents["images"] as! [[String: Any]]).filter { $0["filename"] != nil }
        let entry = entries.first { $0["scale"] as? String == "\(density)x" } ?? entries[0]
        return NSImage(contentsOf: folder.appendingPathComponent(entry["filename"] as! String))!
    }
    @MainActor static func save<V: View>(_ view: V, _ name: String, _ out: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(density)
        let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name)@\(density)x.png"))
    }
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let db = Db(dbPath: out.appendingPathComponent("fixture.sqlite").path, fullRefresh: false)
        let vc = try db.virtualCanvasDao.get()
        let minimum = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let fixtures: [(String, CGRect, CGRect)] = [
            ("minimum", minimum, minimum),
            ("phone", CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382))]
        var measurements: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let canvas = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let runner = LevelRunner()
            for (state, lives, money, wave, total) in [("start",20,500,1,15),("end",1,9999,15,15),("wide",99,9999,99,99)] {
                runner.lives = lives; runner.money = money; runner.currentWaveNumber = wave; runner.waveCount = total
                let row = HudStatsView(runtimeCanvas: canvas, runner: runner)
                let occupied = HudStatsView.occupiedFrame(runtimeCanvas: canvas, config: .standard)
                for d in [1,2,3] {
                    density = d
                    try save(row, "\(name)-\(state)", out)
                    if state != "wide" {
                        for (terrain, mapName) in [("grass", "level_01_battle_road"), ("snow", "level_008_trenton")] {
                            let scene = ZStack(alignment: .topLeading) {
                                Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/Levels/\(mapName).heic")!).resizable().frame(width: vc.size.width * canvas.scaleFactor, height: vc.size.height * canvas.scaleFactor).position(x: canvas.playAreaRect.midX, y: canvas.playAreaRect.midY)
                                row.position(x: occupied.midX, y: occupied.midY)
                            }.frame(width: physical.width, height: physical.height).clipped()
                            try save(scene, "\(name)-\(state)-\(terrain)", out)
                        }
                    }
                }
                measurements.append(["fixture":name,"state":state,"width":occupied.width,"height":occupied.height,"font":HudMetrics(runtimeCanvas:canvas).waveTextSize])
            }
        }
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("layout.json"))
    }
}
'''
swift = OUT / 'render.swift'
swift.write_text('import AppKit\nimport SwiftUI\nimport LevelEditorFormats\n' + views + main)
binary = '/tmp/td-hud-stats-render'
subprocess.run(['swiftc','-parse-as-library','-module-cache-path','/tmp/td-master-controls-swift-cache','-I',str(BUILD / 'Modules'),str(swift)] + [str(p) for p in (BUILD / 'LevelEditorFormats.build').glob('*.swift.o')] + ['-o',binary],check=True)
subprocess.run([binary,str(OUT)],check=True)
measurements = json.loads((OUT / 'layout.json').read_text())
manifest = json.loads((GAME / 'Tools/reports/master-controls-fit-2026-09-09/source-manifest.json').read_text())
manifest['maps'] = []
manifest['assets'] = [dict(id=name,label=name,animated=False,map_height=measurements[0]['height'],states={'se':{'idle':[name],'walk':[name]}},files={name:[f'{name}@{d}x.png' for d in [1,2,3]]}) for name in ['minimum-start','minimum-end','minimum-wide']]
manifest['sizing_sources'] = [f'Production HudStatsView, minimum runtime canvas: {measurements[0]}. macOS SwiftUI renderer with explicit value fixtures; not device gameplay.']
(OUT / 'source-manifest.json').write_text(json.dumps(manifest,indent=2))
inputs = [source,GAME/'Liberty Line/HudMetrics.swift',GAME/'Engine/Layout/HudElementLayouts.swift',GAME/'Engine/Layout/HudSizing.swift']
(OUT / 'source-hashes.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},indent=2))
