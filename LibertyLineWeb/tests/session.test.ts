import { EnemyMorale } from '../src/game/combat-math';
import { beforeAll, beforeEach, afterEach, expect, it, vi } from 'vitest';
import { authored, battleSession, type Authored } from './fixtures';
import { BattleSession } from '../src/game/session';
import { Route, distance } from '../src/game/navigation';
import { fireTicks, ticks } from '../src/game/schedules';
import { SqliteGameData } from '../src/data/sqlite';
import { Ally, ringPoint, type Enemy } from '../src/game/units';
let fixture: Authored, db: ReturnType<Authored['open']>, session: BattleSession, now: number;
beforeAll(async () => { fixture = await authored(); });
beforeEach(async () => { db = fixture.open(); now = 0; session = await battleSession(db, undefined, () => now); });
afterEach(() => db.close());
function roadPoint() { return session.content.routes[0]!.point(session.content.routes[0]!.total * .6); }
function enemy(at = session.heroes[0]!.position, id = 999): Enemy {
  const type = { ...session.content.enemies[0]!, speed: 0 };
  session.content.routes = [new Route([at, { x: at.x + 1000, y: at.y }])];
  return { id, type, path: 0, along: 0, spawnTick: 0, position: at, previous: at, hp: type.max_hp, maximumHP: type.max_hp, morale: new EnemyMorale(session.content.config.combat) };
}
it('derives deployed roles, resources, settings, timing and artwork only from authored content', () => {
  expect(session.heroes).toHaveLength(1); expect(session.hud.heroes).toHaveLength(1);
  expect(session.money).toBe(session.content.level.starting_money); expect(session.lives).toBe(session.content.level.num_starting_lives);
  expect(session.hud.wave).toBe(1); expect(session.hud.nextWave).toBe(1); expect(session.hud.countdownSeconds).toBeNull();
  expect(session.heroes[0]!.position).toEqual(session.content.heroes[0]!.spawn);
  expect(session.imageKeys).toContain(session.actors()[0]!.key);
  expect(() => new BattleSession({ ...session.content, config: { ...session.content.config, playSpeeds: [] } }, session.presentation, () => 0,
    { pause() {}, lifeLost() {}, outcome() {} })).toThrow('play_speed');
  expect(() => new BattleSession(session.content, { ...session.presentation, heroes: {} }, () => 0,
    { pause() {}, lifeLost() {}, outcome() {} })).toThrow('sprite profile');
});
it('toggles heroes and placement mutually exclusively; invalid destinations preserve the previous order and selection', () => {
  session.activate('primaryHero'); expect(session.selectedHero).toBe(0);
  session.activate('primaryHero'); expect(session.selectedHero).toBeNull();
  session.activate('secondaryHero'); expect(session.selectedHero).toBeNull();
  session.activate('primaryHero'); const hero = session.heroes[0]!, oldStation = hero.station;
  expect(session.mapTap({ x: -100, y: -100 })).toBe(false); expect(hero.station).toEqual(oldStation); expect(session.selectedHero).toBe(0);
  expect(session.mapTap({ x: NaN, y: 0 })).toBe(false);
  session.activate('reinforcements'); expect(session.selectedHero).toBeNull(); expect(session.placing).toBe(true);
  session.activate('reinforcements'); expect(session.placing).toBe(false);
  session.activate('reinforcements'); session.activate('primaryHero'); expect(session.placing).toBe(false);
  const target = { x: hero.position.x - 1, y: hero.position.y }; expect(session.content.area.contains(target)).toBe(true);
  expect(session.mapTap(target)).toBe(true); expect(hero.aiEnabled).toBe(false); expect(session.selectedHero).toBeNull();
  session.advance(1); expect(hero.position).toEqual(target); expect(hero.state).toBe('holding');
  expect(session.mapTap(target)).toBe(false); session.heroes[0]!.state = 'dead'; session.activate('primaryHero'); expect(session.selectedHero).toBeNull();
});
it('moves to an exact destination using game ticks, with canonical distance-driven frames and idle facing', () => {
  const hero = session.heroes[0]!, start = { ...hero.position }, target = roadPoint();
  session.activate('primaryHero'); expect(session.mapTap(target)).toBe(true);
  session.advance(1); expect(distance(start, hero.position)).toBeCloseTo(hero.combat.move_speed / 30);
  const a = session.actors(.5).find(a => a.kind === 'hero')!;
  expect(a.key).toContain('_walk_'); expect(distance(a.position, start)).toBeCloseTo(distance(hero.position, start) / 2);
  session.advance(3000); expect(hero.position).toEqual(target); expect(hero.state).toBe('holding'); expect(session.actors(1)[0]!.key).toContain('_idle_');
});
it('deploys SQL-count squads only on the route, starts one cooldown, expires independent lifetimes, and shares formations', () => {
  const config = session.content.config; config.reinforcement.cooldown_seconds = .1; config.reinforcement.time_to_live_seconds = .5;
  session = new BattleSession(session.content, session.presentation, () => now, { pause() {}, lifeLost() {}, outcome() {} });
  const point = roadPoint(); session.activate('reinforcements');
  expect(session.mapTap({ x: 0, y: 0 })).toBe(false); expect(session.hud.reinforcementRemaining).toBe(0); expect(session.placing).toBe(true);
  expect(session.mapTap(point)).toBe(true); expect(session.soldiers).toHaveLength(config.combat.reinforcement_soldier_count);
  expect(session.hud.canCallReinforcements).toBe(false); session.activate('reinforcements'); expect(session.placing).toBe(false);
  session.advance(3); expect(session.hud.canCallReinforcements).toBe(true);
  session.activate('reinforcements'); expect(session.mapTap(point)).toBe(true);
  expect(new Set(session.soldiers.map(u => JSON.stringify(u.station))).size).toBe(session.soldiers.length);
  session.pause(); session.advance(100); expect(session.soldiers).toHaveLength(config.combat.reinforcement_soldier_count * 2);
  session.resume(); session.advance(12); expect(session.soldiers).toHaveLength(config.combat.reinforcement_soldier_count);
  session.advance(3); expect(session.soldiers).toHaveLength(0);
  session.content.reinforcement = null; expect(session.canReinforce).toBe(false);
});
it('confirms a wave once, schedules its actual enemies, and lets later waves overlap with early-call rewards', () => {
  session.heroes.forEach(h => { h.aiEnabled = false; });
  const p = session.hud.callWavePositions[0]!;
  session.tapWave({ x: 0, y: 0 }); expect(session.waves.selected).toBeNull();
  session.tapWave(p); session.advance(10000); expect(session.enemies).toHaveLength(0); expect(session.waves.selected).toEqual(p);
  session.tapWave(p); expect(session.waves.next).toBe(1); const initial = session.money;
  session.tapWave(p); expect(session.waves.next).toBe(1); expect(session.money).toBe(initial);
  const next = session.content.waves[1]!; session.advance(ticks(next.call_button_delay));
  expect(session.enemies.length).toBeGreaterThan(0); expect(session.hud.countdownSeconds).toBe(Math.ceil(next.auto_start_countdown));
  const entrance = session.hud.callWavePositions[0]!; session.tapWave(entrance); session.tapWave(entrance);
  expect(session.waves.next).toBe(2); expect(session.money).toBe(initial + next.early_call_bonus);
  const third = session.content.waves[2]!; session.advance(ticks(third.call_button_delay) + ticks(third.auto_start_countdown));
  expect(session.waves.next).toBeGreaterThanOrEqual(3);
});
it('pauses every game timer and command, preserves speed, and flashes inventory without inventing native inventory content', () => {
  const onPause = vi.fn(); session = new BattleSession(session.content, session.presentation, () => now, { pause: onPause, lifeLost() {}, outcome() {} });
  const speed = session.clock.factor; session.activate('speed'); expect(session.clock.factor).toBe(speed * 2);
  session.activate('inventory'); expect(session.hud.activated).toContain('inventory'); session.advance(15); expect(session.hud.activated).not.toContain('inventory');
  session.activate('pause'); const hud = session.hud; expect(onPause).toHaveBeenCalledOnce();
  now += 100000; session.frame(); session.advance(100); session.activate('speed'); session.selectHero(0); session.tapWave(hud.callWavePositions[0]!);
  expect(session.mapTap(roadPoint())).toBe(false); expect(session.hud).toEqual(hud);
  session.resume(); session.resume(); expect(session.clock.due()).toBe(0); now += 100; session.frame(); expect(session.clock.tick).toBeGreaterThan(15);
  expect(() => session.advance(-1)).toThrow('tick count'); expect(() => session.advance(.5)).toThrow('tick count');
});
it('leaks enemies with authored lives costs, reports defeat once and rejects further input', () => {
  const loss = vi.fn(), outcome = vi.fn(); session = new BattleSession(session.content, session.presentation, () => now, { pause() {}, lifeLost: loss, outcome });
  const e = enemy(); session.content.routes = [new Route([{ x: 0, y: 0 }, { x: 1, y: 0 }])];
  e.type = { ...e.type, speed: 100, lives_cost: 3 }; session.enemies = [e]; session.lives = 2;
  session.player.settings.enemy_escape_haptics_enabled = 1; session.advance(1);
  expect(session.lives).toBe(0); expect(session.outcome).toBe('defeat'); expect(outcome).toHaveBeenCalledOnce(); expect(loss).toHaveBeenCalledOnce();
  expect(session.hud.callWavePositions).toEqual([]); expect(session.acceptsInput).toBe(false); session.advance(300); expect(outcome).toHaveBeenCalledOnce();
});
it('awards DAO kill bounties once and finishes only after the final wave, pending spawn and enemy have cleared', () => {
  const outcome = vi.fn(); session = new BattleSession(session.content, session.presentation, () => now, { pause() {}, lifeLost() {}, outcome }, () => .5);
  const hero = session.heroes[0]!; hero.aiEnabled = false;
  const e = enemy(); e.hp = 1; session.enemies = [e]; hero.state = 'engaging'; hero.target = e.id;
  const money = session.money; session.advance(1);
  expect(session.enemies).toHaveLength(0); expect(session.money).toBe(money + Math.round(e.type.bounty * session.content.config.combat.kill_bounty_multiplier));
  expect(session.outcome).toBeNull(); session.waves.next = session.content.waves.length; session.advance(1);
  expect(session.outcome).toBe('victory'); expect(outcome).toHaveBeenCalledWith('victory');
});
it('applies SQL edits on a fresh attempt, keeps runtime AI orders separate from settings, and rejects missing combat data', async () => {
  db.db.run('UPDATE level_info SET starting_money=987 WHERE id=?', [session.content.level.id]);
  db.db.run('UPDATE play_speed SET factor=3 WHERE source=?', ['player']);
  db.db.run('UPDATE reinforcement_config SET cooldown_seconds=.2, time_to_live_seconds=.3');
  db.db.run('UPDATE hero_combat SET move_speed=60');
  const next = await battleSession(db); expect(next.money).toBe(987); expect(next.clock.factor).toBe(3); expect(next.heroes[0]!.combat.move_speed).toBe(60);
  const data = new SqliteGameData(db), hero = next.heroes[0]!;
  next.setPlayer(await data.player.setHeroAI(hero.hero!.id, true)); expect(hero.aiEnabled).toBe(true);
  next.activate('primaryHero'); next.mapTap({ x: hero.position.x - 1, y: hero.position.y }); expect(hero.aiEnabled).toBe(false);
  next.setPlayer(await data.player.setSetting('debug_mode', !next.player.settings.debug_mode)); expect(hero.aiEnabled).toBe(false);
  next.setPlayer(await data.player.setHeroAI(hero.hero!.id, false)); expect(hero.station).toEqual(hero.position);
  db.db.run('DELETE FROM hero_combat WHERE hero_id=?', [hero.hero!.id]); await expect(battleSession(db)).rejects.toThrow('hero_combat');
});
it('heals holding units, releases dead targets, handles immunity, death/respawn and movement without display frames', () => {
  const hero = session.heroes[0]!, rules = session.content.config.combat, e = enemy(); hero.aiEnabled = false;
  hero.state = 'holding'; hero.hp /= 2; const hp = hero.hp; session.advance(1); expect(hero.hp).toBeGreaterThan(hp);
  session.enemies = [{ ...e, type: { ...e.type, speed: 0, traits: [{ type: 'rideDown' }] } }]; session.advance(1); expect(hero.target).toBe(-1);
  session.enemies[0]!.type.traits = []; session.advance(1); expect(hero.target).toBe(e.id); expect(hero.state).toBe('engaging');
  hero.hp = .01; session.enemies[0]!.type = { ...e.type, speed: 0, max_hp: 1e6, damage_min: 1000, damage_max: 1000 }; session.enemies[0]!.hp = 1e6;
  session.activate('primaryHero'); session.advance(fireTicks(rules.enemy_swing_interval) + 1);
  expect(hero.state).toBe('dead'); expect(session.selectedHero).toBeNull(); expect(session.hud.heroes[0]!.isAvailable).toBe(false);
  expect(hero.command(roadPoint())).toBe(false); expect(session.actors(1).some(a => a.kind === 'hero')).toBe(false);
  session.enemies = []; session.advance(fireTicks(hero.combat.respawn_seconds) + 1);
  expect(hero.hp).toBe(hero.combat.hp); expect(hero.position).toEqual(hero.spawn);
  hero.state = 'engaging'; hero.target = 123; session.advance(1); expect(hero.state).toBe('returning'); expect(hero.target).toBe(-1);
});
it('makes hero AI retreat and recover using database thresholds and reachability', () => {
  const hero = session.heroes[0]!, spawn = { ...hero.spawn }, p = roadPoint();
  hero.aiEnabled = true; hero.position = p; hero.station = p; hero.state = 'holding'; hero.hp = hero.combat.hp * hero.hero!.ai.retreat_health_fraction;
  session.advance(1); expect(hero.recovering).toBe(true); expect(hero.station).toEqual(spawn);
  hero.position = spawn; hero.station = spawn; hero.state = 'holding'; hero.nextDecision = 0; session.advance(1); expect(hero.recovering).toBe(true);
  hero.hp = hero.combat.hp; hero.nextDecision = 0; session.advance(1); expect(hero.recovering).toBe(false);
  const e = enemy(p); e.type = { ...e.type, speed: 0 }; session.enemies = [e]; hero.nextDecision = 0;
  session.advance(1); expect(hero.station).toEqual(p);
  hero.state = 'dead'; hero.nextDecision = 1e9; session.advance(1); expect(hero.nextDecision).toBe(0);
});
it('uses separate soldier spawn/post rings and retains the anchor for movement and respawn', () => {
  const point = roadPoint(), rules = session.content.config.combat;
  expect(ringPoint(0, 1, point, 20)).toEqual(point); expect(ringPoint(0, 2, point, 0)).toEqual(point);
  session.activate('reinforcements'); session.mapTap(point);
  const soldier = session.soldiers[0]!; expect(distance(soldier.spawn, point)).toBeCloseTo(rules.melee_spawn_spread);
  soldier.aiEnabled = true; soldier.hp /= 2; soldier.state = 'holding'; soldier.position = soldier.station;
  session.advance(1); expect(soldier.hp).toBeGreaterThan(soldier.combat.hp / 2);
  soldier.state = 'dead'; soldier.respawn = 0; session.advance(1); expect(soldier.position).toEqual(soldier.spawn); expect(soldier.hp).toBe(soldier.combat.hp);
  const isolated = new Ally('test', point, soldier.combat, null, -10, session.content.area, soldier.scan, soldier.leash);
  isolated.state = 'returning'; isolated.position = isolated.station; isolated.step([], new Set(), rules, session.content.routes, () => .5, () => {});
  expect(isolated.state).toBe('holding');
});
