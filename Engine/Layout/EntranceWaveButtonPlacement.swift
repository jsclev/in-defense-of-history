import CoreGraphics

public final class EntranceWaveButtonPlacement {
    public let positions: [CGPoint]

    public init(entrancePaths: [[CGPoint]],
                slotCenters: [CGPoint],
                slotSize: CGSize,
                buttonSize: CGFloat,
                geometry: ScreenGeometry) {
        let safe = geometry.safeInsetsRect
        let physical = geometry.physicalRect
        let horizontalMargin = geometry.playAreaRect.width * geometry.marginScaleFactor
        let verticalMargin = geometry.playAreaRect.height * geometry.marginScaleFactor

        let leadingNudge = max(0, horizontalMargin - (safe.minX - physical.minX))
        let trailingNudge = max(0, horizontalMargin - (physical.maxX - safe.maxX))
        let topNudge = max(0, verticalMargin - (safe.minY - physical.minY))
        let bottomNudge = max(0, verticalMargin - (physical.maxY - safe.maxY))

        let half = buttonSize / 2
        let minX = safe.minX + leadingNudge + half
        let maxX = safe.maxX - trailingNudge - half
        let minY = safe.minY + topNudge + half
        let maxY = safe.maxY - bottomNudge - half

        let blockedSemiWidth = slotSize.width / 2 + half
        let blockedSemiHeight = slotSize.height / 2 + half

        func onScreen(_ p: CGPoint) -> Bool {
            p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
        }
        func clearOfSlots(_ p: CGPoint) -> Bool {
            slotCenters.allSatisfy {
                hypot(($0.x - p.x) / blockedSemiWidth,
                      ($0.y - p.y) / blockedSemiHeight) >= 1
            }
        }

        var placed: [CGPoint] = []
        for path in entrancePaths {
            let position: CGPoint
            if let clearIndex = path.indices.first(where: { onScreen(path[$0]) && clearOfSlots(path[$0]) }) {
                let entryIndex = path.indices.first { onScreen(path[$0]) } ?? clearIndex
                var index = clearIndex - (clearIndex - entryIndex) / 3
                while index < clearIndex && !onScreen(path[index]) {
                    index += 1
                }
                position = path[index]
            } else if let visible = path.first(where: onScreen) {
                position = visible
            } else if let mouth = path.first {
                position = CGPoint(x: min(max(mouth.x, minX), maxX),
                                   y: min(max(mouth.y, minY), maxY))
            } else {
                continue
            }
            if placed.allSatisfy({ hypot($0.x - position.x, $0.y - position.y) >= buttonSize }) {
                placed.append(position)
            }
        }
        positions = placed
    }
}
