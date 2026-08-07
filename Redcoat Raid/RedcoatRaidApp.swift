import SwiftUI

@main
struct RedcoatRaidApp: App {
    var body: some Scene {
        WindowGroup {
            // No system chrome anywhere: the status bar (clock, wifi,
            // battery) doesn't match the game's art style and breaks player
            // flow. Applied at the root so every screen inherits it.
            RootView()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
