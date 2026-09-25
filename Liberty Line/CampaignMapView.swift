import SwiftUI

@available(iOS 26.0, *)
struct CampaignMapView: View {
    @EnvironmentObject private var settings: PlayerSettingsStore
    @ObservedObject var playerProgress: MetaUpgradeStore
    private var showDebugLayoutGuides: Bool { settings.values.showDebugLayoutGuides }
    var onSelectNode: (CampaignNode) -> Void
    var onSelectMenu: (MenuScreen) -> Void


    @State private var nodes: [CampaignNode] = []
    
    public var virtualCanvas: VirtualCanvas
    public let db: Db
    public let runtimeCanvas: RuntimeCanvas

    var body: some View {
        let mapSize = runtimeCanvas.physicalRect.size
        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        let menu = MenuBarLayout(runtimeCanvas: runtimeCanvas,
                                 itemCount: MenuScreen.allCases.count)
        let title = TitleLayout(runtimeCanvas: runtimeCanvas,
                                aspect: 1 / max(HudIcon.aspect(of: "game_title"), 0.01))
        let scale = CampaignMarkers.scale(for: mapSize)
        let placements = CampaignMarkers.placements(
            for: nodes,
            bestStarsByLevel: playerProgress.bestStarsByLevel,
            viewSize: mapSize
        )
        let menuBox = CGRect(
            x: menu.bar.minX, y: menu.bar.minY,
            width: runtimeCanvas.physicalRect.maxX - menu.bar.minX,
            height: runtimeCanvas.physicalRect.maxY - menu.bar.minY)
        let compass = CampaignCompass.placement(
            viewSize: mapSize,
            callouts: placements,
            menuBox: menuBox
        )
        ZStack(alignment: .topLeading) {
            ZStack {
                CampaignMapMetalView(canvasSize: mapSize)
                    .frame(width: mapSize.width, height: mapSize.height)

                // Historical landmarks are painted into this background.
                CampaignOceanDecorations(runtimeCanvas: runtimeCanvas)

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
                    .accessibilityValue(placement.state.accessibilityValue)
                }
            }

            Image("game_title")
                .resizable()
                .scaledToFit()
                .frame(width: title.frame.width, height: title.frame.height)
                .shadow(color: .black.opacity(0.45),
                        radius: 6 * metrics.scale, y: 3 * metrics.scale)
                .position(x: title.frame.midX, y: title.frame.midY)
                .allowsHitTesting(false)

            ZStack(alignment: .topLeading) {
                ForEach(Array(MenuScreen.allCases.enumerated()), id: \.element.id) { index, item in
                    MenuButton(menuScreen: item,
                               size: menu.itemFrames[index].height) {
                        onSelectMenu(item)
                    }
                    .position(x: menu.itemFrames[index].midX,
                              y: menu.itemFrames[index].midY)
                }
            }

            // Last, so the guides draw over every HUD element.
            if showDebugLayoutGuides {
                DebugLayoutGuidesView(runtimeCanvas: runtimeCanvas)
            }
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .task {
            do {
                try playerProgress.reload()
                nodes = CampaignNode.load(db: db)
            } catch {
                fatalError("Campaign map database error: \(error)")
            }
            #if DEBUG
            if CommandLine.arguments.contains("--campaign-art-review") {
                await CampaignArtDeviceReview.capture(runtimeCanvas: runtimeCanvas,
                    nodes: nodes, bestStarsByLevel: playerProgress.bestStarsByLevel,
                    heroControls: settings.heroControls)
            }
            #endif
        }
    }
}

/// Each canonical asset includes its own water transition and leaves taps free.
struct CampaignOceanDecorations: View {
    let runtimeCanvas: RuntimeCanvas

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(CampaignOceanLayout.placements(runtimeCanvas: runtimeCanvas)) { placement in
                Image(uiImage: CampaignButtonArt.requiredImage(named: placement.assetName))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: placement.frame.width, height: placement.frame.height)
                    .position(x: placement.frame.midX, y: placement.frame.midY)
            }
        }
        .frame(width: runtimeCanvas.physicalRect.width,
               height: runtimeCanvas.physicalRect.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
    }
}
