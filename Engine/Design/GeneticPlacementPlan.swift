import Foundation

/// Successful tower placements, captured during the candidate's original
/// evaluation. Reading or comparing these values never executes the strategy.
public struct GeneticPlacementPlan: Codable, Equatable, Sendable {
    public struct Placement: Codable, Hashable, Sendable {
        public let slot: Int
        /// Authored level-one tower identity. Future branch choices cannot make
        /// identical starting towers count as different.
        public let towerID: UUID
        public init(slot: Int, towerID: UUID) { self.slot = slot; self.towerID = towerID }
    }

    /// Towers successfully placed before the first wave starts.
    public let initial: [Placement]
    /// First five successful later builds, in purchase order; upgrades are excluded.
    public let subsequent: [Placement]
    /// Present only for explicit recovery from an existing demonstration.
    public let sourceRecordingID: UUID?
    /// Compact original observations. Nil means historical evidence is unknown.
    public var playstyle: GeneticPlaystyle? = nil

    public init(initial: [Placement], subsequent: [Placement], sourceRecordingID: UUID? = nil) {
        self.initial = initial; self.subsequent = subsequent
        self.sourceRecordingID = sourceRecordingID
    }
}
