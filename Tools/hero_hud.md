# Lower-left hero HUD

The three buttons are two heroes followed by reinforcements. The path popup and
its ordinary path-tap catcher have been removed. Heroes displayed on the HUD
come from the player's chosen heroes within the level's GeoJSON capacity:
primary first, optional secondary second. Levels 1–5 have one available slot;
levels 6–15 have two. Choosing only one hero leaves the secondary slot empty.
The higher-ranked chosen hero is primary and starts near the GeoJSON primary exit;
the other starts near the secondary exit. `HeroStartingPositionManager` keeps the
full sprites clear of exits and inside the runtime play area. Roles are represented
by `HeroSelection`, with stable UUID ordering for ties. A portrait selects its living unit for a
destination command; unavailable/dead units retain their slot with a gray icon.
Frames retain their color. Reinforcements retain their database-driven lifetime
and cooldown, with the countdown visible continuously on the HUD.

Portrait taps pass the displayed hero's UUID to `selectHero(heroID:)`. The runner
resolves its live unit at the time of the tap and delegates to `selectHero(_:)`,
the same method used by the map sprite. Both entry points therefore share
selection highlighting, switching, toggle-off, menu dismissal, reinforcement
placement cancellation, and the subsequent destination command. A dead or
missing hero cannot change selection; another hero dying cannot shift a portrait
to the wrong unit.

`python3 Tools/check_hero_selection.py --output Tools/reports/hero-selection-2026-09-08`
compiles the current production HUD views and runner selection methods, then
sends pointer events to both SwiftUI portrait buttons in a macOS test window.
It compares resulting state with direct map selection, including switching,
toggle-off, destination commands, death, unavailable identities, and respawn.
The probe deliberately reverses unit order relative to ranking and also exercises
a lone hero with an empty secondary slot. Level loading and unit placement are fixtures; this is not an iOS touch-delivery
test or a physical-device run.

`HeroBarLayout` uses the HUD's left and bottom edges and the projected
`VirtualCanvas.lowerLeftOcclusionArea` right and top edges, clipped to the HUD.
This includes usable space beside or below the map instead of capping the row
at the occlusion's own dimensions. It fits three equal squares and two 10% gaps
to the available width **and** height. At the 340pt minimum playable height with
no safe-area inset, buttons are 44.9556pt and the row is 143.8578pt wide. Adding
the 12.0889pt HUD margin reaches exactly the occlusion's 155.9467pt right edge.
Other screen/safe-area shapes are computed from the same geometry.
The 874×402pt phone fixture with a 750×382pt safe area now permits 58.446pt
buttons, spanning the full reduced occlusion height; the old extra width cap
limited them to 54.7533pt. See `reports/hero-bar-fit-2026-09-09`.

`HudView` keeps this row at the lower-left HUD anchor independently of its other
rows, and normalizes the hero-bar layout slot to southwest. The fixed viewport,
screen origin, map projection, and master/misc button sizes are unchanged.
Selection borders and cooldown rendering stay inside each button's bounds.

Map destination layers use the existing playable shape with the HUD corners
cut out, so selecting a hero or arming reinforcements leaves HUD controls
tappable. The reinforcement button toggles placement; only a valid path tap
deploys and starts cooldown. Choosing a hero or tower cancels reinforcement
placement. Ordinary path taps do not display anything.

Validation: 18 Swift tests cover occlusion fitting, both size limits, safe-area
variations, HUD exclusion from map gestures, reinforcement timing, presentation
lifetime, and viewport stability. The production runner method harness covers
HUD arming/cancellation, invalid paths, cooldown rejection, reavailability and
expiry cleanup. The iPhone build passes. Production SwiftUI HUD renders with
fixture game state keep the map marker and other HUD controls fixed across six
states; see `reports/hero-hud-2026-09-08` and the data repo's
`ArtReadability/reports/hero-hud-2026-09-08`. Physical-device gameplay was not
measured.
