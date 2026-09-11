import SwiftUI

/// Mounted above the level's ordinary content and HUD. Each entry creates its
/// own view subtree, with the most recently opened presentation drawn last.
/// An empty stack has no presentation views or input catchers.
struct PresentationLayers<Presentation: Equatable, LayerContent: View>: View {
    let stack: PresentationStack<Presentation>
    @ViewBuilder let content: (Presentation) -> LayerContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(stack.entries) { entry in
                ZStack(alignment: .topLeading) {
                    content(entry.content)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.identity)
            }
        }
    }
}
