import SwiftUI
import UniformTypeIdentifiers

enum EditorTool: Hashable {
    case select, road, slot, brush
}

enum EditorMode: Hashable {
    case edit, playtest
}

enum EditorSelection: Equatable {
    case none
    case slot(Int)
    case waypoint(road: Int, point: Int)
    case road(Int)
}

@MainActor
@Observable
final class EditorState {
    var mode: EditorMode = .edit
    var tool: EditorTool = .select
    var selection: EditorSelection = .none
    var showGrid = true
    var snapToGrid = true
    var showRanges = true
    var showPlayable = true
    var cursor: Point?
    var toast: String?
    var background: PlatformImage?
    var backgroundPixelSize: CGSize?

    /// Brush half-width in canvas units, before pressure.
    var brushSize: Double = 51
    var brushPressureEnabled = true
    /// Spacing between generated waypoints along a painted stroke.
    var brushSpacing: Double = 24
    var showOuterEdge = true
    var stroke = BrushStroke()

    var zoom: Double?
    var fitScale: Double = 0.4
    /// Scale captured when a pinch starts, so magnification is applied relatively.
    var pinchBase: Double?

    static let zoomLadder: [Double] = [
        0.05, 0.0833, 0.125, 0.1667, 0.25, 0.333, 0.5, 0.667,
        1, 1.5, 2, 3, 4, 6, 8,
    ]

    var currentScale: Double { zoom ?? fitScale }

    var zoomLabel: String {
        zoom == nil ? "Fit" : "\(Int((zoom! * 100).rounded()))%"
    }

    func zoomIn() {
        let c = currentScale
        zoom = Self.zoomLadder.first { $0 > c * 1.001 } ?? Self.zoomLadder.last
    }

    func zoomOut() {
        let c = currentScale
        zoom = Self.zoomLadder.last { $0 < c * 0.999 } ?? Self.zoomLadder.first
    }

    func zoomFit() { zoom = nil }

    func setZoom(_ z: Double) { zoom = min(max(z, 0.05), 8) }

    var backgroundSizeError: String? {
        guard let px = backgroundPixelSize, px != CanvasSpec.size else { return nil }
        return "Reference image is \(Int(px.width))×\(Int(px.height)) — artwork must be \(Int(CanvasSpec.width))×\(Int(CanvasSpec.height))"
    }

    func loadBackground(from path: String?) {
        if let path, let loaded = PlatformImageLoader.load(path: path) {
            background = loaded.image
            backgroundPixelSize = loaded.pixelSize
        } else {
            background = nil
            backgroundPixelSize = nil
        }
    }

    func flash(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }
}

@MainActor
struct EditorView: View {
    @ObservedObject var document: MapDocument
    @State private var state = EditorState()
    @State private var session: SimSession?
    @State private var importingImage = false
    @State private var exportingGeoJSON = false
    @State private var geoJSONFile = GeoJSONFile(data: Data())
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Group {
            if state.mode == .playtest, let session {
                PlaytestView(session: session) { recorded in
                    document.edit(undoManager) { $0.intendedSolution = recorded }
                    state.flash("Adopted \(recorded.count) steps as the intended solution")
                }
            } else {
                editorBody
            }
        }
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $importingImage,
                      allowedContentTypes: [.png, .jpeg, .tiff]) { result in
            if case let .success(url) = result {
                _ = url.startAccessingSecurityScopedResource()
                state.loadBackground(from: url.path)
                document.edit(undoManager) { $0.backgroundImagePath = url.path }
                if let px = state.backgroundPixelSize, px == CanvasSpec.size {
                    state.flash("Image \(Int(px.width))×\(Int(px.height)) — matches the canvas exactly")
                }
            }
        }
        .fileExporter(isPresented: $exportingGeoJSON,
                      document: geoJSONFile,
                      contentType: .geoJSON,
                      defaultFilename: GeoJSONExport.filename(for: document.draft)) { result in
            switch result {
            case let .success(url):
                state.flash("Saved \(url.lastPathComponent)")
            case let .failure(error):
                state.flash("Save failed: \(error.localizedDescription)")
            }
        }
        .onAppear { state.loadBackground(from: document.draft.backgroundImagePath) }
        .onChange(of: document.draft.backgroundImagePath) { _, path in
            state.loadBackground(from: path)
        }
        .focusedSceneValue(\.editorState, state)
        .background(
            Button("") { state.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }

    private var editorBody: some View {
        EditorSplit {
            InspectorView(document: document, state: state, importingImage: $importingImage)
        } detail: {
            VStack(spacing: 0) {
                EditorCanvas(document: document, state: state)
                statusBar
            }
        }
    }

    private func exportGeoJSON() {
        do {
            geoJSONFile = GeoJSONFile(data: try GeoJSONExport.data(for: document.draft))
            exportingGeoJSON = true
        } catch {
            state.flash("Could not build geojson: \(error.localizedDescription)")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            @Bindable var s = state

            Picker("Mode", selection: Binding(
                get: { state.mode },
                set: { setMode($0) }
            )) {
                Label("Edit", systemImage: "pencil").tag(EditorMode.edit)
                Label("Playtest", systemImage: "play.fill").tag(EditorMode.playtest)
            }
            .pickerStyle(.segmented)
            .help(document.draft.isPlayable
                  ? "Switch between editing and playing the level"
                  : "Playtest needs at least one road with 2+ points and one wave")

            if state.mode == .edit {
                Menu {
                    Button("Zoom In") { state.zoomIn() }
                    Button("Zoom Out") { state.zoomOut() }
                    Divider()
                    Button("Fit on Screen") { state.zoomFit() }
                    ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { z in
                        Button("\(Int(z * 100))%") { state.setZoom(z) }
                    }
                } label: {
                    Text(state.zoomLabel)
                        .monospacedDigit()
                        .frame(minWidth: 44)
                }
                .help("Zoom (⌘+ / ⌘− / ⌘0 fit / ⌘1 100%)")

                Picker("Tool", selection: $s.tool) {
                    Image(systemName: "cursorarrow").tag(EditorTool.select)
                        .help("Select and move")
                    Image(systemName: "scribble").tag(EditorTool.road)
                        .help("Road pencil: click to append waypoints, click on a segment to insert")
                    Image(systemName: "paintbrush.pointed").tag(EditorTool.brush)
                        .help("Path paintbrush: paint a road freehand; pressure sets its width")
                    Image(systemName: "plus.circle").tag(EditorTool.slot)
                        .help("Place tower slots")
                }
                .pickerStyle(.segmented)

                if state.tool == .brush {
                    Slider(value: $s.brushSize, in: 12...200) {
                        Image(systemName: "paintbrush.pointed")
                    }
                    .frame(width: 110)
                    .help("Brush width")

                    Toggle(isOn: $s.brushPressureEnabled) {
                        Image(systemName: "hand.draw")
                    }
                    .help("Apple Pencil pressure controls stroke width")
                }

                Toggle(isOn: $s.showOuterEdge) { Image(systemName: "square.dashed") }
                    .help("Show the generated outer-edge waypoints of each road")

                Toggle(isOn: $s.showPlayable) { Image(systemName: "rectangle.dashed") }
                    .help("Highlight the 1920×1080 playable rect and dim the bleed")
                Toggle(isOn: $s.showGrid) { Image(systemName: "grid") }
                    .help("Show grid (15 px minor, 120 px major)")
                Toggle(isOn: $s.snapToGrid) { Image(systemName: "dot.squareshape.split.2x2") }
                    .help("Snap to 10-unit grid")
                Toggle(isOn: $s.showRanges) { Image(systemName: "circle.dashed") }
                    .help("Show tower range circular overlays on the selected slot")

                Menu {
                    Button("Blank Map") { applyTemplate(nil) }
                    Divider()
                    ForEach(Blueprints.all, id: \.name) { bp in
                        Button(bp.name) { applyTemplate(bp) }
                    }
                } label: {
                    Label("Templates", systemImage: "square.on.square")
                }
                .help("Replace the document with a starter template or an existing blueprint")

                Button {
                    PlatformPasteboard.copy(SwiftExport.code(for: document.draft))
                    state.flash("Swift blueprint copied to clipboard")
                } label: {
                    Label("Export Swift", systemImage: "curlybraces")
                }
                .help("Copy a Blueprints.swift-ready LevelBlueprint to the clipboard")

                Button { exportGeoJSON() } label: {
                    Label("Save GeoJSON", systemImage: "square.and.arrow.down")
                }
                .help("Write this level out as a .geojson FeatureCollection")
            }
        }
    }

    private func setMode(_ mode: EditorMode) {
        if mode == .playtest {
            guard document.draft.isPlayable else {
                state.flash("Add a road (2+ points) and a wave before playtesting")
                return
            }
            session = SimSession(blueprint: document.draft.makeBlueprint())
        } else {
            session = nil
        }
        state.mode = mode
    }

    private func applyTemplate(_ bp: LevelBlueprint?) {
        document.edit(undoManager) { d in
            let keepPath = d.backgroundImagePath
            let keepOpacity = d.backgroundOpacity
            d = bp.map(MapDraft.init(blueprint:)) ?? .starter
            d.backgroundImagePath = keepPath
            d.backgroundOpacity = keepOpacity
        }
        state.selection = .none
    }

    private var statusBar: some View {
        let warnings = MapGeometry.warnings(for: document.draft)
        return HStack(spacing: 14) {
            Text(cursorText)
                .monospacedDigit()
                .frame(width: 150, alignment: .leading)
            Text("canvas 2868×2064")
                .foregroundStyle(.tertiary)
            Text("\(document.draft.roads.count) roads · \(document.draft.slots.count) slots · \(document.draft.waves.count) waves")
                .foregroundStyle(.secondary)
            if !warnings.isEmpty {
                Label("\(warnings.count) slot warning\(warnings.count == 1 ? "" : "s")",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(warnings.sorted { $0.key < $1.key }
                        .map { "Slot \($0.key): \($0.value)" }
                        .joined(separator: "\n"))
            }
            if let err = state.backgroundSizeError {
                Label(err, systemImage: "xmark.octagon.fill")
                    .font(.callout.bold())
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
            Spacer()
            if let toast = state.toast {
                Text(toast).foregroundStyle(.green)
            }
            Text(selectionText)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.25))
    }

    private var cursorText: String {
        guard let c = state.cursor else { return "—" }
        let inPlayable = CanvasSpec.playable.contains(CGPoint(x: c.x, y: c.y))
        return "\(Int(c.x.rounded())), \(Int(c.y.rounded())) px\(inPlayable ? "" : " · bleed")"
    }

    private var selectionText: String {
        switch state.selection {
        case .none: return "Nothing selected"
        case let .slot(i): return "Slot \(i)"
        case let .waypoint(r, p): return "Road \(r) · point \(p)"
        case let .road(r): return "Road \(r)"
        }
    }
}
