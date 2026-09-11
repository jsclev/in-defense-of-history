# Provisional hero rankings

Research date: September 9, 2026.

`ranking` is an integer from **1 to 100, with higher numbers better**. These are
editorial estimates of Revolutionary War military effectiveness and impact:
battlefield performance, leadership, engineering, training, logistics, and the
scope and consistency of a person's contribution. The numbers are provisional
game design judgments, not ratings supplied by historians. A one-point difference
does not imply historical precision. Rankings determine the primary and secondary
roles of chosen heroes and their HUD order. They do not modify combat stats or unlocks.

All 15 heroes in the current roster have explicit values, including the default
selected pair, Henry Knox and George Washington. Rough anchors are 90–100 for
exceptional influence or effectiveness, 80–89 for major commanders and specialists,
70–79 for strong but more limited contributions, and 60–69 for meaningful service
with a narrower, uneven, or less securely documented record. The roster already
contains distinguished figures, so it need not fill the entire scale.

| Hero | ranking | Reasoning and historical source |
| --- | ---: | --- |
| George Washington | 98 | Sustained the main army through repeated setbacks, restored morale at Trenton and Princeton, and led through Yorktown. Broad command responsibility gives him the highest initial score. [NPS biography](https://www.nps.gov/people/georgewashington.htm). |
| Nathanael Greene | 95 | Effective supply administration and command of the Southern Department helped recover the American position after Camden. His sustained campaign impact places him near Washington. [NPS biography](https://www.nps.gov/people/nathanael-greene.htm). |
| Daniel Morgan | 93 | Cowpens demonstrated exceptional understanding of troops, terrain, and the opposing commander. His tactical effectiveness earns a very high score, with a narrower command scope than Washington or Greene. [NPS, Daniel Morgan](https://www.nps.gov/cowp/learn/historyculture/daniel-morgan.htm). |
| Henry Knox | 92 | Moved captured artillery to Boston and developed and commanded the army's artillery through Trenton, Princeton, and Yorktown. Combines specialist excellence with sustained army-wide impact. [NPS, Brigadier General Henry Knox](https://home.nps.gov/york/learn/historyculture/knoxbio.htm). |
| Friedrich von Steuben | 91 | Standardized training, tactics, and organization at Valley Forge; his regulations extended the effect across the army. This rewards the effectiveness he enabled in other soldiers. [NPS, Steuben's Regulations Book](https://www.nps.gov/vafo/learn/historyculture/steuben_regulations_book.htm). |
| Benedict Arnold | 90 | His important role in the American victory at Saratoga supports a high assessment of his battlefield effectiveness. This intentionally rates his American-service hero incarnation; his later treason is outside this score, rather than silently treated as a minor penalty. [NPS, Boot Monument](https://www.nps.gov/places/boot-monument.htm). |
| Thaddeus Kosciuszko | 88 | Fortifications and use of terrain contributed to Saratoga, strengthened West Point, and supported movement and supply in Greene's southern campaign. Strong engineering impact across several theaters. [NPS biography](https://www.nps.gov/thko/learn/historyculture/kosciuszkobio.htm). |
| John Glover | 87 | His mariners helped evacuate the army from Brooklyn and cross the Delaware; his brigade also delayed the British at Pell's Point. Specialized skills had unusually large consequences for army survival. [NPS, John Glover: Sailor, Soldier, Patriot](https://www.nps.gov/articles/000/john-glover-sailor-soldier-patriot.htm). |
| Francis Marion | 86 | Disrupted British communications and supplies, sustained lowcountry resistance, and coordinated effectively with Greene and Lee. A strong regional and irregular commander. [NPS biography](https://www.nps.gov/people/francis-marion.htm). |
| Louis Duportail | 85 | Chief engineer whose planning and conduct of the Yorktown siege earned Washington's praise. A major specialist contribution to a decisive victory. [U.S. Army Corps of Engineers, Battle of Yorktown](https://www.usace.army.mil/About/History/Historical-Vignettes/Military-Construction-Combat/102-Battle-of-Yorktown/). |
| William Prescott | 78 | Commanded the Bunker Hill redoubt, encouraged troops under bombardment, and helped make the British assaults costly. Strong demonstrated local command with a more concentrated impact. [NPS, Prescott Statue](https://home.nps.gov/places/bunker-hill-prescott-statue.htm), [NPS, William Prescott](https://home.nps.gov/articles/000/william-prescott.htm). |
| Israel Putnam | 74 | Courage, popularity with soldiers, and leadership at Bunker Hill are balanced against tactical criticism after Long Island and diminishing responsibilities. [NPS biography](https://www.nps.gov/people/israel-putnam.htm). |
| Salem Poor | 70 | Fourteen officers formally commended his bravery at Bunker Hill, and he continued serving through later campaigns. This recognizes strong individual service while keeping its scope distinct from army-level command. [NPS, Salem Poor: Patriot of Bunker Hill](https://www.nps.gov/articles/000/salem-poor-patriot-of-bunker-hill.htm). |
| Horatio Gates | 66 | Administrative ability and successful defensive command at Saratoga are offset by the severe defeat at Camden. The low initial score within this roster reflects inconsistent field performance. [NPS biography](https://home.nps.gov/sara/learn/historyculture/horatio-gates.htm). |
| Mary Hays | 62 | Accounts associate her with water carrying and artillery service at Monmouth. The narrower documented role and uncertainty separating Mary Hays from the composite Molly Pitcher tradition make this the least certain estimate. [National Women's History Museum biography](https://www.womenshistory.org/education-resources/biographies/mary-ludwig-hays), [NPS, The Truth Behind the Legend](https://www.nps.gov/planyourvisit/event-details.htm?id=13AB0F72-E8F5-4C2B-DDACC167F62EF9F7). |

The Arnold treatment and comparisons between individual soldiers, specialists,
and army commanders are useful questions to revisit when defining the eventual
game mechanic. No separate loyalty or historical-confidence field is introduced.

## Storage and revision

- The `hero.ranking` column in `Db/DDL/create_tables.sql` requires an integer in
  the inclusive range 1–100; omitted, null, fractional, and out-of-range values fail.
- Each `Db/DML/Heroes/*.sql` insert provides its hero's value. These scripts already
  run through `Db/create_db.sh`; editing a seed and rebuilding updates the value.
- `Hero.ranking` is a public `Int`, loaded by `HeroDAO.getAll()` and included in
  the model's synthesized `Codable` support. For example:

  ```swift
  let heroes = try db.heroDao.getAll()
  let ranking = heroes.first { $0.shortName == "Henry Knox" }?.ranking
  ```

The current app refreshes its content database from the bundle at startup
(`Engine/Core/Store.swift`), so ship a rebuilt database alongside the updated DAO.
There is no separate persistent-database migration system in this change.

## Chosen heroes and roles

`HeroSelection` represents exactly one or two distinct heroes. Its `primary` hero
has the higher ranking, and its optional `secondary` hero has the lower ranking.
For equal rankings, the lexically smaller UUID is primary. This tie-breaker is
stable across clicks, SQL row order, saves, and reloads. A single hero is always
primary. Removing one member of a pair promotes the remaining hero; the last
chosen hero cannot be removed. Choosing a third hero replaces the current
secondary and recalculates roles.

`HeroDAO.getSelectedHeroes()` returns that model, and `getSelectedHeroIds()`
returns primary-first IDs using the current database rankings. `setSelectedHeroes`
validates the complete choice and atomically saves primary in slot 1 and secondary
in slot 2. Invalid input or a failed insert leaves the previous choice intact.
`Db/DML/selected_heroes.sql` also derives its slots from ranking. Stored slots
record order when saved; editing a ranking takes effect on the next DAO read
without requiring slot edits.

`HeroSelectionStore` keeps the existing `selectedHeroIDs` preference and database
selection synchronized, restoring the player's choices after a content refresh.
It normalizes old ordering, invalid IDs, and duplicates. If neither preferences
nor database contain valid choices, it chooses the first unlocked roster hero.
Existing explicit SQL/saved choices are retained even when their unlock flag is
off; selecting an additional hero through the menu still requires it to be unlocked.

`LevelRunner` deploys the player's choices using the level's GeoJSON capacity
and role assignments on exits. Levels 1–5 deploy only the chosen primary; levels
6–15 can deploy both. With one chosen hero, only primary is deployed on any level.
`heroSelection`, `primaryHero`, and `secondaryHero` describe the deployed lineup;
`chosenHeroes` retains the full menu choice. The legacy `level_hero` records no
longer determine runtime heroes or their positions. Dead heroes retain their
roles and HUD slots until they respawn. Hero details show the chosen role, and
HUD accessibility labels include role, name, and ranking. See
[hero exit configuration](hero_exit_spawns.md) for the GeoJSON contract.
