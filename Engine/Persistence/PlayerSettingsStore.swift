import Combine
import Foundation

/// A live view of the database, never an independent persistent preference store.
@MainActor
public final class PlayerSettingsStore: ObservableObject {
    @Published public private(set) var values: PlayerSettings
    @Published public private(set) var heroControls: [HeroControlSetting]
    private let dao: PlayerSettingsDAO

    public init(dao: PlayerSettingsDAO) throws {
        self.dao = dao
        self.values = try dao.get()
        self.heroControls = try dao.getHeroControls()
    }

    public func setHeroAIEnabled(_ enabled: Bool, heroID: UUID) throws {
        try dao.setHeroAIEnabled(enabled, heroID: heroID)
        heroControls = try dao.getHeroControls()
    }

    /// Connect the live settings to an existing battle, including changes while
    /// paused. Manual orders update SQLite through the same settings store.
    func bindHeroControls(to battle: BattleEngine) -> AnyCancellable {
        var applyingSettings = false
        var writingSettings = false
        let settingsSubscription = $heroControls.sink { [weak battle] controls in
            guard !writingSettings, let battle else { return }
            applyingSettings = true
            defer { applyingSettings = false }
            for control in controls where battle.heroAIEnabled[control.id] != nil {
                battle.setHeroAIEnabled(control.aiEnabled, for: control.id)
            }
        }
        let battleSubscription = battle.$heroAIEnabled.sink { [weak self] modes in
            guard !applyingSettings, let self else { return }
            writingSettings = true
            defer { writingSettings = false }
            for (id, enabled) in modes where self.heroControls.first(where: { $0.id == id })?.aiEnabled != enabled {
                do { try self.setHeroAIEnabled(enabled, heroID: id) }
                catch { fatalError("Unable to save hero control: \(error)") }
            }
        }
        return AnyCancellable {
            settingsSubscription.cancel()
            battleSubscription.cancel()
        }
    }

    public func set(_ keyPath: WritableKeyPath<PlayerSettings, Bool>, to value: Bool) throws {
        var updated = try dao.get()
        updated[keyPath: keyPath] = value
        try dao.set(updated)
        values = try dao.get()
    }
}
