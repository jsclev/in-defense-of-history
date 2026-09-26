# Database authority

Standing user instruction (September 26, 2026): standalone CLI studies create a
unique SQLite database beside `~/bin/LibertyLineSimulator` for each invocation.
The installer builds a fresh starter with `Db/create_db.sh --output`, captures
its maps and schema, and installs `liberty-line-simulator-{build-name}.sqlite`
beside the CLI. The CLI derives that default input filename from its own build
version; `--content-database` overrides it. Normal runs must not read the live
checkout database, maps or SQL files. Start with empty simulator result tables
and keep all workers, recordings, candidates and JSON checkpoints in the run
database, named with the build version plus a unique invocation suffix.
Starting money defaults to the selected level's DAO-loaded value from this
database; an explicit `--starting-money` flag is an experiment override.
Do not export or change the game's `Db/DML/genetic_solutions.sql` during a study;
importing selected solutions from a run database is a separate, future workflow.
The dedicated invocation database is the explicit exception to the desktop
database-location rule below.

The database is `Db/in_defense_of_history.sqlite`, generated exclusively by
`Db/create_db.sh` from the authored SQL scripts. Desktop tools open that file
in the checkout. Simulator records belong in its SQL-defined tables. Device
installations use the generated database and refresh it on every game launch.
Diagnostic exports contain images and JSON only. Mutation tests use disposable
in-memory data. Close database connections before rebuilding.

Tower names, descriptions, tuning, capabilities, unlock limits and simulator
tower search values must be loaded through DAOs from this database. Do not add
Swift defaults, alternate catalogs, nil-coalescing replacement attributes or
SQLite column defaults for tower content. Missing rows, NULL required fields,
unknown identifiers and malformed values are fatal content errors. Stop game
execution with a diagnostic identifying the record and field. A disabled
capability or locked tower must be explicitly authored in the database.
Regression tests must prove both that database edits propagate and that missing
or invalid data fails; constructor defaults and test-only production fallbacks
are not acceptable fixes.

This requirement covers all combat attributes, including shared combat rules,
enemy and hero stats, morale, movement, targeting, projectile collision and
reinforcement counts. Author shared rules in `Db/DML/combat_rules.sql` and load
them through `CombatRulesDAO`. Pass the resulting rules into combat models;
never introduce a parallel Swift tuning catalog or a mutable global registry.

# Simulator boundary

Standing user instruction (September 20, 2026): the simulator must execute the
same gameplay rules as the game. Use the shared BattleEngine for combat,
movement, wave timing, purchases, abilities, rewards and victory/defeat. Do not
maintain separate simulator damage or morale implementations. Campaign settings
and selected upgrades remain database-authoritative; exclude only features the
user explicitly asks to exclude. Legacy CPU/GPU simulation results are not valid
game balance evidence.

The simulator is only an input driver and result recorder. It must not implement
or duplicate any gameplay rule, including eligibility, prices, damage, targeting,
movement, timing, morale, rewards, or outcomes. All simulation entry points,
including editor playtests, must call the same engine used by the game. Delete
obsolete alternate implementations; disabling an entry point is insufficient.
Keep strategy choices and experiment limits separate from engine rules.
Run `SimulatorBoundaryTests` and shared-engine regressions after simulator
changes; any new simulator source requires an explicit ownership audit.

Use the same player-facing engine handlers in the same order, including purchase
confirmation and map-placement validation. Calling lower-level commit methods is
not equivalent. Both drivers must advance complete shared engine ticks; display
interpolation is presentation only. Verify fractional frames and catch-up batches
against individual ticks, and compare native display-clock play with headless
replay. BattleEngine derives difficulty and selected upgrades from BattleContent;
adapters must not supply independent tuning arguments.

# Standard build process — explicit authorization required

Standing user instruction (September 11, 2026): Keep a standard, native Xcode compilation process. Never introduce compiler or build-system workarounds, wrappers, shims, toolchain substitutions or patches, or process-killing/retry automation to get a build through an error or hang unless the user explicitly authorizes that specific workaround in advance. A general request to fix a build or make the workspace compile is not authorization for any such change.

Investigate the root cause, report the evidence and propose a normal fix. Do not silently bypass failures or change compiler/build-system behavior. If a build requires manual intervention, disclose it; do not present that result as an ordinary successful build.

# Player state comes only from the bundled database

Standing user instruction (September 16, 2026): every new installation/update must overwrite all previous player state with exactly the authored bundled database. The game currently refreshes that database on every process launch; preserve that behavior. Hero selections, settings, difficulty and HUD configuration must come from SQLite. Never restore or merge prior `UserDefaults`, `AppStorage`, saved preferences or other parallel state over the fresh database. Remove obsolete preferences without importing them. Treat a failed database refresh or missing required seed as an error, not permission to reuse old state or invent replacement values.

# Starting money authority

Standing user instruction (September 17, 2026): the temporary Charleston experimentation budget has ended. Every campaign level's starting money is authored only in its SQL `level_info.starting_money` field and loaded through `LevelInfoDAO`. Preserve this single source for campaign entry, restarts, app relaunches and deployments; do not introduce Swift budgets, overrides or fallback values.

# Game art and rendering reviews

Standing UI correction (September 16, 2026): prefer non-text graphics whenever they can communicate the action or state. Do not add visible explanatory text or numeric timers where an icon or progress bar will do. Sapper preparation uses a continuous green charge-up bar that fills left to right over a black track beneath the tower; charge placement uses the tower's existing radial menu and rally-point-style flag control. Keep accessibility labels for screen readers.

Artillery level-4 menu choices use dedicated single-object emblems (mortar, swivel gun, heavy cannon), not reduced full emplacement/crew sprites. Keep the three silhouettes distinct at the smallest menu size and check them with the real price label and frame. All tower-menu icons must use one shared inset, defined only in TowerMenuLayout.iconInsetFraction and applied through TowerMenuIcon. Do not add per-tower sizes, offsets, or extra transparent padding; the previous oversized artillery exception was rejected.

The demolition-charge tower is level-4 branch 3 of the internal Special category. Artillery level-4 branch 4 uses slow, long-range solid shot that travels straight through enemies, each struck once, with morale shock.

New sapper towers begin with a ready, unplaced charge. Pulse the tower to indicate readiness; do not add a separate readiness icon. The user found the former 6% pulse too subtle: use a clearly visible, smooth pulse. The on-map sapper emplacement must fill the tower slot width and include a prominent engineer soldier; the former crouching worker disappeared behind the keg at phone size. Never automatically choose its first site or start a cooldown on first placement. The placement menu button belongs at bottom center, matching the melee rally-point seat. The armed ground charge needs a broad, easily visible blinking red light; the former 7-point light was too small on the phone.

Standing UI correction (September 16, 2026): use direct manipulation and action–object proximity. Object-specific actions belong on the object or at the place where the action happens, with the touch target aligned to the visible object. Demolition charges now detonate automatically just before a forward-moving enemy exits the far side of their blast radius along its own path; remove tap-to-detonate interaction. The charge-up bar belongs on the tower. Do not add a detached floating detonation button or a duplicate in the tower menu. Verify the actual interaction as well as rendering.

**Before any visual or graphics work, start with what reads immediately at the smallest actual gameplay size.** Build simple, bold shapes first; remove or merge detail that requires close inspection. Tiny dashes, gaps, ticks, fragments, and texture must not carry essential information. This constraint comes before drawing or implementation.

September 15 user correction: morale uses a solid continuous cue, with no segmentation or tiny breakaway fragments. Repeated screenshot reviews failed to reveal how unreadable those details were on the phone. User feedback overrides those reviews. Verify absolute visibility separately from relative HP/morale prominence, including nearby units and motion; native rendering is not proof of user recognition or acceptance.

The blue morale fill must represent the amount remaining: it shortens after damage over a fixed dark track and stays depleted until actual recovery. A fixed-length blue curve or a white hit flash does not communicate morale loss. Simplifying a visual must preserve the gameplay information it carries.

Standing art direction: all game art uses **Bastion (2011)** as its overall color and illustrated/painterly style guide, with American Revolutionary War subject matter and Kingdom Rush-like clarity at small sizes. Use broad vivid color masses and distinctive silhouettes; simplify details that disappear at gameplay size. Apply this throughout the game. The persistent brief is `../in-defense-of-history-data/ArtReadability/ART_DIRECTION.md`.

For art creation, revisions, or changes affecting on-screen art size, read `../in-defense-of-history-data/ArtReadability/small-game-art/SKILL.md` and its project workflow. If this checkout is elsewhere, the asset workspace is `/Users/john/projects/td/in-defense-of-history-data/ArtReadability`.

All game art must remain highly recognizable at its smallest actual gameplay size. Use the calibrated readability lab, inspect the small proof before enlargements, and save the review evidence before calling an asset finished. Do not use the old fixed 58-pixel hero preview as an acceptance test.

# Physical-device workflow

Do not use iOS Simulator for this project, including auxiliary UI measurement probes. The game's Metal 4 runtime does not run in Simulator. Build, deploy, run, and verify gameplay on the user's physical iPhone. Obtain platform UI dimensions from published references or physical-device measurements. Host-side Swift tests and geometry/art rendering tools remain appropriate when they do not launch Simulator; do not present their output as on-device gameplay verification.

# Enemy content

Enemy display names, descriptions and artwork names are authored only in
`Db/DML/enemy_types.sql` and loaded from SQLite. Use stable enemy keys or UUIDs
in code, waves and saved editor maps; never duplicate display-name literals or
derive artwork names from them. The design roster must use the database too.
Run `python3 Tools/enemy_content.py check` after enemy-content changes; use its
`export` command to obtain marketing copy instead of maintaining another roster.

# Level editor regression checks

For changes under `LevelEditor/`, run `Tools/check_level_editor.sh` and build the
macOS `LevelEditor` target before reporting completion. The check covers erasing,
gesture commit/cancel, keyboard input, native/GeoJSON persistence, hero starts,
and call-wave markers using fixed fixtures. AppKit keyboard tests need a normal
macOS window-system session; they create hidden test windows. Add a regression
case for an editor bug in the actual shared handler/model, rather than copying
the implementation into a test. Report test failures and any unverified live UI
behavior explicitly.
