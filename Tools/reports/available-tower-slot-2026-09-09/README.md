# Available tower-site sprite integration

The new `tower_slot_available` catalog asset is used for empty sites throughout
the game. LevelMapView passes the indices from actual placed towers into
LevelTowerSlotsView; occupied sites keep `tower_slot_field`. Sizing, positions
and touch targets are preserved.

Validation:

- Production device build succeeded (`iphone-build.log`).
- Compiled Assets.car contains the new 528 × 288, 3× rendition
  (`compiled-renditions.json`).
- Physical-iPhone probe loaded the new image at its 176 × 96 logical catalog size.
- Real runner select/arm/confirm actions built a ranged tower and changed the
  production slot rendering from the available marker to the old ground.
  `slot-check.json` records the successful transition. The raster difference
  is confined to one site's region (`build-transition-raster.json`).
- Inspected final level 1 and level 15 captures at the 604 × 340pt minimum
  fixture. The ivory mallet and dark cool rim remain identifiable on new grass;
  level 1's retained baked pads do not hide the new symbol. Normal device and
  3× captures are also preserved in `device-documents`.
- Source and catalog hashes used in the probe match the final workspace
  (`tested-source-hashes.json`). The probe reused the final built game's
  compiled catalog (`compiled-catalog.json`).
- Game installation/launch passed (`install.json`, `launch.json`). The temporary
  probe app was uninstalled after saving the review captures.

The generated master, final transparent sprite, exact built-in image_gen prompt,
export checks, existing calibrated lab and small-size self-review are under
`in-defense-of-history-data/Towers/Available Tower Slot Bastion V1`.
No simulator or independent player recognition study was used.
