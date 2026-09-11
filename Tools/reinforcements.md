# Reinforcement timing

## Button artwork

`HudHeroesBarView` uses `ReinforcementButton`, which loads the named catalog asset
`action_icon_call_reinforcements`. Its 1×/2×/3× PNGs now contain the crossed-sword
emblem from `../in-defense-of-history-data/HUD/CallReinforcements/Revisions/2026-09-09-emblem-v3`.
The production catalog remains `../in-defense-of-history-data/LibertyLineAssets.xcassets`.
The button retains its existing sizing, selection, placement action and cooldown behavior.

The September 9 integration verified exact source/catalog hashes, 30 pixel-identical
host SwiftUI button renders, and a successful physical-iPhone-targeted build. The
compiled rendition digest matches a separate compilation of the approved HUD source.
Evidence is in `../in-defense-of-history-data/HUD/CallReinforcements/Reviews/production-integration-2026-09-09`.
Installation of that build on the iPhone is pending user approval.

## Timing configuration

`reinforcement_config` contains one row (`id = 1`) with independent values in
game seconds:

| Column | Starting value | Behavior |
| --- | --- | --- |
| `time_to_live_seconds` | 20 | Removes the entire deployed group after this duration. |
| `cooldown_seconds` | 20 | Blocks another deployment until this duration has elapsed. |

Edit `Db/DML/reinforcement_config.sql` for seed values. `Db/create_db.sh` includes
the seed during a rebuild. The current `Db/in_defense_of_history.sqlite` also
contains this configuration, and it has been verified in the built iPhone app.
The app's existing `Store` refreshes its database from the bundle on launch;
this change does not alter that policy. No timing defaults are substituted by
the runner if database configuration is missing or invalid.

For a working database, tune the values independently, for example:

```sql
UPDATE reinforcement_config
SET time_to_live_seconds = 30, cooldown_seconds = 20
WHERE id = 1;
```

Configuration loads when entering a level. Both timers use the same simulation
ticks as combat, including before wave 1: pause/backgrounding freezes them and
speed-up accelerates them. Positive fractional seconds are supported and round
up to the next game tick. Each deployment has its own expiration deadline, so
a lifetime longer than the cooldown allows overlapping groups.

Expired groups are removed before walkers advance. Their combat data and cached
sprite positions are discarded, their enemies are released, and the published
sprite list updates even when the last group disappears. Tower garrisons and
heroes remain. A group's dead/respawning members cannot return after its expiry.

The lower-left HUD button shows rounded-up seconds remaining in a badge that moves
from top to bottom. A dark overlay recedes down the icon; the icon stays gray
during cooldown and returns to color when ready. The frame retains its color.
The button stays disabled throughout cooldown, and the runner independently
rejects repeat calls without changing any deadlines. Tap the HUD button to arm
placement, then tap a path to deploy. Tapping the button again cancels without
starting cooldown. Invalid destinations do not deploy or spend the cooldown.
Ordinary path taps do nothing. The temporary destination layer leaves the HUD
corners tappable and is removed on placement/cancellation. Countdown rendering
stays within the fixed HUD button bounds.

Validation:

```sh
swift test --scratch-path /tmp/td-presentation-tests --filter 'ReinforcementTests|LevelViewportTests|PresentationStackTests'
python3 Tools/check_reinforcement_runner.py --output Tools/reports/reinforcements-2026-09-08
```

The runner probe extracts the current deployment/expiration/publishing methods
and links the production Engine with isolated level/tower/hero/clock fixtures.
It covers repeated taps, expiry of the final group, independent overlapping
groups, sprite/cache cleanup, release of blocked enemies, expired respawns, and
preservation of tower soldiers and heroes. It does not launch the full game.

The existing readability lab's saved report is
`../in-defense-of-history-data/ArtReadability/reports/reinforcements-2026-09-08/`.
It uses production SwiftUI button rendering at 49.3pt with 1x/2x/3x exports;
seven points of transparent padding on each side give a 63.3pt proof box.
Physical-device gameplay remains unmeasured.
