import SwiftUI
import UIKit

/// Crops atlas cells once, keeping the painted camera upright at every facing.
/// The full shared cell (including padding) is retained so turning cannot resize
/// the tower or move its ground anchor.
struct ArtilleryTowerSprite: View {
    let sheetName: String
    let fallbackName: String
    let facing: ArtilleryFacing

    var body: some View {
        image.resizable().scaledToFit()
    }

    private var image: Image {
        if let frame = ArtilleryFrameCache.shared.image(named: sheetName, facing: facing) {
            return Image(uiImage: frame)
        }
        return Image(fallbackName)
    }
}

@MainActor
private final class ArtilleryFrameCache {
    static let shared = ArtilleryFrameCache()
    private var frames: [String: [UIImage]] = [:]

    func image(named name: String, facing: ArtilleryFacing) -> UIImage? {
        if let cached = frames[name] { return cached[facing.frameIndex] }
        guard let sheet = UIImage(named: name), let source = sheet.cgImage,
              source.width % ArtilleryFacing.columns == 0,
              source.height % ArtilleryFacing.rows == 0 else { return nil }
        let size = CGSize(width: source.width, height: source.height)
        var cells: [UIImage] = []
        for index in 0..<ArtilleryFacing.frameCount {
            let direction = ArtilleryFacing(heading: -Double(index) * ArtilleryFacing.angleStep)
            guard let crop = source.cropping(to: direction.frameRect(sheetSize: size)) else {
                return nil
            }
            cells.append(UIImage(cgImage: crop, scale: sheet.scale, orientation: .up))
        }
        frames[name] = cells
        return cells[facing.frameIndex]
    }
}
