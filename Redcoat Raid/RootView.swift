import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var menuScreen: MenuScreen?

    var body: some View {
        if let selectedNode {
            LevelMapView(node: selectedNode) {
                self.selectedNode = nil
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
