import type { PlayerState } from '../data/contracts';
import type { Point } from '../hud/layout';
import type { HudControl, HudInput } from '../hud/state';
import type { BattleSession } from './session';
import type { TowerKind } from './tower-tuning';

export type BattleCommand =
  | { type: 'activate'; control: HudControl }
  | { type: 'selectHero'; index: number }
  | { type: 'mapTap' | 'callWave'; point: Point }
  | { type: 'pause' | 'resume' | 'placeTower' }
  | { type: 'setPlayer'; player: PlayerState }
  | { type: 'selectTower'; slot: number }
  | { type: 'buildTower'; kind: TowerKind }
  | { type: 'upgradeTower'; branch: number }
  | { type: 'upgradePath'; id: string };

// The session remains the only state authority. The store is the transaction
// boundary for every UI/host command and for the Phaser simulation clock.
// Subscribers run synchronously after a complete mutation, including the tick
// that finishes a cooldown. Rendering and clicks never advance simulation time.
export class BattleStore {
  private readonly listeners = new Set<() => void>();
  readonly hudInput: HudInput;
  constructor(readonly session: BattleSession) {
    this.hudInput = {
      activate: Object.fromEntries((['primaryHero', 'secondaryHero', 'reinforcements', 'speed', 'pause', 'inventory'] as HudControl[])
        .map(control => [control, () => this.dispatch({ type: 'activate', control })])),
      callWave: point => this.dispatch({ type: 'callWave', point }),
    };
  }
  subscribe(listener: () => void) {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }
  private publish() { for (const listener of this.listeners) listener(); }
  dispatch(command: BattleCommand) {
    const session = this.session, towers = session.towers;
    switch (command.type) {
      case 'activate': session.activate(command.control); break;
      case 'selectHero': session.selectHero(command.index); break;
      case 'mapTap': session.mapTap(command.point); break;
      case 'callWave': session.tapWave(command.point); break;
      case 'pause': session.pause(); break;
      case 'resume': session.resume(); break;
      case 'setPlayer': session.setPlayer(command.player); break;
      case 'selectTower': towers.select(command.slot); break;
      case 'buildTower': towers.tapBuild(command.kind); break;
      case 'upgradeTower': towers.tapUpgrade(command.branch); break;
      case 'upgradePath': towers.tapPath(command.id); break;
      case 'placeTower': towers.beginPlacement(); break;
    }
    this.publish();
  }
  frame() {
    const before = this.session.clock.tick;
    this.session.frame();
    if (before !== this.session.clock.tick) this.publish();
  }
}
