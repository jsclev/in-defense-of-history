import SwiftUI

@available(iOS 26.0, *)
struct HudLayoutConfigView: View {
    private let db: Db
    private let onSave: (HudLayoutConfig) -> Void
    private let onExit: () -> Void

    private let metrics: HudMetrics
    private let boardSize: CGSize
    private let cellSize: CGSize
    private let zoneSize: CGSize
    private let sectionSizes: [HudSection: CGSize]
    private let zoneCorner: CGFloat
    private let zoneInset: CGFloat
    private let zoneLineWidth: CGFloat
    private let zoneDash: [CGFloat]
    private let chipCorner: CGFloat
    private let chipLineWidth: CGFloat
    private let chipTextPadding: CGFloat
    private let titleFontSize: CGFloat
    private let bodyFontSize: CGFloat
    private let chipFontSize: CGFloat
    private let zoneLabelFontSize: CGFloat
    private let panelSpacing: CGFloat
    private let buttonPaddingHorizontal: CGFloat
    private let buttonPaddingVertical: CGFloat

    @State private var hudLayoutConfig: HudLayoutConfig
    @State private var draggedSection: HudSection?
    @State private var dragPoint: CGPoint?
    @State private var targetedLocation: HudLocation?
    @State private var unsavedChanges = false
    @State private var saveFailure: String?

    init(db: Db, runtimeCanvas: RuntimeCanvas, hudLayoutConfig: HudLayoutConfig,
         onSave: @escaping (HudLayoutConfig) -> Void,
         onExit: @escaping () -> Void) {
        self.db = db
        self.onSave = onSave
        self.onExit = onExit
        _hudLayoutConfig = State(initialValue: hudLayoutConfig)

        let metrics = HudMetrics(runtimeCanvas: runtimeCanvas)
        self.metrics = metrics

        boardSize = runtimeCanvas.playAreaRect.size
        cellSize = CGSize(width: boardSize.width / 3, height: boardSize.height / 3)
        zoneInset = 4 * metrics.scale
        zoneSize = CGSize(width: cellSize.width - 2 * zoneInset,
                          height: cellSize.height - 2 * zoneInset)
        sectionSizes = [.heroBar: runtimeCanvas.heroBarSize,
                        .statsView: runtimeCanvas.statsViewSize,
                        .miscView: runtimeCanvas.miscViewSize,
                        .masterControls: runtimeCanvas.masterControlsSize]

        zoneCorner = 14 * metrics.scale
        zoneLineWidth = 2 * metrics.scale
        zoneDash = [7 * metrics.scale, 5 * metrics.scale]
        chipCorner = 10 * metrics.scale
        chipLineWidth = 2 * metrics.scale
        chipTextPadding = 6 * metrics.scale
        titleFontSize = 32 * metrics.scale
        bodyFontSize = Typography.size(14 * metrics.scale)
        chipFontSize = Typography.size(17 * metrics.scale)
        zoneLabelFontSize = Typography.size(13 * metrics.scale)
        panelSpacing = 10 * metrics.scale
        buttonPaddingHorizontal = 24 * metrics.scale
        buttonPaddingVertical = 9 * metrics.scale
    }

    var body: some View {
        board
            .background {
                ZStack {
                    Image("hero_screen_background")
                        .resizable()
                        .scaledToFill()
                    Color.black.opacity(0.62)
                }
                .clipped()
                .ignoresSafeArea()
            }
            .persistentSystemOverlays(.hidden)
    }

    private var board: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    zone(.northWest, alignment: .topLeading)
                    zone(.north, alignment: .top)
                    zone(.northEast, alignment: .topTrailing)
                }
                HStack(spacing: 0) {
                    zone(.west, alignment: .leading)
                    controlPanel
                    zone(.east, alignment: .trailing)
                }
                HStack(spacing: 0) {
                    zone(.southWest, alignment: .bottomLeading)
                    zone(.south, alignment: .bottom)
                    zone(.southEast, alignment: .bottomTrailing)
                }
            }

            if let draggedSection, let dragPoint {
                chip(draggedSection)
                    .shadow(color: .black.opacity(0.6), radius: 8 * metrics.scale)
                    .position(dragPoint)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: boardSize.width, height: boardSize.height)
        .coordinateSpace(.named(Self.boardSpace))
    }

    private func zone(_ hudLocation: HudLocation, alignment: Alignment) -> some View {
        let hudSection = hudLayoutConfig.section(at: hudLocation)
        return ZStack(alignment: alignment) {
            RoundedRectangle(cornerRadius: zoneCorner, style: .continuous)
                .strokeBorder(zoneTint(hudLocation),
                              style: StrokeStyle(lineWidth: zoneLineWidth, dash: zoneDash))
                .overlay {
                    if hudSection == nil {
                        Text(hudLocation.title)
                            .font(.system(size: zoneLabelFontSize, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }

            if let hudSection {
                chip(hudSection)
                    .opacity(draggedSection == hudSection ? 0.22 : 1)
                    .gesture(dragGesture(for: hudSection))
            }
        }
        .frame(width: zoneSize.width, height: zoneSize.height)
        .padding(zoneInset)
    }

    private func dragGesture(for hudSection: HudSection) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.boardSpace))
            .onChanged { value in
                draggedSection = hudSection
                dragPoint = value.location
                targetedLocation = location(at: value.location)
            }
            .onEnded { value in
                if let hudLocation = location(at: value.location) {
                    let moved = hudLayoutConfig.moving(hudSection, to: hudLocation)
                    if moved != hudLayoutConfig {
                        hudLayoutConfig = moved
                        unsavedChanges = true
                        saveFailure = nil
                    }
                }
                draggedSection = nil
                dragPoint = nil
                targetedLocation = nil
            }
    }

    private func location(at point: CGPoint) -> HudLocation? {
        guard point.x >= 0, point.x < boardSize.width,
              point.y >= 0, point.y < boardSize.height else { return nil }
        let column = Int(point.x / cellSize.width)
        let row = Int(point.y / cellSize.height)
        return Self.zoneGrid[row][column]
    }

    private func zoneTint(_ hudLocation: HudLocation) -> Color {
        if targetedLocation == hudLocation { return Self.gold }
        return hudLayoutConfig.section(at: hudLocation) == nil
            ? .white.opacity(0.22)
            : .white.opacity(0.42)
    }

    private func chip(_ hudSection: HudSection) -> some View {
        let requested = sectionSizes[hudSection, default: zoneSize]
        let size = CGSize(width: min(requested.width, zoneSize.width),
                          height: min(requested.height, zoneSize.height))
        return ZStack {
            RoundedRectangle(cornerRadius: chipCorner, style: .continuous)
                .fill(.black.opacity(0.72))
            RoundedRectangle(cornerRadius: chipCorner, style: .continuous)
                .strokeBorder(Self.gold, lineWidth: chipLineWidth)
            Text(hudSection.title)
                .font(.custom("Baskerville-SemiBold", size: chipFontSize))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(chipTextPadding)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
    }

    private var controlPanel: some View {
        VStack(spacing: panelSpacing) {
            Text("HUD Layout")
                .font(.custom("Baskerville-Bold", size: titleFontSize))
                .foregroundStyle(.white)

            Text("Drag a section onto any edge or corner. "
                 + "Dropping onto an occupied area swaps the two.")
                .font(.system(size: bodyFontSize))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)

            if let saveFailure {
                Text(saveFailure)
                    .font(.system(size: bodyFontSize))
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.4))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: panelSpacing) {
                panelButton("Save", prominent: true, action: save)
                panelButton("Done", prominent: false, action: onExit)
            }
        }
        .padding(.horizontal, chipTextPadding * 2)
        .frame(width: cellSize.width, height: cellSize.height)
    }

    private func panelButton(_ title: String, prominent: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Baskerville-SemiBold", size: chipFontSize))
                .foregroundStyle(prominent ? .black : .white)
                .padding(.horizontal, buttonPaddingHorizontal)
                .padding(.vertical, buttonPaddingVertical)
                .background(prominent ? AnyShapeStyle(Self.gold)
                                      : AnyShapeStyle(.white.opacity(0.16)),
                            in: RoundedRectangle(cornerRadius: chipCorner, style: .continuous))
        }
        .disabled(prominent && !unsavedChanges)
        .opacity(prominent && !unsavedChanges ? 0.45 : 1)
    }

    private func save() {
        do {
            try db.hudLayoutDao.set(hudLayoutConfig: hudLayoutConfig)
            unsavedChanges = false
            saveFailure = nil
            onSave(hudLayoutConfig)
        }
        catch {
            saveFailure = "\(error)"
        }
    }

    private static let boardSpace = "hudLayoutBoard"

    private static let zoneGrid: [[HudLocation?]] = [
        [.northWest, .north, .northEast],
        [.west, nil, .east],
        [.southWest, .south, .southEast],
    ]

    private static let gold = Color(red: 0.87, green: 0.72, blue: 0.35)
}

private extension HudSection {
    var title: String {
        switch self {
        case .heroBar: return "Hero Bar"
        case .statsView: return "Stats"
        case .miscView: return "Misc"
        case .masterControls: return "Master Controls"
        }
    }
}

private extension HudLocation {
    var title: String {
        switch self {
        case .northWest: return "North West"
        case .north: return "North"
        case .northEast: return "North East"
        case .west: return "West"
        case .east: return "East"
        case .southWest: return "South West"
        case .south: return "South"
        case .southEast: return "South East"
        }
    }
}
