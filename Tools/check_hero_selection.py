#!/usr/bin/env python3
"""Verify production HUD button actions and runner selection without game saves.

Uses macOS SwiftUI pointer events on the real HUD views. Runner methods
are extracted unchanged; hero placement/clock/loading use deterministic fixtures.
Requires the Engine module built by swift test --scratch-path /tmp/td-presentation-tests.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import tempfile

from check_reinforcement_runner import block

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', type=Path, default=Path('/tmp/td-presentation-tests/arm64-apple-macosx/debug'))
    args = parser.parse_args()
    runner_path = ROOT / 'Liberty Line/LevelRunner.swift'
    source = runner_path.read_text()
    signatures = ['struct HeroSoldier:', 'private struct HeroPost {',
                  'private struct WalkPose {',
                  'var hudHeroes:', 'func hudHeroIndex(', 'func selectHero(_',
                  'func selectHero(heroID:', 'private func publishHeroes(',
                  'func dismissMenu()', 'func commandSelectedHero(']
    paths = [ROOT / 'Liberty Line/Level Views/HUD' / name for name in
             ['HudHeroesBarView.swift', 'HeroHUDButton.swift', 'ReinforcementButton.swift', 'HudButtonView.swift']]
    views = '\n'.join(p.read_text() for p in paths)
    views = re.sub(r'\bImage\(([^)\n]+)\)', r'Image(nsImage: Probe.art(\1))', views)
    harness = r'''
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
    var heroSelection: HeroSelection?
    private var heroPosts: [HeroPost]
    private var heroPrevPositions: [Int: CGPoint] = [:]
    private var heroPoses: [Int: WalkPose] = [:]
    private var heroImageAspectRatios: [UUID: CGFloat] = [:]
    private var blockedWalkerIDs: Set<Int> = []
    var selectedSlotIndex: Int? = 3
    var selectedTowerSlotIndex: Int? = 4
    var armedBuildKind: TowerKind? = .melee
    var armedUpgradeBranch: Int? = 1
    var isPlacingRallyPoint = true
    let money = 123

    init(_ choices: [Hero]) {
        heroSelection = try! HeroSelection(heroes: Array(choices.reversed())) // Input and unit order cannot define roles.
        let combat = HeroCombatStats(attackRating: 5, defenseRating: 1, hp: 100,
            attackInterval: 1, respawnSeconds: 10, healPerSecond: 1, moveSpeed: 40)
        let area = try! HeroMovementArea(geoJSON: Data(#"{"features":[{"properties":{"category":"gameplay","kind":"enemy_path"},"geometry":{"type":"Polygon","coordinates":[[[-20,-20],[200,-20],[200,200],[-20,200],[-20,-20]]]}}]}"#.utf8), defaultPathWidth: 140)
        heroPosts = choices.enumerated().map { index, hero in
            HeroPost(hero: hero, assetName: hero.unitImageName!, combat: combat,
                     unit: MilitiaUnit(position: Point(Double(index * 20), 0), hp: 100),
                     movement: try! HeroMovement(area: area, spawn: Point(Double(index * 20), 0)))
        }
        heroImageAspectRatios = Dictionary(uniqueKeysWithValues: choices.map { ($0.id, CGFloat(1)) })
        publishHeroes()
    }
    func setDead(_ index: Int, _ dead: Bool) {
        heroPosts[index].unit.state = dead ? .dead : .returning
        if dead && selectedHeroIndex == index { selectedHeroIndex = nil }
        publishHeroes()
    }
    func snapshot() -> String {
        "\(String(describing: selectedHeroIndex))|\(heroes.map { "\($0.id):\($0.isSelected):\($0.position):\($0.hp)" })|\(heroPosts.map { $0.movement.station })|\(isPlacingReinforcements)|\(String(describing: selectedSlotIndex))|\(String(describing: selectedTowerSlotIndex))|\(String(describing: armedBuildKind))|\(String(describing: armedUpgradeBranch))|\(isPlacingRallyPoint)|\(money)"
    }
    // PRODUCTION
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
        let choices = ["Henry Knox", "George Washington"].map { name in all.first { $0.shortName == name }! }
        let canvas = try db.virtualCanvasDao.get()
        let rect = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: rect, safeInsetsRect: rect)
        let layout = HeroBarLayout(runtimeCanvas: runtime)
        let hud = LevelRunner(choices), direct = LevelRunner(choices)
        precondition(hud.hudHeroes.map(\.shortName) == ["George Washington", "Henry Knox"])
        let primaryIndex = hud.hudHeroIndex(for: hud.hudHeroes[0].id)!
        let secondaryIndex = hud.hudHeroIndex(for: hud.hudHeroes[1].id)!
        precondition(primaryIndex == 1 && secondaryIndex == 0, "Probe requires HUD order to differ from unit order")
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
            direct.selectHero(heroID: hud.hudHeroes[index].id)
            precondition(hud.snapshot() == direct.snapshot(), "HUD/map selection mismatch")
        }
        precondition(hud.selectedHeroIndex == primaryIndex && hud.heroes[primaryIndex].isSelected)
        precondition(!hud.isPlacingReinforcements && hud.selectedSlotIndex == nil && hud.money == 123)
        precondition(hud.commandSelectedHero(to: CGPoint(x: 100, y: 100)))
        precondition(direct.commandSelectedHero(to: CGPoint(x: 100, y: 100)))
        precondition(hud.snapshot() == direct.snapshot() && hud.selectedHeroIndex == nil)
        // Removing the first sprite must not redirect the second portrait to index zero.
        hud.setDead(primaryIndex, true); direct.setDead(primaryIndex, true); flush()
        let beforeDisabledTap = hud.snapshot()
        press(0)
        precondition(hud.snapshot() == beforeDisabledTap)
        precondition(hud.heroes.map(\.id) == [secondaryIndex])
        press(1); direct.selectHero(secondaryIndex)
        precondition(hud.snapshot() == direct.snapshot() && hud.selectedHeroIndex == secondaryIndex)
        let unchanged = hud.snapshot()
        hud.selectHero(heroID: choices[primaryIndex].id)
        hud.selectHero(heroID: UUID())
        precondition(hud.snapshot() == unchanged, "Unavailable identity changed selection")
        hud.setDead(primaryIndex, false); direct.setDead(primaryIndex, false); flush()
        press(0); direct.selectHero(primaryIndex)
        precondition(hud.snapshot() == direct.snapshot() && hud.selectedHeroIndex == primaryIndex)
        let solo = LevelRunner([choices[0]])
        precondition(solo.hudHeroes.count == 1 && solo.heroSelection?.secondary == nil)
        host.rootView = HudHeroesBarView(layout: layout, runner: solo)
        flush()
        press(1)
        precondition(solo.selectedHeroIndex == nil, "Empty secondary slot must not select a unit")
        press(0)
        precondition(solo.selectedHeroIndex == 0)
        press(1)
        precondition(solo.selectedHeroIndex == 0, "Empty secondary slot must not clear the primary")
        print("PASS: primary-first HUD with reversed unit order and solo choice; actual HUD button presses match map selection; switching, toggling, targeting, menu dismissal, reinforcement cancellation, identity after death, unavailable IDs, and respawn")
    }
}
'''
    harness = harness.replace('// PRODUCTION', '\n'.join(block(source, s) for s in signatures))
    args.output.mkdir(parents=True, exist_ok=True)
    swift_path = args.output / 'hero-selection-probe.swift'
    swift_path.write_text(harness + '\n' + views)
    build = args.build
    with tempfile.TemporaryDirectory(prefix='td-hero-selection-') as tmp:
        executable = Path(tmp) / 'probe'
        subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-tower-swift-cache',
                        '-I', str(build / 'Modules'), str(swift_path)]
                       + [str(p) for p in (build / 'LevelEditorFormats.build').glob('*.swift.o')]
                       + ['-o', str(executable)], check=True)
        result = subprocess.run([str(executable)], capture_output=True, text=True, timeout=30)
        if result.returncode:
            (args.output / 'failure.log').write_text(result.stdout + result.stderr)
            raise RuntimeError(f'Hero selection probe failed; see {args.output / "failure.log"}')
    (args.output / 'failure.log').unlink(missing_ok=True)
    (args.output / 'results.json').write_text(json.dumps(dict(
        result=result.stdout.strip(), production_blocks=signatures,
        sources={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in [runner_path] + paths},
        limitation='macOS SwiftUI pointer events with fixture units; not iOS touch delivery or full game loading.'
    ), indent=2) + '\n')
    print(result.stdout.strip())


if __name__ == '__main__':
    main()
