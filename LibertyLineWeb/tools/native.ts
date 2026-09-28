import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { native, project } from './paths';
import { presentationSchema } from '../src/content/presentation';
import { navigationSchema } from '../src/game/navigation';
import type { ContentDatabase } from '../src/content/database';

export const layoutSources = ['Design/VirtualCanvas', 'Core/RuntimeCanvas', 'Models/Core', 'Models/TowerKind',
  'Layout/HudPlayArea', 'Layout/HudSizing', 'Layout/HudLayoutConfig', 'Layout/HudPlacementSolver',
  'Layout/HudElementLayouts', 'Layout/StackLayout', 'Layout/HeroBarLayout', 'Layout/MasterControlsLayout',
  'Layout/TowerMenuLayout', 'Layout/LevelMapProjection', 'Layout/CallWaveButtonLayout', 'Layout/MapSpriteSizing', 'Layout/HeroSpriteProfile'];
export async function compileNative(entry: string, executable: string, sources = layoutSources) {
  await promisify(execFile)('xcrun', ['swiftc', ...sources.map(f => join(native, 'Engine', `${f}.swift`)), entry, '-o', executable]);
}
export async function exportPresentation(database: ContentDatabase) {
  const temporary = await mkdtemp(join(tmpdir(), 'liberty-line-presentation-'));
  try {
    const executable = join(temporary, 'export');
    await compileNative(join(project, 'tools/presentation.swift'), executable, [...layoutSources, 'Models/UnitFacing', 'Models/ArtilleryFacing', 'Combat/DemolitionExplosion']);
    const kinds = new Map(database.read('tower_type').map(t => [t.id, t.tower_type_key]));
    const tiers = database.read('tower').map(t => ({ kind: kinds.get(t.tower_type_id)!, level: t.tower_level, branch: t.branch }));
    const { stdout } = await promisify(execFile)(executable, [JSON.stringify(tiers)]);
    return presentationSchema.parse(JSON.parse(stdout));
  } finally { await rm(temporary, { recursive: true, force: true }); }
}
export async function exportNavigation(maps: string[], width: number) {
  const temporary = await mkdtemp(join(tmpdir(), 'liberty-line-navigation-'));
  try {
    const executable = join(temporary, 'export');
    await compileNative(join(project, 'tools/navigation.swift'), executable, ['Models/Core', 'Models/HeroMovementArea']);
    const { stdout } = await promisify(execFile)(executable, [String(width), ...maps.map(name => join(native, 'Db', `${name}.geojson`))], { maxBuffer: 8 * 1024 * 1024 });
    return navigationSchema.parse(JSON.parse(stdout));
  } finally { await rm(temporary, { recursive: true, force: true }); }
}
