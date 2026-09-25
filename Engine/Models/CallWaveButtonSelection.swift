/// Selection persists between taps until this wave is confirmed or replaced.
/// All entrances share one selection so another entrance cannot confirm it.
public struct CallWaveButtonSelection: Codable, Equatable {
    public private(set) var waveNumber: Int?
    public private(set) var selectedPosition: Point?
    public private(set) var hasConfirmed = false

    public init() {}

    public func isSelected(_ position: Point, for waveNumber: Int) -> Bool {
        self.waveNumber == waveNumber && selectedPosition == position && !hasConfirmed
    }

    public func isVisible(for waveNumber: Int) -> Bool {
        self.waveNumber != waveNumber || !hasConfirmed
    }

    /// Returns true once, on the second tap of the same entrance for this wave.
    /// No elapsed-time threshold is involved.
    public mutating func tap(_ position: Point, for waveNumber: Int) -> Bool {
        if self.waveNumber != waveNumber {
            self = Self()
            self.waveNumber = waveNumber
        }
        guard !hasConfirmed else { return false }
        guard selectedPosition == position else {
            selectedPosition = position
            return false
        }
        hasConfirmed = true
        return true
    }
}
