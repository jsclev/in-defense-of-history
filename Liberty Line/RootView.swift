import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuScreen: MenuScreen?

    let store: Store
    let runtimeCanvas: RuntimeCanvas

    var body: some View {
        if let selectedNode {
            if let playingDifficulty {
                LevelMapView(db: store.db,
                             virtualCanvas: store.virtualCanvas,
                             runtimeCanvas: runtimeCanvas,
                             towerMenuLayout: store.towerMenuLayout,
                             node: selectedNode, difficulty: playingDifficulty) {
                    self.playingDifficulty = nil
                    self.selectedNode = nil
                }
            } else {
                LevelBriefingView(db: store.db, virtualCanvas: store.virtualCanvas,
                                  runtimeCanvas: runtimeCanvas, node: selectedNode) { difficulty in
                    self.playingDifficulty = difficulty
                }
            }
        } else if menuScreen == .heroes {
            HeroesView(db: store.db, runtimeCanvas: runtimeCanvas) {
                self.menuScreen = nil
            }
        } else if menuScreen == .encyclopedia {
            EncyclopediaView(runtimeCanvas: runtimeCanvas) {
                self.menuScreen = nil
            }
        } else if menuScreen == .settings {
            SettingsView(runtimeCanvas: runtimeCanvas) {
                self.menuScreen = nil
            }
        } else if let menuScreen {
            MenuPlaceholderView(menuScreen: menuScreen, runtimeCanvas: runtimeCanvas) {
                self.menuScreen = nil
            }
        } else {
            CampaignMapView(
                onSelectNode: { selectedNode = $0 },
                onSelectMenu: { menuScreen = $0 },
                virtualCanvas: store.virtualCanvas, db: store.db, runtimeCanvas: runtimeCanvas
            )
        }
    }
}
