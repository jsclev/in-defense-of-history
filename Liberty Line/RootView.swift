import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuScreen: MenuScreen?

    var store = Store()


    var body: some View {
        GeometryReader { proxy in
            let abc = proxy.safeAreaInsets
            let xyz = 1
        }
        
        if let selectedNode {
            if let playingDifficulty {
                LevelMapView(db: store.db,
                             canvasSpec: store.canvasSpec,
                             towerMenuLayout: store.towerMenuLayout,
                             node: selectedNode, difficulty: playingDifficulty) {
                    self.playingDifficulty = nil
                    self.selectedNode = nil
                }
            } else {
                LevelBriefingView(db: store.db, canvasSpec: store.canvasSpec, node: selectedNode) { difficulty in
                    self.playingDifficulty = difficulty
                }
            }
        } else if menuScreen == .heroes {
            HeroesView(db: store.db, canvasSpec: store.canvasSpec) {
                self.menuScreen = nil
            }
        } else if menuScreen == .encyclopedia {
            EncyclopediaView(canvasSpec: store.canvasSpec) {
                self.menuScreen = nil
            }
        } else if menuScreen == .settings {
            SettingsView(canvasSpec: store.canvasSpec) {
                self.menuScreen = nil
            }
        } else if let menuScreen {
            MenuPlaceholderView(screen: menuScreen, canvasSpec: store.canvasSpec) {
                self.menuScreen = nil
            }
        } else {
            CampaignMapView(
                onSelectNode: { selectedNode = $0 },
                onSelectMenu: { menuScreen = $0 }, canvasSpec: store.canvasSpec, db: store.db
            )
        }
    }
}
