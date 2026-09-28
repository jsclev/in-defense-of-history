import type { BattleContent } from './content';
import type { PlayerState, Wave } from '../data/contracts';
import type { Presentation, Pose } from '../content/presentation';
import { contentError } from '../content/schema';
import { visibleWaveMarkers } from '../content/geometry';
import type { HudControl, HudState } from '../hud/state';
import type { Point } from '../hud/layout';
import { distance, equal, lerp } from './navigation';
import { BattleClock, dt, ReinforcementSchedule, WaveSchedule } from './schedules';
import { Ally, ringPoint, type Enemy } from './units';
import { TowerPlacement, type PlacedTower } from './towers';
import type { TowerTier } from '../data/contracts';
import { EnemyMorale } from './combat-math';
import { TowerCombat } from './combat';

export type Actor = { id: string; key: string; position: Point; health: number; kind: 'hero' | 'militia' | 'enemy';
  heroIndex: number | null; selected: boolean; profile: Pose | null; morale?: EnemyMorale };
export type SessionEvents = { pause(): void; outcome(value: 'victory' | 'defeat'): void; lifeLost(): void };
export class BattleSession {
  readonly clock: BattleClock; readonly waves: WaveSchedule; readonly reinforcement: ReinforcementSchedule;
  readonly heroes: Ally[]; soldiers: Ally[] = []; enemies: Enemy[] = [];
  readonly towers: TowerPlacement; readonly combat: TowerCombat;
  money: number; lives: number; paused = false; outcome: 'victory' | 'defeat' | null = null;
  selectedHero: number | null = null; placing = false; player: PlayerState;
  private nextSlot = -1; private nextEnemy = 0;
  private pending: { tick: number; path: number; enemyID: string }[] = [];
  private activated = new Map<HudControl, number>();
  constructor(readonly content: BattleContent, readonly presentation: Presentation, now: () => number,
    private readonly events: SessionEvents, private readonly random = Math.random) {
    const speed = content.config.playSpeeds.find(s => s.source === 'player');
    if (!speed) throw contentError('play_speed[player].factor', 'Missing player clock');
    this.clock = new BattleClock(speed.factor, now); this.waves = new WaveSchedule(content.waves);
    this.reinforcement = new ReinforcementSchedule(content.config.reinforcement);
    this.money = content.level.starting_money; this.lives = content.level.num_starting_lives; this.player = content.player;
    this.heroes = content.heroes.map(({ hero, spawn }, i) => new Ally(`hero-${i}`, spawn, hero.combat, hero, null, content.area,
      content.config.combat.hero_engage_scan_radius, content.config.combat.hero_leash_radius));
    for (const hero of this.heroes) this.profile(hero);
    this.towers = new TowerPlacement(content, { acceptsInput: () => this.acceptsInput, money: () => this.money,
      spend: value => { this.money -= value; }, cancelOther: () => { this.placing = false; this.selectedHero = null; },
      changed: (tower, old, rank) => { this.syncGarrison(tower, old, rank); this.combat.changed(tower, old, rank); } });
    this.combat = new TowerCombat(this, random);
  }
  get acceptsInput() { return !this.paused && this.outcome === null; }
  get canReinforce() { return this.acceptsInput && this.content.reinforcement !== null && this.reinforcement.cooldown(this.clock.tick).fraction === 0; }
  get hud(): HudState {
    const tick = this.clock.tick, schedule = this.waves.state(tick), cooldown = this.reinforcement.cooldown(tick);
    return { heroes: this.heroes.map((unit, i) => ({ id: unit.hero!.id, portrait: unit.hero!.icon_image_name,
      label: `${i === 0 ? 'Primary hero' : 'Secondary hero'}, ${unit.hero!.short_name}, ranking ${unit.hero!.ranking}`,
      isAvailable: unit.state !== 'dead', isSelected: this.selectedHero === i })),
      money: this.money, lives: this.lives, wave: Math.max(1, this.waves.next), waveCount: this.content.waves.length,
      isPaused: this.paused, reinforcementRemaining: cooldown.fraction, reinforcementSeconds: cooldown.seconds,
      canCallReinforcements: this.canReinforce, isPlacingReinforcements: this.placing,
      activated: [...this.activated].filter(([, at]) => (tick - at) * dt < .5).map(([id]) => id),
      callWavePositions: this.outcome === null && this.waves.canCall(tick) ? visibleWaveMarkers(this.content.markers,
        this.content.waves[this.waves.next]!.spawns.map(s => s.path_index)) : [],
      nextWave: this.waves.next + 1, countdownSeconds: schedule.seconds, selectedWave: this.waves.selected,
      acceptsInput: this.acceptsInput, speed: this.clock.factor,
    };
  }
  activate(id: HudControl) {
    if (!this.acceptsInput) return;
    this.activated.set(id, this.clock.tick);
    switch (id) {
      case 'primaryHero': this.selectHero(0); break;
      case 'secondaryHero': this.selectHero(1); break;
      case 'reinforcements': if (this.canReinforce) { this.towers.dismiss(); this.selectedHero = null; this.placing = !this.placing; } break;
      case 'speed': this.clock.setSpeed(this.clock.factor * 2); break;
      case 'pause': this.pause(); this.events.pause(); break;
      case 'inventory': break; // Native LevelHUDState.activateHUD intentionally only flashes this control.
    }
  }
  selectHero(index: number) {
    if (!this.acceptsInput || !this.heroes[index] || this.heroes[index]!.state === 'dead') return;
    this.towers.dismiss(); this.placing = false; this.selectedHero = this.selectedHero === index ? null : index;
  }
  mapTap(point: Point): boolean {
    if (!this.acceptsInput || !Number.isFinite(point.x + point.y)) return false;
    if (this.towers.placement) return this.towers.place(point);
    if (this.towers.selected !== null) { this.towers.dismiss(); return false; }
    if (this.placing) {
      if (!this.canReinforce || !this.content.routes.some(p => p.nearest(point).gap <= this.content.config.canvas.path_width / 2)) return false;
      const slot = this.nextSlot, stats = this.content.reinforcement!, rules = this.content.config.combat;
      if (!this.reinforcement.deploy(slot, this.clock.tick)) return false;
      for (let i = 0; i < rules.reinforcement_soldier_count; i++) {
        const unit = new Ally(`militia-${slot}-${i}`, ringPoint(i, rules.reinforcement_soldier_count, point, rules.melee_spawn_spread),
          { ...stats, move_speed: rules.melee_move_speed }, null, slot, this.content.area,
          stats.rally_point_radius * rules.melee_engage_scan_radius_fraction, stats.rally_point_radius * rules.melee_leash_radius_fraction);
        unit.station = unit.rally = point; this.soldiers.push(unit);
      }
      this.nextSlot--; this.placing = false; this.formations(); return true;
    }
    if (this.selectedHero === null) return false;
    const hero = this.heroes[this.selectedHero]!;
    if (!hero.command(point)) return false;
    // Manual orders disable this attempt's AI, without rewriting the player's default.
    hero.aiEnabled = false; hero.recovering = false; hero.nextDecision = 0; this.selectedHero = null; return true;
  }
  tapWave(point: Point) {
    if (!this.acceptsInput || !this.hud.callWavePositions.some(p => equal(p, point))) return;
    const started = this.waves.tap(point, this.clock.tick); if (started) this.enterWave(started.wave, started.bonus);
  }
  pause() { this.paused = true; }
  resume() { if (!this.paused) return; this.paused = false; this.clock.resync(); }
  setPlayer(player: PlayerState) {
    for (const hero of this.heroes) {
      const enabled = player.heroControls.find(c => c.hero_id === hero.hero!.id)!.ai_enabled;
      if (this.player.heroControls.find(c => c.hero_id === hero.hero!.id)!.ai_enabled !== enabled) {
        hero.aiEnabled = Boolean(enabled); hero.recovering = false; hero.nextDecision = 0;
        if (!enabled && hero.state === 'returning') hero.command(hero.position);
      }
    }
    this.player = player;
    this.towers.meta.setPlayer(player);
  }
  frame() { if (!this.paused) this.advance(this.clock.due()); }
  advance(count: number) {
    if (!Number.isInteger(count) || count < 0) throw Error('Invalid battle tick count');
    for (let i = 0; i < count && !this.paused; i++) this.step();
  }
  private enterWave(wave: Wave, bonus: number) {
    this.money += bonus;
    // The schedule starts each wave once, matching native paidSupplyWaves.
    for (const tower of this.towers.placed) this.money += this.towers.tuning(tower).income_per_wave;
    for (const spawn of wave.spawns) for (let i = 0; i < spawn.num_enemies; i++)
      this.pending.push({ tick: this.clock.tick + Math.round((spawn.delay + i * spawn.spawn_interval) / dt), path: spawn.path_index, enemyID: spawn.enemy_type_id });
    this.pending.sort((a, b) => a.tick - b.tick);
  }
  private step() {
    const tick = ++this.clock.tick, rules = this.content.config.combat;
    this.combat.advanceImpacts();
    if (this.outcome) return;
    let wave;
    while ((wave = this.waves.start(tick, false))) this.enterWave(wave.wave, wave.bonus);
    const expired = this.reinforcement.expire(tick);
    this.towers.advance(dt);
    if (expired.length) { this.soldiers = this.soldiers.filter(u => !expired.includes(u.slot!)); this.formations(); }
    while (this.pending[0] && this.pending[0].tick <= tick) {
      const spawn = this.pending.shift()!, type = this.content.enemies.find(e => e.id === spawn.enemyID)!;
      const position = this.content.routes[spawn.path]!.point(0), hp = type.max_hp * this.player.difficulty.enemy_hp_multiplier;
      this.enemies.push({ id: this.nextEnemy++, type, path: spawn.path, along: 0, spawnTick: spawn.tick, position, previous: position, hp, maximumHP: hp, morale: new EnemyMorale(rules) });
    }
    const allies = [...this.soldiers.slice().sort((a, b) => a.slot! - b.slot!), ...this.heroes];
    const blocked = new Set(allies.filter(u => u.state === 'fighting').map(u => u.target));
    const fields = this.combat.fields();
    this.combat.detonate(blocked, fields);
    for (const enemy of this.enemies) {
      enemy.previous = enemy.position;
      enemy.along += this.combat.travel(enemy, blocked, fields, true);
      const route = this.content.routes[enemy.path]!; enemy.position = route.point(enemy.along);
      if (enemy.along >= route.total) {
        this.lives = Math.max(0, this.lives - enemy.type.lives_cost); enemy.hp = 0;
        if (this.player.settings.enemy_escape_haptics_enabled) this.events.lifeLost();
        if (this.lives === 0) { this.finish('defeat'); break; }
      }
    }
    this.enemies = this.enemies.filter(e => e.hp > 0);
    if (this.outcome) return;
    for (const hero of this.heroes) hero.decide(tick, this.enemies,
      new Set(allies.filter(u => u.state !== 'dead' && u.target >= 0).map(u => u.target)), this.content.routes);
    const claimed = new Set(allies.filter(u => u.state !== 'dead' && u.target >= 0).map(u => u.target));
    for (const unit of allies) {
      this.combat.heal(unit);
      unit.step(this.enemies, claimed, rules, this.content.routes, this.random,
        enemy => this.creditKill(enemy), this.towers.meta);
      unit.pose(this.profile(unit).cycleDistance, this.presentation.walkingThreshold, this.enemies);
    }
    this.enemies = this.enemies.filter(e => e.hp > 0);
    if (this.selectedHero !== null && this.heroes[this.selectedHero]!.state === 'dead') this.selectedHero = null;
    if (this.waves.next === this.content.waves.length && !this.pending.length && !this.enemies.length) this.finish('victory');
    if (!this.outcome) this.combat.update(new Set(allies.filter(u => u.state === 'fighting').map(u => u.target)));
  }
  creditKill(enemy: Enemy) { this.money += Math.max(0, Math.round(enemy.type.bounty * this.content.config.combat.kill_bounty_multiplier)); }
  private finish(outcome: 'victory' | 'defeat') { this.outcome = outcome; this.pending = []; this.placing = false; this.selectedHero = null; this.towers.dismiss(); this.events.outcome(outcome); }
  private syncGarrison(tower: PlacedTower, old: TowerTier | null, rank: boolean) {
    const tuning = this.towers.tuning(tower), melee = tuning.melee, rules = this.content.config.combat;
    if (!melee || !tower.rally) return;
    let soldiers = this.soldiers.filter(s => s.slot === tower.slot);
    if (!old) {
      soldiers = Array.from({ length: melee.soldier_count }, (_, i) => new Ally(`militia-${tower.slot}-${i}`,
        ringPoint(i, melee.soldier_count, tower.position, rules.melee_spawn_spread), { ...melee, move_speed: rules.melee_move_speed },
        null, tower.slot, this.content.area, melee.rally_point_radius * rules.melee_engage_scan_radius_fraction,
        melee.rally_point_radius * rules.melee_leash_radius_fraction));
      this.soldiers.push(...soldiers);
    }
    for (const unit of soldiers) {
      if (old?.melee && rank) {
        if (unit.state !== 'dead') unit.hp = Math.min(melee.hp, unit.hp + Math.max(0, melee.hp - old.melee.hp));
        unit.swing = Math.ceil(unit.swing * melee.attack_interval / old.melee.attack_interval);
        unit.respawn = Math.ceil(unit.respawn * melee.respawn_seconds / old.melee.respawn_seconds);
      } else if (old && old.id !== tuning.id && unit.state !== 'dead') unit.hp = melee.hp;
      Object.assign(unit.combat, melee); unit.rally = tower.rally;
      unit.scan = melee.rally_point_radius * rules.melee_engage_scan_radius_fraction;
      unit.leash = melee.rally_point_radius * rules.melee_leash_radius_fraction;
    }
    this.formations();
  }
  private formations() {
    // Multiple squads at the same rally anchor share one ring.
    const groups = new Map<string, Ally[]>();
    for (const unit of this.soldiers.slice().sort((a, b) => a.slot! - b.slot!)) {
      const anchor = unit.rally;
      const key = `${anchor.x},${anchor.y}`; if (!groups.has(key)) groups.set(key, []); groups.get(key)!.push(unit);
    }
    for (const group of groups.values()) group.forEach((unit, i) => {
      unit.station = ringPoint(i, group.length, unit.rally, this.content.config.combat.melee_post_spread);
    });
  }
  private profile(unit: Ally): Pose {
    if (!unit.hero) return this.presentation.militia;
    const profile = this.presentation.heroes[unit.hero.unit_image_name];
    if (!profile) throw contentError(`presentation.heroes[${unit.hero.unit_image_name}]`, 'Missing native sprite profile');
    return profile;
  }
  get imageKeys(): string[] {
    const profiles = [this.presentation.militia, ...this.heroes.map(h => this.profile(h))];
    const enemyIDs = new Set(this.content.waves.flatMap(w => w.spawns.map(s => s.enemy_type_id)));
    return [...new Set([...profiles.flatMap(p => [...p.idle, ...p.walking.flat()]),
      this.presentation.explosion.asset, ...Object.values(this.presentation.towers).flatMap(t => t.projectile.asset === null ? [] : [t.projectile.asset]),
      'tower_slot_field', 'tower_slot_build_flag', 'tower_slot_upgrade', 'tower_menu_bg', 'tower_menu_square_frame', 'tower_locked_icon', 'tower_build_confirm', 'rally_point_icon', 'engineer_rough_ground',
      ...Object.values(this.presentation.towers).flatMap(t => [t.icon, t.frame, ...Object.values(t.tiers).flatMap(s => [s.art, s.icon, s.atlas].filter((v): v is string => v !== null))]),
      ...this.content.towers.flatMap(t => t.tiers.flatMap(l => l.upgrades.map(p => p.icon_name))),
      ...this.content.enemies.filter(e => enemyIDs.has(e.id)).map(e => e.image_name)])];
  }
  actors(alpha = this.paused || this.outcome ? 1 : this.clock.alpha, heroesOnly = false): Actor[] {
    const result: Actor[] = heroesOnly ? [] : this.enemies.map(e => ({ id: `enemy-${e.id}`, key: e.type.image_name,
      position: lerp(e.previous, e.position, alpha), health: e.hp / e.maximumHP, kind: 'enemy', heroIndex: null, selected: false, profile: null, morale: e.morale }));
    for (const unit of heroesOnly ? this.heroes : [...this.soldiers, ...this.heroes]) if (unit.state !== 'dead') {
      const profile = this.profile(unit), cycle = profile.cycleDistance;
      const phase = ((unit.phase - (unit.walking ? distance(unit.previous, unit.position) : 0) * (1 - alpha)) % cycle + cycle) % cycle;
      const frames = profile.walking[unit.facing]!;
      const index = unit.hero ? this.heroes.indexOf(unit) : null;
      result.push({ id: unit.id, key: unit.walking ? frames[Math.floor(phase / cycle * frames.length)]! : profile.idle[unit.facing]!,
        position: lerp(unit.previous, unit.position, alpha), health: unit.hp / unit.combat.hp, kind: unit.hero ? 'hero' : 'militia',
        heroIndex: index, selected: index !== null && this.selectedHero === index, profile });
    }
    return result;
  }
}
