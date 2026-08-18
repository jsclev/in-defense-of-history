import SwiftUI

@available(iOS 26.0, *)
struct CampaignMapView: View {
    var onSelectNode: (CampaignNode) -> Void
    var onSelectMenu: (MenuScreen) -> Void

    @AppStorage(SafeAreaOverlay.defaultsKey) private var showSafeAreaOverlay = false

    @State private var nodes: [CampaignNode] = []
    
    public var canvasSpec: CanvasSpec
    public let db: Db

    var body: some View {
        GeometryReader { geometry in
            let screen = ScreenGeometry(proxy: geometry)
            let fullSize = screen.physical.size
            let metrics = HudMetrics(viewSize: fullSize)
            let menu = MenuBarLayout(screen: screen,
                                     itemCount: MenuScreen.allCases.count)
            let title = TitleLayout(screen: screen,
                                    aspect: 1 / max(HudIcon.aspect(of: "game_title"), 0.01))
            ZStack(alignment: .topLeading) {
                GeometryReader { mapGeometry in
                    let scale = CampaignMarkers.scale(for: mapGeometry.size)
                    let placements = CampaignMarkers.placements(
                        for: nodes,
                        viewSize: mapGeometry.size
                    )
                    let menuBox = CGRect(
                        x: menu.bar.minX, y: menu.bar.minY,
                        width: screen.physical.maxX - menu.bar.minX,
                        height: screen.physical.maxY - menu.bar.minY)
                    let decor = CampaignDecor.placements(
                        viewSize: mapGeometry.size,
                        callouts: placements,
                        menuExclusion: menuBox
                    )
                    let compass = CampaignCompass.placement(
                        viewSize: mapGeometry.size,
                        callouts: placements,
                        menuBox: menuBox
                    )

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
                }
                .ignoresSafeArea()

                if showSafeAreaOverlay {
                    SafeAreaOverlayView(screen: screen, canvasSpec: canvasSpec)
                        .ignoresSafeArea()
                }

                Image("game_title")
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black.opacity(0.45),
                            radius: 6 * metrics.scale, y: 3 * metrics.scale)
                    .allowsHitTesting(false)
                    .hudFrame(title.frame, in: screen)
                    .ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    ForEach(Array(MenuScreen.allCases.enumerated()), id: \.element.id) { index, item in
                        MenuButton(screen: item,
                                   size: menu.itemFrames[index].height) {
                            onSelectMenu(item)
                        }
                        .hudFrame(menu.itemFrames[index], in: screen)
                    }
                }
                .ignoresSafeArea()
            }
        }
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
