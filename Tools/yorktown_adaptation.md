# Yorktown finale: decision and deferred adaptation

Decision recorded October 3, 2026: use **Yorktown** as the displayed name for
level 15, the main campaign finale, and preview that name change. The present
scope is the displayed name and preservation of replay identity; retain the
existing map, artwork, dates, routes, tower slots, waves, enemies, boss,
starting money, lives, unlocks and gameplay.
The Yorktown adaptation below is a proposal saved for later, not implemented
behavior. The retained Charleston content is not a historical Yorktown scenario.

Keep the level's stable UUID, `4ca73a47-98f6-41b6-815d-c2c797aa746e`. Internal
identifiers and filenames such as `level_15_charleston`,
`Db/DML/Levels/level_15_charleston.sql`, `Db/level_15_charleston.geojson`,
`Db/level_15_charleston.tdmap`, the wave SQL and its generator intentionally
retain their Charleston names during this limited change. A displayed name
change does not require an identity migration.

The authored `level_replay_identity` retains `Charleston` solely for the full
replay and GA content fingerprints. This prevents the displayed name change
from invalidating otherwise identical saved evidence. All gameplay fields
remain part of those fingerprints; no saved evaluation or context SHA is
rewritten. The replay identity is separate from the player-facing name and
does not make changed battle content compatible with old recordings.

Verification limitation: first-wave changes already present before this rename
make the shipped GA demonstrations stale. Preserving the replay identity does
not resolve that pre-existing content mismatch, and refreshing demonstrations
is outside this name-change and deferred-adaptation task.

Charleston remains a candidate for later reuse. Whether it belongs elsewhere in
the main campaign or in a mini campaign is **undecided**. This decision does not
delete Charleston or assign it a new campaign position.

## Historical basis

The Americans and French besieged the British army at Yorktown. Within that
offensive operation, their siege works needed protection. On October 16, 1781,
British troops made a sortie against the Allied guns and attempted to spike
them. It did not stop the bombardment for long. This documented action supplies
a defensive tactical objective without reversing the sides in the siege.
[NPS: Chronology of the Siege of Yorktown](https://www.nps.gov/york/learn/historyculture/siegetimeline.htm)
and [NPS: History of the Siege](https://www.nps.gov/york/learn/historyculture/history-of-the-siege.htm).

Mount Vernon's account describes a sortie of approximately **350 British light
infantry and grenadiers**, with no lasting result. The British surrender followed
on **October 19, 1781**. Treat the sortie and surrender as separate events, with
the historical aftermath connecting them; the British did not surrender at the
instant the October 16 raid ended.
[Mount Vernon: Now or Never transcript, chapters nine and ten](https://mtv-main-assets.mountvernon.org/files/resources/now-or-never-transcript.pdf).
Yorktown provides the campaign's decisive climax, not a claim that all fighting
ended there; the peace treaty followed in 1783.
[Mount Vernon: Yorktown Campaign](https://www.mountvernon.org/library/digitalhistory/digital-encyclopedia/article/yorktown-campaign).

## Proposed play sequence — deferred

1. Draw Allied siege batteries at the route exits, with their large guns facing
   Yorktown. The player's task is to protect the approaches to those batteries.
2. Bring British attackers out from the town's defenses toward the batteries,
   representing parties trying to disable the Allied guns.
3. Use the existing infantry blockers, rifles, artillery and engineers to defend
   the approaches. The player remains part of the besieging Allied army while
   fighting a defensive action within its siege lines.
4. Let enemies that reach an exit cost the existing lives, representing damage
   or disruption at the batteries. This is an abstract loss condition, not
   individually simulated cannon damage.
5. After the final attack, present the historical aftermath and the October 19
   surrender. Preserve the distinction between surviving the October 16 sortie
   and the subsequent surrender of Cornwallis's army.

Dividing the documented sortie into game waves is a deliberate adaptation.
Fifteen waves must not be described as fifteen documented mass assaults.
Authored routes, force sizes, timing and tactical combinations would also need
to be presented as gameplay choices rather than a literal reconstruction.
The existing Clinton boss and Charleston-specific forces remain unchanged in
the name preview; their historical suitability must be addressed separately
before calling a future adaptation complete.

## Existing mechanics and future work

The current shared `BattleEngine` already supports routed enemy waves,
infantry blocking, ranged fire, artillery, engineer obstacles and demolition
charges. Reaching a route endpoint removes lives; zero lives means defeat.
Clearing all started waves and remaining enemies means victory. These mechanics
can support the proposed battery-protection framing. The present level's two
entrances, two exits, six routes, 19 tower slots and 15 waves are documented in
[charleston_waves.md](charleston_waves.md).

The current towers do not have individual health, and their weapons target
enemy units. A drawn battery at an exit would be an objective represented by
the existing lives system. It would not create a functional siege gun that
fires on and destroys the town. The relevant existing behavior is in
[`BattleEngine.swift`](../Engine/Models/BattleEngine.swift), particularly
`PlacedTower`, `advanceWalkers`, `loseLife`, `advanceBattleTick` and
`updateCombat`.

Individually damageable or spikable guns, repairs, bombardment progress,
capturing redoubts and unlocking forward tower positions would require new
mechanics. None is part of the current name-change scope. Likewise, new siege
artwork, attack routes, waves, enemy or boss content, historical dates, and a
surrender presentation remain future work. Any later implementation must use
the authored database and shared engine, and be verified before it is reported
as playable or historically adapted.
