# Liberty Line Simulator

Run this in Terminal to search for **level 15 (Charleston)** solutions:

```sh
~/bin/LibertyLineSimulator 15
```

Replace `15` with the level number you want. No other arguments are needed.

The simulator runs the genetic algorithm locally for up to eight hours, using
up to four CPU workers. It loads starting money, difficulty, heroes and the star
budget from its database, and searches tower plans and explicit meta upgrades.
Keep the Terminal open and your Mac awake. It can finish earlier when it reaches
its generation or evaluation limit; time limits are checked between batches.

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

The installer uses the normal Xcode build and creates
`~/bin/liberty-line-simulator-<build-name>.sqlite` from the authored SQL and maps.
Keep this starter beside the executable. Each run copies it into its own database,
so previous results remain separate. Finish active runs before updating the CLI.

Let a run finish to save its validated candidates. Ctrl-C stops it early and
retains already committed data, but may leave validation unfinished. Keep the
finished database for the later game-import workflow.

The level must have complete battle data in the starting database. Level 15
is verified; level 10 currently fails content validation because it declares
15 waves but contains 12.

[Optional controls and result inspection](Tools/simulator_cli_reference.md)
· [GA details](Tools/genetic_simulator.md)
