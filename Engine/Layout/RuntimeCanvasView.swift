import SwiftUI

/// A screen's content receives the runtime canvas proposal but cannot change
/// the screen's required size. Used for menus as well as the gameplay viewport.
public struct RuntimeCanvasView<Content: View>: View {
    private let size: CGSize
    private let content: Content

    public init(runtimeCanvas: RuntimeCanvas, @ViewBuilder content: () -> Content) {
        size = runtimeCanvas.physicalRect.size
        self.content = content()
    }

    public var body: some View {
        Color.clear
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                content.frame(width: size.width, height: size.height, alignment: .topLeading)
            }
    }
}
