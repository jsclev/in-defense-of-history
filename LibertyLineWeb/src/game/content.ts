import type { Configuration, EnemyDefinition, GameDataAccess, HeroDefinition, MetaCatalog, PlayerState, Wave, TowerDefinition } from '../data/contracts';
import type { Level, Row } from '../data/records';
import { readEnemyRoutes, readHeroSpawns, readWaveMarkers, readSlots, type Slot, type WaveMarker } from '../content/geometry';
import { contentError } from '../content/schema';
import { MovementArea, Route } from './navigation';
import type { Point } from '../hud/layout';
import { MetaEffects } from './tower-tuning';

export type BattleContent = { level: Level; config: Configuration; player: PlayerState; waves: Wave[];
  enemies: EnemyDefinition[]; heroes: { hero: HeroDefinition; spawn: Point }[]; routes: Route[]; area: MovementArea;
  markers: WaveMarker[]; reinforcement: Row<'melee_unit'> | null; towers: TowerDefinition[]; catalog: MetaCatalog;
  unlocks: Row<'level_tower_unlock'>[]; slots: Slot[] };
export async function loadBattleContent(data: GameDataAccess, level: Level, geometry: unknown, rings: number[][][]): Promise<BattleContent> {
  const [config, player, waves, enemies, towers, catalog, unlocks] = await Promise.all([
    data.configuration.get(), data.player.get(), data.waves.getForLevel(level.id), data.enemies.getAll(), data.towers.getAll(), data.metaUpgrades.get(), data.unlocks.getForLevel(level.id),
  ]);
  const area = new MovementArea(rings);
  const authoredRoutes = readEnemyRoutes(geometry, level.map_image_name);
  const paths = authoredRoutes ?? await data.paths.getForLevel(level.id);
  const routes = paths.map(p => new Route(p.points));
  if (!routes.length) throw contentError(`level_info[${level.id}].paths`, 'No enemy routes');
  if (authoredRoutes && paths.some(p => p.points.slice(1).some((point, i) => !area.segment(p.points[i]!, point))))
    throw contentError(`${level.map_image_name}.enemy_route`, 'Enemy route leaves the painted road');
  const heroes = readHeroSpawns(geometry, level.map_image_name).slice(0, player.selectedHeroes.length)
    .map((spawn, i) => ({ hero: player.selectedHeroes[i]!, spawn }));
  for (const { hero, spawn } of heroes) if (!area.contains(spawn)) throw contentError(`hero_spawn[${hero.id}]`, 'Start is outside walkable ground');
  const markers = readWaveMarkers(geometry, level.map_image_name);
  if (markers.some(m => m.pathIndices?.some(i => !routes[i]))) throw contentError(`${level.map_image_name}.call_wave_button.pathIndices`, 'Unknown route');
  for (const wave of waves) for (const spawn of wave.spawns) {
    if (!routes[spawn.path_index]) throw contentError(`level_wave_enemy_spawn[${spawn.id}].path_index`, 'Unknown route');
    if (!enemies.some(e => e.id === spawn.enemy_type_id)) throw contentError(`level_wave_enemy_spawn[${spawn.id}].enemy_type_id`, 'Unknown enemy');
  }
  const base = towers.find(t => t.tower_type_key === 'melee')!.tiers
    .slice().sort((a, b) => a.tower_level - b.tower_level || a.branch - b.branch).find(t => t.melee !== null)?.melee;
  const reinforcement = base ? new MetaEffects(player, catalog).melee(base) : null;
  return { level, config, player, waves, enemies, heroes, routes, area, markers, reinforcement, towers, catalog, unlocks, slots: readSlots(geometry, level.map_image_name) };
}
