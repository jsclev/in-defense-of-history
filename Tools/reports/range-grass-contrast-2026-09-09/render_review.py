"""Render the production SwiftUI range overlay; feed its pixels to the existing lab."""
import json
from pathlib import Path
import sqlite3
import subprocess
import sys

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
GAME = OUT.parents[2]
LAB = GAME.parent / 'in-defense-of-history-data/ArtReadability'
sys.path.insert(0, str(LAB))
import build_readability_lab as lab

source = GAME / 'Liberty Line/Level Views/TowerRangeOverlayView.swift'
with sqlite3.connect(f'file:{GAME}/Db/in_defense_of_history.sqlite?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    row = dict(db.execute('select * from virtual_canvas').fetchone())
    ranges = [r[0] for r in db.execute('select distinct tower_range from tower order by tower_range')]

def size(prefix, fraction=False):
    suffix = '_fraction' if fraction else ''
    return f'CGSize(width:{row[prefix+"_width"+suffix]},height:{row[prefix+"_height"+suffix]})'

virtual = f'''VirtualCanvas(size:{size('canvas')},
playAreaRect:CGRect(x:{row['play_area_x']},y:{row['play_area_y']},width:{row['play_area_width']},height:{row['play_area_height']}),
pathWidth:{row['path_width']},towerSlotSize:{size('slot')},towerMenuTotalSize:{size('tower_menu_total')},
statsViewSizeFraction:{size('stats_view',True)},masterControlsSizeFraction:{size('master_controls',True)},
heroBarSizeFraction:{size('hero_bar',True)},miscViewSizeFraction:{size('misc_view',True)})'''
harness = r'''
@main struct Review {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
        let virtual = VIRTUAL
        let out = URL(fileURLWithPath:OUTPUT)
        var geometry: [[String: Any]] = []
        for height in [221.0625,340,900] {
            let physical = CGRect(x:0,y:0,width:height*virtual.playAreaRect.width/virtual.playAreaRect.height,height:height)
            let canvas = RuntimeCanvas(virtualCanvas:virtual,physicalRect:physical,safeInsetsRect:physical)
            for variant in ["current","before","upgrade","equal","maximum"] {
                let range: CGFloat = variant == "maximum" ? MAXIMUM : MINIMUM
                let upgrade: CGFloat? = variant == "upgrade" ? UPGRADE : (variant == "equal" ? range : nil)
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
'''
for key, value in [('VIRTUAL', virtual), ('OUTPUT', json.dumps(str(OUT))),
                   ('MINIMUM', str(ranges[0])), ('MAXIMUM', str(ranges[-1])), ('UPGRADE', str(ranges[2]))]:
    harness = harness.replace(key, value)
swift = OUT / 'render.swift'
swift.write_text('import AppKit\nimport SwiftUI\n' + source.read_text()
                 + (OUT / 'before.swift').read_text().replace('TowerRangeOverlayView', 'BeforeTowerRangeOverlayView') + harness)
subprocess.run(['swiftc','-parse-as-library','-module-cache-path','/tmp/td-range-border-cache',
                str(GAME/'Engine/Design/VirtualCanvas.swift'),str(GAME/'Engine/Core/RuntimeCanvas.swift'),
                str(GAME/'Engine/Layout/TowerRangeOverlay.swift'),str(swift),'-o',str(OUT/'render')],check=True)
subprocess.run([str(OUT/'render')],check=True,timeout=60)

config = lab.project_manifest()
config['maps'] = [dict(id='grass-only',label='New Bastion grass',base=str(GAME.parent / 'in-defense-of-history-data/Levels/grass_bastion.png')), dict(id='battle-road',label='Battle Road with new grass',base=str(GAME.parent / 'in-defense-of-history-data/ArtReadability/reports/grass-bastion-2026-09-09/runtime/level_01_battle_road.png')), dict(id='trenton',label='Trenton snow',base=str(OUT / 'trenton.png'))]
config['reference_height'] = row['play_area_height']
config['clamp'] = [221.0625,221.0625]
config['default_playable_height'] = 221.0625
config['assets'] = []
for variant in ['current','upgrade']:
    paths = [str(OUT/f'221-{variant}-{d}x.png') for d in [1,2,3]]
    box_height = Image.open(paths[0]).height
    config['assets'].append(dict(id=variant,label=f'{variant} range',animated=False,
        map_height=box_height*row['play_area_height']/221.0625,
        states={'se':{'idle':[variant],'walk':[variant]}},files={variant:paths}))
config['sizing_sources'] = [{'path':str(p),'sha256':lab.digest(p)} for p in [source,
    GAME/'Engine/Layout/TowerRangeOverlay.swift',GAME/'Engine/Core/RuntimeCanvas.swift']]
(OUT/'input-manifest.json').write_text(json.dumps(config,indent=2)+'\n')
lab.build(config,OUT/'lab')

# Native 1x proof: terrain stays at the same world scale as each overlay.
proof = Image.new('RGB',(750,510),'#eee9da')
draw = ImageDraw.Draw(proof)
draw.text((12,9),'Compact portrait / 221 pt playable height / native logical size',font=lab.font(16),fill='#222222')
for col, terrain in enumerate(['grass-only','battle-road','trenton']):
    background = Image.open(OUT/f'lab/{terrain}-under.jpg').convert('RGBA')
    background = lab.resize_rgba(background,(393,221))
    for line, variant in enumerate(['before','current','upgrade']):
        crop = background.crop((72,28,312,176))
        ring = Image.open(OUT/f'221-{variant}-1x.png').convert('RGBA')
        crop.alpha_composite(ring,((240-ring.width)//2,(148-ring.height)//2))
        x,y = 5+col*250,55+line*150
        proof.paste(crop,(x,y))
        draw.text((x+5,y+4),variant,font=lab.font(13),fill='white',stroke_width=1,stroke_fill='#222222')
    draw.text((col*250+10,34),terrain,font=lab.font(13),fill='#222222')
proof.save(OUT/'native-size-proof.png')
print(OUT/'native-size-proof.png')
