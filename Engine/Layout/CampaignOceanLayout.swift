import CoreGraphics

/// Ocean decorations use top-left offsets within the virtual play area,
/// measured on main_campaign_map_03's 1920 × 1080 play rectangle. These
/// fixed Atlantic locations keep the entire painted water footprint offshore.
enum CampaignOceanLayout {
    struct Decoration: Identifiable {
        let assetName: String
        let playAreaFrame: CGRect
        var id: String { assetName }
    }

    struct Placement: Identifiable {
        let assetName: String
        let frame: CGRect
        var id: String { assetName }
    }

    static let decorations: [Decoration] = [
        Decoration(assetName: "main_campaign_map_ship_british",
                   playAreaFrame: CGRect(x: 1156, y: 378, width: 230, height: 230)),
        Decoration(assetName: "main_campaign_map_octopus",
                   playAreaFrame: CGRect(x: 1186, y: 688, width: 190, height: 142.5)),
        Decoration(assetName: "main_campaign_map_whale",
                   // Above the compass; this corner is open Atlantic water.
                   playAreaFrame: CGRect(x: 1636, y: 230, width: 190, height: 142.5)),
    ]

    static func placements(runtimeCanvas: RuntimeCanvas) -> [Placement] {
        let play = runtimeCanvas.playAreaRect
        let scale = runtimeCanvas.scaleFactor
        // Use the same uniform virtual-to-runtime scale for offsets and size.
        // No viewport percentages, per-device clamps, collision relocation or
        // conditional omission: the three objects retain their authored layout.
        return decorations.map { decoration in
            let source = decoration.playAreaFrame
            return Placement(assetName: decoration.assetName,
                frame: CGRect(x: play.minX + source.minX * scale,
                              y: play.minY + source.minY * scale,
                              width: source.width * scale,
                              height: source.height * scale))
        }
    }
}
