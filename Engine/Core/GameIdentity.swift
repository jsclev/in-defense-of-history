import Foundation

/// The game's user-facing name, read from the app bundle at runtime.
///
/// GameName.xcconfig authors the display name. At build time
/// GAME_DISPLAY_NAME lands in the app's Info.plist twice: as
/// CFBundleDisplayName, which the home runtimeCanvas shows, and as the custom
/// GameName key this reads. No Swift file carries the name. (The Xcode
/// target/folder/scheme also say "Liberty Line" — a deliberate choice for
/// identifiability; see the note in GameName.xcconfig.)
///
/// The fallback covers targets whose bundle has no GameName key: the
/// command-line Simulator (no Info.plist at all) and the LevelEditor (its
/// display name is the tool's, not the game's). It is deliberately the
/// franchise name, not a stale copy of the game name.
public enum GameIdentity {
    public static var name: String {
        (Bundle.main.object(forInfoDictionaryKey: "GameName") as? String)
            ?? "In Defense of History"
    }

    public static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0.0.0"
    }
}
