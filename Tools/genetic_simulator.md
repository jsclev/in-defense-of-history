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
Omitting it focuses on the database's earned-star budget (currently 42).
Use `--star-range 0:42:1` explicitly for a broad survey. Earned stars stay pinned to the DAO snapshot; the player
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

## Meta-selection subpopulations and full-battle scoring

`genetic-v6` searches meta selections explicitly. Within each exact stars-used
group, `--meta-selections` (default 8) reserves equally sized subpopulations for
different legal selections. `--population` (default 64) is the total cap per
stars-used group. Divide it by the number of active selections and round down;
the remainder is unused so each selection receives the same plan capacity.
The selection count is limited by the legal combinations and
`--meta-min-candidates` (default 4). Legality and prices continue to come from
shared player-state APIs and the DAO catalog.

Initial subpopulations receive matching plan-family indices and reinforcement /
early-call random streams. Placement heuristics read each selection's real
effects. Breeding and battle-plan mutation stay within a selection. A weak
selection cannot be replaced until it has received its full initial plan
capacity and `--meta-adaptation-generations` (default 2). At most one mature weak
selection per stars-used group is replaced in a generation; the best is protected.
Most introductions use the closest untested legal selection to the champion,
measured by changed upgrade IDs. Every fourth generation explores an arbitrary
untested selection. New subpopulations receive the champion's battle plan with
the new selection, plus fresh paired plan families. Retired selections retain
their evidence and champions and can still reach validation.

The standalone meta mutation operator also favors nearby legal selections at
the same stars used, with occasional broader mutations. Prerequisites and costs
can require exchanging several IDs. The search does not implement purchasing
rules to repair an invalid selection.

`--finalists` (default 8) caps distinct meta selections per stars-used group.
One frozen champion represents each qualified selection, with at least the
requested minimum number of distinct training candidates. A group with one
legal selection needs only one finalist. Underexplored selections remain in the
report but cannot qualify. Too few qualified finalists makes validation incomplete.
The explicit `--fixed-meta` control retains its earlier behavior: several frozen
battle-plan finalists may share the one fixed selection. The distinct-selection
rule applies to meta searches and controlled upgrade exchanges.

### Controlled upgrade exchanges

`--meta-exchange-from /path/to/candidate-strategy.json` takes the same raw player
DNA format as `--seed-strategy`. To use a saved replay, extract its `strategy`
object into a separate JSON file; keep the original replay and executable.
The source determines the exact stars used unless an identical explicit
`--star-range` is supplied. The selection set stays fixed: the original plus the
closest legal alternatives, up to `--meta-selections`. This mode rejects
`--fixed-meta` and additional supplied seeds.

Every selection receives the source battle plan with only its meta IDs changed,
plus the same initial plan families. Each then adapts separately under the same
population, generation, and training-seed settings. Set `--finalists` high enough
to cover every selection. Final validation uses matching, previously unseen seeds
and never feeds back into training. `metaExchangeComparisons` reports named
upgrades removed/added, both training candidate counts, whether those counts
match, paired wins exclusive to each candidate, and the mean change in lives
remaining. Partial comparisons use only common validation seeds. Unequal search
effort or an incomplete panel is explicit. These observations compare adapted
full battle plans, not universal causal effects of individual upgrades.

```sh
Simulator --genetic-study Charleston --starting-money 660 \
  --meta-exchange-from /private/tmp/candidate-strategy.json \
  --population 64 --meta-selections 8 --generations 100 \
  --finalists 8 --validation-seeds 64 --max-evaluations 10000 \
  --genetic-hours 8 --report-dir /private/tmp/charleston-meta-exchanges
```

### Search limits

Star totals have separate populations, selection archives and finalists. Time
and engine-game limits apply to the entire study. Budget validation conservatively
requires room for every requested initial population and final panel. For 43
star groups, the defaults require a ceiling of at least 30,272 games. The actual
validation reservation is smaller when a group has fewer legal selections.
Use a focused star total for depth; short limits can leave groups incomplete.

The database-selected loadout is included when a seat remains in its matching
stars-used group. Supplied selections take priority. All training candidates use
the same training seeds. The cache key includes canonical meta IDs, the complete
purchase plan, reinforcement policy and early-wave choices. Reusing a cached
candidate does not count as evaluating another distinct plan for that selection.

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

`results.md` is a readable table using **Stars used**, **Population candidate ID**,
and **Wins**, with named meta selections. `summary.json` has one `starResults` entry per requested
spending amount. It includes earned/spent/unspent stars, legal loadout count,
actual training games and distinct meta selections tested, the best training
candidate, and separate held-out finalists with named upgrades and win/life
statistics. `validationComplete` is per group and global. An evaluated group
can contain only defeats; completion is not a claim that a solution was found.
`metaSelectionResults` records actual search effort, qualification, introduction
generation, active/retired state, champion and validation for every introduced
selection. `searchedMetaLoadouts` counts selections actually evaluated. Planned
tower mixes describe player intent, not purchases confirmed during battle.
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
`genetic-v5` and `genetic-v6`, `placement_plan` identifies a globally unique population candidate and
`upgrade_policy` is 0 for training or 1 for held-out evaluation. Each result's
`seed_results_json` contains `starsUsed`, the full DNA including `metaUpgrades`,
explicit seeds, actual engine results, and wave-transition economy observations.
`MoneyStudyDAO.geneticSummaryByStars` keeps spend groups and evaluation panels
separate. Older fixed-loadout records are excluded from that aggregation.
V6 persists validation panels and database progress after every complete seed
round, and at finalization for any partial round. A checkpoint can only grow a
held-out panel with unchanged candidate DNA; it cannot overwrite training data.
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

Run `BountyExperimentTests`, `GeneticEarlyWaveTests`, `GeneticReinforcementTests`, `GeneticMetaSearchTests`, `GeneticMetaPopulationTests`, `GeneticStrategyTests`, `SimulatorBoundaryTests`,
`PlayerMetaUpgradeDAOTests`, and shared-engine regressions after changes. The
meta search, reinforcement and early-wave input drivers are explicitly included in the
simulator ownership audit.

## Watch a saved population candidate on macOS

The game target also supports **My Mac (Mac Catalyst)**. Its desktop window is
constrained to the landscape proportions of an 11-inch iPad Pro (4th generation,
1194 × 834 logical points). It uses the existing game views and `LevelRunner`.
Each desktop launch loads the authoritative checkout database into disposable
in-memory content through DAOs. Level recordings go to the checkout database;
player settings and progression remain disposable.
The desktop development app requires that checkout; it creates no second
persistent database. Device builds retain their bundled-database refresh.

Build with the normal Xcode process:

```sh
xcodebuild -project InDefenseOfHistory.xcodeproj -scheme 'Liberty Line' \
  -configuration Release -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath /private/tmp/td-desktop-replay build
```

Launch the movie player with the UUID of an actual recorded level attempt.
Each genetic evaluation now includes `runID`; the same ID is stored in `level_run`.
Player attempts, editor playtests, and simulator evaluations each receive a fresh UUID.
The `simulator_run` ID still identifies the surrounding study, not a level attempt.

```sh
sqlite3 Db/in_defense_of_history.sqlite \
  "SELECT id,source,play_speed_factor,status,last_tick FROM level_run ORDER BY started_at DESC LIMIT 10;"
open -n '/private/tmp/td-desktop-replay/Build/Products/Release-maccatalyst/Liberty Line.app' \
  --args --replay-run <level-run-uuid> --play-speed 1.0 --movie-output /private/tmp/level-run.mp4
```

`LevelReplayer` queries `level_action` in sequence order. Recorded inputs include
rejected commands, menu selections, pause/resume and speed changes; combat events
and compact virtual-time tracks store the actual placements, poses, health,
morale, projectiles, charge preparation, impacts and damage metrics. The run's
setup stores the DAO-loaded level and content values used for that attempt,
including simulator experiment settings. Later balancing edits do not rewrite history.

The movie renderer consumes this data without constructing a battle engine,
running a genetic commander, rolling RNG or writing player progression. Multiple
inputs at one tick are coalesced into that tick's final presentation. Frames use
the recorded tick rate and configured play speed, independent of encoding speed. Missing,
truncated or corrupt recordings fail explicitly. Older strategy JSON can still be
verified by the CLI, but is not a recorded movie source; it must be run once to
produce a UUID-backed recording.

Movie output must be a new file outside the repository. `--movie-output` writes
a silent 2388 × 1668 H.264 MP4 and a sibling JSON report with the UUID, sequence
and frame counts. Without that option, the native app plays the stored run.
Database recording failures stop execution rather than silently dropping actions.
Every attempt records its full timeline without storing a full snapshot per tick.
`timeline-v1` presentation blocks pack ordered events and field tracks: constant
values are stored once, and constant-velocity runs store a start value, virtual
tick range and increment. A changed value or velocity starts another segment.
Incremental floating-point reconstruction is lossless; no tolerance is used to
discard small changes. Repeated inputs at one virtual tick retain all events but
only the final visible state. Bends, hits, stops, spawns and removals remain exact.
Blocks flush at a complete virtual tick after reaching 256 ticks, 16,384 value
segments or 512 pending events. One tick's state and events stay together; these
are packing limits, not a lower sampling rate. Playback expands
one block at a time and never runs combat. Existing full-frame recordings remain
readable. Storage scales with the recorded timeline, not its wall-clock speed.

The recorder visits Codable state directly, reuses field paths, and serializes
unchanged tower tuning and path geometry only once per block. It avoids encoding
and reparsing a full property list on every virtual tick. Temporary Foundation
serialization/compression objects stay within scoped autorelease pools.
`LevelRunDAO` appends batches of complete blocks in short transactions: flush at
four blocks or 512 KiB of encoded payload, and always flush on finalization.
The byte threshold may be exceeded by the last complete block. This bounds pending
writes without holding an entire playthrough or a long database transaction.
Append reads only the write cursor, without repeatedly loading setup blobs.
Simulator entry points and recording/replay models contain no SQL or SQLite calls:
content reads, experiment copies, study results and level recordings all use DAOs.
`Db` owns the underlying connection lifecycle. The simulator boundary tests enforce
this separation. SQL access in disposable mutation/regression fixtures is test-only.

Device database refresh remains unchanged: launching the device app replaces its
database with the bundle, including clearing prior local recordings. Export or
inspect a device recording before the next launch. Desktop records are written to
the checkout database, while desktop player settings remain in a disposable content
copy. Close all database connections before running `Db/create_db.sh`.

### Play speed

`Db/DML/play_speed.sql` authors `play_speed.factor` in game seconds per wall-clock
second. `PlaySpeedDAO` loads the required player, simulator and editor rows into
`BattleContent`; the selected factor is passed into each new level. The player
and editor start at `1.0`. The simulator starts at `1000000000.0`, the supported
maximum, so it normally runs at the machine's throughput limit. This is a target
rate, not a guarantee that hardware can achieve a billion times real time.
Edit the SQL and regenerate with `Db/create_db.sh` to change the authored rates.
Missing, NULL, nonnumeric, nonfinite or out-of-range values fail explicitly.
Supported factors range from `0.01` to `1000000000.0`.

`setPlaySpeed(try PlaySpeed(0.5))` changes a running level to half speed;
`PlaySpeed(2)` changes it to double speed. The HUD shortcut and editor speed picker
use this same setter. Headless production loops wait on the same clock deadlines;
at the maximum rate they do not throttle. All gameplay still executes complete
fixed 1/30-second ticks with identical commands, randomness and combat results.
Pausing does not advance game time, and resume discards paused wall time.
Changing speed reanchors wall-clock deadlines at the current completed tick,
preserving fractional progress without carrying accumulated clock lag forward.
Slowing a CPU-bound simulator therefore takes effect immediately.

Each run stores its initial factor in `level_run.play_speed_factor` and its setup.
Rate changes are recorded as inputs and changes in the presentation speed track.
Replays normally follow those recorded factors. `--play-speed 1.0` overrides them
with real time, `--play-speed 2.0` uses double speed, and `--play-speed 0.5` uses
slow motion. Overrides never change the original run or its events. They also
apply to MP4 duration: exports sample the recorded timeline at 30 fps, consuming
every event while omitting intermediate poses at high rates or holding them at
low rates. Encoding backpressure does not alter the requested movie speed.
Recording format 2 requires speed metadata; older recordings are rejected rather
than silently assigning a made-up factor.

### GA execution costs

Candidate DNA remains the same ordered, portable purchase plan. Execution compiles
it into per-slot chains and a small priority queue containing only each slot's next
unfinished order. A successful purchase exposes the next order at its original
global priority; time/wave gates and saving barriers retain their existing behavior.
Crossover indexes parent chains once instead of rescanning each parent per slot.

Resolved star-upgrade studies are cached by upgrade set within one immutable
DAO-loaded content snapshot. Reusing the same selection avoids repeated content
assembly and validation; new selections still use the shared player-state rules.
New database loads create new snapshots, so later content edits cannot inherit a
stale cache. Study-result writes skip constructing compact fallback JSON when exact
candidate evidence is already supplied.

## Parallel evaluation and throughput

`--workers N` (1–32, default 1) runs complete GA battles in independent native
processes. Each process uses the same executable, its own main actor, the shared
`GeneticCommander`/`GameSimulation`/`BattleEngine`, and the authoritative database
through DAOs. Worker startup verifies the coordinator's authored-content and
executable hashes; either changing is an error. Workers keep their validated content snapshot and
meta-loadout cache for the study. No GPU combat model is used.

The coordinator freezes parent pools, breeds in deterministic order, and buffers
at most N candidate panels. It assigns candidate IDs and scores results in that
same order, regardless of worker completion order. Pending duplicate DNA shares
one evaluation. Training and held-out seeds remain separate. Seed rounds use
bounded parallel batches; every battle still ends in victory, defeat, or an
explicit timeout. The wall-time limit stops admitting new batches, so an already
admitted batch can finish after the deadline. Time-limited searches can naturally
explore different numbers of candidates at different worker counts; fixed-work
comparisons should match DNA and outcomes exactly, except recording UUIDs.

Each worker records every playthrough in the existing SQL tables using bounded
recording buffers and short transactions. Connections wait up to 30 seconds for
a writer lock; lock failures remain errors. Worker failures fail the study and
are not automatically retried. Completed battle recordings remain available,
including when another worker fails before its candidate panel is complete.
Workers receive EOF on normal shutdown; no process-killing loop is used.

Recordings reuse bound field tracks instead of hashing each field path on every
tick. Repeated enemy combat-rule documents are encoded only when their values
change. Replay retains the exact original values and every virtual tick.

Calibrate worker counts on the actual Mac: extra workers may hit storage or
memory-bandwidth limits before all CPU cores help. Include database growth when
budgeting an overnight run; faster evaluation also writes recordings faster.
Reserve space for held-out validation and other work. Do not extrapolate brief
timeout fixtures as full-level throughput. Longer or winning plans can cost more
than the initial population's early defeats.
