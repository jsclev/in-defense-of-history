import SwiftUI

/// The layered map art for a level, resolved by the LevelMaps naming
/// convention. Above the base terrain image a level may ship road art
/// ("<map>_path"), an overlay ("<map>_overlay"), and occlusion art drawn
/// over everything that moves ("<map>_forest_occlusion", then
/// "<map>_occlusion") so enemies stay hidden before they enter and after
/// they leave. A level gains a layer by adding an asset with the matching
/// name — no code or schema change — and a level without one simply has
/// none.
///
/// The map folder is read once, at construction; the level runtimeCanvas
/// keeps one of these on its runner so the per-frame render never
/// re-answers which layers exist.
///
/// This is THE map compositor. It owns both which layers exist and how each
/// is placed: every layer is a full-canvas image projected onto the play
/// area through one LevelMapProjection. The level runtimeCanvas (full size, its
/// walkers slotted between the tiers) and the briefing portrait (small, at
/// rest) both draw through the tiers below and nothing else, so the two can
/// never disagree about what a level looks like.
struct LevelMapArt {
    let mapImageName: String

    let mapImage: UIImage?

    /// The road-art layer, if the level ships one.
    let pathImage: UIImage?

    /// The overlay layer, if the level ships one.
    let overlayImage: UIImage?

    /// Foliage clusters at the path endpoints, if the level ships them.
    /// Drawn after the walkers, so soldiers enter from and disappear into
    /// the foliage.
    let forestOcclusionImage: UIImage?

    /// The occlusion art covering the entrances and exits, if the level
    /// ships one. The topmost art layer.
    let occlusionImage: UIImage?

    init(mapImageName: String) {
        self.mapImageName = mapImageName
        mapImage = Self.loaded(mapImageName)
        pathImage = Self.loaded(mapImageName + "_path")
        overlayImage = Self.loaded(mapImageName + "_overlay")
        forestOcclusionImage = Self.loaded(mapImageName + "_forest_occlusion")
        occlusionImage = Self.loaded(mapImageName + "_occlusion")
    }

    /// Whether the level has any map art at all.
    var hasArt: Bool { !mapImageName.isEmpty }

    /// The projection every surface builds to composite this art: the
    /// canonical play area fitted into `fitRect`. One constructor, so the
    /// level runtimeCanvas and the briefing portrait fit the map identically.
    static func projection(virtualCanvas: VirtualCanvas, fitting fitRect: CGRect) -> LevelMapProjection {
        LevelMapProjection(playArea: virtualCanvas.playAreaRect, fitRect: fitRect, virtualCanvas: virtualCanvas)
    }

    // MARK: - Tiers, in draw order

    /// Tier 1 — the map below everything that moves: base terrain, road
    /// art, overlay.
    @ViewBuilder func underlay(in projection: LevelMapProjection) -> some View {
        layer(mapImage, in: projection)
        layer(pathImage, in: projection)
        layer(overlayImage, in: projection)
    }

    /// Tier 2 — foliage at the path endpoints. Above the walkers.
    @ViewBuilder func forestOcclusion(in projection: LevelMapProjection) -> some View {
        layer(forestOcclusionImage, in: projection)
    }

    /// Tier 3 — the entrance/exit occlusion. Above every playable layer.
    @ViewBuilder func occlusion(in projection: LevelMapProjection) -> some View {
        layer(occlusionImage, in: projection)
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
    @ViewBuilder private func layer(_ image: UIImage?,
                                    in projection: LevelMapProjection) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .frame(width: projection.imageFrameSize.width,
                       height: projection.imageFrameSize.height)
                .position(projection.imageCenter)
                .allowsHitTesting(false)
        }
    }

    private static func loaded(_ name: String) -> UIImage? {
        guard !name.isEmpty,
              let url = Bundle.main.url(forResource: name,
                                        withExtension: "png",
                                        subdirectory: "LevelMaps")
        else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
