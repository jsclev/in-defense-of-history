#if DEBUG
import SwiftUI
import UIKit

/// Physical-device artwork evidence using the production views and compiled catalog.
/// Exports images and JSON only; never changes campaign or player data.
enum CampaignArtDeviceReview {
    @MainActor static func capture(runtimeCanvas: RuntimeCanvas, nodes: [CampaignNode],
                                  bestStarsByLevel: [UUID: Int],
                                  heroControls: [HeroControlSetting]) async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("campaign-art-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await Task.sleep(for: .seconds(1))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw CocoaError(.fileReadUnknown)
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            let screenshot = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try write(screenshot, name: "campaign-screen", directory: directory)
            try write(CampaignButtonArt.requiredImage(named: CampaignMapAsset.imageName),
                      name: "campaign-background-decoded", directory: directory)
            for decoration in CampaignOceanLayout.decorations {
                try write(CampaignButtonArt.requiredImage(named: decoration.assetName),
                          name: decoration.assetName + "-decoded", directory: directory)
            }

            let minimumSize = CGSize(width: 340.0 * 16 / 9, height: 340)
            let minimumPlacements = CampaignMarkers.placements(for: nodes,
                bestStarsByLevel: bestStarsByLevel, viewSize: minimumSize)
            let minimumCanvas = RuntimeCanvas(virtualCanvas: runtimeCanvas.virtualCanvas,
                physicalRect: CGRect(origin: .zero, size: minimumSize),
                safeInsetsRect: CGRect(origin: .zero, size: minimumSize))
            let minimumMenu = MenuBarLayout(runtimeCanvas: minimumCanvas,
                itemCount: MenuScreen.allCases.count)
            let minimumMenuBox = CGRect(x: minimumMenu.bar.minX, y: minimumMenu.bar.minY,
                width: minimumSize.width - minimumMenu.bar.minX,
                height: minimumSize.height - minimumMenu.bar.minY)
            let minimumCompass = CampaignCompass.placement(viewSize: minimumSize,
                callouts: minimumPlacements, menuBox: minimumMenuBox)
            let minimumTitle = TitleLayout(runtimeCanvas: minimumCanvas,
                aspect: 1 / max(HudIcon.aspect(of: "game_title"), 0.01))
            let crop = CampaignMapLayout.makeCrop(imageSize: CampaignMapAsset.imageSize,
                safeRect: CampaignMapAsset.safeRect, viewSize: minimumSize).rect
            let ratio = minimumSize.width / crop.width
            let preview = ZStack(alignment: .topLeading) {
                Image(uiImage: CampaignButtonArt.requiredImage(named: CampaignMapAsset.imageName))
                    .resizable()
                    .frame(width: CampaignMapAsset.imageSize.width * ratio,
                           height: CampaignMapAsset.imageSize.height * ratio)
                    .offset(x: -crop.minX * ratio, y: -crop.minY * ratio)
                    .frame(width: minimumSize.width, height: minimumSize.height,
                           alignment: .topLeading)
                    .clipped()
                CampaignOceanDecorations(runtimeCanvas: minimumCanvas)
                if let minimumCompass {
                    CampaignCompassView(placement: minimumCompass)
                }
                CampaignMarkerTethers(placements: minimumPlacements)
                    .stroke(MarkerPalette.tether, lineWidth: 1.6)
                ForEach(minimumPlacements) { placement in
                    CampaignLevelMarker(placement: placement,
                        scale: CampaignMarkers.scale(for: minimumSize))
                        .position(placement.center)
                }
                Image("game_title")
                    .resizable().scaledToFit()
                    .frame(width: minimumTitle.frame.width, height: minimumTitle.frame.height)
                    .position(x: minimumTitle.frame.midX, y: minimumTitle.frame.midY)
                ForEach(Array(MenuScreen.allCases.enumerated()), id: \.element.id) { index, screen in
                    MenuButton(menuScreen: screen,
                        size: minimumMenu.itemFrames[index].height, action: {})
                        .position(x: minimumMenu.itemFrames[index].midX,
                                  y: minimumMenu.itemFrames[index].midY)
                }
            }
            .frame(width: minimumSize.width, height: minimumSize.height)
            .clipped()
            let previewRenderer = ImageRenderer(content: preview)
            previewRenderer.scale = 1
            guard let minimumImage = previewRenderer.uiImage else { throw CocoaError(.fileWriteUnknown) }
            try write(minimumImage, name: "campaign-minimum-size", directory: directory)
            for density in [2.0, 3.0] {
                previewRenderer.scale = density
                guard let image = previewRenderer.uiImage else { throw CocoaError(.fileWriteUnknown) }
                try write(image, name: "campaign-minimum-size@\(Int(density))x", directory: directory)
            }

            var layouts: [[String: Any]] = []
            for size in [minimumSize, runtimeCanvas.physicalRect.size] {
                let placements = CampaignMarkers.placements(for: nodes,
                    bestStarsByLevel: bestStarsByLevel, viewSize: size)
                var minimumGap = CGFloat.greatestFiniteMagnitude
                for (index, a) in placements.enumerated() {
                    for b in placements.dropFirst(index + 1) {
                        minimumGap = min(minimumGap, hypot(a.center.x - b.center.x,
                            a.center.y - b.center.y) - (a.diameter + b.diameter) / 2)
                    }
                }
                layouts.append(["width": size.width, "height": size.height,
                    "minimumDiscGap": minimumGap,
                    "markers": placements.map { p in
                        ["level": p.id, "x": p.center.x, "y": p.center.y,
                         "diameter": p.diameter, "anchorX": p.anchor.x, "anchorY": p.anchor.y]
                    }])
            }

            let menu = MenuBarLayout(runtimeCanvas: runtimeCanvas, itemCount: MenuScreen.allCases.count)
            var records: [[String: Any]] = []
            for (index, screen) in MenuScreen.allCases.enumerated() {
                let image = CampaignButtonArt.requiredImage(named: screen.iconAssetName)
                try write(image, name: screen.iconAssetName + "-decoded", directory: directory)
                for density in [1.0, 2.0, 3.0] {
                    try render(MenuButton(menuScreen: screen, size: TouchTarget.minimum, action: {}),
                               name: screen.iconAssetName, side: TouchTarget.minimum,
                               density: density, directory: directory)
                }
                records.append(["asset": screen.iconAssetName, "minimumSide": TouchTarget.minimum,
                                "screenSide": menu.itemFrames[index].height,
                                "decodedScale": image.scale])
            }
            for state in CampaignMarkers.State.allCases {
                let scale: CGFloat = 0.75
                let side = CampaignMarkers.diameter(scale: scale, state: state)
                let id = state == .completed ? 14 : state == .current ? 15 : 16
                let node = CampaignNode(id: id, title: "Artwork review", imagePosition: .zero,
                                        levelInfoID: nil, mapImageName: "")
                let placement = CampaignMarkers.Placement(id: id, node: node, state: state,
                    anchor: .zero, center: .zero, diameter: side, showsTether: false)
                let image = CampaignButtonArt.requiredImage(named: state.assetName)
                try write(image, name: state.assetName + "-decoded", directory: directory)
                for density in [1.0, 2.0, 3.0] {
                    try render(CampaignLevelMarker(placement: placement, scale: scale),
                               name: state.assetName, side: side,
                               density: density, directory: directory)
                }
                records.append(["asset": state.assetName, "minimumSide": side,
                                "decodedScale": image.scale])
            }
            result = ["passed": true, "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "",
                      "screenWidth": window.bounds.width, "screenHeight": window.bounds.height,
                      "screenScale": window.screen.scale, "assets": records,
                      "campaignLayouts": layouts,
                      "oceanLayouts": [minimumCanvas, runtimeCanvas].map { canvas in
                          ["playX": canvas.playAreaRect.minX, "playY": canvas.playAreaRect.minY,
                           "playWidth": canvas.playAreaRect.width, "playHeight": canvas.playAreaRect.height,
                           "scaleFactor": canvas.scaleFactor,
                           "decorations": CampaignOceanLayout.placements(runtimeCanvas: canvas).map { p in
                               ["asset": p.assetName, "x": p.frame.minX, "y": p.frame.minY,
                                "width": p.frame.width, "height": p.frame.height,
                                "insidePlayArea": canvas.playAreaRect.contains(p.frame)] as [String: Any]
                           }] as [String: Any]
                      },
                      "heroControls": heroControls.map {
                          ["id": $0.id.uuidString, "name": $0.name, "aiEnabled": $0.aiEnabled]
                      }]
        } catch {
            result["error"] = String(describing: error)
        }
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("review.json"))
        } catch {
            assertionFailure("Campaign artwork review could not save evidence: \(error)")
        }
    }

    @MainActor private static func render<V: View>(_ view: V, name: String, side: CGFloat,
                                                  density: Double, directory: URL) throws {
        let renderer = ImageRenderer(content: view.frame(width: side, height: side))
        renderer.scale = density
        guard let image = renderer.uiImage else { throw CocoaError(.fileWriteUnknown) }
        try write(image, name: "\(name)@\(Int(density))x", directory: directory)
    }

    private static func write(_ image: UIImage, name: String, directory: URL) throws {
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
#endif
