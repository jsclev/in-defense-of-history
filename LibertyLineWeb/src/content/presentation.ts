import { z } from 'zod';
import { positive } from './schema';
import { towerKind } from '../data/records';

const height = z.object({ fraction: positive, minimum: positive, maximum: positive });
const pose = z.object({ height, groundInset: z.number().min(0).lt(1), cycleDistance: positive,
  idle: z.array(z.string().min(1)).length(8), walking: z.array(z.array(z.string().min(1)).nonempty()).length(8) });
export const presentationSchema = z.object({ heroes: z.record(z.string(), pose), militia: pose,
  walker: height, healthWidth: height, healthHeight: height, labelLift: height, walkingThreshold: positive,
  towers: z.record(towerKind, z.object({ height, icon: z.string().min(1), frame: z.string().min(1),
    projectile: z.object({ asset: z.string().min(1).nullable(), height }),
    buildCenter: z.object({ x: z.number(), y: z.number() }),
    tiers: z.record(z.string(), z.object({ art: z.string().min(1), icon: z.string().min(1).nullable(), atlas: z.string().min(1).nullable() })) })),
  explosion: z.object({ asset: z.string().min(1), columns: positive.int(), rows: positive.int(), anchor: positive, frameEnds: z.array(positive).nonempty() }),
  towerGeometry: z.object({ backgroundWidth: positive, backgroundHeight: positive, button: positive, ring: positive, seat: positive,
    iconInset: z.number().min(0).lt(.5), tapMargin: positive, tapMinimum: positive, artworkLift: z.number(), baseLift: height,
    atlasColumns: positive.int(), atlasRows: positive.int() }) });
export type Presentation = z.infer<typeof presentationSchema>;
export type Pose = z.infer<typeof pose>;
export function resolveHeight(value: z.infer<typeof height>, playableHeight: number) {
  return Math.min(Math.max(value.fraction * playableHeight, value.minimum), value.maximum);
}
