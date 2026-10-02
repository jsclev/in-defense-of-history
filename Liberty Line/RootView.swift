import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @State private var selectedNode: CampaignNode?
    @State private var playingDifficulty: Difficulty?
    @State private var menuPresentation: MenuPresentation?
    @State private var configuringHudLayout = false
    @State private var hudLayoutConfig: HudLayoutConfig

    let store: Store
    let runtimeCanvas: RuntimeCanvas

    init(store: Store, runtimeCanvas: RuntimeCanvas) {
        self.store = store
        self.runtimeCanvas = runtimeCanvas
        _hudLayoutConfig = State(initialValue: store.hudLayoutConfig)
        #if DEBUG
        // A launch shortcut enters the ordinary campaign view. Hero control,
        // difficulty, upgrades and starting money still come from SQLite.
        let arguments = CommandLine.arguments
        let reviewCategory: EncyclopediaSession.Category?
        if arguments.contains("--enemy-encyclopedia-review") {
            reviewCategory = .enemies
        } else if arguments.contains("--tower-encyclopedia-review") || arguments.contains("--tower-demo-review") {
            reviewCategory = .towers
        } else {
            reviewCategory = nil
        }
        if let reviewCategory {
            _menuPresentation = State(initialValue: MenuPresentation(.encyclopedia, db: store.db,
                initialCategory: reviewCategory))
        }
        if let flag = arguments.firstIndex(of: "--play-level") ?? arguments.firstIndex(of: "--preview-level") {
            do {
                guard arguments.indices.contains(flag + 1),
                      let number = Int(arguments[flag + 1]), number > 0 else {
                    throw DbError.Db(message: "--play-level requires a positive campaign level number")
                }
                let levels = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
                guard levels.indices.contains(number - 1),
                      let difficulty = try store.db.difficultyDao.getSelected() else {
                    throw DbError.Db(message: "Requested campaign level or authored difficulty is missing")
                }
                _selectedNode = State(initialValue: CampaignNode(order: number, level: levels[number - 1]))
                if arguments.contains("--play-level") { _playingDifficulty = State(initialValue: difficulty) }
            } catch { fatalError("Unable to launch campaign level: \(error)") }
        }
        #endif
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
        } else if case .screen(.upgrades) = menuPresentation {
            MetaUpgradesView(upgrades: store.metaUpgrades, runtimeCanvas: runtimeCanvas) {
                self.menuPresentation = nil
            }
        } else if case .screen(.heroes) = menuPresentation {
            HeroesView(db: store.db, runtimeCanvas: runtimeCanvas) {
                self.menuPresentation = nil
            }
        } else if case let .encyclopedia(session) = menuPresentation {
            EncyclopediaView(session: session, runtimeCanvas: runtimeCanvas) {
                self.menuPresentation = nil
            }
            .id(session.id)
        } else if case .screen(.settings) = menuPresentation {
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
                    self.menuPresentation = nil
                }
            }
        } else if case let .screen(menuScreen) = menuPresentation {
            MenuPlaceholderView(menuScreen: menuScreen, runtimeCanvas: runtimeCanvas) {
                self.menuPresentation = nil
            }
        } else {
            CampaignMapView(
                playerProgress: store.metaUpgrades,
                onSelectNode: { selectedNode = $0 },
                onSelectMenu: { menuPresentation = MenuPresentation($0, db: store.db) },
                virtualCanvas: store.virtualCanvas, db: store.db, runtimeCanvas: runtimeCanvas
            )
        }
    }

    /// Both button taps and review launches construct the destination here.
    /// The encyclopedia cannot be presented with a previous or partial session.
    @MainActor
    private enum MenuPresentation {
        case screen(MenuScreen)
        case encyclopedia(EncyclopediaSession)

        init(_ screen: MenuScreen, db: Db, initialCategory: EncyclopediaSession.Category? = nil) {
            if screen == .encyclopedia {
                do {
                    self = .encyclopedia(try EncyclopediaSession(db: db, initialCategory: initialCategory))
                } catch {
                    fatalError("Invalid authored encyclopedia content: \(error)")
                }
            } else {
                self = .screen(screen)
            }
        }
    }
}
