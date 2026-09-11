import SwiftUI

/// Anchors window-coordinate content at the physical screen origin. A fixed
/// viewport inside a centered root can otherwise be centered in the shorter
/// safe area, moving everything upward by half the bottom inset.
public struct ScreenCanvas<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // This supplies a full-screen layout origin only. RuntimeCanvas still
        // owns the measured geometry; HUD changes do not remeasure the map.
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                content
            }
        }
        .ignoresSafeArea()
    }
}
