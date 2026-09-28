import type { Wave } from '../data/contracts';
import type { Row } from '../data/records';
import type { Point } from '../hud/layout';
import { equal } from './navigation';

// Engine/Core/SimClock.swift; seconds in authored SQL always mean game seconds.
export const ticksPerSecond = 30;
export const dt = 1 / ticksPerSecond;
export const ticks = (seconds: number) => Math.ceil(seconds * ticksPerSecond);
export const fireTicks = (seconds: number) => Math.max(1, Math.round(seconds * ticksPerSecond));
export class BattleClock {
  tick = 0; private origin: number; private anchor = 0;
  constructor(public factor: number, private readonly now: () => number) { this.origin = now(); }
  private elapsed() { return (this.now() - this.origin) / 1000 * ticksPerSecond * this.factor; }
  due(): number { return Math.min(8, Math.max(0, Math.floor(this.elapsed()) - (this.tick - this.anchor))); }
  get alpha() { const elapsed = this.elapsed(); return Math.max(0, Math.min(1, elapsed - Math.floor(elapsed))); }
  resync() { this.origin = this.now(); this.anchor = this.tick; }
  setSpeed(factor: number): boolean {
    if (!Number.isFinite(factor) || factor < .01 || factor > 1e9) return false;
    const fraction = this.alpha; this.factor = factor; this.origin = this.now() - fraction * 1000 / ticksPerSecond / factor;
    this.anchor = this.tick; return true;
  }
}
export class WaveSchedule {
  next = 0; private previousStart = 0; selected: Point | null = null;
  constructor(readonly waves: Wave[]) {}
  state(tick: number): { kind: 'finished' | 'manual' | 'hidden' | 'countdown' | 'due'; seconds: number | null } {
    const wave = this.waves[this.next];
    if (!wave) return { kind: 'finished', seconds: null };
    if (this.next === 0) return { kind: 'manual', seconds: null };
    const reveal = this.previousStart + ticks(wave.call_button_delay), due = reveal + ticks(wave.auto_start_countdown);
    return tick >= due ? { kind: 'due', seconds: null } : tick < reveal ? { kind: 'hidden', seconds: null }
      : { kind: 'countdown', seconds: Math.ceil((due - tick) / ticksPerSecond) };
  }
  canCall(tick: number) { return ['manual', 'countdown'].includes(this.state(tick).kind); }
  tap(point: Point, tick: number): { wave: Wave; bonus: number } | null {
    if (!this.canCall(tick)) return null;
    if (!this.selected || !equal(this.selected, point)) { this.selected = point; return null; }
    return this.start(tick, true);
  }
  start(tick: number, manual: boolean): { wave: Wave; bonus: number } | null {
    if (manual ? !this.canCall(tick) : this.state(tick).kind !== 'due') return null;
    const wave = this.waves[this.next]!, bonus = manual && this.next > 0 ? wave.early_call_bonus : 0;
    this.next++; this.previousStart = tick; this.selected = null; return { wave, bonus };
  }
}
export class ReinforcementSchedule {
  private readyAt = 0; private readonly expires = new Map<number, number>();
  constructor(private readonly config: Row<'reinforcement_config'>) {}
  cooldown(tick: number) {
    const remaining = Math.max(0, this.readyAt - tick);
    return { seconds: Math.ceil(remaining / ticksPerSecond), fraction: Math.min(1, remaining / ticks(this.config.cooldown_seconds)) };
  }
  deploy(slot: number, tick: number): boolean {
    if (this.cooldown(tick).fraction > 0 || this.expires.has(slot)) return false;
    this.readyAt = tick + ticks(this.config.cooldown_seconds); this.expires.set(slot, tick + ticks(this.config.time_to_live_seconds)); return true;
  }
  expire(tick: number): number[] {
    const result = [...this.expires].filter(([, expiry]) => expiry <= tick).map(([id]) => id).sort((a, b) => a - b);
    for (const id of result) this.expires.delete(id); return result;
  }
}
