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
/// The level screen and the briefing portrait both construct the map from
/// this one definition, so the two can never disagree about what a level
/// looks like.
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

    /// The map image below everything that moves: the base terrain, the
    /// road art over it, then the overlay, each drawn at the same frame so
    /// the layers register pixel-for-pixel.
    var underlay: some View {
        ZStack {
            Image(mapImageName).resizable()
            layer(pathName)
            layer(overlayName)
        }
    }

    /// The finished map at rest — every layer, in the level screen's order.
    /// The briefing portrait draws this; the level screen draws the
    /// occlusion layers itself, above its walkers.
    var complete: some View {
        ZStack {
            underlay
            layer(forestOcclusionName)
            layer(occlusionName)
        }
    }

    private static func existing(_ name: String) -> String? {
        UIImage(named: name) != nil ? name : nil
    }

    @ViewBuilder private func layer(_ name: String?) -> some View {
        if let name {
            Image(name).resizable()
        }
    }
}
