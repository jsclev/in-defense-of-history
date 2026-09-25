# Balance analyzer

The dedicated `--balance-study` command audits saved GA solutions and searches
for a single-tower-family exploit. Build the macOS `Simulator` scheme normally
in Xcode (Release). This tool uses the same genetic player DNA, crossover,
mutation and shared game engine as the main GA, with a fixed meta selection.

The first study targets ranged towers. Heroes are disabled in every training,
validation and frozen-plan replay. All marksmanship upgrades are selected from
the DAO catalog; other database-selected upgrades remain selected. Insufficient
earned stars fails explicitly. Reinforcements and early wave calls remain
enabled, unless `--no-early-wave-calls` is explicitly supplied. This means
"ranged only" restricts built towers, not reinforcement soldiers.

Starting money always comes from `LevelInfoDAO`; there is no budget sweep.
The analyzer uses the database's difficulty, unlocks, prices and other rules.
It never publishes experiment winners into the game's solution catalog.
Historical top plans are audited for single-family concentration and full-slot
coverage. Their old money, hero settings and content fingerprint are recorded;
old wins are leads, never treated as wins under the new experiment conditions.
Purchase-plan composition is labeled separately from the towers actually built
in each new battle.

## Run a baseline

```sh
/path/to/Simulator --balance-study Charleston \
  --population 16 --generations 100 --training-seeds 3 \
  --finalists 2 --validation-seeds 64 --max-evaluations 10000 \
  --balance-hours 0.25 --report-dir /private/tmp/charleston-balance
```

The time and evaluation budgets cover the entire study and are allocated equally
to stages. Every scenario has ranged-only and unrestricted search stages; each
variant also has a frozen-baseline replay stage. Search uses 80% of a stage's
time and reserves the rest for held-out validation. An admitted whole battle can
finish after its deadline. Incomplete panels are recorded and labeled; a timeout
is not evidence that ranged towers cannot win. This first implementation runs
one native worker and rejects `--workers` values other than 1.

## Supply variants

Pass `--balance-scenarios /absolute/path/scenarios.json` with a JSON array.
The baseline is inserted automatically; scenario IDs must be unique and cannot
be `baseline`. Separate damage-only, composition-only and combined cases to
distinguish their effects. For example:

```json
[
  {"id":"damage-85","rangedDamageMultiplier":0.85,"replacementFraction":0,"enemyKeys":[]},
  {"id":"cover-speed-25","rangedDamageMultiplier":1,"replacementFraction":0.25,
   "enemyKeys":["hessian_jager","light_dragoon","regimental_drummer"]},
  {"id":"combined-85-25","rangedDamageMultiplier":0.85,"replacementFraction":0.25,
   "enemyKeys":["hessian_jager","light_dragoon","regimental_drummer"]}
]
```

These are explicit experiment choices, not another enemy or tower catalog.
Keys must resolve in `enemy_type`. Each wave deterministically replaces the
specified fraction of individual spawns, rounded down, cycling through the
requested keys. The report gives actual enemy counts, including replacements
that chose an already-present type. Per-enemy scheduled times and paths, total
counts, wave clocks and early-call bonuses stay fixed. Enemy stats, rewards and
lives costs follow their authored types; composition changes can therefore
change total available bounty. No compensating money adjustments are applied.

Damage factors multiply `tower.shot_min_damage` and `shot_max_damage` for every
ranged tier/branch in a disposable in-memory SQLite copy. Ability and meta
multipliers remain authored and are applied by the shared engine. Other damage
effects, morale, reload times and prices are unchanged. Normal DAOs validate
the original and load the changed copy; missing or malformed content fails.
The authored SQL and campaign content are not modified.

## Read the evidence

`balance-report.json` contains the historical audit, exact configuration,
content/executable hashes, per-scenario counts, frozen finalist DNA, engine run
IDs, seeds, outcomes, built tower counts and paired life/win comparisons. Each
scenario also exports its content snapshot as JSON. Every battle and search
panel is recorded through DAOs in the existing SQL-defined result tables.
Keep reports outside the checkout. A new run requires a new report directory.

Variants run only after a held-out ranged-only baseline wins. Each variant
first replays the frozen baseline finalists on matching validation seeds, then
searches again so a mere change in optimal build order cannot hide the exploit.
Historical and baseline plans seed adaptation, alongside fresh plans. Finalists
are chosen using training seeds only and keep that ordering in the report;
validation scores never select parents or the champion used for comparisons.

A variant remains vulnerable if any ranged training, validation or frozen replay
wins. It is a candidate for deeper validation only when complete, timeout-free
ranged panels have no wins and an unrestricted held-out win actually built at
least two tower families. Otherwise the result is inconclusive. Compare the
reported generations and distinct evaluated plans: equal caps or time allocations
do not guarantee equal search effort. None of these outcomes proves that winning
is impossible. Repeat promising cases with larger populations, independent GA
seeds and fresh validation seeds before changing authored balance.
