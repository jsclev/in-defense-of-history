#if DEBUG
import SwiftUI
import UIKit

/// Physical-device artwork evidence using the production views and compiled catalog.
/// Exports images and JSON only; never changes campaign or player data.
enum CampaignArtDeviceReview {
    @MainActor static func capture(runtimeCanvas: RuntimeCanvas) async {
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
                      "screenScale": window.screen.scale, "assets": records]
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
