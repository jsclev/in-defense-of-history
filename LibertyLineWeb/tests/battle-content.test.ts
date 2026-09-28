import { afterEach, beforeAll, beforeEach, expect, it } from 'vitest';
import { authored, navigation, geometry, battleSession, type Authored } from './fixtures';
import { SqliteGameData } from '../src/data/sqlite';
import { loadBattleContent } from '../src/game/content';
import { readHeroSpawns, readEnemyRoutes } from '../src/content/geometry';
let fixture: Authored, db: ReturnType<Authored['open']>, data: SqliteGameData;
beforeAll(async () => { fixture = await authored(); });
beforeEach(() => { db = fixture.open(); data = new SqliteGameData(db); });
afterEach(() => data.close());
it('assembles every complete authored map and rejects incomplete wave catalogs instead of substituting content', async () => {
  const nav = await navigation(db);
  let loaded = 0, rejected = 0;
  for (const level of db.levels().filter(l => l.map_image_name)) {
    const promise = loadBattleContent(data, level, await geometry(level.map_image_name), nav[level.map_image_name]!);
    if (db.read('level_wave', 'WHERE level_info_id=?', [level.id]).length !== level.num_waves) {
      await expect(promise).rejects.toThrow('num_waves'); rejected++;
    } else {
      const content = await promise; expect(content.routes.length).toBeGreaterThan(0); expect(content.heroes.length).toBeGreaterThan(0); loaded++;
      if (level.map_image_name === 'level_15_charleston') expect(content.routes).toHaveLength(6);
    }
  }
  expect(loaded + rejected).toBe(15); expect(loaded).toBeGreaterThan(0); expect(rejected).toBeGreaterThan(0);
});
it('rejects missing native route references and exact hero starts outside the road', async () => {
  const session = await battleSession(db), level = session.content.level;
  const map = await geometry(level.map_image_name) as { heroCount: number; features: { id: string; properties: Record<string, unknown>; geometry: { type: string; coordinates: unknown } }[] };
  const nav = (await navigation(db))[level.map_image_name]!;
  const hero = map.features.find(f => f.properties.kind === 'hero_spawn')!; hero.geometry.coordinates = [0,0];
  await expect(loadBattleContent(data, level, map, nav)).rejects.toThrow('Start is outside');
  hero.geometry.coordinates = [session.heroes[0]!.spawn.x, session.heroes[0]!.spawn.y];
  const marker = map.features.find(f => f.properties.kind === 'call_wave_button')!; marker.properties.pathIndices = [99];
  await expect(loadBattleContent(data, level, map, nav)).rejects.toThrow('Unknown route'); delete marker.properties.pathIndices;
  db.db.run('UPDATE level_wave_enemy_spawn SET path_index=999 WHERE level_wave_id=?', [session.content.waves[0]!.id]);
  await expect(loadBattleContent(data, level, map, nav)).rejects.toThrow('path_index');
  db.db.run('UPDATE level_wave_enemy_spawn SET path_index=0 WHERE level_wave_id=?', [session.content.waves[0]!.id]);
  db.db.run('PRAGMA foreign_keys=OFF'); db.db.run("UPDATE level_wave_enemy_spawn SET enemy_type_id='00000000-0000-0000-0000-000000000000' WHERE level_wave_id=?", [session.content.waves[0]!.id]);
  await expect(loadBattleContent(data, level, map, nav)).rejects.toThrow('enemy_type_id');
});
it('uses native meta-upgrade effects on reinforcement stats and fails missing selected effects', async () => {
  db.db.run("UPDATE player_meta_upgrade_selection SET is_selected=0 WHERE profile_key='active'");
  const before = await battleSession(db), base = before.content.reinforcement!;
  db.db.run("UPDATE player_meta_upgrade_level_stars SET best_stars=3 WHERE profile_key='active'");
  db.db.run("UPDATE player_meta_upgrade_selection SET is_selected=1 WHERE profile_key='active' AND upgrade_key IN ('campaignVeterans','reliefCompanies','fieldDressings')");
  const after = await battleSession(db), upgraded = after.content.reinforcement!;
  const effect = (key: string, parameter: string) => db.one('meta_upgrade_effect', 'WHERE upgrade_key=? AND parameter=?', [key, parameter]).value;
  expect(upgraded.hp).toBe(base.hp * effect('campaignVeterans', 'healthMultiplier'));
  expect(upgraded.respawn_seconds).toBe(base.respawn_seconds * effect('reliefCompanies', 'respawnMultiplier'));
  expect(upgraded.heal_per_second).toBe(base.heal_per_second * effect('fieldDressings', 'healingMultiplier'));
  db.db.run("DELETE FROM meta_upgrade_effect WHERE upgrade_key='campaignVeterans'"); await expect(battleSession(db)).rejects.toThrow('effects');
});
it('validates hero roles and unique spawn IDs without selecting extra heroes for a smaller map', async () => {
  const map = await geometry('level_01_battle_road') as { heroCount: number; features: { id: string; properties: { kind: string; heroRoles?: string[] } }[] };
  expect(readHeroSpawns(map, 'test')).toHaveLength(1);
  const badRole = structuredClone(map); badRole.features[0]!.properties.heroRoles = ['primary']; expect(() => readHeroSpawns(badRole, 'test')).toThrow('Hero roles');
  const missing = structuredClone(map); missing.heroCount = 2; expect(() => readHeroSpawns(missing, 'test')).toThrow('heroCount');
  const duplicate = structuredClone(map); duplicate.features.push(duplicate.features.find(f => f.properties.kind === 'hero_spawn')!); expect(() => readHeroSpawns(duplicate, 'test')).toThrow('heroCount');
  expect(readHeroSpawns({ ...map, heroCount: 0, features: map.features.filter(f => f.properties.kind !== 'hero_spawn') }, 'test')).toEqual([]);
  expect(() => readHeroSpawns({ ...map, heroCount: -1 }, 'test')).toThrow('hero_spawn');
});
it('validates explicit GeoJSON route indices and endpoints, and refuses roads that leave the native navigation surface', async () => {
  const level = db.levels().find(l => l.map_image_name === 'level_15_charleston')!;
  const map = await geometry(level.map_image_name) as { features: { id: string; properties: Record<string, unknown>; geometry: { coordinates: number[][]; type: string } }[] };
  const nav = (await navigation(db))[level.map_image_name]!;
  const route = map.features.find(f => f.properties.kind === 'enemy_route')!;
  const before = structuredClone(route);
  route.properties.pathIndex = 999; expect(() => readEnemyRoutes(map, 'test')).toThrow('contiguous'); Object.assign(route, structuredClone(before));
  route.properties.entranceID = 'missing'; expect(() => readEnemyRoutes(map, 'test')).toThrow('spawn_point'); Object.assign(route, structuredClone(before));
  route.properties.exitID = 'missing'; expect(() => readEnemyRoutes(map, 'test')).toThrow('goal_point'); Object.assign(route, structuredClone(before));
  route.geometry.coordinates[1] = [0, 0]; await expect(loadBattleContent(data, level, map, nav)).rejects.toThrow('leaves the painted road');
  expect(readEnemyRoutes({ type: 'FeatureCollection', features: [] }, 'test')).toBeNull();
});
