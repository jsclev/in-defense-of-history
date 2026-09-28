# Web port

Follow the parent code repository's instructions and the source ownership described in
README.md. All TypeScript/JavaScript behavior needs unit tests. Run `npm run check`
for changes, and exercise the real browser for changes to rendering or loading.
Keep verification evidence under the system temporary directory.

Edit original shared artwork in the sibling data repository, and SQL/GeoJSON in ../Db;
never author replacements in generated/, dist/ or releases/. Those directories
contain disposable deployment products. Keep both hosts on the same game code,
and keep simulation logic independent of Phaser. The current application has an
interactive HUD and partial battle simulation; do not describe it as a completed
playable port. README.md identifies the remaining gameplay systems.

Browser and host input must mutate battle state through `BattleStore.dispatch`.
Phaser advances simulation only through `BattleStore.frame`; render/resize/input
handlers must not advance time. Keep one session as the state authority and
subscribe through the scene lifecycle; do not reintroduce manual HUD refreshes
or a second cooldown timer. Persistent HUD controls must stay above world/tower
controls; call-wave buttons belong below tower menus, matching native
LevelViewport presentations. Button nodes must survive rendering updates during
a pointer gesture.
