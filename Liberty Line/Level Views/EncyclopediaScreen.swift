import SwiftUI

enum EncyclopediaStyle {
    static let ink = Color(red: 0.22, green: 0.12, blue: 0.055)
    static let paper = Color(red: 0.97, green: 0.88, blue: 0.66)
    static let accent = Color(red: 0.48, green: 0.23, blue: 0.07)
    static let selection = Color(red: 1, green: 0.77, blue: 0.20)
}

/// Both rosters share the same painted canvas, parchment, title and controls.
/// Callers provide only their roster entries and selected-entry pages.
@available(iOS 26.0, *)
struct EncyclopediaScreen<Roster: View, Details: View>: View {
    let runtimeCanvas: RuntimeCanvas
    let selectionTitle: String
    let titleIdentifier: String
    let onExit: () -> Void
    private let roster: (TowerEncyclopediaLayout) -> Roster
    private let details: (TowerEncyclopediaLayout) -> Details

    init(runtimeCanvas: RuntimeCanvas, selectionTitle: String, titleIdentifier: String,
         onExit: @escaping () -> Void,
         @ViewBuilder roster: @escaping (TowerEncyclopediaLayout) -> Roster,
         @ViewBuilder details: @escaping (TowerEncyclopediaLayout) -> Details) {
        self.runtimeCanvas = runtimeCanvas
        self.selectionTitle = selectionTitle
        self.titleIdentifier = titleIdentifier
        self.onExit = onExit
        self.roster = roster
        self.details = details
    }

    var body: some View {
        let layout = TowerEncyclopediaLayout(runtimeCanvas: runtimeCanvas, doneAspect: DoneButton.aspect)
        ZStack(alignment: .topLeading) {
            artwork("tower_encyclopedia_background", frame: layout.backgroundFrame)
            artwork("tower_encyclopedia_scroll", frame: layout.scrollFrame)

            roster(layout)
                .frame(width: layout.gridFrame.width, height: layout.gridFrame.height)
                .position(x: layout.gridFrame.midX, y: layout.gridFrame.midY)

            details(layout)
                .frame(width: layout.detailFrame.width, height: layout.detailFrame.height)
                .background(EncyclopediaStyle.paper.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .position(x: layout.detailFrame.midX, y: layout.detailFrame.midY)

            Text(selectionTitle)
                .font(.custom("Baskerville-Bold", size: 23 * layout.typeScale))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: layout.titleFrame.width, height: layout.titleFrame.height)
                .position(x: layout.titleFrame.midX, y: layout.titleFrame.midY)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(titleIdentifier)

            DoneButton(runtimeCanvas: runtimeCanvas, action: onExit, frame: layout.doneFrame)
        }
        .foregroundStyle(EncyclopediaStyle.ink)
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height,
               alignment: .topLeading)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
    }

    private func artwork(_ name: String, frame: CGRect) -> some View {
        Image(uiImage: DemonstrationArtwork.image(name))
            .resizable().interpolation(.high)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
