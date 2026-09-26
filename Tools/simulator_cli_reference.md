# Advanced simulator reference

## Logging

Logging is always available with the normal `~/bin/LibertyLineSimulator 15`
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

## Installation and experiments

`LibertyLineSimulator` is the game's standalone macOS command-line simulator.
It runs the shared `BattleEngine` without a graphical interface. The installer
builds Xcode's `Simulator` target and installs it under this name.

For **level 15 (Charleston)**, `LibertyLineSimulator 15` runs the genetic
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
its `--version` output. Rebuilding produces a new named starter; previous starters
and run databases are retained. The installed executable is replaced only after
its new starter is ready. Building the starter does not rebuild or copy the live
development database.

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

For normal use, only the level number is needed: `~/bin/LibertyLineSimulator 15`.
Optional overrides can follow it. For example, to reduce CPU load and request a
shorter run:

```sh
"$SIM" 15 --workers 2 --genetic-hours 0.25
```

Without overrides, the GA uses up to four workers (leaving a CPU core available)
and an eight-hour budget. This runs locally in the foreground. Keep the Mac awake and the Terminal session
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

The database is the complete run artifact: battle recordings, candidate DNA,
training/validation evidence, configuration, maps, and JSON checkpoints all live
inside it. Long searches can generate large databases because they retain the
battle recordings. SQLite may create a temporary `-journal` file during writes;
a normally closed run is a single `.sqlite` file.

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

- **Time:** `--genetic-hours 8` allocates up to eight hours, reserving 15% for
  held-out validation. Generation or evaluation limits can end the run earlier;
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

JSON reports are rows of `simulator_document`, keyed by `name`. For example:

```sh
sqlite3 -readonly "$SIM_DB" \
  "SELECT content_json FROM simulator_document WHERE name = 'summary.json';"
```

Check `validationComplete` and the win counts in `summary.json`. Other documents
include `configuration.json`, `content.json`, `population.json`, `validation.json`,
and `best-stars-N.json`. The latter is the best **training** replay at that spend,
not necessarily a validated winner. Checkpoints appear as their phases finish;
a running search may not have `summary.json` yet.

To inspect the persisted Charleston catalog, run:

```sh
sqlite3 -readonly -header -column "$SIM_DB" <<'SQL'
SELECT g.run_id, g.candidate_id, g.panel, g.stars_used, g.starting_money,
       json_array_length(g.solution_json, '$.candidate.evaluations') AS games,
       json_extract(g.solution_json, '$.expectedSamples') AS expected_games,
       (SELECT count(*)
          FROM json_each(g.solution_json, '$.candidate.evaluations') AS e
         WHERE json_extract(e.value, '$.result.outcome') = 'victory') AS wins
  FROM genetic_solution AS g
  JOIN level_info AS l ON l.id = g.level_info_id
 WHERE l.map_image_name = 'level_15_charleston'
 ORDER BY g.run_id, g.panel, g.stars_used, g.candidate_id;
SQL
```

This shows the Charleston candidates saved by this invocation. A
validation row has completed its panel when `games = expected_games`. Campaign
playback also needs a win, an affordable star cost, the current difficulty and
authored money/bounty, compatible hero-enabled data, and matching battle content.
Old or experimental rows can remain in the table without being playable advice.

## 4. Keep the run database for later import

Candidate publication into this run database is automatic: training candidates
are saved before validation; validation candidates are saved after that phase,
including partial panels when the normal budget expires. No manual SQL insert
is needed. The CLI prints the published counts and the database path.

The simulator **does not update `Db/DML/genetic_solutions.sql`** or the deployed
game database. Keep the finished `.sqlite` file beside the executable (or archive
it elsewhere) for the later import workflow. That future tool will select the
best compatible solutions from a run database and generate the SQL seed used
by `Db/create_db.sh`. That import command is not implemented yet.

The snapshot records the battle content used by the search. Subsequent changes
to maps, waves, costs or combat tuning can make a solution incompatible with the
current game; the future importer must preserve and check that provenance.

See [the GA reference](genetic_simulator.md) for replay, strategy seeding,
fitness, and meta-selection details, or run `"$SIM" --help-advanced` for all CLI flags.
