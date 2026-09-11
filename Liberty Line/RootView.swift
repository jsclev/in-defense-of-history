import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var hapticAudition = HapticAuditionPlayer()
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
        _hudLayoutConfig = State(initialValue: (try? store.db.hudLayoutDao.get()) ?? .standard)
    }

    var body: some View {
        if let selectedNode {
            if let playingDifficulty {
                LevelMapView(db: store.db,
                             virtualCanvas: store.virtualCanvas,
                             runtimeCanvas: runtimeCanvas,
                             towerMenuLayout: store.towerMenuLayout,
                             node: selectedNode, difficulty: playingDifficulty,
                             hudLayoutConfig: hudLayoutConfig) {
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
                onSelectNode: { selectedNode = $0 },
                onSelectMenu: { menuScreen = $0 },
                virtualCanvas: store.virtualCanvas, db: store.db, runtimeCanvas: runtimeCanvas
            )
            .overlay(alignment: .top) {
                if HapticAuditionPlayer.enabled {
                    HapticAuditionPanel(player: hapticAudition, runtimeCanvas: runtimeCanvas)
                        .padding(.top, runtimeCanvas.safeInsetsRect.minY
                                 + 8 * HudMetrics(runtimeCanvas: runtimeCanvas).scale)
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                hapticAudition.setActive(phase == .active)
            }
            .onDisappear { hapticAudition.setActive(false) }
        }
    }
}

private struct HapticAuditionPanel: View {
    @ObservedObject var player: HapticAuditionPlayer
    let runtimeCanvas: RuntimeCanvas

    var body: some View {
        let scale = HudMetrics(runtimeCanvas: runtimeCanvas).scale
        VStack(alignment: .leading, spacing: 6 * scale) {
            HStack(spacing: 8 * scale) {
                Text("Haptic audition").font(.system(size: Typography.size(17 * scale), weight: .semibold))
                Spacer()
                Text("\(player.current?.id ?? 0) / 20").monospacedDigit()
            }
            Text(player.current?.name ?? "Preparing 20 patterns")
                .font(.system(size: Typography.size(15 * scale)))
            HStack(spacing: 8 * scale) {
                Text(player.status).font(.system(size: Typography.size(12 * scale)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if player.isRunning {
                    Button("Stop") { player.stop() }.frame(minHeight: 44)
                } else {
                    Button("Replay all") { player.playAll() }.frame(minHeight: 44)
                }
                Menu("Replay one") {
                    ForEach(HapticAuditionSample.allCases) { sample in
                        Button("\(sample.id). \(sample.name)") { player.replay(sample) }
                    }
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .font(.system(size: Typography.size(14 * scale)))
        .padding(12 * scale)
        .frame(width: min(440 * max(scale, 0.8), runtimeCanvas.safeInsetsRect.width - 24 * scale))
        .foregroundStyle(.white)
        .tint(.white)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 12 * scale))
    }
}
