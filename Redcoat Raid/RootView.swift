import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuScreen: MenuScreen?

    var body: some View {
        if let selectedNode {
            if let playingDifficulty {
                LevelMapView(node: selectedNode, difficulty: playingDifficulty) {
                    self.playingDifficulty = nil
                    self.selectedNode = nil
                }
            } else {
                LevelBriefingView(node: selectedNode) { difficulty in
                    self.playingDifficulty = difficulty
                }
            }
        } else if menuScreen == .heroes {
            HeroesView {
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
                onSelectMenu: { menuScreen = $0 }
            )
        }
    }
}
