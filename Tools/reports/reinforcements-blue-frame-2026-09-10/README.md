# Restore reinforcement button's blue background

One production line changes: `ReinforcementButton` uses `hud_misc_sack_blue_frame` instead of `tower_menu_square_frame`. The approved swords, 64% icon size, button geometry, selection and cooldown behavior remain unchanged.

`iphone-build.log` records the successful build. The focused iPhone fixture captures the live level HUD and ready/selected/cooldown production views at minimum/device layouts and all three densities; see `reinforcements-check.json` and `device-documents/`. No game actions or balance data are modified by the fixture.

`unchanged-art-hashes.json` records the 32 unchanged artwork/config files. `tested-source-hashes.json` records the exact source/catalog inputs. The view was also compared with the preceding verified version to establish that only the frame asset name changed.

`probe-uninstall.json`, `install.json` and `launch.json` record temporary fixture removal and normal game installation/launch. The data-side visual review and existing lab output are at `ArtReadability/reports/reinforcements-blue-frame-2026-09-10/`.
