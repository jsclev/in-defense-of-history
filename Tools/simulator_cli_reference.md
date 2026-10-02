# Advanced simulator reference

## Logging

Logging is always available with the normal `~/bin/LibertyLineSimulator --level 15 --workers 8`
command. The CLI uses Apple's [Swift Logger API](https://developer.apple.com/documentation/os/logger)
and unified logging, with subsystem **`com.zippyzen.td.simulator`**.
In macOS Console, start streaming and filter for that subsystem. Enable info
or debug messages in Console when you need more detail.

To watch from another Terminal:

```sh
/usr/bin/log stream --level info --style compact \
  --predicate 'subsystem == "com.zippyzen.td.simulator"'
```

To read recent retained events:

```sh
/usr/bin/log show --last 1h --style compact \
  --predicate 'subsystem == "com.zippyzen.td.simulator"'
```

Categories separate `CLI`, `Database`, `GA`, `Worker`, and the optional balance
and money `Study` modes. GA and worker events include the same `runID`, matching
the database's run records. Notice events record starts, periodic training
progress, new best candidates, search stopping reasons, publication and completion
(including whether validation finished). Failures use error level. Generation
and validation checkpoints use info; individual candidate/battle events and
report writes use debug. Use `--level debug` on the **log viewer** to see those
details live. Logging never writes into the workers' JSON response stream.

Game identifiers, run IDs and counters are public. Filesystem paths are private
with hashed correlation, and arbitrary error details are private; direct Terminal
errors retain their full diagnostic. Raw command lines, candidate DNA, SQL and
report bodies are not logged by these categories.

macOS manages log retention. Notice and error events are retained up to the
system's storage limits; info/debug events are primarily for live diagnosis.
These operational logs live in the macOS unified log store. Simulation results
and checkpoints still live in the invocation's SQLite database.
See Apple's [logging guidance](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code).

## GA recording storage

Every candidate keeps its compact evaluation evidence. Playback is generated
only for retained solutions after evaluation. Those recordings use
self-contained setup and event blocks with lossless LZ4
compression. There are no database-size or free-space scheduling caps, replay
pruning, shared-content writes, or automatic compaction during the search.
Time, generation and evaluation ceilings apply only when explicitly supplied.
Historical shared/LZFSE recordings from CLI 1.0.205 remain readable.

## Search stopping policy

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

## Progress estimates

For a quality search, output reports elapsed time, actual battle
counts, generations, and each group's minimum-effort and stability counters.
Completion time is unknown: no fabricated percentage or ETA is shown. Updates
occur every 15 seconds between work batches and at phase changes. A slow batch
can delay an update.

Explicit resource guardrails do not create a predictable quality completion time.
The quality search therefore suppresses percentages and ETA even with such limits:
failed assessments can return to training repeatedly. 100% means execution and
saving finished; only `quality-qualified` means the configured quality goal was
met. `validationComplete` describes panel completeness, not reliability,
diversity or quality-goal success. Legacy budget-only progress remains readable.

The `ga_progress` and `ga_progress_milestone` tables store the latest estimate
and every milestone's elapsed time. `--runs` and `--run-status` show the same
estimate for new GA runs; older run databases retain their existing display.

## Installation and experiments

`LibertyLineSimulator` is the game's standalone macOS command-line simulator.
It runs the shared `BattleEngine` without a graphical interface. The installer
builds Xcode's `Simulator` target and installs it under this name.

For **level 15 (Charleston)**, `LibertyLineSimulator --level 15 --workers 8` runs the genetic
algorithm (GA), evaluates candidate strategies, and automatically saves the best
plans it finds to the **`genetic_solution`** table in a **new SQLite database
unique to that invocation**, beside `~/bin/LibertyLineSimulator`.
The GA searches explicit meta-upgrade selections as well as tower plans,
reinforcement choices, and early wave calls. `MetaUpgradesFactory.make(stars:)`
produces a legal selection at the requested exact star cost; candidates retain
the selected upgrades, and variation preserves their prerequisites.

These are **best-found solutions**, not a guarantee of global optimality or a
win. The catalog retains training and validation evidence; campaign playback
requires a compatible candidate with completed validation and at least one win.

You can build and run this program directly in macOS Terminal, with Codex
closed. The simulator uses local CPU processes and SQLite; it does not call an
AI model, require an API key, or consume Codex usage credits. Asking Codex to
operate or analyze it is a separate use of Codex ([usage documentation](https://learn.chatgpt.com/docs/pricing)).

## 1. Build and install the CLI

Use full Xcode with its normal toolchain selected. The current target requires
macOS 26.5 or newer. From the repository root, run:

```sh
./Tools/install_simulator.sh
```

The [installer](install_simulator.sh) invokes the normal
`xcodebuild -scheme Simulator -configuration Release` build for macOS, keeping
build products in `~/Library/Developer/Xcode/DerivedData/LibertyLineCLI`.
The installer also runs `Db/create_db.sh --output` against a fresh staging file,
then embeds the authored level maps and simulator schema in that database.
It installs the matching pair:

- **`~/bin/LibertyLineSimulator`**
- **`~/bin/liberty-line-simulator-<build-name>.sqlite`** — the starter database

The build name is the CLI's full version, such as `1.0.165`, read directly from
its `--version` output. Every deployment first removes the installed executable
and all previous build-named starter databases, including `-wal`, `-shm` and
`-journal` sidecars. It then builds the executable and generates a fresh starter
from authored SQL and maps. No previous starter content or results are imported.
The new pair is installed only after the starter passes validation. If building
or generation fails, the previous installation is already removed; resolve the
reported error and deploy again.

Finish active runs and close starter databases before deployment. The installer
checks all removal targets and refuses to proceed if any are in use; it does not
stop processes. Saved invocation databases (`*-run-*.sqlite` and their sidecars)
and custom experiment databases are preserved. Building the starter does not
rebuild or copy the live development database.

```sh
SIM="$HOME/bin/LibertyLineSimulator"
"$SIM" --version
"$SIM" --help
```

Use `~/bin/LibertyLineSimulator` from any directory. If `~/bin` is on your shell's `PATH`,
you can also type `LibertyLineSimulator` directly. To add it for the current Terminal session,
run `export PATH="$HOME/bin:$PATH"`.

The `Simulator` scheme is a macOS command-line target, not Apple's iOS Simulator.
The installed executable and starter database are self-contained for running
studies. Keep them together if you move them to another directory. New runs do
not read the checkout's database, GeoJSON files, or SQL schema. Finish active
searches before updating the CLI executable. A normal build advances its build
number.

## 2. Customize a search for level 15 solutions

Starting money comes from the selected level's `level_info.starting_money` in
the installed starter, through `LevelInfoDAO`. Charleston currently has 670 coins.
There is no hardcoded starting-money default. Omit `--starting-money` for normal
campaign conditions; use that flag only for an intentional experiment.

For normal use, supply the level number and required worker count:
`~/bin/LibertyLineSimulator --level 15 --workers 8`. `--workers` accepts integers from
1 to 32 and has no default. Optional overrides can follow it. For example, to reduce CPU load and request a
shorter run:

```sh
"$SIM" --level 15 --workers 2 --genetic-hours 0.25
```

The GA uses the worker count you specify and defaults to an eight-hour budget.
This runs locally in the foreground. Keep the Mac awake and the Terminal session
open. At startup it prints the exact database path, for example:

```text
Simulator database: /Users/john/bin/liberty-line-simulator-<build-name>-run-20260926-180000-<UUID>.sqlite
```

The default input filename is constructed from the running executable's build:
`liberty-line-simulator-<build-name>.sqlite`, in the executable's directory.
Every study copies that starter into a separate build/timestamp/UUID run database.
All workers use that one run database. The snapshot includes the schema, content,
player settings and level maps, and begins with empty result tables. The starter
is opened read-only; new results never modify it or the game's SQL seeds.

The database is the complete run artifact: candidate DNA, training/validation
evidence, configuration, maps, checkpoints and retained-solution recordings all
live inside it. Routine training and validation battles do not generate playback
data. After evaluation and selection, the coordinator reruns one original seed
per retained solution with recording enabled. The configured finalist limit
still applies per star group. Validation candidates are preferred; a group with
no validation samples gets explicitly labeled training demonstrations.

These final recordings run after the evaluation budget and never change fitness
or candidate rankings. `genetic_solution_recording` links each demonstration to
its candidate and original seed, and stores its actual outcome and a comparison
flag. A difference is reported, not substituted into the original evidence.
SQLite may create a temporary `-journal` file during writes; a normally closed
run is a single `.sqlite` file.

To choose the new file yourself, add `--database "$HOME/bin/my-charleston-run.sqlite"`.
It **must not exist**; the CLI refuses to overwrite or append another study to it.
`--content-database /path/to/another-starter.sqlite` overrides the default input.
A completed invocation database can also supply captured input for a new run.
These inputs must contain the captured simulator schema and maps. A missing
starter is an error; the CLI never falls back to the development database.

For example, to inspect the default starter's level budgets:

```sh
SIM_BUILD="$("$SIM" --version)"
SIM_SOURCE="$HOME/bin/liberty-line-simulator-$SIM_BUILD.sqlite"
sqlite3 -readonly -header -column "$SIM_SOURCE" \
  "SELECT level_name, starting_money FROM level_info WHERE map_image_name <> '';"
```

JSON files are optional: add `--report-dir /path/to/new-empty-directory` to export
copies outside the source checkout. The reports are still saved in SQLite.

- **Time (optional):** no deadline by default. `--genetic-hours 8` allocates up to eight hours, reserving 15% for
  held-out validation. Explicit generation or evaluation limits can end the run earlier;
  time limits are checked between work batches. Use `--genetic-hours 0.25` for
  a short trial, which may leave validation incomplete.
- **CPU:** `--workers 4` runs four local battle processes. Use `1` or `2` for
  less CPU load. These workers do not use AI models.
- **Stars:** omitting `--star-range` searches the database-earned star total
  (currently 42), varying the explicit upgrades purchased for that amount.
  To search several spending totals, add `--star-range 0:42:1` while the earned
  budget is 42. This spreads work across 43 groups and needs a larger search
  budget. Spending above the database-earned total is rejected.
- **Selection diversity:** the population cap is per star group, divided among
  active meta selections. `--finalists 8` retains up to eight candidates per
  run, panel, and star group. Omit `--fixed-meta` to keep upgrade selection part
  of the search.
- **Campaign context:** difficulty, chosen heroes, and their AI settings come
  from the captured starter database. Heroes participate in the battles; the GA does not evolve the
  hero lineup. Separate runs cover other contexts. Bounty fraction `1` preserves
  the authored rewards.

Let the run finish normally to publish its validation candidates. Ctrl-C aborts
the process; committed recordings and checkpoints remain in the run database,
but it does not guarantee validation publication. There is no automatic resume
command. Do not copy the database while it is actively being written; use SQLite's
backup facility if you need a consistent backup before the run finishes.

## 3. Inspect progress and saved candidates

In another Terminal window, use the **actual database path printed by the run**:

```sh
SIM="$HOME/bin/LibertyLineSimulator"
SIM_DB="$HOME/bin/liberty-line-simulator-<build-name>-run-<timestamp>-<UUID>.sqlite"
"$SIM" --database "$SIM_DB" --runs
```

Replace the placeholder filename before running the command. Use a run UUID from
that output with `"$SIM" --database "$SIM_DB" --run-status <UUID>`. These inspection
commands open the existing database read-only and create no new database.
Completion of a run alone does not establish that validation finished or that
any candidate won.

GA configuration, candidates, original evaluations, checkpoints and progress
are relational tables. Optional `--report-dir` JSON files are exports only.
See [GA SQL queries](../Db/Queries/GA/README.md) for the complete query set.

```sh
sqlite3 -readonly -header -column "$SIM_DB" <<'SQL'
SELECT * FROM ga_study_overview;
SELECT f.* FROM ga_candidate_fitness f
 WHERE panel='validation' AND panel_complete=1
 ORDER BY run_id,stars_used,win_rate DESC,mean_victory_lives DESC,
          mean_waves_started DESC,mean_survival_seconds DESC,candidate_id;
SQL
```

Run `Db/Queries/GA/top_solutions.sql` as-is to see the three Charleston solutions
selected for the phone; no parameter binding is needed. Edit its literal run ID,
star budget and `LIMIT` for another selection. Never compare different seed
panels or scenarios as though they were one experiment. `ga_summary` records
whether the configured held-out search completed. A complete panel need not
contain a win. Campaign playback additionally requires an affordable star cost,
the current difficulty and authored money/bounty, compatible heroes, matching
content, and a separately linked demonstration.

For a legacy v8 database, first convert to a new file:

```sh
python3 Tools/ga_relational.py old-run.sqlite new-relational-run.sqlite
```

The original remains untouched. New CLI study/status/import operations use the
relational schema. Keep older executables for historical replay formats.

## 4. Keep the run database for later import

To ship three diverse winners from a completed run, scan the original held-out
ranking and generate just three demonstration recordings:

```sh
"$SIM" --ship-ga-solutions source-run.sqlite /absolute/path/to/Db/in_defense_of_history.sqlite \
  new-publication-evidence.sqlite selected-solutions.sql new-recordings-directory
```

This preserves original candidate IDs, seeds, validation panels and fitness.
`GeneticSolutionDiversitySelector.selectCompleteSet` chooses the strongest reliable
baseline that permits three compatible plans, then favors the greatest minimum
playstyle difference against every selected plan. It backtracks when a greedy
choice would prevent a complete set. Original fitness remains unchanged and breaks novelty ties.
The comparison uses saved openings, time-weighted actual investment, participating
tower mechanics, development, route coverage, workload and recovery margins.
The old 75% position and five-build checks are preferences, not vetoes.

`GeneticPlacementPlan` stores successful pre-wave-one builds and the first five
later builds. Its optional `GeneticPlaystyle` adds successful purchases and
phase samples. `ga_placement*` and `ga_playstyle*` tables hold this evidence in
normal SQL columns. Comparison never executes a battle or playback. Missing
legacy evidence remains unknown; publishing new creative recommendations requires
complete playstyle evidence. Publication fails rather than padding duplicates.

For a quick greedy diagnostic of the saved archive (a shortfall here does not
prove that no other three-plan combination exists):

```sh
"$SIM" --audit-ga-diversity source-run.sqlite
```

That read-only command scans validation and training rankings separately, using
fitness columns and saved placement/playstyle rows (using the representative seed for its diagnostic ranking). Training winners
still require full held-out validation before publication; its results must not
be treated as validated solutions or mixed into the held-out ranking.

After selection, publication checks current authored battle content, records one representative seed per
solution, and verifies each recording can be read to completion. Demonstration
differences are stored separately. The catalog SQL preserves advice for other
levels. Keep these generated exports outside the source repository in
`../in-defense-of-history-data/GeneticSolutions`: the catalog is
`genetic_solutions.sql` and the three recording SQL files are
`GeneticRecordings/*.sql`. Run `Db/create_db.sh` before the normal device build;
it requires the external catalog and recording exports before rebuilding. To use another
external directory, pass `--genetic-seeds /absolute/path/to/GeneticSolutions`.
Database creation, installation and host tests also accept the absolute
`LIBERTY_LINE_GENETIC_SEEDS` environment override for other checkout layouts. These exports
must not be committed to Git. Phone previews read those recordings without running
combat. Device database validation permits only three linked demonstrations,
rejects unrelated research history, and caps the bundle database at 128 MiB.
The app target excludes SQL source files from its resources; only the generated
SQLite database carries these recordings to the phone.

Candidate publication into this run database is automatic: training candidates
are saved before validation; validation candidates are saved after that phase,
including partial panels when the normal budget expires. No manual SQL insert
is needed. The CLI prints the published counts and the database path.

Studies **do not update the external shipping catalog** or the deployed game
database. Keep the original run database, including failed runs with saved
candidates. A separate offline command can recover three distinct training
leaders and validate them for the game's preview:

```sh
"$SIM" --import-ga-solutions source-run.sqlite current-content-starter.sqlite \
  new-validation-evidence.sqlite selected-solutions.sql
```

The current-content starter must be generated from the game's current authored
SQL and maps using the normal starter preparation command. Import reads the
source without changing it, ranks complete training panels with the GA's own
fitness/tie breaker, and freezes three winners selected by the same creative
composition and pairwise placement policy before validation. It
requires an exact content match, reproduces every saved training evaluation,
and runs the entire recorded held-out seed panel using the shared engine.
New compact battle results go into the new evidence database;
the original study's failed/completed status remains unchanged. The SQL output
is written only after all three panels finish, each plan has a victory, and
the held-out candidates still pass the same data-only diversity check.
It contains the selected level's training and validation records. Merge this
selection into the external `GeneticSolutions/genetic_solutions.sql` catalog
while retaining other levels' records, then
rebuild the game database with `Db/create_db.sh`.

The snapshot records the battle content used by the search. Subsequent changes
to maps, waves, costs or combat tuning can make a solution incompatible with the
current game; the importer rejects those mismatches.

See [the GA reference](genetic_simulator.md) for replay, strategy seeding,
fitness, and meta-selection details, or run `"$SIM" --help-advanced` for all CLI flags.

To audit tower diversity, run separate searches with `--max-towers areaOfEffect:1`
and `--majority-tower ranged`, alongside an unrestricted control. These constrain
the automated player's plans without changing game rules. Summaries include
`builtTowersBySeed` and `winsMeetingTowerLimits`; use those actual purchases
instead of planned tower counts when checking a winning defense's composition.

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
