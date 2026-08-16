import SwiftUI

/// The layered map art for a level, resolved by the asset-library naming
/// convention. Above the base terrain image a level may ship road art
/// ("<map>_path"), an overlay ("<map>_overlay"), and occlusion art drawn
/// over everything that moves ("<map>_forest_occlusion", then
/// "<map>_occlusion") so enemies stay hidden before they enter and after
/// they leave. A level gains a layer by adding an asset with the matching
/// name — no code or schema change — and a level without one simply has
/// none.
///
/// The asset library is probed once, at construction; the level screen
/// keeps one of these on its runner so the per-frame render never
/// re-answers which layers exist.
///
/// This is THE map compositor. It owns both which layers exist and how each
/// is placed: every layer is a full-canvas image projected onto the play
/// area through one LevelMapProjection. The level screen (full size, its
/// walkers slotted between the tiers) and the briefing portrait (small, at
/// rest) both draw through the tiers below and nothing else, so the two can
/// never disagree about what a level looks like.
struct LevelMapArt {
    let mapImageName: String

    /// The road-art layer's asset name, if the level ships one.
    let pathName: String?

    /// The overlay layer's asset name, if the level ships one.
    let overlayName: String?

    /// Foliage clusters at the path endpoints, if the level ships them.
    /// Drawn after the walkers, so soldiers enter from and disappear into
    /// the foliage.
    let forestOcclusionName: String?

    /// The occlusion art covering the entrances and exits, if the level
    /// ships one. The topmost art layer.
    let occlusionName: String?

    init(mapImageName: String) {
        self.mapImageName = mapImageName
        pathName = Self.existing(mapImageName + "_path")
        overlayName = Self.existing(mapImageName + "_overlay")
        forestOcclusionName = Self.existing(mapImageName + "_forest_occlusion")
        occlusionName = Self.existing(mapImageName + "_occlusion")
    }

    /// Whether the level has any map art at all.
    var hasArt: Bool { !mapImageName.isEmpty }

    /// The projection every surface builds to composite this art: the
    /// canonical play area fitted into `fitRect`. One constructor, so the
    /// level screen and the briefing portrait fit the map identically.
    static func projection(fitting fitRect: CGRect) -> LevelMapProjection {
        LevelMapProjection(playArea: CanvasSpec.playArea, fitRect: fitRect)
    }

    // MARK: - Tiers, in draw order

    /// Tier 1 — the map below everything that moves: base terrain, road
    /// art, overlay.
    @ViewBuilder func underlay(in projection: LevelMapProjection) -> some View {
        layer(mapImageName, in: projection)
        layer(pathName, in: projection)
        layer(overlayName, in: projection)
    }

    /// Tier 2 — foliage at the path endpoints. Above the walkers.
    @ViewBuilder func forestOcclusion(in projection: LevelMapProjection) -> some View {
        layer(forestOcclusionName, in: projection)
    }

    /// Tier 3 — the entrance/exit occlusion. Above every playable layer.
    @ViewBuilder func occlusion(in projection: LevelMapProjection) -> some View {
        layer(occlusionName, in: projection)
    }

    /// The finished map at rest — all three tiers, in the level screen's
    /// order, with nothing between them. What the briefing portrait draws.
    @ViewBuilder func complete(in projection: LevelMapProjection) -> some View {
        underlay(in: projection)
        forestOcclusion(in: projection)
        occlusion(in: projection)
    }

    // MARK: - Placement

    /// The one placement rule: a layer is a full-canvas image, sized to the
    /// projected canvas and centred on it, so every layer registers
    /// pixel-for-pixel with the terrain. Never hit-tested — art layers sit
    /// among tappable controls and must not swallow their taps.
    @ViewBuilder private func layer(_ name: String?,
                                    in projection: LevelMapProjection) -> some View {
        if let name, !name.isEmpty {
            Image(name)
                .resizable()
                .frame(width: projection.imageFrameSize.width,
                       height: projection.imageFrameSize.height)
                .position(projection.imageCenter)
                .allowsHitTesting(false)
        }
    }

    private static func existing(_ name: String) -> String? {
        UIImage(named: name) != nil ? name : nil
    }
}
