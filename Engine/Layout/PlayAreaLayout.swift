import Foundation
import CoreGraphics

public enum PlayAreaLayout {
    public static func scalingFactor(virtualCanvas: VirtualCanvas, runtimePlayArea: CGRect) -> CGFloat {
        let virtual = virtualCanvas.playAreaRect
        guard virtual.width > 0, virtual.height > 0 else { return 1 }
        return min(runtimePlayArea.width / virtual.width,
                   runtimePlayArea.height / virtual.height)
    }
}
