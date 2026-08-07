import SwiftUI

/// The compass rose, positioned from screen geometry rather than a fixed
/// berth in the artwork.
///
/// It is centred in the open sea bounded by the New Haven name plate, the
/// right edge of the map and the corner menu: horizontally halfway between
/// the plate's left edge and the screen's right edge, vertically halfway
/// between the plate's bottom edge and the top of the menu. Its height is
/// half of that same vertical gap, so the rose grows and shrinks with the
/// space it occupies rather than with the screen.
enum CampaignCompass {
    static let assetName = "main_campaign_map_compass"

    /// Height as a share of the gap it sits in — the clear band between the
    /// bottom of the reference plate and the top of the corner menu. Width
    /// follows from the artwork's aspect, so the rose scales as one piece.
    static let heightFractionOfGap: CGFloat = 0.5

    /// The plate the compass is measured against.
    static let referenceNodeID = 13         // New Haven

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

        // Fall back to the sea's own bounds if that plate ever goes missing.
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
