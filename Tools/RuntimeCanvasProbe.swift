// Isolated UIKit test of the production geometry gate; no game database or saves.
import SwiftUI
import UIKit

@MainActor private enum Evidence {
    static var frames: [String: [CGFloat]] = [:]
    static var measured: [String: Any] = [:]
    static var rows: [[String: Any]] = []
    static func rect(_ r: CGRect) -> [CGFloat] { [r.minX, r.minY, r.width, r.height] }
}

private struct FrameSpy: UIViewRepresentable {
    let key: String
    var canvas: RuntimeCanvas? = nil
    var identity: UUID? = nil
    func makeUIView(context: Context) -> FrameView { FrameView(key: key) }
    func updateUIView(_ view: FrameView, context: Context) {
        if let canvas, let identity {
            Evidence.measured = ["physical": Evidence.rect(canvas.physicalRect),
                                 "safe": Evidence.rect(canvas.safeInsetsRect),
                                 "play": Evidence.rect(canvas.playAreaRect),
                                 "identity": identity.uuidString]
        }
        view.record()
    }
}
private final class FrameView: UIView {
    let key: String
    init(key: String) { self.key = key; super.init(frame: .zero); isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError() }
    override func didMoveToWindow() { super.didMoveToWindow(); record() }
    override func layoutSubviews() { super.layoutSubviews(); record() }
    func record() {
        if let window { Evidence.frames[key] = Evidence.rect(convert(bounds, to: window)) }
    }
}
private let virtual = VirtualCanvas(
    size: CGSize(width: 2868, height: 2064),
    playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
    pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
    towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
    statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
    masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
    heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
    miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))

private struct ProbeScreen: View {
    let canvas: RuntimeCanvas
    let oversized: Bool
    @State private var identity = UUID()
    var body: some View {
        LevelViewport(size: canvas.physicalRect.size) {
            Color.green.overlay(alignment: .topLeading) {
                Color.red.frame(width: 12, height: 12)
                    .background(FrameSpy(key: "marker"))
                    .position(x: canvas.playAreaRect.midX, y: canvas.playAreaRect.midY)
            }.background(FrameSpy(key: "map"))
        } interface: {
            if oversized { Color.clear.frame(width: 4000, height: 2000) }
        } presentations: { EmptyView() }
        .background(FrameSpy(key: "screen", canvas: canvas, identity: identity))
    }
}
@MainActor private final class Delegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { .landscape }
}
@main struct RuntimeCanvasProbe: App {
    @UIApplicationDelegateAdaptor(Delegate.self) private var delegate
    var body: some Scene { WindowGroup { ProbeRoot() } }
}
private struct ProbeRoot: View {
    @State private var oversized = false
    var body: some View {
        ScreenGeometryGate(virtualCanvas: virtual) { canvas in
            ProbeScreen(canvas: canvas, oversized: oversized)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            try? await Task.sleep(for: .seconds(1))
            let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
            let window = scene.windows.first!
            let original = window.frame
            for phase in ["initial", "oversized", "resized", "restored"] {
                oversized = phase == "oversized"
                if phase == "resized" { window.frame = CGRect(x: 0, y: 0, width: 740, height: 360) }
                if phase == "restored" { window.frame = original }
                window.setNeedsLayout()
                window.layoutIfNeeded()
                try? await Task.sleep(for: .milliseconds(600))
                @MainActor func refresh(_ view: UIView) {
                    (view as? FrameView)?.record()
                    view.subviews.forEach(refresh)
                }
                refresh(window)
                Evidence.rows.append(["phase": phase,
                    "runID": ProcessInfo.processInfo.arguments.last ?? "",
                    "window": Evidence.rect(window.bounds),
                    "safe": Evidence.rect(window.bounds.inset(by: window.safeAreaInsets)),
                    "frames": Evidence.frames, "canvas": Evidence.measured])
            }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("runtime-canvas-results.json")
            try! JSONSerialization.data(withJSONObject: Evidence.rows, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        }
    }
}
