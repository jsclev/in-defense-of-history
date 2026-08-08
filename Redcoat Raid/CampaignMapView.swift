import SwiftUI

@available(iOS 26.0, *)
struct CampaignMapView: View {
    var onSelectNode: (CampaignNode) -> Void
    var onSelectMenu: (MenuScreen) -> Void

    @AppStorage(SafeAreaOverlay.defaultsKey) private var showSafeAreaOverlay = false

    @State private var nodes: [CampaignNode] = []

    var body: some View {
        GeometryReader { geometry in
            let screen = ScreenGeometry(proxy: geometry)
            let fullSize = screen.physical.size
            let metrics = HudMetrics(viewSize: fullSize)
            let menu = MenuBarLayout(screen: screen,
                                     itemCount: MenuScreen.allCases.count)
            let title = TitleLayout(screen: screen,
                                    aspect: 1 / max(HudIcon.aspect(of: "redcoat_raid_title"), 0.01))
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
                    let compassBox: CGRect = compass.map { c in
                        let a = CampaignMapLayout.imagePoint(
                            forViewPoint: CGPoint(x: c.center.x - c.size.width / 2,
                                                  y: c.center.y - c.size.height / 2),
                            imageSize: CampaignMapAsset.imageSize,
                            safeRect: CampaignMapAsset.safeRect,
                            viewSize: mapGeometry.size)
                        let b = CampaignMapLayout.imagePoint(
                            forViewPoint: CGPoint(x: c.center.x + c.size.width / 2,
                                                  y: c.center.y + c.size.height / 2),
                            imageSize: CampaignMapAsset.imageSize,
                            safeRect: CampaignMapAsset.safeRect,
                            viewSize: mapGeometry.size)
                        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                      width: abs(b.x - a.x), height: abs(b.y - a.y))
                    } ?? .zero
                    let titleBox = title.frame.insetBy(dx: -title.frame.width * 0.075,
                                                       dy: -title.frame.height * 0.15)
                    let warshipObstacles = [menuBox, titleBox]
                        + (compass.map { [CGRect(x: $0.center.x - $0.size.width / 2,
                                                 y: $0.center.y - $0.size.height / 2,
                                                 width: $0.size.width,
                                                 height: $0.size.height)] } ?? [])
                        + placements.map { $0.rect.insetBy(dx: -6, dy: -6) }
                        + decor.map(\.frame)
                    let warshipCenter = CampaignWarshipBerth.center(
                        viewSize: mapGeometry.size,
                        avoiding: warshipObstacles
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

                        if let warshipCenter {
                            CampaignAnchoredSprite(kind: .britishWarship,
                                                   viewSize: mapGeometry.size,
                                                   center: warshipCenter)
                        }

                        CampaignPirateShip(viewSize: mapGeometry.size,
                                           compassBox: compassBox)

                        CampaignBeaver(viewSize: mapGeometry.size)

                        CampaignCritter(species: .grizzly,
                                        viewSize: mapGeometry.size)
                        CampaignCritter(species: .jackrabbit,
                                        viewSize: mapGeometry.size)

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
                    SafeAreaOverlayView(screen: screen)
                        .ignoresSafeArea()
                }

                Image("redcoat_raid_title")
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
            if nodes.isEmpty { nodes = CampaignNode.load() }
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

#Preview {
    CampaignMapView(onSelectNode: { _ in }, onSelectMenu: { _ in })
}
