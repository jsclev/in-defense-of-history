import AppKit
import SwiftUI
import LevelEditorFormats
import SwiftUI

struct HudHeroesBarView: View {
    let layout: HeroBarLayout
    @ObservedObject var runner: LevelRunner

    var body: some View {
        let heroes = runner.hudHeroes
        HStack(spacing: layout.buttonSpacing) {
            ForEach(0..<2, id: \.self) { index in
                let hero = heroes.indices.contains(index) ? heroes[index] : nil
                let unitIndex = hero.flatMap { runner.hudHeroIndex(for: $0.id) }
                let role: HeroSelection.Role = index == 0 ? .primary : .secondary
                HeroHUDButton(iconName: hero?.iconImageName ?? "tower_locked_icon",
                              name: hero.map { "\(role.title), \($0.shortName), ranking \($0.ranking)" }
                                ?? "No \(role.title.lowercased()) chosen",
                              buttonSize: layout.buttonSize,
                              isAvailable: unitIndex != nil,
                              isSelected: unitIndex != nil && unitIndex == runner.selectedHeroIndex) {
                    if let hero { runner.selectHero(heroID: hero.id) }
                }
            }
            ReinforcementButton(buttonSize: CGSize(width: layout.buttonSize, height: layout.buttonSize),
                                cooldown: runner.reinforcementCooldown,
                                isAvailable: runner.canCallReinforcements,
                                action: { runner.toggleReinforcementPlacement() },
                                isSelected: runner.isPlacingReinforcements)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}

import SwiftUI

struct HeroHUDButton: View {
    let iconName: String
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(nsImage: Proof.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(nsImage: Proof.art(iconName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.75, height: buttonSize * 0.75)
                    .grayscale(isAvailable ? 0 : 1)
            }
            .frame(width: buttonSize, height: buttonSize)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HeroHUDButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private struct HeroHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(nsImage: Proof.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(nsImage: Proof.art("action_icon_call_reinforcements"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize.width * 0.75, height: buttonSize.height * 0.75)
                    .grayscale(cooldown.isReady ? 0 : 1)
                if !cooldown.isReady {
                    cooldownOverlay
                }
            }
            .frame(width: buttonSize.width, height: buttonSize.height)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize.width * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize.width * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ReinforcementButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel("Call reinforcements")
        .accessibilityValue(cooldown.isReady ? "Ready" : "\(cooldown.displaySeconds) seconds remaining")
    }

    private var cooldownOverlay: some View {
        // Keep the colored frame exposed. All progress stays inside a fixed
        // image box, so changing the countdown cannot affect menu/map layout.
        let width = buttonSize.width * 0.78
        let height = buttonSize.height * 0.78
        let remainingHeight = height * cooldown.remainingFraction
        let boundary = height - remainingHeight
        let labelHeight = buttonSize.height * 0.34
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55)
                .frame(width: width, height: remainingHeight)
                .offset(y: boundary)
            Text("\(cooldown.displaySeconds)")
                .font(.system(size: max(12, buttonSize.height * 0.26), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, buttonSize.width * 0.06)
                .frame(height: labelHeight)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: buttonSize.width * 0.06))
                .position(x: width / 2,
                          y: labelHeight / 2 + (height - labelHeight) * (1 - cooldown.remainingFraction))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: buttonSize.width * 0.04))
        .allowsHitTesting(false)
    }
}

private struct ReinforcementButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Availability changes the icon/overlay only, preserving the frame.
        configuration.label
    }
}
import SwiftUI

struct BeforeHudHeroesBarView: View {
    let layout: BeforeHeroBarLayout
    @ObservedObject var runner: LevelRunner

    var body: some View {
        let heroes = runner.hudHeroes
        HStack(spacing: layout.buttonSpacing) {
            ForEach(0..<2, id: \.self) { index in
                let hero = heroes.indices.contains(index) ? heroes[index] : nil
                let unitIndex = hero.flatMap { runner.hudHeroIndex(for: $0.id) }
                let role: HeroSelection.Role = index == 0 ? .primary : .secondary
                HeroHUDButton(iconName: hero?.iconImageName ?? "tower_locked_icon",
                              name: hero.map { "\(role.title), \($0.shortName), ranking \($0.ranking)" }
                                ?? "No \(role.title.lowercased()) chosen",
                              buttonSize: layout.buttonSize,
                              isAvailable: unitIndex != nil,
                              isSelected: unitIndex != nil && unitIndex == runner.selectedHeroIndex) {
                    if let hero { runner.selectHero(heroID: hero.id) }
                }
            }
            ReinforcementButton(buttonSize: CGSize(width: layout.buttonSize, height: layout.buttonSize),
                                cooldown: runner.reinforcementCooldown,
                                isAvailable: runner.canCallReinforcements,
                                action: { runner.toggleReinforcementPlacement() },
                                isSelected: runner.isPlacingReinforcements)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}
import CoreGraphics

/// A bottom-left HUD row whose overlap with the map stays inside the authored
/// lower-left occlusion. HUD margins consume space; they do not enlarge it.
public struct BeforeHeroBarLayout: Equatable {
    public static let buttonCount = 3
    public let buttonSize: CGFloat
    public let buttonSpacing: CGFloat
    public let frame: CGRect

    public init(runtimeCanvas: RuntimeCanvas) {
        let canvas = runtimeCanvas.virtualCanvas
        let occlusion = canvas.lowerLeftOcclusionArea
        let scale = runtimeCanvas.scaleFactor
        let right = runtimeCanvas.playAreaRect.minX
            + (occlusion.maxX - canvas.playAreaRect.minX) * scale
        let top = runtimeCanvas.playAreaRect.minY
            + (canvas.playAreaRect.maxY - occlusion.maxY) * scale
        let hud = runtimeCanvas.hudRect
        let width = max(0, min(occlusion.width * scale, right - hud.minX))
        let height = max(0, min(occlusion.height * scale, hud.maxY - top))
        let sections = CGFloat(Self.buttonCount) + CGFloat(Self.buttonCount - 1) * 0.1
        buttonSize = min(width / sections, height)
        buttonSpacing = buttonSize * 0.1
        frame = CGRect(x: hud.minX, y: hud.maxY - buttonSize,
                       width: sections * buttonSize, height: buttonSize)
    }
}

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
