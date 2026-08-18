// SimKernel.metal
// One GPU thread = one complete simulation run, executed in bounded tick
// slices so the display GPU's watchdog never fires: per-sim state persists in
// a device buffer between dispatches. Mirrors the tick order of
// Engine/Models/Simulation.swift; the integer RNG is bit-identical to the CPU
// engine, float math is fp32 (CPU uses Double), so agreement is statistical —
// the --gpu-validate harness checks it.
#include <metal_stdlib>
#include "SimGPUTypes.h"
using namespace metal;

// MARK: - RNG (bit-identical port of Engine/Models/Core.swift)

struct SplitMix64 {
    ulong state;
    ulong next() {
        state += 0x9E3779B97F4A7C15ul;
        ulong z = state;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ul;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBul;
        return z ^ (z >> 31);
    }
};

static inline ulong rotl64(ulong x, ulong k) { return (x << k) | (x >> (64 - k)); }

struct Xoshiro {
    ulong s0, s1, s2, s3;

    void seedWith(ulong seed) {
        SplitMix64 sm { seed };
        s0 = sm.next(); s1 = sm.next(); s2 = sm.next(); s3 = sm.next();
        if ((s0 | s1 | s2 | s3) == 0) { s3 = 0x9E3779B97F4A7C15ul; }
    }

    void load(device const sim_u64* p) { s0 = p[0]; s1 = p[1]; s2 = p[2]; s3 = p[3]; }
    void store(device sim_u64* p) { p[0] = s0; p[1] = s1; p[2] = s2; p[3] = s3; }

    ulong next() {
        ulong result = rotl64(s1 * 5, 7) * 9;
        ulong t = s1 << 17;
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3; s2 ^= t;
        s3 = rotl64(s3, 45);
        return result;
    }

    Xoshiro fork(ulong stream) {
        SplitMix64 sm { s0 ^ (0xD1B54A32D192ED03ul * (stream + 1)) };
        Xoshiro r;
        r.seedWith(sm.next());
        return r;
    }

    float unit() { return float(next() >> 40) * (1.0f / 16777216.0f); }
    float range(float lo, float hi) { return lo + unit() * (hi - lo); }
    bool chance(float p) {
        if (p <= 0) return false;
        if (p >= 1) return true;
        return unit() < p;
    }
};

// MARK: - Path

static float2 pathPoint(constant LevelGPU& lvl, uint path, float d) {
    uint n = lvl.pathPointCount[path];
    if (d <= 0) return lvl.pathPoints[path][0];
    float total = lvl.pathTotalLength[path];
    if (d >= total) return lvl.pathPoints[path][n - 1];
    uint lo = 0, hi = n - 1;
    while (lo + 1 < hi) {
        uint mid = (lo + hi) / 2;
        if (lvl.pathCumulative[path][mid] <= d) lo = mid; else hi = mid;
    }
    float segStart = lvl.pathCumulative[path][lo];
    float segLen = lvl.pathCumulative[path][hi] - segStart;
    float t = segLen > 0 ? (d - segStart) / segLen : 0;
    return mix(lvl.pathPoints[path][lo], lvl.pathPoints[path][hi], t);
}

static inline float dist2(float2 a, float2 b) {
    float2 v = a - b;
    return dot(v, v);
}

// Live index of the enemy with this spawnID; -1 if gone. Claims are unique
// (one unit per enemy), so a live scan matches the CPU engine's
// built-once-per-militia-step spawnID index observably.
//
// spawnID[] is always ascending - enemies are appended with a monotonic id and
// the compaction pass preserves order - so this binary searches instead of
// scanning. That is ~7 probes against an average of n/2 for a linear walk, with
// no extra state: a spawnID-indexed lookup table measured 6-7% SLOWER, because
// the kernel is bound by per-thread memory traffic rather than by instructions.
static int findEnemy(device SimStateGPU& S, uint n, int spawnID) {
    if (spawnID < 0 || n == 0) return -1;
    uint lo = 0, hi = n;
    while (lo < hi) {
        uint mid = (lo + hi) >> 1;
        int v = int(S.spawnID[mid]);
        if (v == spawnID) return S.removed[mid] ? -1 : int(mid);
        if (v < spawnID) lo = mid + 1; else hi = mid;
    }
    return -1;
}

// Command-aura holders shock their own side when they fall (CPU: remove()).
static void commandDeathShock(device SimStateGPU& S, constant LevelGPU& lvl,
                              uint n, uint i, thread float2* positions,
                              thread float* discBonus) {
    constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
    if (!(type.flags & SIM_TRAIT_COMMAND)) return;
    float sr2 = type.cmdRadius * type.cmdRadius;
    for (uint j = 0; j < n; j++) {
        if (S.removed[j] || S.state[j] == 2) continue;
        if (dist2(positions[j], positions[i]) > sr2) continue;
        constant EnemyTypeGPU& jt = lvl.enemyTypes[S.typeIndex[j]];
        float ed = min(1.0f, jt.discipline + discBonus[j]);
        S.morale[j] -= type.cmdShock * (1.0f - ed);
    }
}

// Garrison creation at build time (CPU: Simulation.build).
static void spawnGarrison(device SimStateGPU& S, constant LevelGPU& lvl,
                          constant PermGPU& perm, uint slot, uint kind) {
    constant TowerLevelGPU& t0 = perm.towers[kind][0];
    if (t0.meleeUnitCount <= 0) return;
    uint count = min(uint(t0.meleeUnitCount), uint(SIM_MAX_MELEE_UNITS_PER));
    float2 towerPos = lvl.slots[slot];
    for (uint k = 0; k < count; k++) {
        uint m = slot * SIM_MAX_MELEE_UNITS_PER + k;
        S.muX[m] = towerPos.x;
        S.muY[m] = towerPos.y;
        S.muHP[m] = t0.meleeUnitHP;
        S.muState[m] = SIM_MU_RETURNING;
        S.muTarget[m] = -1;
        S.muRespawnTicks[m] = 0;
        S.muSwingTicks[m] = 0;
        S.muEnemySwingTicks[m] = 0;
    }
}

// MARK: - Removal & economy

static void removeEnemy(device SimStateGPU& S, constant LevelGPU& lvl,
                        constant PermGPU& perm,
                        uint i, uint fate, device SimResultGPU* result);

// Militia garrisons: MilitiaAI decides, engine executes — a tick-for-tick
// mirror of Simulation.stepMilitia, including the rngCombat draw order
// (strikes, then return blows, per unit). Also called with n == 0 so garrison
// upkeep (respawn, heal, walk to rally) continues on an empty field; that
// path draws no RNG. Returns whether any garrison exists (movement reads it
// alongside muBlocked).
static bool militiaStep(device SimStateGPU& S, constant LevelGPU& lvl,
                        constant PermGPU& perm, uint n, float dt,
                        thread float2* positions, thread float* discBonus,
                        thread uchar* muClaimed, thread uchar* muFree,
                        thread uchar* muBlocked,
                        thread Xoshiro& rngCombat,
                        device SimResultGPU* result) {
    bool hasMilitia = false;
    for (uint slot = 0; slot < lvl.slotCount; slot++) {
        if (S.towerLevel[slot] >= 0
            && perm.towers[S.towerKind[slot]][0].meleeUnitCount > 0) {
            hasMilitia = true;
            break;
        }
    }
    if (!hasMilitia) return false;

    for (uint i = 0; i < n; i++) { muClaimed[i] = 0; muBlocked[i] = 0; }
    for (uint m = 0; m < SIM_MAX_MELEE_UNITS; m++) {
        if (S.muState[m] == SIM_MU_NONE) continue;
        int ei = findEnemy(S, n, S.muTarget[m]);
        if (ei >= 0) muClaimed[ei] = 1;
    }
    for (uint slot = 0; slot < lvl.slotCount; slot++) {
        int tl = S.towerLevel[slot];
        if (tl < 0) continue;
        uint kind = S.towerKind[slot];
        int unitCount = perm.towers[kind][0].meleeUnitCount;
        if (unitCount <= 0) continue;
        constant TowerLevelGPU& ms = perm.towers[kind][tl];
        float2 towerPos = lvl.slots[slot];
        float2 rally = perm.rallyPoints[slot];
        // Free enemies near this post: alive, steady/shaken,
        // blockable, unclaimed. Snapshot per slot, like the CPU:
        // a disengage frees the enemy for LATER slots only.
        for (uint i = 0; i < n; i++) {
            muFree[i] = !S.removed[i] && S.state[i] != 2 && !muClaimed[i]
                && !(lvl.enemyTypes[S.typeIndex[i]].flags & SIM_TRAIT_RIDE_DOWN);
        }
        uint count = min(uint(unitCount), uint(SIM_MAX_MELEE_UNITS_PER));
        for (uint ui = 0; ui < count; ui++) {
            uint m = slot * SIM_MAX_MELEE_UNITS_PER + ui;
            if (S.muState[m] == SIM_MU_NONE) continue;
            float2 post = rally;
            if (count > 1) {
                float ang = 2.0f * M_PI_F * float(ui) / float(count);
                post += lvl.militiaRallySpread * float2(cos(ang), sin(ang));
            }
            int tei = findEnemy(S, n, S.muTarget[m]);
            bool hasTarget = tei >= 0 && S.state[tei] != 2;
            float2 targetPos = hasTarget ? positions[tei] : float2(0);
            float2 pos = float2(S.muX[m], S.muY[m]);
            if (S.muSwingTicks[m] > 0) S.muSwingTicks[m]--;

            uint st = S.muState[m];
            bool doStrike = false;
            bool doDisengage = false;
            if (st == SIM_MU_DEAD) {
                if (S.muRespawnTicks[m] > 0) {
                    S.muRespawnTicks[m]--;
                } else {
                    S.muX[m] = towerPos.x; S.muY[m] = towerPos.y;
                    S.muHP[m] = ms.meleeUnitHP;
                    S.muState[m] = SIM_MU_RETURNING;
                    S.muTarget[m] = -1;
                    S.muSwingTicks[m] = 0;
                    S.muEnemySwingTicks[m] = 0;
                    result->militiaRespawns++;
                }
            } else if (st == SIM_MU_RETURNING) {
                float d = distance(pos, post);
                if (d <= 2.0f) {
                    S.muState[m] = SIM_MU_HOLDING;   // arrival
                } else {
                    float step = lvl.militiaMoveSpeed * dt;
                    float2 np = d <= step ? post : mix(pos, post, step / d);
                    S.muX[m] = np.x; S.muY[m] = np.y;
                }
            } else if (st == SIM_MU_HOLDING) {
                // Nearest free enemy inside the scan radius of the
                // POST (soldiers defend their ground).
                int best = -1;
                float bestDist = lvl.militiaEngageScanRadius;
                for (uint i = 0; i < n; i++) {
                    if (!muFree[i]) continue;
                    float d = distance(positions[i], post);
                    if (d <= bestDist) { bestDist = d; best = int(i); }
                }
                if (best >= 0) {
                    S.muState[m] = SIM_MU_ENGAGING;
                    S.muTarget[m] = int(S.spawnID[best]);
                    muClaimed[best] = 1;
                    muFree[best] = 0;
                } else if (distance(pos, post) > 2.0f) {
                    float d = distance(pos, post);
                    float step = lvl.militiaMoveSpeed * dt;
                    float2 np = d <= step ? post : mix(pos, post, step / d);
                    S.muX[m] = np.x; S.muY[m] = np.y;
                } else {
                    S.muHP[m] = min(ms.meleeUnitHP,
                                    S.muHP[m] + ms.meleeHealPerSecond * dt);
                }
            } else if (st == SIM_MU_ENGAGING) {
                if (!hasTarget
                    || distance(targetPos, post) > lvl.militiaLeashRadius) {
                    doDisengage = true;
                } else if (distance(pos, targetPos) <= lvl.militiaMeleeReach) {
                    doStrike = true;   // first blow starts the fight
                } else {
                    float d = distance(pos, targetPos);
                    float step = lvl.militiaMoveSpeed * dt;
                    float2 np = d <= step ? targetPos
                                          : mix(pos, targetPos, step / d);
                    S.muX[m] = np.x; S.muY[m] = np.y;
                }
            } else if (st == SIM_MU_FIGHTING) {
                if (!hasTarget
                    || distance(targetPos, post) > lvl.militiaLeashRadius) {
                    doDisengage = true;
                } else if (S.muSwingTicks[m] <= 0) {
                    doStrike = true;
                }
            }

            if (doStrike) {
                if (S.muState[m] == SIM_MU_ENGAGING) {
                    S.muState[m] = SIM_MU_FIGHTING;
                    S.muEnemySwingTicks[m] = short(lvl.militiaEnemySwingTicks);
                }
                if (tei >= 0) {
                    uint i = uint(tei);
                    constant EnemyTypeGPU& etype = lvl.enemyTypes[S.typeIndex[i]];
                    float roll = rngCombat.range(ms.meleeDamageMin, ms.meleeDamageMax);
                    S.hp[i] -= roll * (1.0f - etype.cover);
                    if (S.hp[i] <= 0) {
                        removeEnemy(S, lvl, perm, i, 0, result);
                        result->militiaKills++;
                        S.muState[m] = SIM_MU_HOLDING;
                        S.muTarget[m] = -1;
                        S.muEnemySwingTicks[m] = 0;
                        commandDeathShock(S, lvl, n, i, positions, discBonus);
                    }
                }
                S.muSwingTicks[m] = short(ms.meleeAttackTicks);
            }
            if (doDisengage) {
                int ei = findEnemy(S, n, S.muTarget[m]);
                if (ei >= 0) muClaimed[ei] = 0;
                S.muState[m] = SIM_MU_RETURNING;
                S.muTarget[m] = -1;
                S.muEnemySwingTicks[m] = 0;
            }

            // Fights hold the enemy in place and draw return blows.
            if (S.muState[m] == SIM_MU_FIGHTING && S.muTarget[m] >= 0) {
                int fi = findEnemy(S, n, S.muTarget[m]);
                if (fi >= 0) {
                    muBlocked[fi] = 1;
                    short swing = S.muEnemySwingTicks[m] - 1;
                    if (swing <= 0) {
                        constant EnemyTypeGPU& et = lvl.enemyTypes[S.typeIndex[fi]];
                        S.muHP[m] -= rngCombat.range(et.damageMin, et.damageMax)
                            * (1.0f - ms.meleeDefenseRating);
                        swing = short(lvl.militiaEnemySwingTicks);
                        if (S.muHP[m] <= 0) {
                            result->militiaDeaths++;
                            muClaimed[fi] = 0;
                            muBlocked[fi] = 0;
                            S.muState[m] = SIM_MU_DEAD;
                            S.muTarget[m] = -1;
                            S.muRespawnTicks[m] = short(ms.meleeRespawnTicks);
                            S.muEnemySwingTicks[m] = 0;
                        }
                    }
                    if (S.muTarget[m] >= 0) S.muEnemySwingTicks[m] = swing;
                }
            }
        }
    }
    return true;
}

static void removeEnemy(device SimStateGPU& S, constant LevelGPU& lvl,
                        constant PermGPU& perm,
                        uint i, uint fate, device SimResultGPU* result) {
    // fate: 0 killed, 1 routed, 2 captured, 3 leaked
    if (S.removed[i]) return;
    S.removed[i] = 1;
    float base = float(perm.enemyGold[S.typeIndex[i]]);
    int earned = 0;
    if (fate == 0) { S.killed++; earned = int(round(base * lvl.killBountyMult)); }
    else if (fate == 1) { S.routed++; earned = int(round(base * lvl.routBountyMult)); }
    else if (fate == 2) { S.captured++; earned = int(round(base * lvl.captureBountyMult)); }
    else {
        S.leaked++;
        uint w = S.waveIndex[i];
        if (w < SIM_MAX_WAVES) result->leaksByWave[w]++;
    }
    S.gold += earned;
    S.goldEarned += uint(earned);
}

// MARK: - Kernel

kernel void simulate(
    constant LevelGPU& lvl [[buffer(0)]],
    constant PermGPU* perms [[buffer(1)]],
    constant DispatchParamsGPU& dp [[buffer(2)]],
    device SimResultGPU* results [[buffer(3)]],
    device SimStateGPU* states [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    uint tid = gid + dp.threadBase;
    uint permIndex = tid / dp.seedsPerPerm;
    uint seedIndex = tid % dp.seedsPerPerm;
    if (permIndex >= dp.permCount) return;
    constant PermGPU& perm = perms[permIndex];
    device SimResultGPU* result = &results[tid];
    device SimStateGPU& S = states[tid];

    if (S.outcome != 0) return;   // finished in an earlier slice

    // First slice: initialize.
    if (S.initialized == 0) {
        S.initialized = 1;
        Xoshiro root;
        root.seedWith(dp.baseSeed + seedIndex);
        Xoshiro c = root.fork(1); c.store(S.rngCombat);
        Xoshiro m = root.fork(2); m.store(S.rngMorale);
        Xoshiro g = root.fork(3); g.store(S.rngContagion);
        S.gold = perm.money;
        S.lives = perm.lives;
        for (uint i = 0; i < lvl.slotCount; i++) {
            S.towerLevel[i] = -1;
            S.towerCooldown[i] = 0;
            S.slotOrder[i] = perm.slotOrder[i];
        }
        for (uint m = 0; m < SIM_MAX_MELEE_UNITS; m++) {
            S.muState[m] = SIM_MU_NONE;
            S.muTarget[m] = -1;
        }
        if (dp.mode == SIM_MODE_NAIVE_W1) {
            Xoshiro shuffle;
            shuffle.seedWith((dp.baseSeed + seedIndex) ^ 0xA1F05107ul);
            for (uint i = 0; i < lvl.slotCount; i++) { S.slotOrder[i] = i; }
            for (int i = int(lvl.slotCount) - 1; i > 0; i--) {
                uint j = min(uint(shuffle.range(0, float(i))), uint(i));
                uint tmp = S.slotOrder[i]; S.slotOrder[i] = S.slotOrder[j]; S.slotOrder[j] = tmp;
            }
        }
        for (uint w = 0; w < SIM_MAX_WAVES; w++) {
            result->waveMaxProgress[w] = 0;
            result->leaksByWave[w] = 0;
        }
    }

    Xoshiro rngCombat; rngCombat.load(S.rngCombat);
    Xoshiro rngMorale; rngMorale.load(S.rngMorale);
    Xoshiro rngContagion; rngContagion.load(S.rngContagion);

    float maxSeconds = dp.mode == SIM_MODE_NAIVE_W1
        ? min(dp.maxSeconds, perm.w1CutoffSeconds) : dp.maxSeconds;
    float dt = lvl.dt;
    int maxTicks = int(maxSeconds * float(lvl.ticksPerSecond));
    int checkEvery = lvl.ticksPerSecond / 2;
    int sliceEnd = min(S.tick + int(dp.sliceTicks), maxTicks);
    uint outcome = 0;

    float2 positions[SIM_MAX_ENEMIES];
    float moraleRegen[SIM_MAX_ENEMIES];
    float discBonus[SIM_MAX_ENEMIES];
    uchar muClaimed[SIM_MAX_ENEMIES];
    uchar muFree[SIM_MAX_ENEMIES];
    uchar muBlocked[SIM_MAX_ENEMIES];

    while (outcome == 0 && S.tick < sliceEnd) {
        float time = float(S.tick) * dt;

        // 1. Policy.
        if (S.tick >= S.nextCheckTick) {
            S.nextCheckTick = S.tick + checkEvery;
            if (S.buildsDone < perm.planLen && S.buildsDone < lvl.slotCount) {
                uint kind = perm.planKind[S.buildsDone];
                uint slot = S.slotOrder[S.buildsDone];
                if (kind < perm.kindCount && S.towerLevel[slot] < 0) {
                    int cost = perm.towers[kind][0].cost;
                    if (S.gold >= cost) {
                        S.gold -= cost;
                        S.towerLevel[slot] = 0;
                        S.towerKind[slot] = uchar(kind);
                        S.towerCooldown[slot] = 0;
                        spawnGarrison(S, lvl, perm, slot, kind);
                        S.buildsDone++;
                    }
                } else {
                    S.buildsDone++;
                }
            } else if (dp.mode == SIM_MODE_GREEDY) {
                bool acted = false;
                for (uint k = 0; k < lvl.slotCount && !acted; k++) {
                    uint slot = S.slotOrder[k];
                    int lvlNow = S.towerLevel[slot];
                    if (lvlNow < 0) continue;
                    uint kind = S.towerKind[slot];
                    if (uint(lvlNow + 1) >= perm.levelsPerKind[kind]) continue;
                    int cost = perm.towers[kind][lvlNow + 1].cost;
                    if (S.gold >= cost + 40) {
                        S.gold -= cost;
                        S.towerLevel[slot] = char(lvlNow + 1);
                        // Upgrading re-equips the garrison (CPU: Simulation.upgrade).
                        constant TowerLevelGPU& nt = perm.towers[kind][lvlNow + 1];
                        if (nt.meleeUnitCount > 0) {
                            for (uint u = 0; u < uint(SIM_MAX_MELEE_UNITS_PER); u++) {
                                uint mu = slot * SIM_MAX_MELEE_UNITS_PER + u;
                                if (S.muState[mu] != SIM_MU_NONE
                                    && S.muState[mu] != SIM_MU_DEAD) {
                                    S.muHP[mu] = nt.meleeUnitHP;
                                }
                            }
                        }
                    }
                    acted = true;
                }
                if (!acted) {
                    uint built = 0;
                    for (uint i = 0; i < lvl.slotCount; i++) { if (S.towerLevel[i] >= 0) built++; }
                    if (built < min(6u, lvl.slotCount) && S.gold >= 150) {
                        uint slot = S.slotOrder[built];
                        uint kind = perm.planKind[0];
                        if (S.towerLevel[slot] < 0 && kind < perm.kindCount) {
                            int cost = perm.towers[kind][0].cost;
                            if (S.gold >= cost) {
                                S.gold -= cost;
                                S.towerLevel[slot] = 0;
                                S.towerKind[slot] = uchar(kind);
                                spawnGarrison(S, lvl, perm, slot, kind);
                            }
                        }
                    }
                }
            }
        }

        // 2. Spawns.
        while (S.scheduleCursor < perm.spawnCount
               && perm.spawns[S.scheduleCursor].time <= time) {
            constant SpawnGPU& sp = perm.spawns[S.scheduleCursor];
            S.scheduleCursor++;
            if (S.n >= SIM_MAX_ENEMIES) { S.spawnOverflow++; continue; }
            uint i = S.n++;
            constant EnemyTypeGPU& type = lvl.enemyTypes[sp.typeIndex];
            S.distance[i] = 0;
            S.hp[i] = perm.enemyMaxHP[sp.typeIndex];
            S.morale[i] = lvl.moraleMax;
            S.threshold[i] = lvl.moraleMax * rngMorale.range(type.breakLo, type.breakHi);
            S.typeIndex[i] = uchar(sp.typeIndex);
            S.pathIndex[i] = uchar(sp.pathIndex);
            S.waveIndex[i] = uchar(sp.waveIndex);
            S.state[i] = 0;
            S.infected[i] = 0;
            S.removed[i] = 0;
            S.spawnID[i] = ushort(S.nextSpawnID++);
        }

        uint n = S.n;
        if (n > 0) {
            // 3. Position cache.
            for (uint i = 0; i < n; i++) {
                positions[i] = pathPoint(lvl, S.pathIndex[i], S.distance[i]);
            }

            // 4. Auras.
            for (uint i = 0; i < n; i++) {
                moraleRegen[i] = lvl.baseMoraleRegen;
                discBonus[i] = 0;
            }
            for (uint i = 0; i < n; i++) {
                if (S.removed[i]) continue;
                constant EnemyTypeGPU& t = lvl.enemyTypes[S.typeIndex[i]];
                if (t.flags & SIM_TRAIT_RALLY) {
                    float r2 = t.auraRadius * t.auraRadius;
                    for (uint j = 0; j < n; j++) {
                        if (j == i || S.removed[j]) continue;
                        if (dist2(positions[i], positions[j]) <= r2) {
                            moraleRegen[j] += t.auraRate;
                        }
                    }
                }
                if (t.flags & SIM_TRAIT_COMMAND) {
                    float r2 = t.cmdRadius * t.cmdRadius;
                    for (uint j = 0; j < n; j++) {
                        if (j == i || S.removed[j]) continue;
                        if (dist2(positions[i], positions[j]) <= r2) {
                            discBonus[j] = max(discBonus[j], t.cmdBonus);
                        }
                    }
                }
            }

            // 5. Towers fire.
            for (uint slot = 0; slot < lvl.slotCount; slot++) {
                int tl = S.towerLevel[slot];
                if (tl < 0) continue;
                constant TowerLevelGPU& tw = perm.towers[S.towerKind[slot]][tl];
                if (!(tw.shotMaxDamage > 0 || tw.terrorMax > 0 || tw.contagionChance > 0)) {
                    continue;   // melee garrisons fight in their own step
                }
                S.towerCooldown[slot] -= 1;
                if (S.towerCooldown[slot] > 0) continue;
                float2 origin = lvl.slots[slot];
                float r2 = tw.range * tw.range;
                int best = -1;
                float bestKey = -INFINITY;
                for (uint i = 0; i < n; i++) {
                    if (S.removed[i]) continue;
                    if (dist2(positions[i], origin) > r2) continue;
                    float key;
                    switch (tw.targeting) {
                        case SIM_TARGET_FIRST: key = S.distance[i] - lvl.pathTotalLength[S.pathIndex[i]]; break;
                        case SIM_TARGET_LAST: key = lvl.pathTotalLength[S.pathIndex[i]] - S.distance[i]; break;
                        case SIM_TARGET_STRONGEST: key = S.hp[i]; break;
                        default: key = S.state[i] == 2 ? -1000000.0f : -S.morale[i]; break;
                    }
                    if (key > bestKey) { bestKey = key; best = int(i); }
                }
                if (best < 0) continue;

                if (tw.projectileSpeed > 0) {
                    // Launch: homing round at the enemy, or a ballistic shell
                    // at its current position. Damage happens at impact.
                    if (S.projCount < SIM_MAX_PROJECTILES) {
                        uint pj = S.projCount++;
                        float2 o = lvl.slots[slot];
                        S.projX[pj] = o.x; S.projY[pj] = o.y;
                        S.projAimX[pj] = positions[best].x;
                        S.projAimY[pj] = positions[best].y;
                        S.projTarget[pj] = tw.aoeRadius > 0 ? -1 : int(S.spawnID[best]);
                        S.projKind[pj] = S.towerKind[slot];
                        S.projLevel[pj] = uchar(tl);
                        S.projRemoved[pj] = 0;
                    } else {
                        result->projOverflow++;
                    }
                    S.towerCooldown[slot] = tw.fireTicks;
                    continue;
                }

                float2 center = positions[best];
                float aoe2 = tw.aoeRadius * tw.aoeRadius;
                for (uint i = 0; i < n; i++) {
                    if (S.removed[i]) continue;
                    bool isPrimary = (int(i) == best);
                    bool isBlast = tw.aoeRadius > 0;
                    float blastT = 0;
                    if (isBlast) {
                        float d2 = dist2(positions[i], center);
                        if (d2 > aoe2) continue;
                        // KR blast model: max damage at the impact center
                        // falling to min at the edge; distance is the roll.
                        blastT = pow(min(1.0f, sqrt(d2) / tw.aoeRadius), tw.aoeFalloffExponent);
                    } else if (!isPrimary) {
                        continue;
                    }
                    constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                    if (tw.shotMaxDamage > 0) {
                        float damage, effCover;
                        if (isBlast) {
                            damage = tw.shotMaxDamage - (tw.shotMaxDamage - tw.shotMinDamage) * blastT;
                            effCover = type.cover * (1.0f - tw.splashCoverPierce);
                        } else {
                            damage = rngCombat.range(tw.shotMinDamage, tw.shotMaxDamage);
                            effCover = type.cover;
                        }
                        S.hp[i] -= damage * (1.0f - effCover);
                    }
                    if (tw.terrorMax > 0) {
                        float effDisc = min(1.0f, type.discipline + discBonus[i]);
                        if (effDisc < 1.0f) {
                            float terror = isBlast
                                ? tw.terrorMax - (tw.terrorMax - tw.terrorMin) * blastT
                                : rngCombat.range(tw.terrorMin, tw.terrorMax);
                            S.morale[i] -= terror * (1.0f - effDisc);
                        }
                    }
                    if (isPrimary && tw.contagionChance > 0 && !S.infected[i]) {
                        if (rngCombat.chance(tw.contagionChance * (1.0f - type.hardiness))) {
                            S.infected[i] = 1;
                        }
                    }
                    if (S.hp[i] <= 0) {
                        removeEnemy(S, lvl, perm, i, 0, result);
                        commandDeathShock(S, lvl, n, i, positions, discBonus);
                    }
                }
                S.towerCooldown[slot] = tw.fireTicks;
            }

            // 5b. Projectiles fly; collision applies damage at impact.
            // Keep the volley math in lockstep with the tower-fire loop above.
            for (uint pj = 0; pj < S.projCount; pj++) {
                if (S.projRemoved[pj]) continue;
                constant TowerLevelGPU& tw = perm.towers[S.projKind[pj]][S.projLevel[pj]];
                float travel = tw.projectileSpeed * dt;
                float2 pos = float2(S.projX[pj], S.projY[pj]);
                float2 dest = float2(S.projAimX[pj], S.projAimY[pj]);
                int targetIndex = -1;
                if (S.projTarget[pj] >= 0) {
                    for (uint i = 0; i < n; i++) {
                        if (!S.removed[i] && int(S.spawnID[i]) == S.projTarget[pj]) {
                            targetIndex = int(i);
                            break;
                        }
                    }
                    if (targetIndex < 0) { S.projRemoved[pj] = 1; result->projFizzles++; continue; }
                    dest = positions[uint(targetIndex)];
                }
                float dd = distance(pos, dest);
                if (dd <= travel) {
                    result->projImpacts++;
                    if (S.projTarget[pj] >= 0) {
                        uint i = uint(targetIndex);
                        constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                        if (tw.shotMaxDamage > 0) {
                            float roll = rngCombat.range(tw.shotMinDamage, tw.shotMaxDamage);
                            S.hp[i] -= roll * (1.0f - type.cover);
                        }
                        if (tw.terrorMax > 0) {
                            float effDisc = min(1.0f, type.discipline + discBonus[i]);
                            if (effDisc < 1.0f) {
                                float roll = rngCombat.range(tw.terrorMin, tw.terrorMax);
                                S.morale[i] -= roll * (1.0f - effDisc);
                            }
                        }
                        if (tw.contagionChance > 0 && !S.infected[i]) {
                            if (rngCombat.chance(tw.contagionChance * (1.0f - type.hardiness))) {
                                S.infected[i] = 1;
                            }
                        }
                        if (S.hp[i] <= 0) {
                            removeEnemy(S, lvl, perm, i, 0, result);
                            commandDeathShock(S, lvl, n, i, positions, discBonus);
                        }
                    } else {
                        // Ballistic blast where the shell lands, against
                        // enemies there NOW; no primary, so no contagion.
                        float aoe2 = tw.aoeRadius * tw.aoeRadius;
                        for (uint i = 0; i < n; i++) {
                            if (S.removed[i]) continue;
                            float d2 = dist2(positions[i], dest);
                            if (d2 > aoe2) continue;
                            float blastT = pow(min(1.0f, sqrt(d2) / tw.aoeRadius), tw.aoeFalloffExponent);
                            constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                            if (tw.shotMaxDamage > 0) {
                                float damage = tw.shotMaxDamage - (tw.shotMaxDamage - tw.shotMinDamage) * blastT;
                                float effCover = type.cover * (1.0f - tw.splashCoverPierce);
                                S.hp[i] -= damage * (1.0f - effCover);
                            }
                            if (tw.terrorMax > 0) {
                                float effDisc = min(1.0f, type.discipline + discBonus[i]);
                                if (effDisc < 1.0f) {
                                    float terror = tw.terrorMax - (tw.terrorMax - tw.terrorMin) * blastT;
                                    S.morale[i] -= terror * (1.0f - effDisc);
                                }
                            }
                            if (S.hp[i] <= 0) {
                                removeEnemy(S, lvl, perm, i, 0, result);
                                commandDeathShock(S, lvl, n, i, positions, discBonus);
                            }
                        }
                    }
                    S.projRemoved[pj] = 1;
                } else {
                    pos = mix(pos, dest, travel / dd);
                    S.projX[pj] = pos.x;
                    S.projY[pj] = pos.y;
                }
            }
            {
                // Order-preserving projectile compaction (RNG order parity).
                uint w = 0;
                for (uint pj = 0; pj < S.projCount; pj++) {
                    if (S.projRemoved[pj]) continue;
                    if (w != pj) {
                        S.projX[w] = S.projX[pj]; S.projY[w] = S.projY[pj];
                        S.projAimX[w] = S.projAimX[pj]; S.projAimY[w] = S.projAimY[pj];
                        S.projTarget[w] = S.projTarget[pj];
                        S.projKind[w] = S.projKind[pj];
                        S.projLevel[w] = S.projLevel[pj];
                        S.projRemoved[w] = 0;
                    }
                    w++;
                }
                S.projCount = w;
            }

            // 5c. Militia garrisons (tick-for-tick mirror of
            // Simulation.stepMilitia; body lives in militiaStep above).
            bool hasMilitia = militiaStep(S, lvl, perm, n, dt,
                                          positions, discBonus,
                                          muClaimed, muFree, muBlocked,
                                          rngCombat, result);

            // 6. Contagion.
            S.contagionAcc += dt;
            if (S.contagionAcc >= lvl.contagionTickInterval) {
                S.contagionAcc -= lvl.contagionTickInterval;
                float interval = lvl.contagionTickInterval;
                for (uint i = 0; i < n; i++) {
                    if (S.removed[i] || !S.infected[i]) continue;
                    constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                    float floorHP = perm.enemyMaxHP[S.typeIndex[i]] * lvl.diseaseHPFloorFraction;
                    if (S.hp[i] > floorHP) {
                        S.hp[i] = max(floorHP, S.hp[i] - lvl.diseaseHPPerSecond * interval);
                    } else {
                        float effDisc = min(1.0f, type.discipline + discBonus[i]);
                        if (effDisc < 1.0f) {
                            S.morale[i] -= lvl.diseaseMoralePerSecond * interval * (1.0f - effDisc);
                        }
                    }
                }
                float r2 = lvl.contagionSpreadRadius * lvl.contagionSpreadRadius;
                for (uint i = 0; i < n; i++) {
                    if (S.removed[i] || !S.infected[i]) continue;
                    for (uint j = 0; j < n; j++) {
                        if (j == i || S.removed[j] || S.infected[j]) continue;
                        if (dist2(positions[i], positions[j]) > r2) continue;
                        float hard = lvl.enemyTypes[S.typeIndex[j]].hardiness;
                        if (rngContagion.chance(lvl.contagionSpreadChance * (1.0f - hard))) {
                            S.infected[j] = 1;
                        }
                    }
                }
            }

            // 7. Morale: regen, transitions, break cascades.
            for (uint i = 0; i < n; i++) {
                if (S.removed[i]) continue;
                if (S.state[i] != 2) {
                    S.morale[i] = min(lvl.moraleMax, S.morale[i] + moraleRegen[i] * dt);
                    constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                    bool steadyGate = (type.flags & SIM_TRAIT_STEADY_ADVANCE)
                        && S.hp[i] > perm.enemyMaxHP[S.typeIndex[i]] * lvl.steadyAdvanceHPGate;
                    if (S.state[i] == 0 && S.morale[i] <= S.threshold[i] && !steadyGate) {
                        S.state[i] = 1;
                    } else if (S.state[i] == 1 && S.morale[i] > S.threshold[i]) {
                        S.state[i] = 0;
                    }
                }
            }
            bool anyBroke = true;
            while (anyBroke) {
                anyBroke = false;
                for (uint i = 0; i < n; i++) {
                    if (S.removed[i] || S.state[i] == 2 || S.morale[i] > 0) continue;
                    anyBroke = true;
                    S.state[i] = 2;
                    constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                    float mult = (type.flags & SIM_TRAIT_WAVERING) ? lvl.waveringSplashMult : 1.0f;
                    float splash = lvl.breakSplash * mult;
                    float r2 = lvl.breakSplashRadius * lvl.breakSplashRadius;
                    for (uint j = 0; j < n; j++) {
                        if (j == i || S.removed[j] || S.state[j] == 2) continue;
                        if (dist2(positions[i], positions[j]) > r2) continue;
                        constant EnemyTypeGPU& jt = lvl.enemyTypes[S.typeIndex[j]];
                        float ed = min(1.0f, jt.discipline + discBonus[j]);
                        S.morale[j] -= splash * (1.0f - ed);
                    }
                    if (type.flags & SIM_TRAIT_MERCENARY) {
                        removeEnemy(S, lvl, perm, i, 2, result);
                    }
                }
            }

            // 8. Movement & exits.
            for (uint i = 0; i < n; i++) {
                if (S.removed[i]) continue;
                if (hasMilitia && muBlocked[i] && S.state[i] != 2) {
                    continue;   // held in melee: stands and fights
                }
                constant EnemyTypeGPU& type = lvl.enemyTypes[S.typeIndex[i]];
                float total = lvl.pathTotalLength[S.pathIndex[i]];
                float speed = perm.enemySpeed[S.typeIndex[i]];
                if (S.state[i] == 2) {
                    S.distance[i] -= speed * lvl.routSpeedMult * dt;
                    if (S.distance[i] <= 0) {
                        removeEnemy(S, lvl, perm, i, 1, result);
                    }
                } else {
                    float mult = S.state[i] == 1 ? lvl.shakenSpeedMult : 1.0f;
                    S.distance[i] += speed * mult * dt;
                    float progress = min(S.distance[i] / total, 1.0f);
                    uint w = S.waveIndex[i];
                    if (w < SIM_MAX_WAVES && progress > result->waveMaxProgress[w]) {
                        result->waveMaxProgress[w] = progress;
                    }
                    if (S.distance[i] >= total) {
                        S.lives -= type.livesCost;
                        removeEnemy(S, lvl, perm, i, 3, result);
                    }
                }
            }

            // 9. Compaction (order-preserving, like the CPU engine).
            uint w = 0;
            for (uint i = 0; i < n; i++) {
                if (S.removed[i]) continue;
                if (w != i) {
                    S.distance[w] = S.distance[i];
                    S.hp[w] = S.hp[i];
                    S.morale[w] = S.morale[i];
                    S.threshold[w] = S.threshold[i];
                    S.typeIndex[w] = S.typeIndex[i];
                    S.pathIndex[w] = S.pathIndex[i];
                    S.waveIndex[w] = S.waveIndex[i];
                    S.state[w] = S.state[i];
                    S.infected[w] = S.infected[i];
                    S.spawnID[w] = S.spawnID[i];
                    S.removed[w] = 0;
                }
                w++;
            }
            S.n = w;
        } else {
            // Empty field: garrison upkeep still runs — soldiers respawn,
            // heal, and walk to the rally point between spawns (mirrors
            // Simulation.step's else branch); draws no RNG.
            militiaStep(S, lvl, perm, 0, dt, positions, discBonus,
                        muClaimed, muFree, muBlocked, rngCombat, result);
        }

        // 10. End conditions.
        if (S.lives <= 0) {
            outcome = SIM_OUTCOME_DEFEAT;
        } else if (S.scheduleCursor == perm.spawnCount && S.n == 0) {
            outcome = SIM_OUTCOME_VICTORY;
        }

        S.tick += 1;
    }

    rngCombat.store(S.rngCombat);
    rngMorale.store(S.rngMorale);
    rngContagion.store(S.rngContagion);

    if (outcome == 0 && S.tick >= maxTicks) outcome = SIM_OUTCOME_TIMEOUT;
    if (outcome != 0) {
        S.outcome = outcome;
        result->outcome = outcome;
        result->livesRemaining = max(0, S.lives);
        result->gold = S.gold;
        result->killed = S.killed;
        result->routed = S.routed;
        result->captured = S.captured;
        result->leaked = S.leaked;
        result->goldEarned = S.goldEarned;
        result->seconds = float(S.tick) * dt;
        result->spawnOverflow = S.spawnOverflow;
    }
}
