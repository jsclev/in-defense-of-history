import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuScreen: MenuScreen?
    @State private var configuringHudLayout = false
    @State private var hudLayoutConfig: HudLayoutConfig

    let store: Store
    let runtimeCanvas: RuntimeCanvas

    init(store: Store, runtimeCanvas: RuntimeCanvas) {
        self.store = store
        self.runtimeCanvas = runtimeCanvas
        _hudLayoutConfig = State(initialValue: store.hudLayoutConfig)
    }

    var body: some View {
        if let selectedNode {
            if playingDifficulty != nil {
                LevelMapView(db: store.db,
                             virtualCanvas: store.virtualCanvas,
                             runtimeCanvas: runtimeCanvas,
                             towerMenuLayout: store.towerMenuLayout,
                             node: selectedNode,
                             hudLayoutConfig: hudLayoutConfig,
                             onVictory: { lives, startingLives in
                                 guard let id = selectedNode.levelInfoID else { return 0 }
                                 do { return try store.metaUpgrades.recordVictory(levelID: id, lives: lives, startingLives: startingLives) }
                                 catch { fatalError("Meta upgrade database error: \(error)") }
                             }) {
                    self.playingDifficulty = nil
                    self.selectedNode = nil
                }
            } else {
                LevelBriefingView(db: store.db, virtualCanvas: store.virtualCanvas,
                                  runtimeCanvas: runtimeCanvas, node: selectedNode) { difficulty in
                    self.playingDifficulty = difficulty
                }
            }
        } else if menuScreen == .upgrades {
            MetaUpgradesView(upgrades: store.metaUpgrades, runtimeCanvas: runtimeCanvas) {
                self.menuScreen = nil
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
            if configuringHudLayout {
                HudLayoutConfigView(db: store.db,
                                    runtimeCanvas: runtimeCanvas,
                                    hudLayoutConfig: hudLayoutConfig,
                                    onSave: { hudLayoutConfig = $0 }) {
                    self.configuringHudLayout = false
                }
            } else {
                SettingsView(runtimeCanvas: runtimeCanvas,
                             onConfigureHudLayout: { configuringHudLayout = true }) {
                    self.menuScreen = nil
                }
            }
        } else if let menuScreen {
            MenuPlaceholderView(menuScreen: menuScreen, runtimeCanvas: runtimeCanvas) {
                self.menuScreen = nil
            }
        } else {
            CampaignMapView(
                playerProgress: store.metaUpgrades,
                onSelectNode: { selectedNode = $0 },
                onSelectMenu: { menuScreen = $0 },
                virtualCanvas: store.virtualCanvas, db: store.db, runtimeCanvas: runtimeCanvas
            )
        }
    }
}
