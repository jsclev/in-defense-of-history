Wave 1 displays its call button immediately and waits indefinitely for a double-tap.
Every call-wave button requires a double-tap; a single tap does not call a wave.
For every later wave, `level_wave.call_button_delay` is the number of game
seconds from the previous wave's **actual start** until the call button appears.
`level_wave.auto_start_countdown` is how long that button remains available.
At the deadline the wave starts and its button disappears. A zero countdown
starts the wave at the reveal deadline without showing a button. Both fields
must be nonnegative.

`level_wave.early_call_bonus` is the fixed money award for manually calling
that wave. Double-tapping an available call button after wave 1 immediately
adds that wave's bonus to the player's money. The first wave, automatic starts,
expired calls, and repeated calls receive no bonus. The amount does not shrink
as the countdown runs down. A value of zero disables the bonus for that wave.

The initial seed is 0 for the first wave and 13 coins for each later wave.
A published analysis of the original Kingdom Rush reports one gold per second
called early ([Game Developer](https://www.gamedeveloper.com/design/kingdom-rush---the-wonderful-campaign-level-design)).
This game's fixed 13-coin reward is a tuning choice based on its 13-second
call window, not an official Kingdom Rush per-wave reward table.

For example, a delay of 27.3 and countdown of 13 shows the button 27.3 seconds
after the previous start and automatically launches the wave at 40.3 seconds.
Double-tapping it at 30 seconds starts it immediately; the following wave's delay
then runs from that actual 30-second start. Wave starts can overlap existing
enemies, projectiles, and pending spawns. Clearing the map early does not
skip the timing, and victory requires every wave to start and every enemy to
be resolved.

The countdown uses simulation ticks, follows the speed control, and pauses
when the map is stopped or the app becomes inactive. Returning resumes the
same enemies, spawn queue, and remaining countdown.

Wave timing values are written directly in the `INSERT INTO level_wave`
statements in `Db/DML/level_waves.sql` and the level-specific wave seed files.
`Db/create_db.sh` invokes those files in its normal seed sequence. Edit the
`call_button_delay`, `auto_start_countdown`, and `early_call_bonus` values in the appropriate row
and rebuild the database with that script. For generated level seeds, keep
`WAVE_START_TIMING` and `EARLY_CALL_BONUSES` in the corresponding Python generator in sync.
Charleston uses `STARTS` in `Tools/generate_charleston_waves.py`; running that
generator updates its SQL, GeoJSON, and native map together. Its [15-wave plan](charleston_waves.md)
lists nominal starts and enemy counts.

Runtime reads these columns through `WaveDAO`; it does not derive tuning from
`spawn_time`. Swift contains no numeric defaults for these durations. Missing
or invalid database timing fails level loading. Legacy headless documents can
omit interactive timing, but cannot drive an interactive wave schedule without it.

The headless CPU/GPU balance simulators retain their absolute `spawn_time`
schedule; they have no interactive call-wave UI.
