# Genetic balance search by meta-upgrade spending

Build the macOS `Simulator` scheme with the normal Xcode Release configuration.
Battles use the game's `BattleEngine` through `GeneticCommander` and
`GameSimulation`. The search chooses player inputs; it contains no combat model.

The current balance study's starting-money range is 590–770 coins. The separate
`--money-study` sweep defaults to `590:770:5`; a genetic study defaults to the
first-pass budget of 660 coins and takes one fixed `--starting-money` value, so
compare budgets using separate genetic runs. These are experiment settings;
campaign entry still uses the authored `level_info.starting_money` value.

Tower build, tier and ability prices are the fixed baseline for bounty studies.
`--bounty-fraction 0.75` tests 75% of the current authored kill-bounty multiplier.
The authored multiplier is now 0.30: a fraction of 1 uses 30% of the original
bounty, while 0.75 and 0.5 use 22.5% and 15% of the original bounty. Label
comparisons with both the scenario fraction and effective multiplier; retain
each run's content snapshot so historical results keep their original meaning.
`BountyExperimentDAO` copies the authored SQL schema/content into disposable
in-memory SQLite, changes only `combat_rules.kill_bounty_multiplier`, and reloads
the battle through the existing DAOs. Reward amounts and rounding are still
computed by BattleEngine. The saved game database and tower content are not
edited. Study records still go into the authoritative database's result tables.

For a controlled bounty comparison, use `--fixed-meta --star-range 40:40:1`
when the database currently has 40 stars selected. This locks the exact upgrade
IDs, including price discounts, rather than evolving different same-cost
selections. `--seed-strategy /path/to/strategy.json` accepts explicit candidate
DNA and is repeatable. Seeds are validated against the requested spending groups
and fixed selection. Four supplied strategies with `--population 4 --generations
1 --finalists 4` form a frozen comparison panel; reuse their combat seeds across
bounty settings. Re-enable generations to test whether players can adapt their
purchases and reinforcement choices. Neither comparison proves impossibility.

```sh
Simulator --genetic-study Charleston --starting-money 660 \
  --star-range 0:40:10 --population 8 --generations 20 --training-seeds 3 \
  --finalists 2 --validation-seeds 16 --max-evaluations 6000 \
  --genetic-hours 1 --seed 1776 --report-dir /private/tmp/charleston-meta-search
```

## Stars and candidate DNA

The DAO supplies the earned-star ledger and the complete meta-upgrade catalog.
The candidate contains both its explicit `metaUpgrades` IDs and its ordered
build, tier-upgrade, and ability-purchase decisions. Decisions retain earliest
wave/time and whether to reserve money when the engine reports `needGold`.
Meta-upgrade selections are fixed for that candidate's entire battle.

Heroes are disabled. Reinforcements are enabled in every candidate. The
`reinforcements` gene specifies which visible enemy to prioritize (nearest an
exit, or nearest a preferred map point) and how long to hold a ready charge.
Deployment is at that enemy's position, through the same toggle/placement
handlers as the phone. The commander reads the engine's readiness flag; it does
not calculate cooldowns, reserve capacity, lifetime, troop counts or stats.
It waits when no enemy is present. A tower saving decision never blocks this
independent player action. Alarm Riders applies through the shared meta engine.

Early wave calls are enabled in the GA search. The explicit `earlyWaves` gene
contains per-wave player choices: leave the automatic start alone, wait after
the call button appears, wait for a displayed countdown threshold, or wait for
at most a chosen number of visible enemies. Unlisted waves are deliberately
left automatic. The first wave is started after opening purchases as before.
Crossover combines per-wave choices and mutation changes them. These genes are
part of candidate identity and replay, alongside tower and reinforcement plans.

The input driver reads `canStartWave` and the engine's displayed countdown; it
does not reproduce the reveal clock, automatic deadline, overlap rules or bonus
formula. `BattleEngine.perform(.startWave)` follows the same shared entrance
selection/confirmation helper and `startNextWave()` handler as the HUD. The
engine records successful manual calls with their actual time, wave, displayed
countdown, awarded early-call bonus and money before/after the call. Money after
the call may also include normal wave-start supply income; the bonus is recorded
separately by the engine. The first call's bonus is zero.

Use `--no-early-wave-calls` for a matched control. It disables this search
dimension and rejects supplied early-calling seeds. Older strategy JSON must
be explicitly imported with `"earlyWaves":{"decisions":[]}` to preserve its
previous automatic timing; missing genes are not silently invented. Keep the
original old record and executable. To adapt a known winner, seed both its
unchanged version and variants with explicit early-call choices.

`starsUsed` is the shared loadout's actual spent-star count, including all
prerequisites. It is not the player's earned stars, available balance, or number
of selected upgrades. Two equally priced selections are distinct genes and
cache entries. The initial tower-placement policy sees its candidate's selected
effects, and every evaluation applies that selection to shared battle content.

`--star-range min:max:step` requests exact spending amounts, including zero.
Omitting it requests every integer from zero through the database's earned-star
budget (currently 42). Earned stars stay pinned to the DAO snapshot; the player
may deliberately leave any portion unspent. Spending above that budget is an
error. A requested total with no legal allocation is reported as
`no_legal_loadout`, rather than rounded to another total.

`GeneticMetaSearch` enumerates the small meta-selection space by calling the
same `MetaUpgradeLoadout.purchase` API used by `PlayerMetaUpgradeDAO`. It uses
that API's costs and prerequisite verdicts; it does not implement its own.
Enumerating loadouts does not run battles or claim exhaustive strategy coverage.
Candidate validation and the DAO share `PlayerMetaUpgradeState.selecting`.
Experimental selections never change the active database profile, its earned
ledger, campaign money, or the authored restore preset.

## Populations and full-battle scoring

Each exact star amount has its own population, elites, archive, and finalists.
High-star winners cannot remove low-star candidates. `--population` (default 64)
and `--finalists` (default 8) apply **per reachable star group**. Time and engine-
game budgets apply to the entire study. The evaluation ceiling must accommodate
all initial populations and all requested validation panels. For example,
43 groups at the defaults require 8,256 initial training games plus 22,016
held-out games, before additional generations. Use an explicit smaller range or
population for quick experiments; a short time limit can leave groups incomplete.

Initial plans vary tower choices, placements and purchase schedules alongside
legal meta selections. The database-selected loadout is included in its matching
spending group. Crossover inherits one parent's whole meta selection and mixes
per-slot tower action chains. Mutation can select another legal meta allocation
at the same spend, or change placements, investment depth, timing, ordering and
saving. All new candidates use the same training seed panel. The cache key
includes canonical, sorted meta IDs as well as the complete purchase plan.
Reinforcement priority and hold time also belong to that key. Initial candidates
sample those choices; crossover inherits a parent's reinforcement policy and
mutation can change it. The initial baseline uses a ready charge immediately
against the enemy geometrically nearest any path exit.
Early-wave decisions are also crossed over and mutated; the unchanged
automatic-call baseline is retained among starting choices.

Every evaluation completes the level or reaches the explicit experiment timeout.
Fitness ranks full-level win rate, lives retained in victories, waves reached,
and survival on defeats. There is no greedy per-wave reward, early-wave pruning,
or claim that a failed search proves impossibility. Timeouts remain timeouts.

The first 85% of the wall-time budget is available for search. Training visits
star groups in round-robin order. Every group's finalists are frozen before
held-out results are observed, and validation visits those finalists in seed
rounds. Validation never feeds back into breeding. Global limits can leave
partial panels; completion is reported separately for every spending group.
A full-score training result is not a guarantee of success on other seeds.

This search covers meta selections, tower purchases/timing, reinforcement
target priority/hold time and per-wave early-call choices. It retains the
engine's default rally/obstacle positions and the player's nearest offered
ready-demolition-site policy. It does not search map-command locations or
deploy heroes. Reinforcement priorities select among currently
visible enemies; this first pass does not evolve arbitrary reinforcement sites
or a separate policy for every wave.

## Results and replay

`summary.json` is a compact report with one `starResults` entry per requested
spending amount. It includes earned/spent/unspent stars, legal loadout count,
actual training games and distinct meta selections tested, the best training
candidate, and separate held-out finalists with named upgrades and win/life
statistics. `validationComplete` is per group and global. An evaluated group
can contain only defeats; completion is not a claim that a solution was found.
Each candidate summary includes its reinforcement policy and mean deployment
count, the early-call policy, mean actual early-call count and mean awarded
early-call bonus. Every evaluation records successful deployments and the
engine's manual-call receipts, including in SQLite and replay documents.
Configurations explicitly distinguish heroes disabled, reinforcements enabled
and whether early calls are a permitted search dimension. Permitting calls does
not mean every candidate chooses to use them.

`best-stars-N.json` is the best training replay at exactly N stars. Full candidate
evidence lives in `population.json`, `validation.json`, and SQLite. No single
overall winner is selected across different spending amounts.

The existing SQL-defined `simulator_run`, `money_study`, and
`money_study_result` tables store the study through `MoneyStudyDAO`. For
`genetic-v5`, `placement_plan` identifies a globally unique genome and
`upgrade_policy` is 0 for training or 1 for held-out evaluation. Each result's
`seed_results_json` contains `starsUsed`, the full DNA including `metaUpgrades`,
explicit seeds, actual engine results, and wave-transition economy observations.
`MoneyStudyDAO.geneticSummaryByStars` keeps spend groups and evaluation panels
separate. Older fixed-loadout records are excluded from that aggregation.
v2/v3/v4 star-group records remain readable under their original run IDs. v2 has
no reinforcement commands; v3 has reinforcements but no bounty experiment field.
v4 has no early-call gene or receipt trace. v5 requires both explicitly.

The immutable content snapshot includes the earned-star ledger, all upgrade
costs, prerequisites, IDs, names and effects, plus the original selected loadout
and all other game content. Both content and executable identities are recorded.

```sh
Simulator --genetic-study Charleston \
  --genetic-replay /private/tmp/charleston-meta-search/best-stars-20.json \
  --report-dir /private/tmp/charleston-meta-replay
```

Replay checks the candidate's exact spend, content/executable identities and the
complete engine result, wave-economy trace, reinforcement deployment trace and
manual wave-call receipts. A mismatch fails. v5 records the bounty fraction and reconstructs its
disposable database scenario before checking the content identity. It requires
explicit meta, reinforcement and early-wave genes. Keep the original
executable with historical replay documents.
Historical results are not rewritten or extrapolated to other star budgets.

The separate `--money-study` sweep uses the same immediate reinforcement policy
for all tower plans and budgets. Its configuration records that policy, replay
reports include deployment traces, and completion/calibration reports include
total deployment counts. Its campaigns and player profile remain unchanged.

Run `BountyExperimentTests`, `GeneticEarlyWaveTests`, `GeneticReinforcementTests`, `GeneticMetaSearchTests`, `GeneticStrategyTests`, `SimulatorBoundaryTests`,
`PlayerMetaUpgradeDAOTests`, and shared-engine regressions after changes. The
meta search, reinforcement and early-wave input drivers are explicitly included in the
simulator ownership audit.
