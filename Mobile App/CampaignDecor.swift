import SwiftUI

enum CampaignDecor {
    struct Piece {
        var assetName: String
        var imagePosition: CGPoint
        var widthFraction: CGFloat
        var flipped: Bool = false
    }

    struct Placement: Identifiable {
        var id: String { piece.assetName }
        var piece: Piece
        var center: CGPoint
        var size: CGSize

        var frame: CGRect {
            CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                   width: size.width, height: size.height)
        }
    }

    static let pieces: [Piece] = [
        Piece(assetName: "main_campaign_map_ship_american",
              imagePosition: CGPoint(x: 2690, y: 1040), widthFraction: 0.075,
              flipped: true),

        Piece(assetName: "main_campaign_map_ship_spanish",
              imagePosition: CGPoint(x: 1085, y: 1600), widthFraction: 0.065,
              flipped: true),

        Piece(assetName: "main_campaign_map_land_voyageur",
              imagePosition: CGPoint(x: 1039, y: 730), widthFraction: 0.078),
        Piece(assetName: "main_campaign_map_land_conestoga",
              imagePosition: CGPoint(x: 1030, y: 1380), widthFraction: 0.080),
        Piece(assetName: "main_campaign_map_land_cumberland",
              imagePosition: CGPoint(x: 1350, y: 1220), widthFraction: 0.070),

        Piece(assetName: "main_campaign_map_land_boonestation",
              imagePosition: CGPoint(x: 1324, y: 998), widthFraction: 0.075),

        Piece(assetName: "main_campaign_map_land_chartres",
              imagePosition: CGPoint(x: 2291, y: 427), widthFraction: 0.072),
        Piece(assetName: "main_campaign_map_land_haudenosaunee",
              imagePosition: CGPoint(x: 1815, y: 605), widthFraction: 0.072),
    ]

    static func placements(
        viewSize: CGSize,
        callouts: [CampaignMarkers.Placement],
        menuExclusion: CGRect
    ) -> [Placement] {
        guard viewSize.width > 0, viewSize.height > 0 else { return [] }

        var result: [Placement] = []
        for piece in pieces {
            let center = CampaignMapLayout.viewPoint(
                forImagePoint: piece.imagePosition,
                imageSize: CampaignMapAsset.imageSize,
                safeRect: CampaignMapAsset.safeRect,
                viewSize: viewSize
            )
            guard let image = UIImage(named: piece.assetName) else { continue }
            let width = viewSize.width * piece.widthFraction
            let height = width * image.size.height / max(image.size.width, 1)
            let frame = CGRect(
                x: center.x - width / 2, y: center.y - height / 2,
                width: width, height: height
            )

            guard CGRect(origin: .zero, size: viewSize).contains(frame) else { continue }
            guard !frame.intersects(menuExclusion) else { continue }
            guard !result.contains(where: { $0.frame.intersects(frame) }) else { continue }

            let clash = callouts.contains { callout in
                let disc = callout.rect.insetBy(dx: -6, dy: -6)
                if disc.intersects(frame) { return true }
                if frame.insetBy(dx: frame.width * 0.12, dy: frame.height * 0.12)
                    .contains(callout.anchor) { return true }
                guard callout.showsTether else { return false }
                return segment(callout.center, callout.anchor, intersects: frame)
            }
            guard !clash else { continue }

            result.append(Placement(piece: piece, center: center,
                                    size: CGSize(width: width, height: height)))
        }
        return result
    }

    private static func segment(_ a: CGPoint, _ b: CGPoint,
                                intersects rect: CGRect) -> Bool {
        var t0: CGFloat = 0, t1: CGFloat = 1
        let dx = b.x - a.x, dy = b.y - a.y
        let checks: [(CGFloat, CGFloat)] = [
            (-dx, a.x - rect.minX), (dx, rect.maxX - a.x),
            (-dy, a.y - rect.minY), (dy, rect.maxY - a.y),
        ]
        for (p, q) in checks {
            if p == 0 {
                if q < 0 { return false }
                continue
            }
            let r = q / p
            if p < 0 {
                if r > t1 { return false }
                if r > t0 { t0 = r }
            } else {
                if r < t0 { return false }
                if r < t1 { t1 = r }
            }
        }
        return true
    }
}

struct CampaignDecorView: View {
    var placement: CampaignDecor.Placement

    var body: some View {
        Image(placement.piece.assetName)
            .resizable()
            .scaledToFit()
            .scaleEffect(x: placement.piece.flipped ? -1 : 1)
            .frame(width: placement.size.width, height: placement.size.height)
            .shadow(color: .black.opacity(0.28),
                    radius: placement.size.width * 0.04,
                    y: placement.size.height * 0.03)
            .allowsHitTesting(false)
    }
}
