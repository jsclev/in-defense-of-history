Hero HUD restoration checks, 2026-09-08

18 Swift tests pass, including the new width/height/occlusion/margin checks and previous reinforcement/viewport/presentation regressions. The extracted runner method probe also passes HUD arming/cancel/place, invalid destinations, cooldown gating, expiry cleanup and tower/hero preservation. The iPhone build succeeds.

Production HUD views rendered with fixture state keep other HUD controls and the map marker fixed across six states; the evidence and minimum-size review are in the data repo ArtReadability/reports/hero-hud-2026-09-08. See ../../hero_hud.md. Physical-device gameplay was not measured.
