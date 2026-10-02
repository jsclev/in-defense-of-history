import Foundation
@testable import LevelEditorFormats

/// Synthetic behavior, not a fallback tower catalog. Rates are independently
/// controlled so tests distinguish changed spending from changed participation.
enum GeneticDefenseFixtures {
    struct Tower {
        let slot: Int
        let family: UUID
        var cost = 100
        var damageRate = 10.0
        var blockingRate = 0.0
        var slowingRate = 0.0
        var income = 0
        var routes: [GeneticPlaystyle.Tower.Route] = []
    }
    static func plan(initial: [GeneticPlacementPlan.Placement], subsequent: [GeneticPlacementPlan.Placement]) -> GeneticPlacementPlan {
        plan(initial.map { Tower(slot:$0.slot,family:$0.towerID) }, subsequent:subsequent)
    }
    static func plan(_ specs: [Tower], subsequent: [GeneticPlacementPlan.Placement] = []) -> GeneticPlacementPlan {
        var result = GeneticPlacementPlan(initial:specs.map { .init(slot:$0.slot,towerID:$0.family) }, subsequent:subsequent)
        result.playstyle = .init(duration:90,purchases:specs.map {
            .init(seconds:0,wave:0,slot:$0.slot,familyID:$0.family,tierID:$0.family,action:"build",pathID:nil,cost:$0.cost)
        },towers:(0...3).flatMap { phase in specs.map { t in
            GeneticPlaystyle.Tower(phase:phase,seconds:Double(phase*30),slot:t.slot,familyID:t.family,tierID:t.family,
                level:1,branch:1,attackMode:"fixture",spent:t.cost,damage:t.damageRate * Double(phase*30),shots:t.damageRate > 0 ? phase : 0,
                blockingSeconds:t.blockingRate * Double(phase*30),income:t.income*phase,detonations:0,
                routes:t.routes,slowingSeconds:t.slowingRate * Double(phase*30))
        } },reinforcementActions:0,earlyWaveActions:0,demolitionActions:0,startingLives:20,minimumLives:20)
        return result
    }
}
