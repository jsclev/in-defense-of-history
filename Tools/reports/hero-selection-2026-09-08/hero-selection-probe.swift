
import AppKit
import SwiftUI
import LevelEditorFormats

final class LevelRunner: ObservableObject {
    @Published var selectedHeroIndex: Int?
    @Published var heroes: [HeroSoldier] = []
    @Published var isPlacingReinforcements = true
    var reinforcementCooldown: ReinforcementCooldown = .ready
    var canCallReinforcements = true
    func toggleReinforcementPlacement() { isPlacingReinforcements.toggle() }
    var selectedHeroes: [Hero]
    private var heroPosts: [HeroPost]
    private var heroPrevPositions: [Int: CGPoint] = [:]
    private var heroPoses: [Int: WalkPose] = [:]
    private var heroRoads = HeroRoads(points: [Point(0, 0), Point(100, 100)], neighbors: [[1], [0]])
    var selectedSlotIndex: Int? = 3
    var selectedTowerSlotIndex: Int? = 4
    var armedBuildKind: TowerKind? = .melee
    var armedUpgradeBranch: Int? = 1
    var isPlacingRallyPoint = true
    let money = 123

    init(_ choices: [Hero]) {
        selectedHeroes = choices.reversed() // Player order differs from live unit order.
        let combat = HeroCombatStats(attackRating: 5, defenseRating: 1, hp: 100,
            attackInterval: 1, respawnSeconds: 10, healPerSecond: 1, moveSpeed: 40)
        heroPosts = choices.enumerated().map { index, hero in
            HeroPost(hero: hero, assetName: hero.unitImageName!, combat: combat,
                     unit: MilitiaUnit(position: Point(Double(index * 20), 0), hp: 100),
                     stationNode: 0, spawnNode: 0)
        }
        publishHeroes()
    }
    func setDead(_ index: Int, _ dead: Bool) {
        heroPosts[index].unit.state = dead ? .dead : .returning
        if dead && selectedHeroIndex == index { selectedHeroIndex = nil }
        publishHeroes()
    }
    func snapshot() -> String {
        "\(String(describing: selectedHeroIndex))|\(heroes.map { "\($0.id):\($0.isSelected):\($0.position):\($0.hp)" })|\(heroPosts.map { $0.stationNode })|\(isPlacingReinforcements)|\(String(describing: selectedSlotIndex))|\(String(describing: selectedTowerSlotIndex))|\(String(describing: armedBuildKind))|\(String(describing: armedUpgradeBranch))|\(isPlacingRallyPoint)|\(money)"
    }
    struct HeroSoldier: Identifiable {
        let id: Int
        let assetName: String
        let baseAssetName: String
        var position: CGPoint
        var hp: Double
        var maxHP: Double
        var isSelected: Bool
    }
private struct HeroPost {
        let hero: Hero
        let assetName: String
        let combat: HeroCombatStats
        var unit: MilitiaUnit
        var stationNode: Int
        let spawnNode: Int
        var route: [Int] = []
        var routeTarget: Int = -1
        var enemySwingTicks: [Int: Int] = [:]
    }
private struct WalkPose {
        var facing: UnitFacing
        var walkPhase: Double
        var isWalking: Bool
    }
private struct HeroRoads {
        let points: [Point]
        let neighbors: [[Int]]
    }
var hudHeroes: [Hero] {
        var choices = heroPosts.map(\.hero)
        for hero in selectedHeroes where !choices.contains(where: { $0.id == hero.id }) {
            choices.append(hero)
        }
        return Array(choices.prefix(2))
    }
func hudHeroIndex(for heroID: UUID) -> Int? {
        heroPosts.firstIndex { $0.hero.id == heroID && $0.unit.state != .dead }
    }
func selectHero(_ index: Int) {
        guard heroPosts.indices.contains(index), heroPosts[index].unit.state != .dead else { return }
        dismissMenu()
        isPlacingReinforcements = false
        selectedHeroIndex = selectedHeroIndex == index ? nil : index
        publishHeroes()
    }
func selectHero(heroID: UUID) {
        guard let index = hudHeroIndex(for: heroID) else { return }
        selectHero(index)
    }
private func publishHeroes(alpha: Double = 1) {
        var out: [HeroSoldier] = []
        for (i, post) in heroPosts.enumerated() where post.unit.state != .dead {
            let cur = CGPoint(x: post.unit.position.x, y: post.unit.position.y)
            let prev = heroPrevPositions[i] ?? cur
            let pose = heroPoses[i]
                ?? WalkPose(facing: .south, walkPhase: 0, isWalking: false)
            let stepDistance = hypot(Double(cur.x - prev.x),
                                     Double(cur.y - prev.y))
            let renderedPhase = MeleeWalkCycle.interpolatedPhase(
                currentPhase: pose.walkPhase,
                stepDistance: stepDistance,
                alpha: alpha,
                cycleDistance: HeroWalkCycle.cycleDistance)
            out.append(HeroSoldier(
                id: i,
                assetName: HeroWalkCycle.assetName(
                    baseAssetName: post.assetName,
                    facing: pose.facing,
                    walkPhase: renderedPhase,
                    isWalking: pose.isWalking),
                baseAssetName: post.assetName,
                position: CGPoint(x: prev.x + (cur.x - prev.x) * alpha,
                                  y: prev.y + (cur.y - prev.y) * alpha),
                hp: post.unit.hp,
                maxHP: post.combat.hp,
                isSelected: selectedHeroIndex == i))
        }
        heroes = out
    }
func dismissMenu() {
        selectedSlotIndex = nil
        selectedTowerSlotIndex = nil
        armedBuildKind = nil
        armedUpgradeBranch = nil
        isPlacingRallyPoint = false
    }
func commandSelectedHero(to point: CGPoint) {
        guard let index = selectedHeroIndex, heroPosts.indices.contains(index) else { return }
        let node = heroNearestNode(to: Point(Double(point.x), Double(point.y)))
        guard node >= 0 else { return }
        heroPosts[index].stationNode = node
        heroPosts[index].route = []
        heroPosts[index].routeTarget = -1
        if heroPosts[index].unit.targetSpawnID >= 0 {
            heroPosts[index].enemySwingTicks[heroPosts[index].unit.targetSpawnID] = nil
        }
        heroPosts[index].unit.state = .returning
        heroPosts[index].unit.targetSpawnID = -1
        selectedHeroIndex = nil
        publishHeroes()
    }
private func heroNearestNode(to p: Point) -> Int {
        var best = -1
        var bestGap = Double.infinity
        for (i, q) in heroRoads.points.enumerated() {
            let gap = q.distance(to: p)
            if gap < bestGap {
                bestGap = gap
                best = i
            }
        }
        return best
    }
}

@main struct Probe {
    @MainActor static func art(_ name: String) -> NSImage {
        let folder = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
        let contents = try! JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String: Any]
        let entry = (contents["images"] as! [[String: Any]]).first { $0["filename"] != nil }!
        return NSImage(contentsOf: folder.appendingPathComponent(entry["filename"] as! String))!
    }
    @MainActor static func flush() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
    }
    @MainActor static func main() throws {
        let db = Db(dbPath: "/Users/john/projects/td/in-defense-of-history/Db/in_defense_of_history.sqlite", fullRefresh: false)
        let all = try db.heroDao.getAll()
        let choices = ["George Washington", "Henry Knox"].map { name in all.first { $0.shortName == name }! }
        let canvas = try db.virtualCanvasDao.get()
        let rect = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: rect, safeInsetsRect: rect)
        let layout = HeroBarLayout(runtimeCanvas: runtime)
        let hud = LevelRunner(choices), direct = LevelRunner(choices)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let host = NSHostingView(rootView: HudHeroesBarView(layout: layout, runner: hud))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: layout.frame.size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        defer { window.orderOut(nil) }
        flush()
        var eventNumber = 0
        func press(_ index: Int) {
            let location = CGPoint(x: layout.buttonSize / 2 + CGFloat(index) * (layout.buttonSize + layout.buttonSpacing),
                                   y: layout.buttonSize / 2)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                eventNumber += 1
                let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: eventNumber, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
                window.sendEvent(event)
                flush()
            }
        }
        // Press both actual portrait buttons, switch, and repeat to toggle off.
        for index in [0, 1, 1, 0] {
            press(index)
            direct.selectHero(index)
            precondition(hud.snapshot() == direct.snapshot(), "HUD/map selection mismatch")
        }
        precondition(hud.selectedHeroIndex == 0 && hud.heroes[0].isSelected)
        precondition(!hud.isPlacingReinforcements && hud.selectedSlotIndex == nil && hud.money == 123)
        hud.commandSelectedHero(to: CGPoint(x: 100, y: 100))
        direct.commandSelectedHero(to: CGPoint(x: 100, y: 100))
        precondition(hud.snapshot() == direct.snapshot() && hud.selectedHeroIndex == nil)
        // Removing the first sprite must not redirect the second portrait to index zero.
        hud.setDead(0, true); direct.setDead(0, true); flush()
        let beforeDisabledTap = hud.snapshot()
        press(0)
        precondition(hud.snapshot() == beforeDisabledTap)
        precondition(hud.heroes.map(\.id) == [1])
        press(1); direct.selectHero(1)
        precondition(hud.snapshot() == direct.snapshot() && hud.selectedHeroIndex == 1)
        let unchanged = hud.snapshot()
        hud.selectHero(heroID: choices[0].id)
        hud.selectHero(heroID: UUID())
        precondition(hud.snapshot() == unchanged, "Unavailable identity changed selection")
        hud.setDead(0, false); direct.setDead(0, false); flush()
        press(0); direct.selectHero(0)
        precondition(hud.snapshot() == direct.snapshot() && hud.selectedHeroIndex == 0)
        print("PASS: actual HUD button presses match map selection; switching, toggling, targeting, menu dismissal, reinforcement cancellation, identity after death, unavailable IDs, and respawn")
    }
}

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
                HeroHUDButton(iconName: hero?.iconImageName ?? "tower_locked_icon",
                              name: hero?.shortName ?? "No hero selected",
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
                Image(nsImage: Probe.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(nsImage: Probe.art(iconName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.75, height: buttonSize * 0.75)
                    .grayscale(isAvailable ? 0 : 1)
            }
            .frame(width: buttonSize, height: buttonSize)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize * 0.08)
                        .strokeBorder(.white, lineWidth: 2)
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
                Image(nsImage: Probe.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(nsImage: Probe.art("action_icon_call_reinforcements"))
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
                        .strokeBorder(.white, lineWidth: 2)
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
                .padding(.horizontal, 3)
                .frame(height: labelHeight)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
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
