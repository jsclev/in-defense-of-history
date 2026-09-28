import type { Level, Row } from './records';

export type UpgradePath = Row<'tower_upgrade_path'> & { ranks: Row<'tower_upgrade_rank'>[] };
export type TowerTier = Row<'tower'> & { history: Row<'tower_history'>; melee: Row<'melee_unit'> | null; upgrades: UpgradePath[] };
export type TowerDefinition = Row<'tower_type'> & { tiers: TowerTier[] };
export type EnemyDefinition = Row<'enemy_type'> & { encyclopedia: Row<'enemy_encyclopedia'> };
export type HeroDefinition = Row<'hero'> & { combat: Row<'hero_combat'>; ai: Row<'hero_ai'>;
  control: Row<'player_hero_control'>; unlocked: boolean; unlockWave: Row<'level_wave'> };
export type Wave = Row<'level_wave'> & { spawns: (Row<'level_wave_enemy_spawn'> & { delay: number })[] };
export type Path = { index: number; points: { x: number; y: number }[] };
export type MetaUpgrade = Row<'meta_upgrade'> & { effects: Row<'meta_upgrade_effect'>[] };
export type MetaCatalog = { tracks: Row<'meta_upgrade_track'>[]; upgrades: MetaUpgrade[] };
export type MetaState = { profile: Row<'player_meta_upgrade_profile'>['profile_key'];
  selections: Row<'player_meta_upgrade_selection'>[]; stars: Row<'player_meta_upgrade_level_stars'>[];
  earned: number; spent: number; available: number };
export type Configuration = { canvas: Row<'virtual_canvas'>; combat: Row<'combat_rules'>;
  reinforcement: Row<'reinforcement_config'>; playSpeeds: Row<'play_speed'>[];
  difficulties: Row<'difficulty'>[]; encyclopediaDemo: Row<'encyclopedia_demo'> };
export type PlayerState = { settings: Row<'player_settings'>; difficulty: Row<'difficulty'>;
  selectedHeroes: HeroDefinition[]; unlockedHeroes: Row<'player_unlocked_hero'>[];
  heroControls: Row<'player_hero_control'>[]; hud: Row<'player_hud_layout'>[]; meta: MetaState };
export type PlayerSetting = Exclude<keyof Row<'player_settings'>, 'id'>;

interface Catalog<T> { getAll(): Promise<T[]> }
interface IdentifiedCatalog<T> extends Catalog<T> { get(id: string): Promise<T> }
interface LevelQuery<T> { getForLevel(levelID: string): Promise<T[]> }

// This is the browser-facing boundary. No SQL, sql.js handles, fetch responses,
// or renderer types escape it. A future backend adapter implements this contract.
export interface GameDataAccess {
  campaigns: IdentifiedCatalog<Row<'campaign'>>;
  levels: IdentifiedCatalog<Level> & { getForCampaign(campaignID: string): Promise<Level[]> };
  towers: Catalog<TowerDefinition>;
  enemies: Catalog<EnemyDefinition>;
  heroes: Catalog<HeroDefinition>;
  waves: LevelQuery<Wave> & { get(levelID: string, waveNumber: number): Promise<Wave> };
  paths: LevelQuery<Path>;
  unlocks: LevelQuery<Row<'level_tower_unlock'>>;
  levelHeroes: LevelQuery<Row<'level_hero'>>;
  configuration: { get(): Promise<Configuration> };
  metaUpgrades: { get(): Promise<MetaCatalog> };
  player: { get(): Promise<PlayerState>; getMetaUpgrades(profile: MetaState['profile']): Promise<MetaState>;
    setSetting(key: PlayerSetting, enabled: boolean): Promise<PlayerState>;
    setHeroAI(heroID: string, enabled: boolean): Promise<PlayerState> };
  close(): void;
}
export type OpenGameData = (url: string) => Promise<GameDataAccess>;
