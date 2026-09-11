import AppKit
import LevelEditorFormats
import SwiftUI

@available(iOS 26.0, *)
struct SettingsView: View {
    @AppStorage("debugMode") private var debugMode = true
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @AppStorage(Constants.showDebugLayoutGuidesKey) private var showDebugLayoutGuides = false
    @AppStorage(Constants.enemyEscapeHapticsEnabledKey) private var enemyEscapeHapticsEnabled = true

    private let runtimeCanvas: RuntimeCanvas
    private let onConfigureHudLayout: () -> Void
    private let onExit: () -> Void
    private let metrics: HudMetrics
    private let contentInsets: EdgeInsets
    private let doneButtonHeight: CGFloat

    init(runtimeCanvas: RuntimeCanvas,
         onConfigureHudLayout: @escaping () -> Void,
         onExit: @escaping () -> Void) {
        self.runtimeCanvas = runtimeCanvas
        self.onConfigureHudLayout = onConfigureHudLayout
        self.onExit = onExit
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        self.metrics = metrics
        let padding = 28 * metrics.scale
        let safe = runtimeCanvas.safeInsetsRect
        let physical = runtimeCanvas.physicalRect
        contentInsets = EdgeInsets(top: safe.minY - physical.minY + padding,
                                   leading: safe.minX - physical.minX + padding,
                                   bottom: physical.maxY - safe.maxY + padding,
                                   trailing: physical.maxX - safe.maxX + padding)
        doneButtonHeight = HudSizing.doneButton.resolved(at: metrics.scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * metrics.scale) {
            Text("Settings")
                .font(.custom("Baskerville-Bold", size: 40 * metrics.scale))
                .foregroundStyle(.white)

            ScrollView {
                VStack(alignment: .leading, spacing: 18 * metrics.scale) {
                    toggle("Life-loss haptics",
                           detail: "Feel feedback when an enemy escapes and you lose a life.",
                           isOn: $enemyEscapeHapticsEnabled)

                    options
                }
            }

            Text("Version \(GameIdentity.version)")
                .font(.system(size: Typography.size(12 * metrics.scale)))
                .foregroundStyle(.white.opacity(0.5))

            HStack {
                Spacer()
                DoneButton(action: onExit)
                    .frame(height: doneButtonHeight)
            }
        }
        .padding(contentInsets)
        .background {
            ZStack {
                Image(nsImage: Probe.art("hero_screen_background"))
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(0.45)
            }
            .clipped()
            .ignoresSafeArea()
        }
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private var options: some View {
        toggle("Debug mode",
               detail: "Firing range ring under each tower you place, "
                     + "coloured and labelled by range.",
               isOn: $debugMode)

        toggle("Layout guides",
               detail: "Physical runtimeCanvas edge in green, safe area in red, play area in orange.",
               isOn: $showDebugLayoutGuides)

        toggle("Simulation readout",
               detail: "Wave and spawn state, top-left of the level map.",
               isOn: $showDebugInfo)

        Button(action: onConfigureHudLayout) {
            VStack(alignment: .leading, spacing: 3 * metrics.scale) {
                Text("HUD layout")
                    .font(.custom("Baskerville-SemiBold", size: 22 * metrics.scale))
                    .foregroundStyle(Color(red: 0.87, green: 0.72, blue: 0.35))
                Text("Drag the hero bar, stats, misc button, and master controls "
                     + "to any edge or corner of the screen.")
                    .font(.system(size: Typography.size(13 * metrics.scale)))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }

    }

    private func toggle(_ title: String, detail: String,
                        isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3 * metrics.scale) {
                Text(title)
                    .font(.custom("Baskerville-SemiBold", size: 22 * metrics.scale))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: Typography.size(13 * metrics.scale)))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .tint(Color(red: 0.87, green: 0.72, blue: 0.35))
    }
}

struct DoneButton: View {
    static let assetName = "done_button_20"

    

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(nsImage: Probe.art(Self.assetName))
                .resizable()
                .scaledToFit()
        }
        .buttonStyle(DoneButtonStyle())
        .accessibilityLabel("Done")
    }
}
private struct DoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
            .animation(configuration.isPressed
                ? .easeOut(duration: 0.09)
                : .spring(response: 0.28, dampingFraction: 0.55),
                value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    ()
                }
            }
    }
}
struct HudMetrics {
    let scale: CGFloat

    init(viewSize: CGSize, virtualCanvas: VirtualCanvas) {
        scale = HudScale(viewSize: viewSize, virtualCanvas: virtualCanvas).value
    }

    init(runtimeCanvas: RuntimeCanvas) {
        scale = HudScale(playableHeight: runtimeCanvas.playAreaRect.height).value
    }

    init(scale: CGFloat) {
        self.scale = scale
    }

    var livesIconHeight: CGFloat { HudSizing.livesIcon.resolved(at: scale) }
    var livesTextSize: CGFloat { HudSizing.livesText.resolved(at: scale) }
    var livesValueWidth: CGFloat { HudSizing.livesValueWidth.resolved(at: scale) }
    var livesRowSpacing: CGFloat { HudSizing.livesRowSpacing.resolved(at: scale) }

    var moneyIconHeight: CGFloat { HudSizing.moneyIcon.resolved(at: scale) }
    var moneyTextSize: CGFloat { HudSizing.moneyText.resolved(at: scale) }
    var moneyRowSpacing: CGFloat { HudSizing.moneyRowSpacing.resolved(at: scale) }

    var waveTextSize: CGFloat { HudSizing.waveText.resolved(at: scale) }

    var rangeLegendTextSize: CGFloat { HudSizing.rangeLegendText.resolved(at: scale) }

    var statSpacing: CGFloat { HudSizing.statSpacing.resolved(at: scale) }
    var statRowSpacing: CGFloat { HudSizing.statRowSpacing.resolved(at: scale) }
    var statPanelMargin: CGFloat { HudSizing.statPanelMargin.resolved(at: scale) }
    var statPlatePadding: CGFloat { HudSizing.statPlatePadding.resolved(at: scale) }
    var statPlateCorner: CGFloat { HudSizing.statPlateCorner.resolved(at: scale) }

    var hudPadding: CGFloat { HudSizing.hudPadding.resolved(at: scale) }

    var cornerButtonSize: CGFloat { HudSizing.cornerButton.resolved(at: scale) }
    var cornerButtonSpacing: CGFloat { HudSizing.cornerButtonSpacing.resolved(at: scale) }
    var hudMargin: CGFloat { HudSizing.hudMargin.resolved(at: scale) }

    var menuButtonSize: CGFloat { HudSizing.menuButton.resolved(at: scale) }
    var menuButtonSpacing: CGFloat { HudSizing.menuButtonSpacing.resolved(at: scale) }
}
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
