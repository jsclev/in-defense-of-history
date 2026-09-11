"""Render current production hero HUD views with fixture state and real geometry."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

OUT = Path(__file__).resolve().parent
GAME = OUT.parents[2]
ART = GAME.parent / 'in-defense-of-history-data'
BUILD = Path('/tmp/td-runtime-canvas-tests/arm64-apple-macosx/debug')
inputs = [GAME / 'Liberty Line/Level Views/HUD' / name for name in
          ['HudHeroesBarView.swift', 'HeroHUDButton.swift', 'ReinforcementButton.swift']]
views = '\n'.join(p.read_text() for p in inputs)
views = re.sub(r'\bImage\(([^)\n]+)\)', r'Image(nsImage: Proof.art(\1))', views)
old_view = inputs[0].read_text().replace('HudHeroesBarView', 'BeforeHudHeroesBarView')
old_view = old_view.replace('HeroBarLayout', 'BeforeHeroBarLayout')
old_layout = (OUT / 'before-HeroBarLayout.swift').read_text().replace('HeroBarLayout', 'BeforeHeroBarLayout')
shutil.copy2(GAME / 'Db/in_defense_of_history.sqlite', OUT / 'fixture.sqlite')
main = r'''
@MainActor final class LevelRunner: ObservableObject {
    @Published var selectedHeroIndex: Int?
    @Published var isPlacingReinforcements = false
    @Published var reinforcementCooldown: ReinforcementCooldown = .ready
    let hudHeroes: [Hero]
    var canCallReinforcements: Bool { reinforcementCooldown.isReady }
    init(_ heroes: [Hero]) { hudHeroes = heroes }
    func hudHeroIndex(for id: UUID) -> Int? { hudHeroes.firstIndex { $0.id == id } }
    func selectHero(heroID: UUID) { selectedHeroIndex = hudHeroIndex(for: heroID) }
    func toggleReinforcementPlacement() { isPlacingReinforcements.toggle() }
}

@main struct Proof {
    @MainActor static var density = 1
    @MainActor static func art(_ name: String) -> NSImage {
        let base = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
        let info = try! JSONSerialization.jsonObject(with: Data(contentsOf: base.appendingPathComponent("Contents.json"))) as! [String: Any]
        let entries = (info["images"] as! [[String: Any]]).filter { $0["filename"] != nil }
        let entry = entries.first { $0["scale"] as? String == "\(density)x" } ?? entries[0]
        return NSImage(contentsOf: base.appendingPathComponent(entry["filename"] as! String))!
    }
    static func values(_ r: CGRect) -> [CGFloat] { [r.minX, r.minY, r.width, r.height] }
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let db = Db(dbPath: out.appendingPathComponent("fixture.sqlite").path, fullRefresh: false)
        let vc = try db.virtualCanvasDao.get()
        let heroes = try db.heroDao.getAll()
        let pair = ["Henry Knox", "George Washington"].map { name in heroes.first { $0.shortName == name }! }
        let runner = LevelRunner(pair)
        let minimum = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let fixtures: [(String, CGRect, CGRect)] = [
            ("minimum", minimum, minimum),
            ("phone", CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382)),
            ("tablet", CGRect(x: 0, y: 0, width: 1024, height: 768), CGRect(x: 0, y: 24, width: 1024, height: 724))
        ]
        var measurements: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let layout = HeroBarLayout(runtimeCanvas: runtime)
            let before = BeforeHeroBarLayout(runtimeCanvas: runtime)
            let occlusion = CGRect(x: runtime.playAreaRect.minX,
                                   y: runtime.playAreaRect.maxY - vc.lowerLeftOcclusionArea.height * runtime.scaleFactor,
                                   width: vc.lowerLeftOcclusionArea.width * runtime.scaleFactor,
                                   height: vc.lowerLeftOcclusionArea.height * runtime.scaleFactor)
            if name == "minimum" { precondition(layout == HeroBarLayout(runtimeCanvas: runtime) && abs(layout.buttonSize - before.buttonSize) < 1e-8) }
            if name == "phone" {
                precondition(before.buttonSize < occlusion.height)
                precondition(abs(layout.buttonSize - occlusion.height) < 1e-8)
            }
            measurements.append(["fixture": name, "beforeButton": before.buttonSize,
                                 "button": layout.buttonSize, "frame": values(layout.frame),
                                 "hud": values(runtime.hudRect), "occlusion": values(occlusion)])
            for d in [1, 2, 3] {
                density = d
                for state in ["ready", "hero-selected", "placing", "cooldown-20", "cooldown-10", "cooldown-1"] {
                    runner.selectedHeroIndex = state == "hero-selected" ? 0 : nil
                    runner.isPlacingReinforcements = state == "placing"
                    runner.reinforcementCooldown = .ready
                    if state.hasPrefix("cooldown-") {
                        let remaining = Int(state.split(separator: "-").last!)!
                        var schedule = ReinforcementSchedule(config: try ReinforcementConfig(timeToLiveSeconds: 20, cooldownSeconds: 20))
                        precondition(schedule.deploy(slot: -1, at: 0))
                        runner.reinforcementCooldown = schedule.cooldown(at: Int64((20 - remaining) * SimClock.ticksPerSecond))
                    }
                    let row = HudHeroesBarView(layout: layout, runner: runner)
                    try save(row.padding(7), name: "\(name)-\(state)", out: out)
                    if name == "minimum" {
                        for i in 0..<2 {
                            try save(HeroHUDButton(iconName: pair[i].iconImageName, name: pair[i].shortName,
                                buttonSize: layout.buttonSize, isAvailable: true,
                                isSelected: runner.selectedHeroIndex == i, action: {}).padding(7),
                                name: "hero-\(i)-\(state)", out: out)
                        }
                        try save(ReinforcementButton(buttonSize: CGSize(width: layout.buttonSize, height: layout.buttonSize),
                            cooldown: runner.reinforcementCooldown, isAvailable: runner.canCallReinforcements,
                            action: {}, isSelected: runner.isPlacingReinforcements).padding(7),
                            name: "reinforcement-\(state)", out: out)
                    }
                    if state == "ready" {
                        let oldRow = BeforeHudHeroesBarView(layout: before, runner: runner)
                        try save(oldRow.padding(7), name: "\(name)-before", out: out)
                        if d == 1 {
                            try save(scene(runtime: runtime, physical: physical, occlusion: occlusion, row: row, frame: layout.frame), name: "\(name)-guides", out: out)
                            try save(scene(runtime: runtime, physical: physical, occlusion: occlusion, row: oldRow, frame: before.frame), name: "\(name)-before-guides", out: out)
                        }
                    }
                }
            }
        }
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys]).write(to: out.appendingPathComponent("layout.json"))
    }
    @MainActor static func scene<V: View>(runtime: RuntimeCanvas, physical: CGRect, occlusion: CGRect, row: V, frame: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.15, green: 0.18, blue: 0.12)
            Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/ArtReadability/reports/hero-hud-2026-09-08/battle-road-under.jpg")!)
                .resizable().frame(width: runtime.playAreaRect.width, height: runtime.playAreaRect.height)
                .position(x: runtime.playAreaRect.midX, y: runtime.playAreaRect.midY)
            Rectangle().fill(Color.blue.opacity(0.2)).frame(width: occlusion.maxX - runtime.hudRect.minX, height: runtime.hudRect.maxY - occlusion.minY)
                .position(x: (occlusion.maxX + runtime.hudRect.minX) / 2, y: (runtime.hudRect.maxY + occlusion.minY) / 2)
            row.position(x: frame.midX, y: frame.midY)
            SwiftUI.Path(runtime.runtimePlayArea).stroke(.pink, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            Rectangle().stroke(.yellow, style: StrokeStyle(lineWidth: 1, dash: [9, 6]))
                .frame(width: runtime.hudRect.width, height: runtime.hudRect.height)
                .position(x: runtime.hudRect.midX, y: runtime.hudRect.midY)
        }.frame(width: physical.width, height: physical.height).clipped()
    }
    @MainActor static func save<V: View>(_ view: V, name: String, out: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = CGFloat(density)
        guard let cg = renderer.cgImage else { fatalError("No render") }
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name)@\(density)x.png"))
    }
}
'''
source = OUT / 'render.swift'
source.write_text('import AppKit\nimport SwiftUI\nimport LevelEditorFormats\n' + views + old_view + old_layout + main)
binary = '/tmp/td-hero-bar-fit-render'
subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-hero-bar-fit-swift-cache',
                '-I', str(BUILD / 'Modules'), str(source)] +
               [str(p) for p in (BUILD / 'LevelEditorFormats.build').glob('*.swift.o')] + ['-o', binary], check=True)
subprocess.run([binary, str(OUT)], check=True)
manifest = json.loads((ART / 'ArtReadability/reports/hero-hud-2026-09-08/source-manifest.json').read_text())
manifest['sizing_sources'] = ['Current production HeroBarLayout and HUD views; unchanged 44.9556pt minimum buttons, 7pt proof padding. See layout.json for phone/tablet measurements.']
(OUT / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
inputs += [GAME / 'Engine/Layout/HeroBarLayout.swift', GAME / 'Engine/Core/RuntimeCanvas.swift', GAME / 'Engine/Design/VirtualCanvas.swift']
(OUT / 'source-hashes.json').write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}, indent=2) + '\n')
print('Rendered production views at minimum, phone, and tablet sizes, each at 1x/2x/3x.')
