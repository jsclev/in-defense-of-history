import SwiftUI
import UIKit

/// The full coordinate chain from a SwiftUI subtree down to the screen,
/// measured with UIKit's documented conversions. SwiftUI's .global space
/// ends at the hosting view; these three rects cover the links it cannot
/// see. To draw at a screen-space y from local code:
///   localY = screenY - windowFrame.minY - viewInWindow.minY
public struct WindowGeometryReport: Equatable {
    /// The measured SwiftUI subtree's frame in WINDOW coordinates
    /// (UIView.convert(bounds, to: window)).
    public let viewInWindow: CGRect
    /// The window's frame in SCREEN coordinates.
    public let windowFrame: CGRect
    /// UIScreen.bounds — the screen in points, current orientation.
    public let screenBounds: CGRect
}

/// Hands the hosting UIWindow and the measured coordinate chain to SwiftUI
/// code. UIView.window is nil until the view joins a hierarchy, and frames
/// settle during layout, so capture happens in didMoveToWindow and again in
/// layoutSubviews. Callbacks arrive on the next main-queue hop so state
/// writes never land inside a render pass.
struct WindowReader: UIViewRepresentable {
    let onWindow: (UIWindow) -> Void
    var onReport: (WindowGeometryReport) -> Void = { _ in }

    func makeUIView(context: Context) -> WindowSpyView {
        WindowSpyView(onWindow: onWindow, onReport: onReport)
    }
    func updateUIView(_ uiView: WindowSpyView, context: Context) {}
}

final class WindowSpyView: UIView {
    let onWindow: (UIWindow) -> Void
    let onReport: (WindowGeometryReport) -> Void
    private var lastReport: WindowGeometryReport?

    init(onWindow: @escaping (UIWindow) -> Void,
         onReport: @escaping (WindowGeometryReport) -> Void) {
        self.onWindow = onWindow
        self.onReport = onReport
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            DispatchQueue.main.async { [onWindow] in onWindow(window) }
            report(in: window)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let window { report(in: window) }
    }

    private func report(in window: UIWindow) {
        let next = WindowGeometryReport(
            viewInWindow: convert(bounds, to: window),
            windowFrame: window.frame,
            screenBounds: window.screen.bounds
        )
        guard next != lastReport else { return }
        lastReport = next
        DispatchQueue.main.async { [onReport] in onReport(next) }
    }
}
