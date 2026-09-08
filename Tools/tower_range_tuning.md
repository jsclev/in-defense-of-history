# Tower ranges — September 7, 2026

The original Kingdom Rush provides the proportions; Liberty Line's existing
330.48-map-unit militia rally radius provides the scale. The reference is the
[KR1 tower statistics guide's base-range table](https://steamcommunity.com/sharedfiles/filedetails/?id=2812921847).
Use its values consistently: archers 280 / 320 / 360, Rangers 400, Musketeers 470;
artillery 320 / 320 / 360, Big Bertha 360, Tesla 330; mages 280 / 320 / 360 / 400;
barracks rally range 290 at every tier. Star upgrades and special-attack ranges
are excluded. The table's numeric convention is only a reference scale, not
Liberty Line map pixels or device points.

Conversion: `map radius = reference range × (330.48 / 290)`, rounded to two
decimals in `Db/DML/towers.sql`. This makes the basic gun radius 16.62% of the
1920-unit playable width, up from 10.31%. It preserves existing militia reach
and the relative KR progression without depending on either game's resolution.

| Family / tower | Previous radius | New map radius | Reference / role |
| --- | ---: | ---: | --- |
| Musketmen | 198 | 319.08 | Archer 280 |
| Marksmen | 231 | 364.67 | Marksmen 320 |
| Riflemen | 264 | 410.25 | Sharpshooter 360 |
| Morgan's Sharpshooters | 275 | 535.61 | Musketeer 470; longest rifle reach |
| Knowlton's Rangers | 275 | 455.83 | Rangers 400 |
| Whitcomb's Rangers | 275 | 490.02 | Adapted 430; between Rangers and sharpshooters |
| All six militia / continental towers | 330.48 | 330.48 | Barracks 290; rally placement, not shooting |
| 4-pounder | 240 | 364.67 | Bombard 320 |
| 6-pounder | 240 | 364.67 | Artillery 320 |
| Howitzer | 270 | 410.25 | Howitzer 360 |
| Mortar Battery | 300 | 455.83 | Adapted 400; longer bombardment reach |
| Mobile Field Battery | 300 | 410.25 | Big Bertha 360; field support |
| Knox's Siege Guns | 300 | 501.42 | Adapted 440; longest artillery reach |
| Engineer Post | 210 | 319.08 | Mage-tier coverage 280 |
| Field Engineers | 240 | 364.67 | Mage-tier coverage 320 |
| Sappers | 270 | 410.25 | Mage-tier coverage 360 |
| Demolition Sappers | 300 | 455.83 | Mage-tier coverage 400 |
| Fieldworks Corp | 300 | 478.63 | Adapted 420; broad support coverage |
| Corps of Miners | 300 | 410.25 | Adapted 360; local work area |

The adapted branches and the engineer-to-mage analogy are Liberty Line design
choices, not claims about historical weapon distances or additional KR towers.
Engineer towers currently have no projectile / damage implementation in
`LevelRunner`; these values tune their preview / future support radius, not a
new attack. Damage, fire rate, splash radius, costs, troop leashes and rally
placement behavior are unchanged. Increased coverage will make levels easier;
campaign difficulty should be assessed separately before further stat tuning.
The focused simulator sweeps now bracket Musketmen at 280–360 and Marksmen at
320–410; the previous 100–275 intervals excluded the new defaults.

## Runtime units

Combat and simulation operate in canonical map coordinates, and both load the
same tower rows. Do not multiply stored ranges by screen scale: that would
compare screen distances against map positions and change balance per device.
`RuntimeCanvas.rangeRadius(forMapRadius:)` resolves map radius to points using
the live `scaleFactor`. Build, upgrade, debug and editor playtest rings all
require that canvas; there is no caller-supplied range scale. Safe areas,
orientation and window resizing consequently change the displayed distance
in the same proportion as the map.

The existing ring artwork has a 0.7 height/width ratio. That presentation
convention remains; combat and rally checks still use circular map distances.
The displayed horizontal radius is the actual scaled combat radius.

## Verification

From the repository root:

```sh
swiftc -module-cache-path /tmp/td-range-module-cache \
  Engine/Design/VirtualCanvas.swift Engine/Core/RuntimeCanvas.swift \
  Engine/Layout/TowerRangeOverlay.swift Engine/Models/Core.swift \
  Engine/Models/Path.swift Engine/Models/Tower.swift Engine/Models/MilitiaAI.swift \
  Engine/Combat/TargetCommand.swift Tools/check_tower_ranges.swift \
  -o /tmp/td-check-tower-ranges
/tmp/td-check-tower-ranges Db/in_defense_of_history.sqlite
```

The check reads all 24 database rows and the real virtual canvas. It verifies
upgrade progression, role ordering, unchanged rally radii, targets at / beyond
the attack boundary, and range projection on phones, tablets, portrait and
resized views. The bundled SQLite database must be refreshed when SQL changes;
the game copies it at launch. The simulator's Documents database is separate.
