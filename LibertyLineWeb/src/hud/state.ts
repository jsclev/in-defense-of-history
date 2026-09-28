import type { PlayerState } from '../data/contracts';
import type { Point } from './layout';

export type HudControl = 'primaryHero' | 'secondaryHero' | 'reinforcements' | 'speed' | 'pause' | 'inventory';
// Mirrors LevelHUDState. The renderer consumes state; it owns no combat rules.
export type HudState = {
  heroes: { id: string; portrait: string; label: string; isAvailable: boolean; isSelected: boolean }[];
  lives: number; money: number; wave: number; waveCount: number; isPaused: boolean;
  reinforcementRemaining: number; reinforcementSeconds: number; canCallReinforcements: boolean; isPlacingReinforcements: boolean;
  activated: HudControl[]; callWavePositions: Point[]; nextWave: number; countdownSeconds: number | null; selectedWave: Point | null;
  acceptsInput: boolean; speed: number;
};
export type HudInput = { activate?: Partial<Record<HudControl, () => void>>; callWave?: (position: Point) => void };
export type HudContent = { player: PlayerState; state: HudState };
