#!/usr/bin/env python3
"""Render the production tower view and verify that spriteHeight controls its pixels.

Build the Swift package first. This probe extracts the current SwiftUI view;
only asset loading and the fixture's requested sprite height are substituted.
The existing readability lab generates the artwork proofs and source hashes.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

from PIL import Image, ImageDraw

GAME = Path(__file__).resolve().parents[1]
LAB = GAME.parent / "in-defense-of-history-data/ArtReadability"
sys.path.insert(0, str(LAB))
import build_readability_lab as lab


def tower_view(source, name):
    start = source.index('            ForEach(runner.placedTowers) { tower in\n                if let assetName')
    end = source.index('\n            ForEach(runner.walkers)', start)
    knobs = '\n'.join(line for line in source.splitlines()
                      if 'private static let slotTower' in line or 'private static let towerArtworkLift' in line)
    return (f'struct {name}: View {{\nlet runner: Fixture\nlet projection: LevelMapProjection\n'
            'let sprites: MapSpriteScale\nlet size: CGSize\n' + knobs
            + '\nvar body: some View { ZStack(alignment: .topLeading) { Color.clear.frame(width:size.width,height:size.height)\n'
            + source[start:end] + '\n} }\n}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', type=Path, default=Path('/tmp/td-tower-sprite-tests/arm64-apple-macosx/debug'))
    parser.add_argument('--before-view', type=Path)
    parser.add_argument('--measure-only', action='store_true', help='Recheck already generated raster output')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'renders').mkdir(exist_ok=True)
    source_path = GAME / 'Liberty Line/Level Views/LevelMapView.swift'
    source = source_path.read_text()
    kinds_path = GAME / 'Engine/Models/TowerKind.swift'
    kinds = kinds_path.read_text()
    config = lab.project_manifest()
    config['assets'] = []
    config['sizing_sources'] = [{'path': str(p), 'sha256': lab.digest(p)} for p in (
        source_path, kinds_path, GAME / 'Engine/Layout/MapSpriteSizing.swift')]
    items = []
    for family, kind in [('ranged', 'ranged'), ('melee', 'melee'), ('artillery', 'areaOfEffect'), ('special', 'special')]:
        match = re.search(rf'case \.{kind}: return MapSpriteSizing.tower\(mapPixels: ([0-9.]+)\)', kinds)
        if not match:
            raise ValueError(f'Update the lab adapter for the {kind} height declaration')
        for folder in sorted(lab.CATALOG.glob(f'{family}_tower_level_*.imageset')):
            name = folder.stem
            level = re.search(r'level_(\d)(?:_branch_(\d))?$', name)
            entries = [e for e in json.loads((folder / 'Contents.json').read_text())['images'] if e.get('filename')]
            paths = [str(folder / next((e['filename'] for e in entries if e.get('scale') == f'{d}x'), entries[0]['filename'])) for d in [1, 2, 3]]
            config['assets'].append(dict(id=name, label=name.replace('_', ' '), animated=False,
                map_height=float(match[1]), states={'se': {'idle': [name], 'walk': [name]}}, files={name: paths}))
            items.append(dict(name=name, kind=kind, level=int(level[1]), branch=int(level[2] or 1)))
    (out / 'input-manifest.json').write_text(json.dumps(config, indent=2) + '\n')
    if not args.measure_only:
        lab.build(config, out / 'lab')
    (out / 'items.json').write_text(json.dumps(items))
    projection = source[source.index('struct LevelMapProjection {'):source.index('\nstruct LevelMapView: View {')]
    views = tower_view(source, 'CurrentTowers')
    if args.before_view:
        views += '\n' + tower_view(args.before_view.read_text(), 'BeforeTowers')
    slot_view = (GAME / 'Liberty Line/Level Views/LevelTowerSlotsView.swift').read_text()
    harness = r'''
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
    let directory = URL(fileURLWithPath: CATALOG).appendingPathComponent("\(name).imageset")
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
        let out = URL(fileURLWithPath: OUTPUT)
        let items = try JSONDecoder().decode([Item].self, from: Data(contentsOf: out.appendingPathComponent("items.json")))
        let db = Db(dbPath: DATABASE, fullRefresh: false)
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
                    for variant in VARIANTS {
                        let multiplier: CGFloat = variant == "double" || variant == "before-double" ? 2 : 1
                        let slotMultiplier: CGFloat = variant == "wide-slot" ? 2 : 1
                        let kind = FixtureKind(base:base,multiplier:multiplier)
                        let runner = Fixture(placedTowers:[FixtureTower(kind:kind,level:item.level,branch:item.branch,position:p)],
                                             slotSize:CGSize(width:canvas.towerSlotSize.width*slotMultiplier,height:canvas.towerSlotSize.height*slotMultiplier))
                        let towers = SELECT_VIEW
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
'''
    variants = ['current', 'double', 'wide-slot']
    select = 'AnyView(CurrentTowers(runner:runner,projection:projection,sprites:sprites,size:size))'
    if args.before_view:
        variants += ['before', 'before-double']
        select = 'variant.hasPrefix("before") ? AnyView(BeforeTowers(runner:runner,projection:projection,sprites:sprites,size:size)) : ' + select
    harness = harness.replace('SELECT_VIEW', select).replace('VARIANTS', json.dumps(variants))
    for token, value in [('CATALOG', str(lab.CATALOG)), ('OUTPUT', str(out)), ('DATABASE', str(GAME / 'Db/in_defense_of_history.sqlite'))]:
        harness = harness.replace(token, json.dumps(value))
    swift = ('import AppKit\nimport SwiftUI\nimport LevelEditorFormats\n' + projection + slot_view + views + harness)
    swift = swift.replace('Image(assetName)', 'assetImage(assetName)').replace('Image(towerSlotImageName)', 'assetImage(towerSlotImageName)')
    render = out / 'render.swift'
    render.write_text(swift)
    if not args.measure_only:
        subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-tower-sprite-cache',
                        '-I', str(args.build / 'Modules'), str(render)]
                       + [str(p) for p in (args.build / 'LevelEditorFormats.build').glob('*.swift.o')]
                       + ['-o', str(out / 'render')], check=True)
        subprocess.run([str(out / 'render')], check=True, timeout=60)
    checks = []
    old_failures = []
    def image(item, playable, density, variant):
        return Image.open(out / f'renders/{item["name"]}-{playable}-{density}x-{variant}-clear.png').convert('RGBA')
    def bounds(im):
        return im.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
    for item in items:
        for playable, densities in [(340, [1, 2, 3]), (900, [1])]:
            for density in densities:
                current = image(item, playable, density, 'current')
                double = image(item, playable, density, 'double')
                a, b = bounds(current), bounds(double)
                assert a and b, (item, playable, density, 'invisible sprite')
                for low, high in [(0, 2), (1, 3)]:
                    # Alpha-threshold edges shift with resampling, especially
                    # for the current 7.8-point ranged canvas. Allow four raster
                    # pixels while requiring both visible dimensions to grow.
                    assert b[high]-b[low] > a[high]-a[low], (item, a, b)
                    assert abs((b[high]-b[low]) - 2*(a[high]-a[low])) <= 4, (item, playable, density, a, b)
                assert current.tobytes() == image(item, playable, density, 'wide-slot').tobytes(), 'Slot geometry overrode spriteHeight'
                if args.before_view:
                    before = image(item, playable, density, 'before')
                    if item['kind'] != 'ranged':
                        assert current.tobytes() == before.tobytes(), ('Other tower changed', item)
                    else:
                        old_double = image(item, playable, density, 'before-double')
                        assert before.tobytes() == old_double.tobytes(), 'Expected to reproduce ignored ranged height'
                        old_failures.append(dict(asset=item['name'], playable=playable, density=density))
                checks.append(dict(asset=item['name'], playable=playable, density=density, configured_bounds=a, doubled_bounds=b))
    (out / 'raster-checks.json').write_text(json.dumps(dict(passed=checks, reproduced_old_bug=old_failures), indent=2)+'\n')
    proof = Image.new('RGB', (780, 705), '#eee9da')
    draw = ImageDraw.Draw(proof)
    draw.text((12, 10), 'Current tower settings / native logical size / rows: ranged, melee, artillery, special', font=lab.font(16), fill='#222222')
    first = [i for i in items if i['level'] == 1]
    for row, item in enumerate(first):
        for col, terrain in enumerate(['battle-road', 'great-bridge', 'trenton']):
            for variant_index, variant in enumerate(['current', 'double']):
                path = out / f'renders/{item["name"]}-340-1x-{variant}-{terrain if variant == "current" else "clear"}.png'
                im = Image.open(path).convert('RGBA')
                x, y = col*260+variant_index*130, 50+row*160
                proof.paste(im, (x,y), im)
            if row == 0:
                draw.text((col*260+5, 31), f'{terrain} / height doubled', font=lab.font(12), fill='#222222')
    proof.save(out / 'native-size-proof.png')
    print(f'PASS: {len(checks)} SwiftUI sizing checks; {len(old_failures)} pre-fix ranged failures reproduced.')


if __name__ == '__main__':
    main()
