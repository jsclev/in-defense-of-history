# Liberty Line Simulator

Run this in Terminal to search for **level 15 (Charleston)** solutions:

```sh
~/bin/LibertyLineSimulator 15 --workers 8
```

Replace `15` with the level number you want. `--workers` is required; choose
an integer from 1 to 32 for the number of parallel battle processes.

The simulator runs the genetic algorithm locally for up to eight hours, using
the number of CPU workers you specify. It loads starting money, difficulty, heroes and the star
budget from its database, and searches tower plans and explicit meta upgrades.
Keep the Terminal open and your Mac awake. It can finish earlier when it reaches
its generation or evaluation limit; time limits are checked between batches.

Progress appears automatically in Terminal and the GA logs, for example:

```text
GA progress: ~20.0% | elapsed 1h 36m 0s | about 6h 24m 0s remaining | search | generations 0 | battles 100
GA milestone: passed 20% after 1h 36m 0s
```

The percentage estimates completion of the run, including validation and saving
results. It updates about every 15 seconds between completed work batches and at
each 10% milestone. Estimates can change as battle speed changes; 100% appears
after results have been saved. It does not measure how close a strategy is to optimal.

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

Let a run finish to save its validated candidates. Ctrl-C stops it early and
retains already committed data, but may leave validation unfinished. Keep the
finished database for the later game-import workflow.

The level must have complete battle data in the starting database. Level 15
is verified; level 10 currently fails content validation because it declares
15 waves but contains 12.

[Optional controls and result inspection](Tools/simulator_cli_reference.md)
· [GA details](Tools/genetic_simulator.md)
