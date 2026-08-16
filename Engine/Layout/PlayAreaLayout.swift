import Foundation
import CoreGraphics

public enum PlayAreaLayout {
    public static func scalingFactor(runtimePlayArea: CGRect) -> CGFloat {
        let virtual = CanvasSpec.playArea
        guard virtual.width > 0, virtual.height > 0 else { return 1 }
        return min(runtimePlayArea.width / virtual.width,
                   runtimePlayArea.height / virtual.height)
    }
}
