import Foundation

extension GeneticStore {
    func tacticalOrders(strategyID: Int64, row: GeneticSQL.Row) throws -> [GeneticTacticalOrder] {
        guard row.fields["tactical_count"] != nil, try !row.isNull("tactical_count") else { return [] }
        return try ordered("SELECT * FROM ga_tactical_order WHERE strategy_id=? ORDER BY ordinal", [strategyID],
            count: row.int("tactical_count")).map { row in
                guard let kind = GeneticTacticalOrder.Kind(rawValue: try row.string("kind")) else { throw row.invalid("kind") }
                let progress = try row.double("progress")
                guard (0...1).contains(progress) else { throw row.invalid("progress") }
                return try .init(slot: row.int("slot"), kind: kind, pathIndex: row.int("path_index"), progress: progress)
            }
    }
    func tacticalActions(evaluationID: Int64, row: GeneticSQL.Row) throws -> [GeneticTacticalReceipt]? {
        guard row.fields["tactical_count"] != nil, try !row.isNull("tactical_count") else { return nil }
        return try ordered("SELECT * FROM ga_tactical_action WHERE evaluation_id=? ORDER BY ordinal", [evaluationID],
            count: row.int("tactical_count")).map { row in
                guard let kind = GeneticTacticalOrder.Kind(rawValue: try row.string("kind")) else { throw row.invalid("kind") }
                return try .init(seconds: row.double("seconds"), wave: row.int("wave"), slot: row.int("slot"), kind: kind,
                    point: Point(row.double("x"), row.double("y")))
            }
    }
}
