from pathlib import Path
import re, sys, subprocess
root=Path('/Users/john/projects/td/in-defense-of-history')
sys.path.insert(0,str(root/'Tools'))
from check_reinforcement_runner import block
p=root/'Tools/reports/enemy-escape-haptics-2026-09-08'
source=(root/'Liberty Line/SettingsView.swift').read_text()
menu=(root/'Liberty Line/MenuScreens.swift').read_text()
source+='\n'+block(menu,'struct DoneButton:')+'\n'+block(menu,'private struct DoneButtonStyle:')
source+='\n'+block((root/'Liberty Line/HudMetrics.swift').read_text(),'struct HudMetrics {')
source=source.replace('static var aspect: CGFloat { HudIcon.aspect(of: assetName) }','').replace('UIImpactFeedbackGenerator(style: .light).impactOccurred()', '()')
source=re.sub(r'\bImage\(([^)\n]+)\)',r'Image(nsImage: Probe.art(\1))',source)
main=r'''
@main struct Probe {
 @MainActor static func art(_ name: String) -> NSImage {
  let dir=URL(fileURLWithPath:"/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
  let data=try! JSONSerialization.jsonObject(with:Data(contentsOf:dir.appendingPathComponent("Contents.json"))) as! [String:Any]
  let item=(data["images"] as! [[String:Any]]).first { $0["filename"] != nil }!
  return NSImage(contentsOf:dir.appendingPathComponent(item["filename"] as! String))!
 }
 @MainActor static func main() throws {
  let app=NSApplication.shared
  app.setActivationPolicy(.accessory)
  app.finishLaunching()
  let db=Db(dbPath:"/Users/john/projects/td/in-defense-of-history/Db/in_defense_of_history.sqlite",fullRefresh:false)
  let vc=try db.virtualCanvasDao.get()
  for h in [340.0,402.0] {
   let rect=CGRect(x:0,y:0,width:h*16/9,height:h)
   let runtime=RuntimeCanvas(virtualCanvas:vc,physicalRect:rect,safeInsetsRect:rect)
   let view=SettingsView(runtimeCanvas:runtime,onConfigureHudLayout:{},onExit:{}).frame(width:rect.width,height:rect.height)
   let host=NSHostingView(rootView:view)
   let window=NSWindow(contentRect:rect,styleMask:[.borderless],backing:.buffered,defer:false)
   window.contentView=host
   window.makeKeyAndOrderFront(nil)
   host.layoutSubtreeIfNeeded()
   RunLoop.main.run(until:Date(timeIntervalSinceNow:0.15))
   let rep=host.bitmapImageRepForCachingDisplay(in:host.bounds)!
   host.cacheDisplay(in:host.bounds,to:rep)
   try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("settings-\(Int(h))pt.png"))
   window.orderOut(nil)
  }
 }
}
'''
swift=p/'settings-render.swift';swift.write_text('import AppKit\nimport LevelEditorFormats\n'+source+main)
build=Path('/tmp/td-presentation-tests/arm64-apple-macosx/debug')
subprocess.run(['swiftc','-parse-as-library','-module-cache-path','/tmp/td-tower-swift-cache','-I',str(build/'Modules'),str(swift)]+[str(f) for f in (build/'LevelEditorFormats.build').glob('*.swift.o')]+['-o','/tmp/td-haptic-settings-render'],check=True)
subprocess.run(['/tmp/td-haptic-settings-render',str(p)],check=True)
