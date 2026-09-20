import Foundation

/// Marker states derive from the same authored star ledger as upgrade rewards.
public enum CampaignProgress {
    public enum State: String, CaseIterable, Sendable {
        case completed, current, upcoming
    }

    public static func states(orderedLevelIDs: [UUID], bestStarsByLevel: [UUID: Int]) throws -> [State] {
        var foundCurrent = false
        return try orderedLevelIDs.map { id in
            guard let stars = bestStarsByLevel[id], (0...3).contains(stars) else {
                throw DbError.Db(message: "player_meta_upgrade_level_stars[active:\(id)]: missing or invalid best_stars")
            }
            if stars > 0 { return .completed }
            if !foundCurrent {
                foundCurrent = true
                return .current
            }
            return .upcoming
        }
    }
}
