import Foundation

enum LevelHUDControl: String, Codable, CaseIterable {
    case primaryHero, secondaryHero, reinforcements, speed, pause, inventory
}

/// The same display input feeds the live HUD and its recorded, read-only copy.
/// Availability, cooldowns, selection, and wave timing are resolved by the engine.
struct LevelHUDState: Codable, Equatable {
    struct HeroButton: Codable, Equatable {
        let id: UUID
        let portrait: String
        let label: String
        let isAvailable: Bool
        let isSelected: Bool
    }
    static let activationSeconds = 0.5
    let heroes: [HeroButton]
    let reinforcementCooldown: ReinforcementCooldown
    let canCallReinforcements: Bool
    let isPlacingReinforcements: Bool
    let lives: Int
    let money: Int
    let wave: Int
    let waveCount: Int
    let isPaused: Bool
    let seconds: Double
    let activated: [LevelHUDControl]
    let callWavePositions: [Point]
    let nextWave: Int
    let countdownSeconds: Int?
    let callWaveSelection: CallWaveButtonSelection

    func isActivated(_ control: LevelHUDControl) -> Bool { activated.contains(control) }

    @MainActor init(engine: BattleEngine) {
        heroes = engine.hudHeroes.enumerated().map { index, hero in
            let unit = engine.hudHeroIndex(for: hero.id)
            let role: HeroSelection.Role = index == 0 ? .primary : .secondary
            return HeroButton(id: hero.id, portrait: hero.iconImageName,
                label: "\(role.title), \(hero.shortName), ranking \(hero.ranking)",
                isAvailable: unit != nil, isSelected: unit != nil && unit == engine.selectedHeroIndex)
        }
        reinforcementCooldown = engine.reinforcementCooldown
        canCallReinforcements = engine.canCallReinforcements
        isPlacingReinforcements = engine.isPlacingReinforcements
        lives = engine.lives; money = engine.money
        wave = engine.currentWaveNumber; waveCount = engine.waveCount
        isPaused = engine.isPaused
        seconds = Double(engine.timer.tick) * SimClock.dt
        activated = LevelHUDControl.allCases.filter { control in
            guard let tick = engine.hudActivationTicks[control] else { return false }
            return Double(engine.timer.tick - tick) * SimClock.dt < Self.activationSeconds
        }
        callWavePositions = engine.awaitingWaveStart ? engine.callWaveButtonPositions : []
        nextWave = engine.nextWaveNumber
        countdownSeconds = engine.waveCountdownSeconds
        callWaveSelection = engine.callWaveSelection
    }
}

extension BattleEngine {
    /// Record the HUD gesture, including buttons whose activation has no lasting
    /// selected state. The existing handlers still own all gameplay behavior.
    func activateHUD(_ control: LevelHUDControl) {
        recordingInput("activateHUD", ["control": control.rawValue]) {
            guard acceptsPlayerInput else { return }
            hudActivationTicks[control] = timer.tick
            switch control {
            case .primaryHero, .secondaryHero:
                let index = control == .primaryHero ? 0 : 1
                if hudHeroes.indices.contains(index) { selectHero(heroID: hudHeroes[index].id) }
            case .reinforcements: toggleReinforcementPlacement()
            case .speed: speedUp()
            case .pause: pause()
            case .inventory: break
            }
        }
    }

    func tapCallWave(at point: Point) {
        recordingInput("tapCallWave", ["x": String(point.x), "y": String(point.y)]) {
            guard acceptsPlayerInput, awaitingWaveStart, callWaveButtonPositions.contains(point) else { return }
            if callWaveSelection.tap(point, for: nextWaveNumber) { startNextWave() }
        }
    }
}
