import Combine

/// A live view of the database, never an independent persistent preference store.
@MainActor
public final class PlayerSettingsStore: ObservableObject {
    @Published public private(set) var values: PlayerSettings
    private let dao: PlayerSettingsDAO

    public init(dao: PlayerSettingsDAO) throws {
        self.dao = dao
        self.values = try dao.get()
    }

    public func set(_ keyPath: WritableKeyPath<PlayerSettings, Bool>, to value: Bool) throws {
        var updated = try dao.get()
        updated[keyPath: keyPath] = value
        try dao.set(updated)
        values = try dao.get()
    }
}
