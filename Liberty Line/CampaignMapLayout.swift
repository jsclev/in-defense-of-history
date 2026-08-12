import CoreGraphics

enum CampaignMapLayout {
    struct Crop {
        var rect: CGRect

        var rotated: Bool
    }

    static func makeCrop(
        imageSize: CGSize,
        safeRect: CGRect,
        viewSize: CGSize
    ) -> Crop {
        let rotated = viewSize.height > viewSize.width

        let viewAspect = rotated
            ? viewSize.height / viewSize.width
            : viewSize.width / viewSize.height

        let safeAspect = safeRect.width / safeRect.height

        var cropWidth: CGFloat
        var cropHeight: CGFloat

        if viewAspect > safeAspect {
            cropHeight = safeRect.height
            cropWidth = cropHeight * viewAspect
        } else {
            cropWidth = safeRect.width
            cropHeight = cropWidth / viewAspect
        }

        assert(
            cropWidth <= imageSize.width && cropHeight <= imageSize.height,
            "\(CampaignMapAsset.imageName) doesn't have enough bleed " +
            "around safeRect to aspect-fill this view without " +
            "stretching. Extend the artwork's margins to fix this."
        )

        cropWidth = min(cropWidth, imageSize.width)
        cropHeight = min(cropHeight, imageSize.height)

        var cropOriginX = safeRect.midX - cropWidth / 2
        var cropOriginY = safeRect.midY - cropHeight / 2

        cropOriginX = min(max(cropOriginX, 0), imageSize.width - cropWidth)
        cropOriginY = min(max(cropOriginY, 0), imageSize.height - cropHeight)

        return Crop(
            rect: CGRect(
                x: cropOriginX,
                y: cropOriginY,
                width: cropWidth,
                height: cropHeight
            ),
            rotated: rotated
        )
    }

    static func viewRect(
        forImageRect imageRect: CGRect,
        imageSize: CGSize,
        safeRect: CGRect,
        viewSize: CGSize
    ) -> (center: CGPoint, size: CGSize) {
        let crop = makeCrop(
            imageSize: imageSize,
            safeRect: safeRect,
            viewSize: viewSize
        )
        let center = viewPoint(
            forImagePoint: CGPoint(x: imageRect.midX, y: imageRect.midY),
            imageSize: imageSize,
            safeRect: safeRect,
            viewSize: viewSize
        )
        if crop.rotated {
            let scaleX = viewSize.width / crop.rect.height
            let scaleY = viewSize.height / crop.rect.width
            return (center, CGSize(width: imageRect.height * scaleX,
                                   height: imageRect.width * scaleY))
        } else {
            let scaleX = viewSize.width / crop.rect.width
            let scaleY = viewSize.height / crop.rect.height
            return (center, CGSize(width: imageRect.width * scaleX,
                                   height: imageRect.height * scaleY))
        }
    }

    static func imagePoint(
        forViewPoint viewPointIn: CGPoint,
        imageSize: CGSize,
        safeRect: CGRect,
        viewSize: CGSize
    ) -> CGPoint {
        let crop = makeCrop(imageSize: imageSize, safeRect: safeRect, viewSize: viewSize)
        let fractionX: CGFloat
        let fractionY: CGFloat
        if crop.rotated {
            fractionX = viewPointIn.y / viewSize.height
            fractionY = 1 - viewPointIn.x / viewSize.width
        } else {
            fractionX = viewPointIn.x / viewSize.width
            fractionY = viewPointIn.y / viewSize.height
        }
        return CGPoint(x: crop.rect.minX + fractionX * crop.rect.width,
                       y: crop.rect.minY + fractionY * crop.rect.height)
    }

    static func viewPoint(
        forImagePoint imagePoint: CGPoint,
        imageSize: CGSize,
        safeRect: CGRect,
        viewSize: CGSize
    ) -> CGPoint {
        let crop = makeCrop(
            imageSize: imageSize,
            safeRect: safeRect,
            viewSize: viewSize
        )

        let fractionX = (imagePoint.x - crop.rect.minX) / crop.rect.width
        let fractionY = (imagePoint.y - crop.rect.minY) / crop.rect.height

        guard crop.rotated else {
            return CGPoint(
                x: fractionX * viewSize.width,
                y: fractionY * viewSize.height
            )
        }

        return CGPoint(
            x: (1 - fractionY) * viewSize.width,
            y: fractionX * viewSize.height
        )
    }
}
