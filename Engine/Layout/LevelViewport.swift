import SwiftUI

/// The measured screen owns the level's size. Map, HUD, and presentations
/// receive that same rectangle, but none can resize it through their content.
/// In particular, removing a full-screen control must never resize/recenter
/// the map in its parent.
/// Keep presentations above the interface: build/upgrade menus must cover
/// call-wave controls, including their hit targets, wherever they overlap.
public struct LevelViewport<MapContent: View, InterfaceContent: View, PresentationContent: View>: View {
    private let size: CGSize
    private let map: MapContent
    private let interface: InterfaceContent
    private let presentations: PresentationContent

    public init(size: CGSize,
                @ViewBuilder map: () -> MapContent,
                @ViewBuilder interface: () -> InterfaceContent,
                @ViewBuilder presentations: () -> PresentationContent) {
        self.size = size
        self.map = map()
        self.interface = interface()
        self.presentations = presentations()
    }

    public var body: some View {
        Color.black
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topLeading) {
                map.frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .overlay(alignment: .topLeading) {
                interface.frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .overlay(alignment: .topLeading) {
                presentations.frame(width: size.width, height: size.height, alignment: .topLeading)
            }
    }
}
