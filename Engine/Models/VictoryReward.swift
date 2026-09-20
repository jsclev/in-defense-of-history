import Foundation

/// The existing campaign star rule, shared by battles and ledger persistence.
public struct VictoryReward: Equatable {
    public let earned: Int
    public let bestStars: Int

    public init(lives: Int, startingLives: Int, previousBestStars: Int) throws {
        guard startingLives > 0, (0...startingLives).contains(lives), (0...3).contains(previousBestStars) else {
            throw DbError.Db(message: "Invalid victory lives or previous star result")
        }
        let fraction = Double(lives) / Double(startingLives)
        let stars = lives == 0 ? 0 : fraction >= 0.9 ? 3 : fraction >= 0.3 ? 2 : 1
        bestStars = max(previousBestStars, stars)
        earned = bestStars - previousBestStars
    }
}
