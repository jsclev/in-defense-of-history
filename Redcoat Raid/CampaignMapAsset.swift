import CoreGraphics

enum CampaignMapAsset {
    static let imageName = "main_campaign_map_03"

    static let imageSize = CGSize(width: 3840, height: 2160)

    static let safeRectOrigin = CGPoint(x: 792, y: 472)
    static let safeRectSize = CGSize(width: 2136, height: 1202)

    static var safeRect: CGRect {
        CGRect(origin: safeRectOrigin, size: safeRectSize)
    }
}
