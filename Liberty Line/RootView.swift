import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuScreen: MenuScreen?
    
//    private var db: Db
//    private var canvasSpec: CanvasSpec
    
    var store = Store()
//    @StateObject var store = Store()



    var body: some View {
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
                LevelBriefingView(db: store.db, node: selectedNode) { difficulty in
                    self.playingDifficulty = difficulty
                }
            }
        } else if menuScreen == .heroes {
            HeroesView(db: store.db) {
                self.menuScreen = nil
            }
        } else if menuScreen == .encyclopedia {
            EncyclopediaView {
                self.menuScreen = nil
            }
        } else if menuScreen == .settings {
            SettingsView {
                self.menuScreen = nil
            }
        } else if let menuScreen {
            MenuPlaceholderView(screen: menuScreen) {
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
