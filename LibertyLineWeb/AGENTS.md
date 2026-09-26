# Web port

Follow the parent code repository's instructions and the source ownership described in
README.md. All TypeScript/JavaScript behavior needs unit tests. Run `npm run check`
for changes, and exercise the real browser for changes to rendering or loading.
Keep verification evidence under the system temporary directory.

Edit original shared artwork in the sibling data repository, and SQL/GeoJSON in ../Db;
never author replacements in generated/, dist/ or releases/. Those directories
contain disposable deployment products. Keep both hosts on the same game code,
and keep simulation logic independent of Phaser. The current application is a
battlefield preview; do not describe it as a completed playable port.
