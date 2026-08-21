import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuScreen: MenuScreen?

    let store: Store
    let screen: ScreenGeometry

    var body: some View {
        if let selectedNode {
            if let playingDifficulty {
                LevelMapView(db: store.db,
                             canvasSpec: store.canvasSpec,
                             screen: screen,
                             towerMenuLayout: store.towerMenuLayout,
                             node: selectedNode, difficulty: playingDifficulty) {
                    self.playingDifficulty = nil
                    self.selectedNode = nil
                }
            } else {
                LevelBriefingView(db: store.db, canvasSpec: store.canvasSpec,
                                  screen: screen, node: selectedNode) { difficulty in
                    self.playingDifficulty = difficulty
                }
            }
        } else if menuScreen == .heroes {
            HeroesView(db: store.db, screen: screen) {
                self.menuScreen = nil
            }
        } else if menuScreen == .encyclopedia {
            EncyclopediaView(screen: screen) {
                self.menuScreen = nil
            }
        } else if menuScreen == .settings {
            SettingsView(screen: screen) {
                self.menuScreen = nil
            }
        } else if let menuScreen {
            MenuPlaceholderView(menuScreen: menuScreen, screen: screen) {
                self.menuScreen = nil
            }
        } else {
            CampaignMapView(
                onSelectNode: { selectedNode = $0 },
                onSelectMenu: { menuScreen = $0 },
                canvasSpec: store.canvasSpec, db: store.db, screen: screen
            )
        }
    }
}
