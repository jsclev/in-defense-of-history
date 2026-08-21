import SwiftUI
import UIKit

public struct DebugLayoutGuidesView: View {
    @State private var screen: ScreenGeometry?
    private let canvasSpec: CanvasSpec

    /// The hosting UIWindow, captured once the view joins the hierarchy:
    /// the authority for physical bounds and live safe-area insets.
    @State private var window: UIWindow?

    /// The measured chain SwiftUI's .global space cannot see:
    /// this subtree → window → screen.
    @State private var chain: WindowGeometryReport?

    @State private var hardwareInsets: UIEdgeInsets = .zero
    
    private let safeInsetsDash: [CGFloat] = [1, 6]
    private let playableDash: [CGFloat] = [4, 10]

    private let labelFloor: CGFloat = 30
    
    private let physicalLineThickness: Int = 1
    private let safeInsetsLineThickness: Int = 1
    private let playAreaLineThickness: Int = 1

    private let physicalGuideColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let playAreaGuideColor = Color(red: 0.75, green: 0.15, blue: 1.0)
    private let safeInsetsGuideColor = Color(red: 0.18, green: 1.0, blue: 0.33)
    
    @State private var physicalRectWidth: CGFloat?
    @State private var physicalRectHeight: CGFloat?

    @State private var safeInsetsRect: CGRect?
    
    public init(canvasSpec: CanvasSpec) {
        self.canvasSpec = canvasSpec
    }

    public var body: some View {
        GeometryReader { geometry in
            if let window {
                let frame = geometry.frame(in: .global)
                let physicalRect = window.bounds
                let safeInsets = window.safeAreaInsets
                let safeInsetsRect = CGRect(x: safeInsets.left,
                                            y: frame.minY,
                                            width: frame.width - safeInsets.right - safeInsets.left,
                                            height: frame.height - safeInsets.bottom)

                ZStack(alignment: .topLeading) {
                    createRectView(rect: physicalRect,
                                   borderColor: physicalGuideColor,
                                   borderThickness: physicalLineThickness)
                    createRectView(rect: safeInsetsRect,
                                   borderColor: safeInsetsGuideColor,
                                   borderThickness: safeInsetsLineThickness,
                    borderDash: safeInsetsDash)
                }
            }
        }
        .ignoresSafeArea()
        .background(WindowReader(onWindow: { window = $0 },
                                 onReport: { chain = $0 }))
    }

    private func createRectView(rect: CGRect,
                                borderColor: Color,
                                borderThickness: Int,
                                borderDash: [CGFloat] = []) -> some View {
        return Rectangle()
            .strokeBorder(borderColor, lineWidth: CGFloat(borderThickness))
            .frame(width: rect.width, height: rect.height)
            .position(
                x: rect.midX,
                y: rect.midY
            )
    }

    private func createPlayAreaView() -> some View {
        let projection = LevelMapArt.projection(canvasSpec: canvasSpec, fitting: screen!.playable)
        return SwiftUI.Path(canvasSpec.playAreaShape)
            .applying(projection.viewTransform)
            .stroke(playAreaGuideColor,
                    style: StrokeStyle(lineWidth: CGFloat(playAreaLineThickness),
                                       dash: playableDash))
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
private struct WindowReader: UIViewRepresentable {
    let onWindow: (UIWindow) -> Void
    let onReport: (WindowGeometryReport) -> Void

    func makeUIView(context: Context) -> WindowSpyView {
        WindowSpyView(onWindow: onWindow, onReport: onReport)
    }
    func updateUIView(_ uiView: WindowSpyView, context: Context) {}
}

private final class WindowSpyView: UIView {
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
