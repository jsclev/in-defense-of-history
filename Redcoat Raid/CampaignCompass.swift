import SwiftUI

enum CampaignCompass {
    static let assetName = "main_campaign_map_compass"

    static let heightFractionOfGap: CGFloat = 0.5

    static let referenceNodeID = 13

    struct Placement {
        var center: CGPoint
        var size: CGSize
    }

    static func placement(
        viewSize: CGSize,
        callouts: [CampaignMarkers.Placement],
        menuBox: CGRect
    ) -> Placement? {
        guard viewSize.width > 0, viewSize.height > 0,
              let image = UIImage(named: assetName),
              image.size.width > 0 else { return nil }

        let plate = callouts.first { $0.node.id == referenceNodeID }
        let plateLeft = plate.map { $0.rect.minX }
            ?? viewSize.width * 0.55
        let plateBottom = plate.map { $0.rect.maxY }
            ?? viewSize.height * 0.42

        let gap = menuBox.minY - plateBottom
        guard gap > 0 else { return nil }

        let height = gap * heightFractionOfGap
        let width = height * image.size.width / image.size.height

        return Placement(
            center: CGPoint(x: (plateLeft + viewSize.width) / 2,
                            y: (plateBottom + menuBox.minY) / 2),
            size: CGSize(width: width, height: height)
        )
    }
}

struct CampaignCompassView: View {
    var placement: CampaignCompass.Placement

    var body: some View {
        Image(CampaignCompass.assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: placement.size.width, height: placement.size.height)
            .position(placement.center)
            .allowsHitTesting(false)
    }
}
