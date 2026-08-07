import CoreGraphics

/// The campaign map artwork and the gameplay-safe rect within it.
///
/// Both the Metal renderer and the SwiftUI HUD need these same values to
/// stay in sync — the renderer to decide what to draw, the HUD to
/// position tappable nodes on top of it. The renderer independently reads
/// the real loaded texture's pixel size for its own drawing, but the HUD
/// has no texture to query, so `imageSize` must be kept in sync by hand
/// whenever the artwork is replaced (as must `safeRectOrigin` /
/// `safeRectSize`, which have no source of truth other than the art).
enum CampaignMapAsset {
    static let imageName = "main_campaign_map_03"

    /// The image's actual pixel dimensions in Assets.xcassets.
    static let imageSize = CGSize(width: 3840, height: 2160)

    /// The rectangle, in the image's own pixel coordinates, that must
    /// always be fully visible on screen. Read from the outline the artist
    /// drew on `main_campaign_map_02_playable_rect.png` (03 is 02 plus
    /// the Mississippi; the framing is unchanged) (diff that file
    /// against the plain art to recover it if the framing changes again).
    /// It is 16:9, so a 16:9 screen shows exactly this and nothing more;
    /// wider or narrower screens reveal extra bleed on one axis, of which
    /// the art has plenty in every direction.
    static let safeRectOrigin = CGPoint(x: 792, y: 472)
    static let safeRectSize = CGSize(width: 2136, height: 1202)

    static var safeRect: CGRect {
        CGRect(origin: safeRectOrigin, size: safeRectSize)
    }
}
