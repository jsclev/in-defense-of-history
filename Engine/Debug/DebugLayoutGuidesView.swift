import SwiftUI
import UIKit

public struct DebugLayoutGuidesView: View {
    private let screen: ScreenGeometry

    @State private var chain: WindowGeometryReport?

    private let safeInsetsDash: [CGFloat] = [16, 9]
    private let playAreaRectDash: [CGFloat] = [6, 10]
    private let playAreaDash: [CGFloat] = [6, 10]

    private let labelFloor: CGFloat = 30
    private let lineThickness: Int = 2

    private let physicalGuideColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let safeInsetsGuideColor = Color(red: 0.18, green: 1.0, blue: 0.33)
    private let playAreaRectGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)
    private let playAreaGuideColor = Color(red: 1.0, green: 0.0, blue: 1.0)

    public init(screen: ScreenGeometry) {
        self.screen = screen
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if let chain {
                ZStack(alignment: .topLeading) {
                    createRectView(rect: screen.physicalRect,
                                   borderColor: physicalGuideColor,
                                   borderThickness: lineThickness)
                    createRectView(rect: screen.safeInsetsRect,
                                   borderColor: safeInsetsGuideColor,
                                   borderThickness: lineThickness,
                                   borderDash: safeInsetsDash)
                    createRectView(rect: screen.playAreaRect,
                                   borderColor: playAreaRectGuideColor,
                                   borderThickness: lineThickness,
                                   borderDash: playAreaRectDash)
                    createPlayAreaView()
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .background(WindowReader(onWindow: { _ in },
                                 onReport: { chain = $0 }))
    }

    private func createRectView(rect: CGRect,
                                borderColor: Color,
                                borderThickness: Int,
                                borderDash: [CGFloat] = []) -> some View {
        return Rectangle()
            .strokeBorder(borderColor,
                          style: StrokeStyle(lineWidth: CGFloat(borderThickness), dash: borderDash))
            .frame(width: rect.width, height: rect.height)
            .position(
                x: rect.midX,
                y: rect.midY
            )
    }

    private func createPlayAreaView() -> some View {
        SwiftUI.Path(screen.runtimePlayArea)
            .stroke(playAreaGuideColor,
                    style: StrokeStyle(lineWidth: CGFloat(lineThickness),
                                       dash: playAreaDash))
    }

    private func fmt(_ v: CGFloat) -> String { String(format: "%.0f", v) }

    private func fmt(_ r: CGRect) -> String {
        "(\(fmt(r.minX)), \(fmt(r.minY)))  \(fmt(r.width)) × \(fmt(r.height))"
    }

    private func inset(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: Typography.size(11), weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(safeInsetsGuideColor.opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 3))
            .position(point)
    }
}

/// The full coordinate chain from this SwiftUI subtree down to the screen,
/// measured with UIKit's documented conversions. SwiftUI's .global space
/// ends at the hosting view; these three rects cover the links it cannot
/// see. To draw at a screen-space y from local code:
///   localY = screenY - windowFrame.minY - viewInWindow.minY
public struct WindowGeometryReport: Equatable {
    /// This SwiftUI subtree's frame in WINDOW coordinates
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
/// layoutSubviews.
struct WindowReader: UIViewRepresentable {
    let onWindow: (UIWindow) -> Void
    let onReport: (WindowGeometryReport) -> Void

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
            onWindow(window)
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
        // UIKit layout is outside SwiftUI's render pass, but the async hop
        // keeps the state write safe if a pass is in flight.
        DispatchQueue.main.async { [onReport] in onReport(next) }
    }
}
