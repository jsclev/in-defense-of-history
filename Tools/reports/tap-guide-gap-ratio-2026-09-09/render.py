"""Host-render the actual debug guide view; does not launch the game or Simulator."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

out = Path(__file__).resolve().parent
game = out.parents[2]
build = Path('/tmp/td-tap-area-tests/arm64-apple-macosx/debug')
shutil.copy2(game / 'Db/in_defense_of_history.sqlite', out / 'fixture.sqlite')
view_file = game / 'Engine/Debug/DebugLayoutGuidesView.swift'
# UIKit is an unused import in this view; all drawing is ordinary SwiftUI.
view = view_file.read_text().replace('import UIKit', 'import AppKit')
main = r'''
@main struct TapAreaProof {
    static func values(_ rect: CGRect) -> [CGFloat] {
        [rect.minX, rect.minY, rect.width, rect.height]
    }
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let db = Db(dbPath: out.appendingPathComponent("fixture.sqlite").path, fullRefresh: false)
        let vc = try db.virtualCanvasDao.get()
        let minimum = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let fixtures: [(String, CGRect, CGRect)] = [
            ("minimum", minimum, minimum),
            ("phone", CGRect(x: 0, y: 0, width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 373)),
            ("tablet", CGRect(x: 0, y: 0, width: 1133, height: 744), CGRect(x: 0, y: 0, width: 1133, height: 719))
        ]
        var data: [[String: Any]] = []
        for (name, physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let scene = ZStack(alignment: .topLeading) {
                Color(red: 0.09, green: 0.11, blue: 0.14)
                SwiftUI.Path(runtime.runtimePlayArea).fill(.white.opacity(0.04))
                DebugLayoutGuidesView(runtimeCanvas: runtime)
            }.frame(width: physical.width, height: physical.height).clipped()
            for density in (name == "phone" ? [1, 3] : [1]) {
                let renderer = ImageRenderer(content: scene)
                renderer.scale = CGFloat(density)
                let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
                try rep.representation(using: .png, properties: [:])!
                    .write(to: out.appendingPathComponent("\(name)-guides@\(density)x.png"))
            }
            data.append(["fixture": name, "physical": values(physical), "safe": values(safe),
                         "play": values(runtime.playAreaRect), "tapBounds": values(runtime.runtimeTapArea.boundingBoxOfPath),
                         "topInset": runtime.playAreaRect.height * VirtualCanvas.tapAreaTopInsetFraction])
        }
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
            .write(to: out.appendingPathComponent("layout.json"))
    }
}
'''
source = out / 'render.swift'
source.write_text('import LevelEditorFormats\n' + view + main)
binary = '/tmp/td-tap-area-render'
subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-tap-area-swift-cache',
                '-I', str(build / 'Modules'), str(source)]
               + [str(p) for p in (build / 'LevelEditorFormats.build').glob('*.swift.o')]
               + ['-o', binary], check=True)
subprocess.run([binary, str(out)], check=True)
files = ['Engine/Design/VirtualCanvas.swift', 'Engine/Core/RuntimeCanvas.swift',
         'Engine/Debug/DebugLayoutGuidesView.swift', 'Liberty Line/SettingsView.swift',
         'LevelEditor/EditorCanvas.swift', 'LevelEditor/EditorView.swift',
         'Tests/LevelEditorFormatsTests/TapAreaTests.swift']
(out / 'source-hashes.json').write_text(json.dumps({f: hashlib.sha256((game/f).read_bytes()).hexdigest()
                                                 for f in files}, indent=2) + '\n')
