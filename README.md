# Liberty Line Simulator

Run this in Terminal to search for **level 15 (Charleston)** solutions:

```sh
~/bin/LibertyLineSimulator --level 15 --workers 8
```

Set `--level` to the level number you want. `--workers` is required; choose
an integer from 1 to 32 for the number of parallel battle processes.

The simulator runs the genetic algorithm locally using the CPU workers you
specify. It loads starting money, difficulty, heroes and the star budget from its
database, and searches tower plans and explicit meta upgrades. Keep the Terminal
open and your Mac awake.

There is no default time, generation or battle ceiling. Completion requires the
configured minimum training effort, stability, and reliable, distinct winners on
held-out seeds. Explicit resource limits can end a run with the quality goal unmet.
See the [stopping policy](Tools/simulator_cli_reference.md#search-stopping-policy)
for the requirements and optional limits.

Progress appears automatically in Terminal and the GA logs. It reports elapsed
time, generations, actual battle counts and each group's effort/stability counters.
Completion time is unknown while the quality search continues; no percentage or
ETA is claimed. Updates occur about every 15 seconds between completed work
batches and when phases change.

Each invocation prints the path to a new, dedicated SQLite database beside
`~/bin/LibertyLineSimulator`. Results, recordings and checkpoints go into that
one file. Best-found candidates are saved automatically in `genetic_solution`;
a win or a globally optimal solution is not guaranteed. The game development
database is untouched. The program runs independently of Codex and makes no AI
API calls.

Logging is automatic through Apple's unified logging system. To view it, open
macOS Console and filter by subsystem `com.zippyzen.td.simulator`.
[Log viewing details](Tools/simulator_cli_reference.md#logging) include Terminal commands.

To build or update the installed Release executable and its starting database:

```sh
cd /Users/john/projects/td/in-defense-of-history
./Tools/install_simulator.sh
```

Each deployment first deletes the installed executable and all previous
build-named starter databases, including their SQLite sidecar files. It then uses
the normal Xcode build and recreates
`~/bin/liberty-line-simulator-<build-name>.sqlite` from the authored SQL and maps.
A failed build or database generation leaves no installed replacement; fix the
reported error and deploy again. Finish active runs and close starter databases
before deploying; the installer refuses to remove files that are in use.

Keep the new starter beside the executable. Saved run databases are preserved;
each invocation copies the fresh starter into its own new database.

Generated GA catalog and playback exports live outside the source repository in
`../in-defense-of-history-data/GeneticSolutions`. Database creation imports
`genetic_solutions.sql` and `GeneticRecordings/*.sql` from that directory and
requires the catalog and recording exports before rebuilding. To use another external location,
pass `--genetic-seeds /absolute/path/to/GeneticSolutions` to `Db/create_db.sh`,
or set `LIBERTY_LINE_GENETIC_SEEDS` for database creation, installation and host
tests from a different checkout layout. Keep generated
catalogs, recordings, study databases and diagnostic reports out of Git.

Let a run finish to save its validated candidates. Ctrl-C stops it early and
retains already committed data, but may leave validation unfinished. Keep the
finished database for the later game-import workflow.

The level must have complete battle data in the starting database. Level 15
is verified; level 10 currently fails content validation because it declares
15 waves but contains 12.

[Optional controls and result inspection](Tools/simulator_cli_reference.md)
· [GA details](Tools/genetic_simulator.md)
