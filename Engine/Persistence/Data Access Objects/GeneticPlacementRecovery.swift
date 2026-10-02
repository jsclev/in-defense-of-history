import Foundation

/// Explicit legacy-data recovery, separate from ranking and comparison. Reads
/// stored tower changes directly; no battle, playback clock or RNG is run.
enum GeneticPlacementRecovery {
    static func read(dao: LevelRunDAO, recordingID: UUID) throws -> GeneticPlacementPlan {
        let record = try dao.get(id: recordingID)
        let setup = try dao.replaySetup(record)
        let bases = Dictionary(uniqueKeysWithValues: setup.towers.filter { $0.level == 1 && $0.branch == 1 }.map { ($0.kind, $0.id) })
        var initial: [GeneticPlacementPlan.Placement] = [], later: [GeneticPlacementPlan.Placement] = []
        var seen: Set<Int> = [], cursor: Int64 = -1, sawOpening = false
        while let row = try dao.actions(runID: recordingID, after: cursor, limit: 1).first {
            cursor = row.sequence
            guard row.name.hasPrefix("battle-events-") else { continue }
            let block = try BattleEventBlock.decode(row, resolve: { try dao.loadContent($0) })
            for change in block.towers.changes {
                for tower in change.value where seen.insert(tower.slotIndex).inserted {
                    guard let base = bases[tower.kind] else {
                        throw DbError.Db(message: "recording \(recordingID): missing base tower identity for \(tower.kind)")
                    }
                    let placement = GeneticPlacementPlan.Placement(slot: tower.slotIndex, towerID: base)
                    if change.tick == 0 { initial.append(placement) }
                    else if later.count < 5 { later.append(placement) }
                }
                if change.tick == 0 { sawOpening = true }
            }
            if later.count == 5 { break }
        }
        guard sawOpening else {
            throw DbError.Db(message: "recording \(recordingID): missing initial tower state; cannot infer opening")
        }
        return GeneticPlacementPlan(initial: initial, subsequent: later, sourceRecordingID: recordingID)
    }
}
