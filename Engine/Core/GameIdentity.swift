/// The game's user-facing name — location 2 of exactly 2.
///
/// The other location is GameName.xcconfig at the repo root, which stamps the
/// same name into the app's home-screen label (CFBundleDisplayName). Change
/// both when renaming the game; nothing else in the repo carries the name.
///
/// Any code that shows or logs the game's name reads this constant — never a
/// string literal. The Simulator and LevelEditor share it too, which is why
/// it lives in the Engine rather than the app target.
public enum GameIdentity {
    public static let name = "Liberty Line"
}
