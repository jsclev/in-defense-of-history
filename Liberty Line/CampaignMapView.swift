import SwiftUI

@available(iOS 26.0, *)
struct CampaignMapView: View {
    var onSelectNode: (CampaignNode) -> Void
    var onSelectMenu: (MenuScreen) -> Void

    @AppStorage(Constants.showDebugLayoutGuidesKey) private var showDebugLayoutGuides = false

    @State private var nodes: [CampaignNode] = []
    
    public var virtualCanvas: VirtualCanvas
    public let db: Db
    public let screen: ScreenGeometry

    var body: some View {
        let mapSize = screen.physicalRect.size
        let metrics = HudMetrics(screen: screen)
        let menu = MenuBarLayout(screen: screen,
                                 itemCount: MenuScreen.allCases.count)
        let title = TitleLayout(screen: screen,
                                aspect: 1 / max(HudIcon.aspect(of: "game_title"), 0.01))
        let scale = CampaignMarkers.scale(for: mapSize)
        let placements = CampaignMarkers.placements(
            for: nodes,
            viewSize: mapSize
        )
        let menuBox = CGRect(
            x: menu.bar.minX, y: menu.bar.minY,
            width: screen.physicalRect.maxX - menu.bar.minX,
            height: screen.physicalRect.maxY - menu.bar.minY)
        let decor = CampaignDecor.placements(
            viewSize: mapSize,
            callouts: placements,
            menuExclusion: menuBox
        )
        let compass = CampaignCompass.placement(
            viewSize: mapSize,
            callouts: placements,
            menuBox: menuBox
        )
        ZStack(alignment: .topLeading) {
            ZStack {
                CampaignMapMetalView()

                ForEach(decor) { piece in
                    CampaignDecorView(placement: piece)
                        .position(piece.center)
                }

                if let compass {
                    CampaignCompassView(placement: compass)
                }

                CampaignMarkerTethers(placements: placements)
                    .stroke(Color.black.opacity(0.45),
                            lineWidth: max(1.6, 1.9 * scale))
                CampaignMarkerTethers(placements: placements)
                    .stroke(MarkerPalette.tether.opacity(0.85),
                            lineWidth: max(0.8, 0.9 * scale))
                CampaignMarkerAnchors(placements: placements, scale: scale)

                ForEach(placements) { placement in
                    Button {
                        onSelectNode(placement.node)
                    } label: {
                        CampaignLevelMarker(placement: placement, scale: scale)
                    }
                    .buttonStyle(CampaignMarkerButtonStyle())
                    .position(placement.center)
                    .accessibilityLabel(
                        "Level \(placement.node.id), \(placement.node.title)"
                    )
                }
            }
            .frame(width: screen.physicalRect.width, height: screen.physicalRect.height)

            Image("game_title")
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.45),
                        radius: 6 * metrics.scale, y: 3 * metrics.scale)
                .allowsHitTesting(false)
                .hudFrame(title.frame, in: screen)

            ZStack(alignment: .topLeading) {
                ForEach(Array(MenuScreen.allCases.enumerated()), id: \.element.id) { index, item in
                    MenuButton(screen: item,
                               size: menu.itemFrames[index].height) {
                        onSelectMenu(item)
                    }
                    .hudFrame(menu.itemFrames[index], in: screen)
                }
            }

            // Last, so the guides draw over every HUD element.
            if showDebugLayoutGuides {
                DebugLayoutGuidesView(screen: screen)
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .task {
            if nodes.isEmpty { nodes = CampaignNode.load(db: db) }
        }
    }
}

private struct CampaignMarkerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
            .animation(configuration.isPressed
                ? .easeOut(duration: 0.09)
                : .spring(response: 0.28, dampingFraction: 0.55),
                value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}
