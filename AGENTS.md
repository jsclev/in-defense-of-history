# Game art and rendering reviews

Standing art direction: all game art uses **Bastion (2011)** as its overall color and illustrated/painterly style guide, with American Revolutionary War subject matter and Kingdom Rush-like clarity at small sizes. Use broad vivid color masses and distinctive silhouettes; simplify details that disappear at gameplay size. Apply this throughout the game. The persistent brief is `../in-defense-of-history-data/ArtReadability/ART_DIRECTION.md`.

For art creation, revisions, or changes affecting on-screen art size, read `../in-defense-of-history-data/ArtReadability/small-game-art/SKILL.md` and its project workflow. If this checkout is elsewhere, the asset workspace is `/Users/john/projects/td/in-defense-of-history-data/ArtReadability`.

All game art must remain highly recognizable at its smallest actual gameplay size. Use the calibrated readability lab, inspect the small proof before enlargements, and save the review evidence before calling an asset finished. Do not use the old fixed 58-pixel hero preview as an acceptance test.

# Physical-device workflow

Do not use iOS Simulator for this project, including auxiliary UI measurement probes. The game's Metal 4 runtime does not run in Simulator. Build, deploy, run, and verify gameplay on the user's physical iPhone. Obtain platform UI dimensions from published references or physical-device measurements. Host-side Swift tests and geometry/art rendering tools remain appropriate when they do not launch Simulator; do not present their output as on-device gameplay verification.

# Level editor regression checks

For changes under `LevelEditor/`, run `Tools/check_level_editor.sh` and build the
macOS `LevelEditor` target before reporting completion. The check covers erasing,
gesture commit/cancel, keyboard input, native/GeoJSON persistence, hero starts,
and call-wave markers using fixed fixtures. AppKit keyboard tests need a normal
macOS window-system session; they create hidden test windows. Add a regression
case for an editor bug in the actual shared handler/model, rather than copying
the implementation into a test. Report test failures and any unverified live UI
behavior explicitly.
