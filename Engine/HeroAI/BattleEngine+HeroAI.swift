import Foundation

extension BattleEngine {
    /// Run only inside a complete shared battle tick, never from a UI frame or
    /// simulation adapter. Pauses, speed changes and batching use the same clock.
    func stepHeroAI() {
        for index in heroPosts.indices {
            let post = heroPosts[index]
            let id = post.hero.id
            guard heroAIEnabled[id] == true else { continue }
            guard let controller = heroAIControllers[id], let config = content.heroAI[id] else {
                fatalError("hero_ai[\(id)]: missing controller or configuration")
            }
            guard post.unit.state != .dead else {
                controller.reset()
                nextHeroAIDecisionTick[id] = nil
                continue
            }
            if let due = nextHeroAIDecisionTick[id], timer.tick < due { continue }
            nextHeroAIDecisionTick[id] = timer.tick + Int64(BattleGeometry.fireTicks(config.decisionInterval))
            let claimed = Set((garrisonsBySlot.values.flatMap(\.units) + heroPosts.map(\.unit))
                .filter { $0.state != .dead && $0.targetSpawnID >= 0 }.map(\.targetSpawnID))
            let threats = walkers.compactMap { enemy -> HeroAIContext.Threat? in
                guard enemy.hp > 0, !enemy.blockImmune, !claimed.contains(enemy.id) else { return nil }
                let path = paths[enemy.pathIndex]
                return HeroAIContext.Threat(id: enemy.id,
                    position: Point(enemy.position.x, enemy.position.y),
                    secondsToExit: max(0, path.totalLength - enemy.pathDistance) / enemy.speed)
            }
            let context = HeroAIContext(unit: post.unit, combat: post.combat,
                movement: post.movement, configuration: config,
                engageScanRadius: combatRules.heroEngageScanRadius, threats: threats)
            if let destination = controller.destination(in: context) {
                _ = commandHero(at: index, to: destination)
            }
        }
    }

    /// Shared order handler for player and AI. Does not select/deselect heroes,
    /// close tower menus, spend cooldowns or bypass navigation validation.
    @discardableResult
    func commandHero(at index: Int, to destination: Point) -> Bool {
        guard heroPosts.indices.contains(index) else { return false }
        var post = heroPosts[index]
        let previousTarget = post.unit.targetSpawnID
        guard post.movement.command(to: destination, unit: &post.unit) else { return false }
        if previousTarget >= 0 {
            post.enemySwingTicks[previousTarget] = nil
            blockedWalkerIDs.remove(previousTarget)
        }
        heroPosts[index] = post
        return true
    }
}
