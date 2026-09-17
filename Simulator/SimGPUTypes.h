#ifndef SimGPUTypes_h
#define SimGPUTypes_h

#ifdef __METAL_VERSION__
#include <metal_stdlib>
typedef metal::float2 sim_float2;
typedef ulong sim_u64;
#else
#include <simd/simd.h>
#include <stdint.h>
typedef simd_float2 sim_float2;
typedef uint64_t sim_u64;
#endif

#define SIM_MAX_PATHS 4
#define SIM_MAX_PATH_POINTS 16
#define SIM_MAX_SLOTS 16
#define SIM_MAX_WAVES 16
#define SIM_MAX_SPAWNS 320
#define SIM_MAX_ENEMY_TYPES 16
#define SIM_MAX_TOWER_KINDS 4
#define SIM_MAX_TOWER_LEVELS 4
#define SIM_MAX_ENEMIES 96
#define SIM_MAX_PROJECTILES 48
#define SIM_PLAN_LEN 4
#define SIM_MAX_MELEE_UNITS_PER 4
#define SIM_MAX_MELEE_UNITS (SIM_MAX_SLOTS * SIM_MAX_MELEE_UNITS_PER)

#define SIM_MU_DEAD 0
#define SIM_MU_RETURNING 1
#define SIM_MU_HOLDING 2
#define SIM_MU_ENGAGING 3
#define SIM_MU_FIGHTING 4
#define SIM_MU_NONE 5

#define SIM_TRAIT_WAVERING 1u
#define SIM_TRAIT_MERCENARY 2u
#define SIM_TRAIT_STEADY_ADVANCE 4u
#define SIM_TRAIT_RALLY 8u
#define SIM_TRAIT_COMMAND 16u
#define SIM_TRAIT_RIDE_DOWN 32u

#define SIM_TARGET_FIRST 0u
#define SIM_TARGET_LAST 1u
#define SIM_TARGET_STRONGEST 2u
#define SIM_TARGET_SHAKIEST 3u

#define SIM_OUTCOME_VICTORY 1u
#define SIM_OUTCOME_DEFEAT 2u
#define SIM_OUTCOME_TIMEOUT 3u

#define SIM_MODE_GREEDY 0u
#define SIM_MODE_NAIVE_W1 1u

typedef struct {
    float maxHP;
    float speed;
    float cover;
    float discipline;
    float hardiness;
    float breakLo;
    float breakHi;
    float auraRadius;
    float auraRate;
    float cmdRadius;
    float cmdBonus;
    float cmdShock;
    float damageMin;
    float damageMax;
    int gold;
    int livesCost;
    unsigned int flags;
    unsigned int _pad0;
} EnemyTypeGPU;

typedef struct {
    int cost;
    float range;
    float fireInterval;
    float shotMinDamage;
    float shotMaxDamage;
    float terrorMin;
    float terrorMax;
    float aoeRadius;
    float aoeFalloffExponent;
    float splashCoverPierce;
    float contagionChance;
    unsigned int targeting;
    int fireTicks;
    float projectileSpeed;

    int meleeUnitCount;
    float meleeUnitHP;
    float meleeDamageMin;
    float meleeDamageMax;
    float meleeDefenseRating;
    int meleeAttackTicks;
    int meleeRespawnTicks;
    float meleeHealPerSecond;
    float meleeLeashRadius;
    float meleeEngageScanRadius;
} TowerLevelGPU;

typedef struct {
    unsigned int pathCount;
    unsigned int slotCount;
    unsigned int enemyTypeCount;
    unsigned int numWaves;
    int lives;
    unsigned int _pad0;
    unsigned int pathPointCount[SIM_MAX_PATHS];
    float pathTotalLength[SIM_MAX_PATHS];
    sim_float2 pathPoints[SIM_MAX_PATHS][SIM_MAX_PATH_POINTS];
    float pathCumulative[SIM_MAX_PATHS][SIM_MAX_PATH_POINTS];
    sim_float2 slots[SIM_MAX_SLOTS];
    EnemyTypeGPU enemyTypes[SIM_MAX_ENEMY_TYPES];

    float moraleMax;
    float baseMoraleRegen;
    float breakSplash;
    float breakSplashRadius;
    float waveringSplashMult;
    float shakenSpeedMult;
    float routSpeedMult;
    float steadyAdvanceHPGate;
    float contagionTickInterval;
    float diseaseHPPerSecond;
    float diseaseHPFloorFraction;
    float diseaseMoralePerSecond;
    float contagionSpreadRadius;
    float contagionSpreadChance;
    float killBountyMult;
    float routBountyMult;
    float captureBountyMult;
    float dt;
    int ticksPerSecond;

    float arrivalRadius;
    float rangeVerticalFraction;
    float militiaMoveSpeed;
    float militiaMeleeReach;
    float militiaRallySpread;
    int militiaEnemySwingTicks;
} LevelGPU;

typedef struct {
    float time;
    unsigned int typeIndex;
    unsigned int pathIndex;
    unsigned int waveIndex;
} SpawnGPU;

typedef struct {
    int money;
    int lives;
    unsigned int kindCount;
    unsigned int spawnCount;
    unsigned int planLen;
    float w1CutoffSeconds;
    unsigned int _pad0;
    unsigned int _pad1;
    unsigned int levelsPerKind[SIM_MAX_TOWER_KINDS];
    TowerLevelGPU towers[SIM_MAX_TOWER_KINDS][SIM_MAX_TOWER_LEVELS];
    SpawnGPU spawns[SIM_MAX_SPAWNS];
    unsigned int slotOrder[SIM_MAX_SLOTS];
    unsigned int planKind[SIM_PLAN_LEN];

    float enemySpeed[SIM_MAX_ENEMY_TYPES];
    float enemyMaxHP[SIM_MAX_ENEMY_TYPES];
    int enemyGold[SIM_MAX_ENEMY_TYPES];

    sim_float2 rallyPoints[SIM_MAX_SLOTS];
} PermGPU;

typedef struct {
    unsigned int permCount;
    unsigned int seedsPerPerm;
    unsigned int mode;
    unsigned int sliceTicks;
    sim_u64 baseSeed;
    float maxSeconds;
    unsigned int threadBase;
} DispatchParamsGPU;

typedef struct {
    float distance[SIM_MAX_ENEMIES];
    float hp[SIM_MAX_ENEMIES];
    float morale[SIM_MAX_ENEMIES];
    float threshold[SIM_MAX_ENEMIES];
    unsigned char typeIndex[SIM_MAX_ENEMIES];
    unsigned char pathIndex[SIM_MAX_ENEMIES];
    unsigned char waveIndex[SIM_MAX_ENEMIES];
    unsigned char state[SIM_MAX_ENEMIES];
    unsigned char infected[SIM_MAX_ENEMIES];
    unsigned char removed[SIM_MAX_ENEMIES];
    unsigned short spawnID[SIM_MAX_ENEMIES];
    signed char towerLevel[SIM_MAX_SLOTS];
    unsigned char towerKind[SIM_MAX_SLOTS];
    int towerCooldown[SIM_MAX_SLOTS];
    unsigned int slotOrder[SIM_MAX_SLOTS];
    sim_u64 rngCombat[4];
    sim_u64 rngMorale[4];
    sim_u64 rngContagion[4];
    int gold;
    int lives;
    unsigned int killed;
    unsigned int routed;
    unsigned int captured;
    unsigned int leaked;
    unsigned int goldEarned;
    unsigned int scheduleCursor;
    unsigned int n;
    unsigned int spawnOverflow;
    float contagionAcc;

    float projX[SIM_MAX_PROJECTILES];
    float projY[SIM_MAX_PROJECTILES];
    float projAimX[SIM_MAX_PROJECTILES];
    float projAimY[SIM_MAX_PROJECTILES];
    int projTarget[SIM_MAX_PROJECTILES];
    unsigned char projKind[SIM_MAX_PROJECTILES];
    unsigned char projLevel[SIM_MAX_PROJECTILES];
    unsigned char projRemoved[SIM_MAX_PROJECTILES];
    unsigned int projCount;

    float muX[SIM_MAX_MELEE_UNITS];
    float muY[SIM_MAX_MELEE_UNITS];
    float muHP[SIM_MAX_MELEE_UNITS];
    int muTarget[SIM_MAX_MELEE_UNITS];
    short muRespawnTicks[SIM_MAX_MELEE_UNITS];
    short muSwingTicks[SIM_MAX_MELEE_UNITS];
    short muEnemySwingTicks[SIM_MAX_MELEE_UNITS];
    unsigned char muState[SIM_MAX_MELEE_UNITS];
    unsigned int nextSpawnID;
    unsigned int buildsDone;
    int nextCheckTick;
    int tick;
    unsigned int initialized;
    unsigned int outcome;
    unsigned int _pad0;
} SimStateGPU;

typedef struct {
    unsigned int outcome;
    int livesRemaining;
    int gold;
    unsigned int killed;
    unsigned int routed;
    unsigned int captured;
    unsigned int leaked;
    unsigned int goldEarned;
    float seconds;
    unsigned int spawnOverflow;
    unsigned int projOverflow;
    unsigned int militiaKills;
    unsigned int militiaDeaths;
    unsigned int militiaRespawns;
    unsigned int projImpacts;
    unsigned int projFizzles;
    float waveMaxProgress[SIM_MAX_WAVES];
    unsigned int leaksByWave[SIM_MAX_WAVES];
} SimResultGPU;

#endif
