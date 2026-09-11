# Tower slot front grass — physical-iPhone verification

The shared available tower pad uses the V3 sparse front grass fringe, with its approved hammer and back stones preserved. Production renderer and layout code are unchanged by this revision.

The production game and a temporary verification app were built for the physical iPhone. The probe reuses the production compiled catalog, captures Charleston and Battle Road at 852 × 393 and 604 × 340 logical points, and performs a real select/arm/confirm tower build to check the transition to the occupied pad. It saves 1× and 3× captures, the loaded 3× slot image, source hashes, and results. The temporary app was removed after success.

`slot-check.json` records the passed runtime checks. `compiled-rendition-match.json` confirms the loaded 528 × 288 image matches the final source in premultiplied color within 2 of 255 channel levels. `staged-package.json` confirms the separately staged signed game uses exactly the tested catalog. Installation and launch results are recorded in `install.json` and `launch.json`.

The final native-size review and all art provenance are in `/Users/john/projects/td/in-defense-of-history-data/Towers/Available Tower Slot Bastion V3/Review/`. The 1× images were inspected before enlargements. Observations are familiar-agent judgments; independent human recognition and physical-display color preference are not measured.
