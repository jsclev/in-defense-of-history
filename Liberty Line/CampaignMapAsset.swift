import CoreGraphics

enum CampaignMapAsset {
    static let imageName = "main_campaign_map_03"

    // SQL world-map positions use pixels in the full painted virtual canvas.
    static let imageSize = CGSize(width: 2868, height: 2064)

    static let safeRectOrigin = CGPoint(x: 474, y: 492)
    static let safeRectSize = CGSize(width: 1920, height: 1080)

    static var safeRect: CGRect {
        CGRect(origin: safeRectOrigin, size: safeRectSize)
    }
}
