Every evaluated candidate is kept in `ga_candidate`, with its full strategy and
per-battle results in the related `ga_*` tables. `genetic_solution` only marks
selected candidate/panel keys; it never replaces or deletes the complete archive.
`genetic_solution_recording` links separate demonstration results to playback.

**All candidates:** run `all_candidates.sql` against the complete study database.
The corrected run contains **14,342** candidates and **44,562** battle results;
every evaluation has saved placement fields. The query returns every candidate
in training-fitness order, including losers,
with no shortlist filter or row limit. `ga_candidate_fitness` is the queryable
view of their fitness components. Its `strategy_id` connects to `ga_decision`,
`ga_meta_upgrade`, `ga_early_wave` and `ga_strategy` for the complete makeup.
The bundled phone database contains only the imported catalog, not the full study.
`candidate_diversity.sql` lists every complete winning candidate in fitness order,
with its initial-layout difference and next-five-placement difference from the
top winner in the same run, panel and star budget. It needs no parameters.

To see the three Charleston solutions selected for the phone bundle, run
`top_solutions.sql` as-is. It needs no parameters and returns candidates **10585,
11442, and 12886**, ranked by their original held-out results. Each won **64/64**
validation battles; their full-study fitness ranks are **4, 19 and 20**.
The full study is preserved at
`/Users/john/bin/liberty-line-simulator-1.0.234-run-20260929-193129-1074207D-C6F1-4EA3-82C5-BC32284B9D15.sqlite`
(run `F486C197-4FBD-4C72-BC30-18B17A25B085`).

| Candidate | Actual opening | Held-out mean lives |
|---|---|---|
| 10585 | 3 artillery, 2 engineers, 1 musket tower | 19.547 |
| 11442 | 3 artillery, 2 engineers, 2 supply carts | 14.906 |
| 12886 | 4 artillery, 1 engineer, 2 militia towers | 13.750 |

**Player-rejected recommendations:** all three movies above were judged too
similar: they reuse the artillery/engineer opening. Their old comparison passes
were a false positive, not evidence of useful variety. The revised comparison
keeps these as permanent negative regression fixtures and vetoes their shared
core. The phone catalog has not been replaced by this comparison-only change.
The rejected artillery/ranged phone selections and their original recordings
remain preserved in their previous run and in
`/Users/john/bin/ga-publication-backups/20260929-before-rangers`.
This study includes Queen's Rangers and their shared-engine concealment behavior.

```sh
sqlite3 -readonly -header -column \
  /Users/john/projects/td/in-defense-of-history/Db/in_defense_of_history.sqlite \
  < /Users/john/projects/td/in-defense-of-history/Db/Queries/GA/top_solutions.sql
```

Remove the `candidate_id` filter and change `LIMIT 3` to see more candidates in the run database. The bundled
database contains only those three candidates from this study. To query another
study, use `studies.sql` to find its run ID and edit the literal `run_id`,
`candidate_id` and `stars_used` filters in `top_solutions.sql`. Change `panel` to `'training'` to
inspect training results; keep those distinct from held-out validation.

To inspect what those candidates actually contain, run these without parameters:

- `candidate_openings.sql`: one row per saved candidate and panel, in original
  fitness order, with the actual opening mix, participating opening towers,
  exact slots and next five successful builds. Includes every candidate,
  including losers; evidence flags distinguish empty lists from unknown data.
- `candidate_makeup.sql`: one row per candidate in fitness order, with all
  planned tower branches/slots, level-up steps, ability upgrades, campaign
  upgrades, reinforcement settings, wave rules and heroes.
- `candidate_similarity.sql`: pairwise counts of matching tower slots, campaign
  upgrades/star spend and wave rules, plus reinforcement-policy agreement.
- `top_candidate_actions.sql`: every planned purchase in fitness/priority order,
  with exact timing, wave gates and save-for-purchase flags.

These return the three bundled candidates or all 24 validated candidates in
the completed study. Tower plans are intended branches and purchases; some may
never execute. Similarity counts describe specific components, not a single
gameplay-equivalence score. The publication command additionally uses
`GeneticSolutionDiversitySelector` to choose different winning playstyles using
the paid opening core and sustained damage/control roles. It compares every
alternative against the whole selected set and keeps original fitness unchanged.
The old position and five-build counts are diagnostics only. Comparison uses
saved data without simulation or replay. Full eligibility is described below.
`candidate_placements.sql` exposes the exact input: successful builds before wave
one and the first five successful later builds. Tower IDs describe the starting
tower type, not a possible future branch. New evaluations save these facts in
`ga_placement_plan` and `ga_placement`; opening diagnostics read those fields; the full selector also reads playstyle evidence.
Old evidence without these fields reports unknown, never an inferred layout.
Explicit offline recovery can extract them from existing stored tower changes
without running a battle; `source_recording_id` identifies that provenance.
The earlier 14,229-candidate study and its original recordings remain preserved
in their separate run databases. Selecting three phone demonstrations never
removes any candidates or evaluations from either study.

Other queries below have named parameters where indicated; bind those in your
SQL client before running them. Unbound optional parameters are NULL.

| Query | Purpose | Required parameters |
|---|---|---|
| `studies.sql` | Runs, budgets, progress, evaluation totals | none |
| `all_candidates.sql` | Every saved candidate in fitness order, with links to its makeup | none |
| `candidate_openings.sql` | Fitness-ranked actual opening mixes, slots and next five builds | none |
| `candidate_diversity.sql` | Fitness-ranked winners and exact diversity counts against the top winner | none |
| `candidate_placements.sql` | Saved initial layout and subsequent placements for every candidate | none |
| `candidate_playstyles.sql` | Actual purchases and phase-by-phase tower activity, including blocking, slowing and income, in original fitness order | none |
| `configuration.sql` | Captured settings, heroes, seeds, star budgets and tower limits | `run_id` |
| `top_solutions.sql` | The currently installed Charleston movies in original fitness order | none |
| `candidate_makeup.sql` | Complete strategy makeup in held-out fitness order | none |
| `candidate_similarity.sql` | Pairwise structural agreement, with explicit counts | none |
| `top_candidate_actions.sql` | All validated candidates' exact purchase plans in fitness order | none |
| `retained_solutions.sql` | Retained catalog and demonstration links | none |
| `candidate_actions.sql` | Ordered purchases, meta upgrades, reinforcement and wave policies | `run_id`, `candidate_id` |
| `evaluations.sql` | Original per-seed outcomes | `run_id`, `candidate_id` |
| `evaluation_details.sql` | Wave economy, fates, purchases, reinforcement and wave-call receipts | `evaluation_id` |
| `compare_candidates.sql` | Side-by-side results paired on the same seed | `run_id`, `candidate_a`, `candidate_b` |
| `checkpoints.sql` | Population selections and ordered archive membership | `run_id` |
| `storage.sql` | Allocated space per GA table/index | none |
| `check_integrity.sql` | SQLite integrity, foreign keys, missing samples/children | none |
| `retention.sql` | Add an existing evaluated candidate to the retained set | `run_id`, `candidate_id`, `panel` |

`top_solutions.sql` ranks the three currently published candidates; remove its
candidate filter to inspect all complete candidates in the selected panel.
The publication step additionally removes exact duplicate strategies. Rank only within a common
run, panel and star budget. Original fitness uses complete-level win rate,
victory lives averaged over **all** samples, mean waves reached, then mean
survival seconds on **defeats**. Candidate ID breaks ties. Demonstration outcomes
never enter this ranking. Seed columns use decimal TEXT so the entire UInt64
range is exact; gameplay numbers are SQLite REAL (Double), not rounded strings.

DDL is in `Db/DDL/create_genetic_solutions.sql`,
`Db/DDL/create_genetic_studies.sql`, `Db/DDL/create_genetic_placements.sql` and
`Db/DDL/create_genetic_playstyles.sql`; the exact ranking view is in
`Db/DDL/create_genetic_fitness.sql`. All are loaded by `Db/create_db.sh`. Fresh GA studies
save no JSON report documents. Optional `--report-dir` JSON exports and worker
IPC remain interchange formats. Authored GeoJSON maps and non-GA study/report
formats are separate from this schema.

Convert a completed legacy invocation **to a new file**:

```sh
python3 Tools/ga_relational.py /path/to/old-run.sqlite /path/to/new-relational.sqlite
```

The converter opens the source read-only, takes a consistent SQLite snapshot,
loads the authored DDL, and verifies exact candidate/evaluation round trips and
unchanged playback bytes. It refuses to overwrite an existing destination or
convert an active study. The original remains available, including its original
report documents. GA copies of candidate/population/validation/report JSON are
removed from the converted file after their structured data has been migrated;
content tables and map bytes already carry the captured battle inputs. Legacy
fields never recorded (such as search stop reason) are NULL, never invented.
Unsupported algorithms or missing retained context fail explicitly and preserve
the source. This is an offline conversion, not work performed during a GA run.

Do not edit original fitness evidence to change a ranking. Keep experiments in
new invocations and use SQL transactions with `PRAGMA foreign_keys=ON`. No query
here deletes study evidence or saved playback.

The placement queries require `Db/DDL/create_genetic_placements.sql`. For the
September 28 study, the preserved original relational database has a separate
copy beside it ending in `-relational-placements.sqlite`. Eight demonstrated
validation candidates have recovered placement fields there; the other old
candidates remain explicitly unknown. Apply schema extensions only to a copy,
then use `LibertyLineSimulator --recover-ga-placements <copy.sqlite>` for existing
recordings. This reads stored tower changes; it does not run combat or alter scores.

Creative playstyle evidence (`genetic-v10` and `genetic-v11`) is stored in `ga_playstyle`,
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

Breeding protects the global champion and material opening-family champions,
including roles still learning to win. A protected role can mate within its own
family coverage. Half of parent picks sample representatives directly; the rest
use the existing fitness tournament. Creative openings explore every unlocked
family; fresh proposals enter each subgroup every eighth generation. Finalists
cover playstyles within the best observed training win-rate band, reserve one
third of seats for successful campaign-upgrade alternatives, and can include
multiple plans with the same upgrades. They are frozen before validation.
Original fitness, all candidates, seeds, engine rules and evidence remain intact.
