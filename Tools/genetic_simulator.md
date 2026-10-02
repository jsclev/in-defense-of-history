# Genetic balance search by meta-upgrade spending

For auditing single-family exploits and comparing damage/wave variants, use the
separate [balance analyzer](balance_analyzer.md). It fixes authored starting
money, disables heroes, maximizes ranged progression, and runs ranged-only
searches alongside unrestricted controls.

Start a normal run with `~/bin/LibertyLineSimulator --level 15 --workers 8` (replace `15` with the level number).
`--workers N` is required for GA searches; choose an integer from 1 to 32.
See the [CLI README](../README.md) for installation or the
[advanced reference](simulator_cli_reference.md) for optional controls and result inspection.
Build the macOS `Simulator` scheme with the normal Xcode Release configuration.
Battles use the game's `BattleEngine` through `GeneticCommander` and
`GameSimulation`. The search chooses player inputs; it contains no combat model.

The installer builds a starter database from authored SQL and embeds its maps
and schema in `liberty-line-simulator-<build-name>.sqlite` beside the executable.
New studies use that build-derived input by default; `--content-database` overrides
it. Each study creates a separate run database whose name includes the build.
Normal runs do not read the development checkout.

Enemy behavior, including Queen's Rangers' concealment, runs inside the shared
battle engine even when playback recording is disabled. Hidden Rangers keep
moving, cannot take damage or be blocked by troops, and living nearby heroes
reveal them under the same DAO-authored rules as the game. These consequences
therefore enter the GA's original battle results and fitness. Adding a unit or
changing its behavior requires rebuilding the CLI and starter before a new
study; existing executables and captured run databases do not acquire later
source or content edits. Historical results retain their original meaning.

Training and held-out validation save compact evaluation evidence without
playback recording. Once those panels and the retained solution catalog are
saved, the coordinator reruns one original seed per retained plan to create its
demonstration. It prefers a winning seed using the existing fitness order, with
a stable seed tie-break. This phase runs after evaluation; its results never
replace fitness evidence or change rankings. `genetic_solution_recording`
contains queryable candidate/seed/recording links, actual rerun results and a
`matches_evaluation` flag. Differences are allowed and reported. The configured
finalist count is unchanged. For each star group, recorded plans come from the
saved validation panel, or the saved training panel when no validation sample
was completed. Existing historical playback readers remain available.

A genetic study defaults to the chosen level's DAO-loaded
`level_info.starting_money`. Use `--starting-money` only for an explicit fixed-budget
experiment. The separate `--money-study` sweep defaults to `590:770:5`;
those budgets are experiment settings. Campaign entry continues to use authored
starting money.

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
edited. Study records go into the invocation database's result tables.

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
Simulator --genetic-study Charleston --workers 8 --starting-money 660 \
  --star-range 0:40:10 --population 8 --generations 20 --training-seeds 3 \
  --finalists 2 --validation-seeds 16 --max-evaluations 6000 \
  --genetic-hours 1 --seed 1776 --report-dir /private/tmp/charleston-meta-search
```

## Stars and candidate DNA

For composition counterexample searches, add `--max-towers areaOfEffect:1` to
search defenses with zero or one artillery tower, or `--majority-tower ranged`
to search defenses with more than half their planned towers in the ranged
family. `--max-towers <kind:n>` can be repeated for different families. Legal
family identifiers are `ranged`, `melee`, `areaOfEffect`, `special`, and `supply`.
These are search constraints, not campaign construction limits or fitness bonuses.
Explicit seeds and meta-exchange sources must satisfy the requested constraints;
mutations and crossover offspring outside them are excluded before evaluation.

Inspect `builtTowersBySeed` and `winsMeetingTowerLimits` in candidate summaries.
They use actual purchases at the end of each battle: a planned majority may
never be purchased. Older evaluations omit `builtTowersByKind` and cannot verify
actual composition. Compare restricted searches with an unrestricted search
using identical content, heroes, difficulty, money, stars, and seed panels.
Validate frozen finalists on unseen seeds. A restricted win is a counterexample;
failure to find one within a finite search is not proof that none exists.

The DAO supplies the earned-star ledger and the complete meta-upgrade catalog.
Each strategy stores an immutable `MetaUpgradeProgression` containing packed
upgrade bits and their DAO-derived cost. A candidate's `starsUsed` is derived
from that progression; candidate construction never accepts an independent
star count. The strategy also stores its ordered build, tier-upgrade, and
ability-purchase decisions. Decisions retain earliest
wave/time and whether to reserve money when the engine reports `needGold`.
Meta-upgrade selections are fixed for that candidate's entire battle.

Configure `MetaUpgradesFactory(catalog:)` once using `MetaUpgradeDAO.get()`, then
call `factory.make(stars: n)` to produce a legal chosen progression spending
exactly `n` stars. The seeded overload accepts an RNG and optional exclusions
for deterministic, distinct population choices. Zero returns the empty selection;
negative or unreachable totals fail. The factory does not need a player profile.
Campaign entry separately checks the earned ledger through the shared player API.

Worker messages and saved strategies encode the progression as canonical named
`metaUpgrades` IDs for portability. Decode with
`MetaUpgradesFactory.decoder(catalog:)`: missing IDs, duplicate IDs, broken
prerequisites, and candidate `starsUsed` mismatches fail rather than reconstructing
a loadout from a star count.

Heroes are enabled in every GA evaluation, including held-out validation and
replay. The lineup is fixed for a run: by default it comes from `HeroDAO`'s player
selection. `--heroes <hero-uuid[,hero-uuid]>` targets another one- or two-hero
lineup through the DAO in the experiment's in-memory database, without changing
the player's saved selection. Run each desired lineup separately to build
adviser coverage. Rankings determine primary/secondary roles and the level's
authored hero capacity determines who actually deploys.

Heroes execute the shared engine's combat and their existing autonomous AI;
database `ai_enabled` settings are respected by default. `--hero-ai on` or
`--hero-ai off` explicitly changes only the chosen heroes in the experiment's
in-memory database. Workers and live solution playback restore those recorded
AI settings without changing the player's settings. The GA does not evolve hero
movement commands or select different heroes while breeding tower plans.
When a hero's AI is off, that hero receives no manual movement commands from
the GA; it still fights according to the shared engine at its authored position.
Configuration, worker handshakes, replays and shipping solutions record chosen
IDs, deployed IDs/roles/spawns, and AI settings. Content hashes also include hero
combat stats and AI tuning, so changed hero balance invalidates old advice.

Reinforcements are enabled in every candidate. The
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

`genetic-v13` searches factory-validated meta progressions explicitly with a fixed hero lineup. Within each exact stars-used
group, `--meta-selections` (default 8) reserves equally sized subpopulations for
different legal selections. `--population` (default 64) is the total cap per
stars-used group. Divide it by the number of active selections and round down;
the remainder is unused so each selection receives the same plan capacity.
The selection count is limited by the legal combinations and
`--meta-min-candidates` (default 4). Legality and prices continue to come from
shared player-state APIs and the DAO catalog.

Initial subpopulations use independently drawn plan dimensions and random streams.
Only controlled meta exchanges deliberately pair their plan inputs. A weak
selection gets its full initial capacity and `--meta-adaptation-generations`
(default 12) before replacement. At most one mature weak selection per stars-used
group is replaced per generation; the best is protected. New legal selections
come from factory crossover, nearest untested mutation or an arbitrary untested
selection every fourth generation, always at the exact authored star cost.
New groups receive a plan from an archived behavior champion (including retired
groups), plus independent fresh plans. Retirement never erases original results
or finalist eligibility.

The standalone meta mutation operator chooses a different nearest legal selection
at the same stars used, or retains the original if it is the sole legal choice. Prerequisites and costs
can require exchanging several IDs. The search does not implement purchasing
rules to repair an invalid selection.

`--finalists` (default 8) caps frozen battle plans per stars-used group.
Selections must have the requested minimum number of distinct training candidates
before their plans can qualify. Modern creative profiles reserve one third of
the panel for different successful upgrade selections, then emphasize opening
and playstyle variety. Several plans may share an upgrade selection, including
in ordinary meta searches. Underexplored selections remain in the report but
cannot qualify. Legacy candidates without playstyle profiles retain the older
one-champion-per-selection behavior unless `--fixed-meta` is specified.

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
Simulator --genetic-study Charleston --workers 8 --starting-money 660 \
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

When explicitly supplied, the first 85% of the wall-time guardrail is available
for search. By default there is no deadline. Training visits
star groups in round-robin order. Every group's finalists are frozen before
held-out results are observed, and validation visits those finalists in seed
rounds. Validation never feeds back into breeding. Global limits can leave
partial panels; completion is reported separately for every spending group.
A full-score training result is not a guarantee of success on other seeds.

This search covers meta selections, tower purchases/timing, reinforcement
target priority/hold time and per-wave early-call choices. It retains the
candidate's evolved rally/obstacle and repeated demolition route targets.
It does not evolve
manual hero movement. Reinforcement priorities select among currently
visible enemies; this first pass does not evolve arbitrary reinforcement sites
or a separate policy for every wave.

## Results and replay

Every GA run publishes its best distinct population plans per exact star spend
to `genetic_solution` through `db.geneticSolutionDao`. `--finalists` is also the
per-run, per-panel, per-star retention limit. Training archives (including retired
selections) are published before validation. Held-out candidates are published
after validation, including explicitly incomplete panels when time runs out.
Each invocation writes its own SQLite snapshot beside `LibertyLineSimulator`;
previous invocations remain in their separate databases. These are the best plans found, not a proof of global optimality.

The shared `GeneticSolutionDAO.best(context:starsUsed:study:)` API returns typed
strategies and complete evaluation evidence, ordered by the GA's fitness and
deduplicated by strategy. Its defaults require a completed held-out panel and at
least one victory. Training, incomplete panels and nonwinning candidates are
available only via explicit query options. An empty result means this scenario
still needs a solution. Each record includes source run/candidate/generation,
executable hash, requested sample count and the exact hero loadout. Format-2
solutions match chosen hero IDs, deployments and AI settings as well as battle
content. Archived format-1 no-hero rows remain exportable but are excluded from
adviser lookups; they are never relabeled as hero-enabled results.
It does not depend on simulator history or external report files.

Create the lookup `GeneticSolutionContext` from the DAO-loaded study, money,
bounty fraction and game-time limit. Matching includes level, difficulty and a
content hash of maps, waves, prices and tuning. Player star earnings/selections
are excluded from this hash; the candidate retains its exact upgrade IDs and
star cost. Campaign advisers must use the level's authored starting money and
the authored bounty (fraction 1). Experimental budgets/bounties remain isolated.
Changed content needs new GA runs; executable hashes retain engine provenance.

The level preview's play-screen button opens the best compatible, completed
validation winner for its selected difficulty, authored starting money and
earned-star budget. It restores that solution's heroes, AI modes, upgrade
selection and a winning combat seed in a disposable content context. The live
demonstration runs the shared engine, offers pause and 0.5x/1x/2x/4x/8x controls,
and checks its complete outcome against the saved evaluation. It awards no
campaign progress and does not change player selections. Settings → Watch GA
solutions controls the button; its SQLite seed is on. Normal launch refreshes
restore the authored settings as elsewhere in the game.

Studies do not export the shipping GA catalog or recordings. Generated shipping
exports live outside Git in `../in-defense-of-history-data/GeneticSolutions`,
with `genetic_solutions.sql` and `GeneticRecordings/*.sql` imported by
`Db/create_db.sh`. Use `--genetic-seeds /absolute/path/to/GeneticSolutions` for a
different external directory. The coordinator and all
workers persist only in the invocation database. The explicit offline
`--import-ga-solutions` command considers all complete training winners using
`GeneticSolutionDiversitySelector`. It keeps one strongest reliable winner and
chooses alternatives by maximum minimum playstyle difference against every
selected plan. Opening composition, actual investment, participating mechanics,
development, spatial coverage, workload and recovery margin remain distinct
metrics. Original fitness is preserved and breaks novelty ties. The old position
and five-build rules are preferences rather than selection vetoes. It checks current content, reproduces original evaluations, and runs
the source configuration's full held-out panel before exporting a selected-level
SQL seed. See the CLI reference for inputs and merging with other levels. It
preserves the original run and saves compact results in a separate database;
it never runs automatically or consumes an active study's evaluation budget.
Publication fails if fewer than three qualify, including if the held-out candidates
fail the final data-only diversity check. Initial builds are successful purchases
before wave one, captured during the original evaluation. The first five successful
later builds are saved in order. Missing legacy placement data is unknown; time-zero
orders and intended future branches must never be substituted. No replay or battle
execution is involved in comparison. The separate
`--ship-ga-solutions` command searches for a complete compatible set among held-out
winners, including another reliable baseline when the global champion blocks
coverage, before creating only their three demonstration recordings.

GA studies use relational `ga_*` tables; `--report-dir` optionally exports JSON
reports. Those exports are not stored as duplicate JSON documents in SQLite. Authored map bytes
live in `simulator_map`, so workers never reread live checkout maps.
`summary.json` has one `starResults` entry per requested
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
Configurations explicitly distinguish heroes enabled, reinforcements enabled
and whether early calls are a permitted search dimension. Permitting calls does
not mean every candidate chooses to use them.

`best-stars-N.json` is the best training replay at exactly N stars. Full candidate
evidence lives in `ga_candidate`, `ga_panel`, `ga_evaluation` and their child
tables. `population.json` and `validation.json` are optional external exports. No single
overall winner is selected across different spending amounts.
Hero-enabled replays use `genetic-replay-v6` and restore their recorded lineup
through the experiment DAO. Keep the original executable for older no-hero
replays; they must not be evaluated as hero-enabled runs.

`GeneticStudyDAO` saves configuration, seed panels, candidates, progress and
population membership in SQL-defined `ga_*` tables. Strategies have ordered
build actions, selected meta-upgrade rows, reinforcement fields and per-wave
policies. Each original evaluation has explicit outcome columns and related
rows for enemy fates, wave progress/leaks/economy, reinforcements, calls and
actual built towers. `ga_candidate_fitness` exposes the existing fitness order.
`genetic_solution` retains candidate/panel keys without duplicating the evidence.

Validation checkpoints append new samples only after verifying all earlier DNA
and evidence. Original results remain separate from post-selection demonstration
results. Checkpoint membership is saved as candidate IDs, not repeated genomes.
The authored DDL is in `Db/DDL/create_genetic_solutions.sql` and
`Db/DDL/create_genetic_studies.sql`; runtime code never creates tables.

See [GA SQL queries](../Db/Queries/GA/README.md) for top solutions, candidate
actions, per-seed evidence, paired comparisons, progress and retention.
`Tools/ga_relational.py old.sqlite new.sqlite` converts completed legacy v8
studies to a new file, verifies exact candidate/evaluation and playback round
trips, and preserves the original. Non-GA money/balance studies keep their
separate formats; they are not used to store new GA solutions.

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
Every simulator attempt records timestamped input/combat events and resolved
simulation-state changes in `battle-events-v5` event batches. Compressed batches
are stored directly in `level_action.event_data` BLOBs, with only `{}` in
`payload_json`, eliminating base64 expansion and JSON wrapping. Tower-tuning
captures and encoded metadata are reused until tower configuration or loaded
tuning changes. Position, health and morale state tracks use 32-bit Float;
projectile headings/distances and troop target positions use the same compact
state representation. Observations round once before segment construction.
An increment is retained only when it reproduces every rounded tick exactly,
so playback does not accumulate additional rounding drift. Combat arithmetic,
candidate scores, seeds, action payloads and clock tracks are unchanged. Numeric
tracks use bulk binary writes, and action strings
use length-delimited binary storage. Each block remains self-contained. The GA does not
construct `LevelReplayFrame`, select animation sprites, or encode presentation
tracks. Entity definitions are separated from observed numeric changes; exact
movement increments are packed without predicting movement or rerunning rules.
Playback constructs visual frames and animations from this data. This recorder
is used for retained-solution reruns and explicitly requested recordings;
routine GA evaluations do not invoke it. Existing JSON-wrapped `battle-events-v1`,
`battle-events-v2`, and `battle-events-v3` recordings remain readable, including
databases without the BLOB column; playback never migrates historical databases.
New recordings require the current schema generated by `Db/create_db.sh` (the
CLI installer creates a matching fresh starter). Versions 2 and 3 store repeated
enemy/projectile definitions once per block and keep tower definitions, aim, volley and charge preparation in
separate catalogs. Numeric segments, changing statistics and entity references
use bounded little-endian binary tracks inside the compressed event payload.
Versions 2–4 retain their original Double precision; version 5 state tracks
retain the Float bit patterns captured for each tick. Missing references,
truncated tracks, invalid lengths and unsupported versions are errors. The
battle ticks and recorded action order are unchanged.

New writes use the original fast, lossless LZ4 compression, with self-contained
setup and tuning. There are no storage-based scheduling caps, replay pruning,
shared-content writes, or incremental compaction in the search path. Search and
validation follow the configured time, generation and evaluation limits.
Shared setup/tuning and tagged LZFSE recordings written by CLI 1.0.205 remain
readable with content-hash verification. A historical movie already pruned by
that version still reports its retention marker; the rollback cannot recreate it.

Fixed battle geometry is cached inside each shared `BattleEngine`: rally-path
selection and distance, shared soldier posts and ordering, and road-aligned
engineer footprints. Cache keys follow actual rally positions, squad membership
and size, tower placement and upgrade state. Path replacements and loaded tower
tuning changes invalidate the affected geometry. Unit movement, damage, deaths,
respawns and tower aim continue normally without rebuilding fixed geometry.
`Path` also prepares immutable segment differences and lengths once, retaining
the original projection arithmetic and nearest-path tie breaking. These caches
are local to a battle and never carry mutable state between GA candidates.

Player/editor recordings retain their full presentation timeline without storing a full snapshot per tick.
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

The player/editor recorder visits Codable state directly, reuses field paths, and serializes
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
The purchase queue wakes on a changed balance, a wave transition, a pending time
gate, or the tick following a successful purchase. Reinforcement and wave inputs
still run every tick. Crossover indexes parent chains once instead of rescanning each parent per slot.

Resolved star-upgrade studies are cached by upgrade set within one immutable
DAO-loaded content snapshot. Reusing the same selection avoids repeated content
assembly and validation; new selections still use the shared player-state rules.
New database loads create new snapshots, so later content edits cannot inherit a
stale cache. Study-result writes skip constructing compact fallback JSON when exact
candidate evidence is already supplied.

## Parallel evaluation and throughput

The default GA has no wall-clock, generation, or battle ceiling. Completion
requires **all** of these conditions in **every** requested star-spend group:

- At least 1,000,000 actual training battles, excluding cached duplicate DNA.
- At least 250,000 training battles and 1,000 generations since the latest
  fitness improvement, winning-niche improvement/discovery, or exploration restart.
- Three reliable winning strategies that satisfy the existing all-pairs opening
  and observed combat-role diversity gates.
- A frozen assessment on 64 held-out seeds: each selected strategy wins at least
  90% of its panel, and every pair differs meaningfully on at least 90% of seeds.

The battle floor is **not** a cap or a claim of exhaustive search. These are
initial, configurable policy values, not proof of optimality or player enjoyment.
`--minimum-training-battles 100000000` or `1000000000` raises the floor to 100
million or one billion per group. `--stability-battles`, `--stability-generations`,
and `--goal-solutions` configure the other requirements. Larger counters are
supported; billion-battle throughput and memory use have not been qualified.

Stable training without the required winning variety starts another exploration
window. Failed qualification also resumes training and preserves its full evidence.
Every later frozen assessment uses a new, non-overlapping held-out seed panel;
held-out fitness never enters breeding or the training convergence tracker.
Repeated candidates must also meet reliability across all their earlier held-out
evidence, and pairs must meet diversity across all shared assessed seeds. A lucky
fresh panel cannot erase earlier failed evidence.
An empty generation requests fresh plans and never establishes convergence.

`--generations`, `--max-evaluations`, and `--genetic-hours` are optional resource
guardrails for explicitly bounded experiments. Stored zero values mean no ceiling.
A battle cap includes training and all qualification attempts, with a final panel
reserved. An explicit time cap reserves 15% for final assessment; in-flight work
and subsequent demonstration recording may extend runtime. Historical positive
limits retain their meaning. Resource exhaustion is reported as **quality goal
not achieved**, even when the final assessment panel is complete.

The successful stopping reason is `quality-qualified`. `time-budget`,
`generation-limit`, and `evaluation-budget` identify resource exhaustion.
`ga_stopping_policy` stores the chosen requirements, `ga_search_goal` stores
training effort/stability, and `ga_qualification` plus `ga_qualification_seed`
retain every attempt and its panel. Rejected attempt evidence uses separate
`ga_run` IDs; the final panel is also published under the study ID for existing
readers. Actual-battle totals exclude that publication copy.

`--workers N` (required for GA searches, 1–32, no default) runs complete GA battles in independent native
processes. Each process uses the same executable, its own main actor, the shared
`GeneticCommander`/`GameSimulation`/`BattleEngine`, and the authoritative database
through DAOs. Worker startup verifies the coordinator's authored-content and
executable hashes; either changing is an error. Workers keep their validated content snapshot and
meta-loadout cache for the study. No GPU combat model is used.

The coordinator freezes parent pools, breeds in deterministic order, and buffers
up to ceil(4 × N / training-seed-count) candidate panels (at least one).
Serial execution saves each candidate immediately. The bounded queue gives fast
workers more battles while slower ones finish. Candidate IDs and scores retain
admission order, regardless of worker completion order. Pending duplicate DNA shares
one evaluation. Training and held-out seeds remain separate. Within each admitted
candidate panel, a free worker immediately receives the next queued battle;
it does not wait for the other workers. The coordinator polls all result pipes,
including partial replies, and restores request order before scoring. It still
finishes the admitted panel before saving candidates or breeding another
generation. Population sizes, seeds, fitness and validation coverage are unchanged.
Every battle still ends in victory, defeat, or an explicit timeout. The wall-time
limit stops admitting new panels, so an already admitted panel can finish after
the deadline. Time-limited searches can naturally
explore different numbers of candidates at different worker counts; fixed-work
comparisons should match DNA and outcomes exactly, except recording UUIDs.

Workers evaluate battles without playback recorders and return compact results
to the coordinator. Worker failures fail the study and are not automatically
retried. Completed candidate evidence remains saved. Workers receive EOF after
evaluation, before the coordinator records the retained solutions; no
process-killing loop is used. Database connections wait up to 30 seconds for a
writer lock; lock failures remain errors.

Retained-solution recordings compare typed state and pack timestamped changes.
The search loop does not serialize or compress playback state. Playback reads
the recorded data and never invokes the battle engine or RNG. Recording remains
bounded and synchronous; every terminal path flushes the last events.

Calibrate worker counts on the actual Mac: extra workers may hit CPU or memory
bandwidth limits before all cores help. Include compact evidence, checkpoints
and final demonstration recordings when budgeting disk space. Do not extrapolate
brief timeout fixtures as full-level throughput. Longer or winning plans can
cost more evaluation time than the initial population's early defeats.

Legacy candidates without playstyle evidence compete at equal fitness on recorded opening diversity,
then following placements and construction decisions. Exact ties permit newer
candidates to enter while preserving the original best champion, population
capacity, fitness components and evaluation budgets. Held-out finalist selection
uses the same tie policy while retaining one finalist per qualified meta selection.

Creative playstyle evidence (`genetic-v10` and later) is stored in `ga_playstyle`,
`ga_playstyle_purchase`, `ga_playstyle_tower` and `ga_playstyle_route`. These
record successful purchases and paid prices, authored tier/ability identities,
opening/one-third/two-thirds/final samples, observed damage/shots/blocking time/
engineer slowing time/supply income/detonations, route coverage, and player action counts. Unknown
legacy evidence stays absent. `candidate_playstyles.sql` exposes this evidence.

Selection uses `GeneticDefenseComparison` through the dedicated selector. It
requires all of the following; a high score in another dimension cannot rescue
a failed condition:

- Less than 60% shared visible opening AND shared paid opening defense. Match
  the same family one-to-one
  at the same slot or equivalent nearby route coverage, using maximum-weight
  assignment. Divide shared cost by the smaller defense budget so adding extras
  cannot dilute an existing core. Check the entire visible layout separately
  from the participating defense; idle and income-only towers cannot dilute the
  defense, and identical visible layouts fail even if different subsets act.
- At least 40% turnover in the paid, participating opening family mix.
- A material change in damage or control roles during both the first and second
  thirds of the waves. Damage-family turnover must reach 40%, or blocking/slowing
  family turnover must reach 50% with at least 0.5 enemy-seconds per second from
  a different control family. Keep damage, blocking and slowing in separate units.
  Use interval increments for the middle waves, not cumulative early activity.

Nearby coverage requires at least 80% common route identities and no more than
8% route-progress separation on each common path; it is a geometric proxy, not
proof of enemy interception. Family attribution avoids crediting earlier damage
to a later upgrade. Missing phase/control evidence is unknown and cannot qualify.
Novelty is the weakest of visible-opening difference, opening-core difference,
opening-family turnover, early
role difference and middle role difference. Investment, branches, workload and
risk remain available as diagnostics; they cannot offset these hard gates.
This intentionally conservative movie-screening policy rejects even mechanically
useful additions when the viewer would still see the same dominant opening.

Publication chooses the strongest reliable baseline that permits a complete
compatible set and backtracks around dead ends. Every selected pair must qualify
on at least 90% of matching held-out seeds; eligible candidates need at least 90%
wins. Original fitness and evidence remain unchanged. No simulation or replay
is used for comparison. Demonstration recording is a separate publication step.
These policy thresholds are not proof of fun; player feedback is authoritative.

`genetic-v13` keeps every candidate eligible for finalist selection. The working
parent pool is bounded, but a separate persistent archive keeps the strongest
candidate in every observed behavior niche. Two of every three breeding slots
are allocated to the least-bred niches; the remaining third develops the global
champion. Improved niche champions inherit the niche's visit count. Local mates
must have similar opening and investment mixes, and crossover inherits opening
slot chains together. Retired meta selections remain in the full finalist pool
and may donate plans to new selections. `ga_population_niche` records champions
and allocated offspring; `search_coverage.sql` exposes both archives.

Fresh plans draw family, opening size, placement policy, upgrade cadence, delay
and investment depth independently. Normal meta groups use independent streams;
controlled meta-exchange experiments retain deliberately paired inputs. Families
are sampled uniformly before branches so extra authored branches do not bias
family probability. Fresh introductions occupy the actual last offspring slot
every eighth generation, and enter evaluation without another mutation pass.

Mutation targets successful purchases from original training evidence 75% of
the time when available; the remainder explores dormant orders. Replacement
chains retain their original global priorities and triggers. Coordinated opening
changes can cross fitness valleys. Rally points, engineer obstacle sites and
repeated demolition targets are evolved route-target preferences and execute via
normal player commands. Actual accepted positions are stored per seed in
`ga_tactical_action`; DNA is in `ga_tactical_order`. Old DNA retains historical
automatic sites, and missing old tactical evidence remains unknown.

Finalists are drawn from every qualified selection's complete candidate pool,
not its parent seats. The global champion remains first. Three quarters of the
finalist cap prefer the best training win-rate band; up to a quarter may explore
other styles with at least one training win. Return fewer finalists when the
archive cannot supply more distinct observed niches; never pad with behavior
clones. Meta coverage also skips an already represented niche. This small-panel
uncertainty allowance does not relax the independent held-out publication gate.
One third of seats first seek successful meta-selection coverage. All finalists
are frozen before any held-out result arrives. Fitness, combat precision,
training seeds and held-out seeds remain unchanged.

Recorded upgrade DNA uses `MetaUpgradesFactory.restore` against a fresh DAO
catalog. Do not construct a search factory per saved candidate: its initializer
enumerates every legal progression. Single-selection validation preserves the
same prerequisites, costs and error handling without that enumeration.

Population checkpoints append newly evaluated membership instead of deleting and
rewriting the entire historical population each generation. Parent/archive seats,
behavior champions and breeding visits still update each checkpoint; all original
candidates and evaluation records remain available. Failed checkpoint transactions
do not advance the in-memory append cursor.
