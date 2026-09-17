import Foundation

public final class CombatRulesDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "combat_rules", loggerName: CombatRulesDAO.self)
    }

    public func get() throws -> CombatRules {
        let records = try authoredRows("SELECT * FROM combat_rules", entity: "combat_rules") { row in
            guard try row.integer("id", minimum: 1) == 1 else { throw row.invalid("id", "must be 1") }
            let angles: [Double]
            do { angles = try JSONDecoder().decode([Double].self, from: Data(try row.text("grapeshot_spread_degrees").utf8)) }
            catch { throw row.invalid("grapeshot_spread_degrees", "must contain numeric angles") }
            guard !angles.isEmpty, angles.allSatisfy({ $0.isFinite && abs($0) <= 180 }), Set(angles).count == angles.count else {
                throw row.invalid("grapeshot_spread_degrees", "must contain distinct finite angles within +/-180 degrees")
            }
            let rules = CombatRules(
                killBountyMultiplier: try row.number("kill_bounty_multiplier", minimum: 0),
                routBountyMultiplier: try row.number("rout_bounty_multiplier", minimum: 0),
                captureBountyMultiplier: try row.number("capture_bounty_multiplier", minimum: 0),
                moraleMax: try row.number("morale_max", minimum: 0, strictlyGreater: true),
                baseMoraleRegenPerSecond: try row.number("base_morale_regen_per_second", minimum: 0, strictlyGreater: true),
                breakMoraleSplash: try row.number("break_morale_splash", minimum: 0),
                breakSplashRadius: try row.number("break_splash_radius", minimum: 0, strictlyGreater: true),
                waveringSplashMultiplier: try row.number("wavering_splash_multiplier", minimum: 0),
                shakenSpeedMultiplier: try row.number("shaken_speed_multiplier", minimum: 0, maximum: 1),
                routSpeedMultiplier: try row.number("rout_speed_multiplier", minimum: 0, strictlyGreater: true),
                steadyAdvanceHPGate: try row.number("steady_advance_hp_gate", minimum: 0, maximum: 1),
                contagionTickInterval: try row.number("contagion_tick_interval", minimum: 0, strictlyGreater: true),
                diseaseHPPerSecond: try row.number("disease_hp_per_second", minimum: 0),
                diseaseHPFloorFraction: try row.number("disease_hp_floor_fraction", minimum: 0, maximum: 1),
                diseaseMoralePerSecond: try row.number("disease_morale_per_second", minimum: 0),
                contagionSpreadRadius: try row.number("contagion_spread_radius", minimum: 0, strictlyGreater: true),
                contagionSpreadChance: try row.number("contagion_spread_chance", minimum: 0, maximum: 1),
                meleeAttackSpread: try row.number("melee_attack_spread", minimum: 0, maximum: 1),
                meleeMoveSpeed: try row.number("melee_move_speed", minimum: 0, strictlyGreater: true),
                meleeEngageScanRadiusFraction: try row.number("melee_engage_scan_radius_fraction", minimum: 0, strictlyGreater: true, maximum: 1),
                meleeReach: try row.number("melee_reach", minimum: 0, strictlyGreater: true),
                meleeCombatSpacing: try row.number("melee_combat_spacing", minimum: 0, strictlyGreater: true),
                meleeLeashRadiusFraction: try row.number("melee_leash_radius_fraction", minimum: 0, strictlyGreater: true, maximum: 1),
                enemySwingInterval: try row.number("enemy_swing_interval", minimum: 0, strictlyGreater: true),
                heroEngageScanRadius: try row.number("hero_engage_scan_radius", minimum: 0, strictlyGreater: true),
                heroLeashRadius: try row.number("hero_leash_radius", minimum: 0, strictlyGreater: true),
                meleePostSpread: try row.number("melee_post_spread", minimum: 0),
                meleeSpawnSpread: try row.number("melee_spawn_spread", minimum: 0),
                arrivalRadius: try row.number("arrival_radius", minimum: 0, strictlyGreater: true),
                rangeVerticalFraction: try row.number("range_vertical_fraction", minimum: 0, strictlyGreater: true, maximum: 1),
                projectileHitRadius: try row.number("projectile_hit_radius", minimum: 0, strictlyGreater: true),
                grapeshotHitRadius: try row.number("grapeshot_hit_radius", minimum: 0, strictlyGreater: true),
                solidShotHitRadius: try row.number("solid_shot_hit_radius", minimum: 0, strictlyGreater: true),
                firingToleranceDegrees: try row.number("firing_tolerance_degrees", minimum: 0, strictlyGreater: true, maximum: 180),
                initialHeadingDegrees: try row.number("initial_heading_degrees", minimum: -180, maximum: 180),
                enemyBodyOffsetX: try row.number("enemy_body_offset_x", minimum: -1000000),
                enemyBodyOffsetY: try row.number("enemy_body_offset_y", minimum: -1000000),
                moraleVisibilityThreshold: try row.number("morale_visibility_threshold", minimum: 0),
                moraleResponseDuration: try row.number("morale_response_duration", minimum: 0, strictlyGreater: true),
                moraleRecoveryDelay: try row.number("morale_recovery_delay", minimum: 0),
                moraleDisplayDuration: try row.number("morale_display_duration", minimum: 0, strictlyGreater: true),
                reinforcementSoldierCount: try row.integer("reinforcement_soldier_count", minimum: 1),
                grapeshotSpreadDegrees: angles)
            guard rules.moraleVisibilityThreshold <= rules.moraleMax else {
                throw row.invalid("morale_visibility_threshold", "exceeds morale_max")
            }
            return rules
        }
        guard records.count == 1 else { throw DbError.Db(message: "combat_rules: exactly one authored row is required") }
        return records[0]
    }
}
