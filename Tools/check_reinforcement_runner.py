#!/usr/bin/env python3
"""Exercise production runner deployment/cleanup without UIKit or a game save.

Run swift test --scratch-path /tmp/td-presentation-tests first. This extracts the
current methods unchanged and links the actual Engine module. Only level loading,
the display-link clock, and the tower/hero fixtures are replaced.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def block(source, signature):
    start = source.index(signature)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, default=Path('/tmp/td-presentation-tests/arm64-apple-macosx/debug'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source_path = ROOT / 'Liberty Line/LevelRunner.swift'
    source = source_path.read_text()
    declarations = ['struct MilitiaSoldier:', 'private struct MilitiaGarrison {', 'private struct WalkPose {']
    methods = ['var canCallReinforcements:', 'private var reinforcementStats:',
               'private func garrisonMelee(', 'func callReinforcements(',
               'func toggleReinforcementPlacement()', 'func placeReinforcements(',
               'private func advanceReinforcements(', 'private func publishMilitia(']
    harness = r'''
import Foundation
import Combine
import LevelEditorFormats

final class RunnerProbe {
    struct Clock { var tick: Int64 = 0 }
    var timer = Clock()
    var isReady = true
    var isDefeated = false
    var isCleared = false
    var money = 123
    var selectedHeroIndex: Int?
    var menuDismissals = 0
    var heroPublications = 0
    func dismissMenu() { menuDismissals += 1 }
    func publishHeroes() { heroPublications += 1 }
    func isOnPath(_ point: CGPoint) -> Bool { point.y == 180 }
    private let meleeFormation = MeleeFormation()
    private static let reinforcementCount = 2
    private var nextReinforcementSlot = -1
    private var reinforcementSchedule: ReinforcementSchedule?
    private var reinforcementCooldown: ReinforcementCooldown = .ready
    private var isPlacingReinforcements = false
    private var garrisonsBySlot: [Int: MilitiaGarrison] = [:]
    private var militia: [MilitiaSoldier] = []
    private var militiaPrevPositions: [Int: CGPoint] = [:]
    private var militiaPoses: [Int: WalkPose] = [:]
    private var militiaRespawnedIDs: Set<Int> = []
    private var blockedWalkerIDs: Set<Int> = []
    private var damageTotalBySlot: [Int: Double] = [:]
    struct HeroFixture { var unit: MilitiaUnit }
    private var heroPosts: [HeroFixture] = []
    struct TowerFixture { var position: CGPoint = .zero }
    func placedTower(atSlot slot: Int) -> TowerFixture? { slot >= 0 ? TowerFixture() : nil }
    func towerLevel(for tower: TowerFixture) -> TowerLevel? { towerLevels[.melee]?[1]?[1] }
    var towerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [.melee: [1: [1:
        TowerLevel(cost: 100, range: 100, fireInterval: 1,
            meleeUnit: MeleeUnitStats(soldierCount: 2, attackRating: 5,
                defenseRating: 0, hp: 50, rallyPointRadius: 100, attackInterval: 1,
                respawnSeconds: 5, healPerSecond: 0))]]]

    init(lifetime: Double = 20, cooldown: Double = 20) throws {
        reinforcementSchedule = ReinforcementSchedule(config:
            try ReinforcementConfig(timeToLiveSeconds: lifetime, cooldownSeconds: cooldown))
    }
    func advance(to seconds: Int) {
        timer.tick = Int64(seconds * SimClock.ticksPerSecond)
        advanceReinforcements()
    }
    // PRODUCTION

    static func run() throws {
        let point = CGPoint(x: 120, y: 180)
        let placement = try RunnerProbe()
        // Path taps are inert until the HUD button arms deployment.
        placement.placeReinforcements(at: point)
        precondition(placement.militia.isEmpty)
        placement.selectedHeroIndex = 0
        placement.toggleReinforcementPlacement()
        precondition(placement.isPlacingReinforcements && placement.militia.isEmpty)
        precondition(placement.selectedHeroIndex == nil && placement.menuDismissals == 1)
        placement.placeReinforcements(at: .zero)
        precondition(placement.militia.isEmpty && placement.isPlacingReinforcements)
        placement.toggleReinforcementPlacement()
        precondition(!placement.isPlacingReinforcements && placement.reinforcementCooldown.isReady)
        placement.toggleReinforcementPlacement()
        placement.placeReinforcements(at: point)
        precondition(placement.militia.count == 2 && !placement.isPlacingReinforcements)
        placement.toggleReinforcementPlacement()
        placement.placeReinforcements(at: point)
        precondition(placement.militia.count == 2 && !placement.isPlacingReinforcements)
        placement.advance(to: 20)
        placement.toggleReinforcementPlacement()
        placement.placeReinforcements(at: point)
        precondition(placement.militia.count == 2 && !placement.isPlacingReinforcements)
        let single = try RunnerProbe()
        precondition(single.callReinforcements(at: point))
        precondition(single.militia.count == 2)
        precondition(single.militia.allSatisfy { $0.position == point })
        for _ in 0..<20 { precondition(!single.callReinforcements(at: .zero)) }
        precondition(single.garrisonsBySlot.count == 1 && single.nextReinforcementSlot == -2)
        single.garrisonsBySlot[-1]!.units[0].state = .fighting
        single.garrisonsBySlot[-1]!.units[0].targetSpawnID = 99
        single.blockedWalkerIDs = [99]
        single.militiaPrevPositions[-8] = point
        single.militiaPoses[-8] = WalkPose(facing: .south, walkPhase: 0, isWalking: false)
        single.militiaRespawnedIDs = [-8]
        single.damageTotalBySlot[-1] = 10
        single.advance(to: 19)
        precondition(single.militia.count == 2 && !single.canCallReinforcements)
        single.advance(to: 20)
        precondition(single.militia.isEmpty && single.garrisonsBySlot.isEmpty)
        precondition(single.blockedWalkerIDs.isEmpty && single.militiaPrevPositions.isEmpty)
        precondition(single.militiaPoses.isEmpty && single.militiaRespawnedIDs.isEmpty)
        precondition(single.damageTotalBySlot.isEmpty && single.money == 123)
        precondition(single.canCallReinforcements && single.reinforcementCooldown.isReady)
        precondition(single.callReinforcements(at: point))
        precondition(single.militia.count == 2 && !single.canCallReinforcements)

        let overlap = try RunnerProbe(lifetime: 30, cooldown: 20)
        precondition(overlap.callReinforcements(at: point))
        overlap.advance(to: 20)
        precondition(overlap.callReinforcements(at: .zero))
        precondition(overlap.militia.count == 4)
        var towerUnit = MilitiaUnit(position: Point(5, 5), hp: 50)
        towerUnit.state = .fighting
        towerUnit.targetSpawnID = 100
        overlap.garrisonsBySlot[0] = MilitiaGarrison(rallyPoint: Point(5, 5), units: [towerUnit])
        var heroUnit = towerUnit
        heroUnit.targetSpawnID = 101
        overlap.heroPosts = [HeroFixture(unit: heroUnit)]
        overlap.blockedWalkerIDs = [99, 100, 101]
        overlap.advance(to: 30)
        precondition(overlap.garrisonsBySlot[-1] == nil && overlap.garrisonsBySlot[-2] != nil)
        precondition(overlap.militia.count == 3 && overlap.blockedWalkerIDs == [100, 101])
        overlap.advance(to: 50)
        precondition(overlap.militia.map(\.id) == [0] && overlap.garrisonsBySlot.count == 1)
        precondition(overlap.heroPosts.count == 1 && overlap.blockedWalkerIDs == [100, 101])

        let dead = try RunnerProbe(lifetime: 5, cooldown: 20)
        precondition(dead.callReinforcements(at: point))
        for i in 0..<2 {
            dead.garrisonsBySlot[-1]!.units[i].state = .dead
            dead.garrisonsBySlot[-1]!.units[i].respawnTicksLeft = 100
        }
        dead.advance(to: 5)
        precondition(dead.garrisonsBySlot.isEmpty && dead.militia.isEmpty)
        precondition(!dead.canCallReinforcements)
        dead.advance(to: 200)
        precondition(dead.garrisonsBySlot.isEmpty && dead.militia.isEmpty)

        for state in 0..<4 {
            let unavailable = try RunnerProbe()
            if state == 0 { unavailable.isReady = false }
            if state == 1 { unavailable.isDefeated = true }
            if state == 2 { unavailable.isCleared = true }
            if state == 3 { unavailable.towerLevels = [:] }
            precondition(!unavailable.callReinforcements(at: point))
            precondition(unavailable.garrisonsBySlot.isEmpty && unavailable.reinforcementCooldown.isReady)
        }
        print("PASS: HUD arm/cancel/place, invalid path, cooldown gating, runner deployment, repeated taps, expiry cleanup, dead groups, overlapping groups, tower/hero preservation, unavailable states")
    }
}
@main struct Probe { static func main() throws { try RunnerProbe.run() } }
'''
    harness = harness.replace('// PRODUCTION', '\n'.join(block(source, d) for d in declarations + methods))
    args.output.mkdir(parents=True, exist_ok=True)
    swift_path = args.output / 'runner-probe.swift'
    swift_path.write_text(harness)
    with tempfile.TemporaryDirectory(prefix='td-reinforcement-probe-') as tmp:
        executable = Path(tmp) / 'probe'
        subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', '/tmp/td-tower-swift-cache',
                        '-I', str(args.build / 'Modules'), str(swift_path)]
                       + [str(p) for p in (args.build / 'LevelEditorFormats.build').glob('*.swift.o')]
                       + ['-o', str(executable)], check=True)
        result = subprocess.run([str(executable)], text=True, capture_output=True, check=True)
    (args.output / 'runner-results.json').write_text(json.dumps(dict(
        source_sha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
        production_blocks=declarations + methods, result=result.stdout.strip(),
        limitation='Method harness with level/tower/hero/clock fixtures; not full game on a physical device.'
    ), indent=2) + '\n')
    print(result.stdout.strip())


if __name__ == '__main__':
    main()
