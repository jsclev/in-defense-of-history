import SwiftUI
import UniformTypeIdentifiers

enum EditorTool: Hashable {
    case select, slot, brush, paint, eraser, entrance, exitPoint, zoomIn, zoomOut
}

enum EditorMode: Hashable {
    case edit, playtest
}

enum EditorSelection: Equatable {
    case none
    case slot(Int)
    case waypoint(road: Int, point: Int)
    case road(Int)
    case entrance(Int)
    case exitPoint(Int)
}

@MainActor
@Observable
final class EditorState {
    let content: EditorContent
    let virtualCanvas: VirtualCanvas
    let mapGeometry: MapGeometry
    let towerMenuLayout: TowerMenuLayout
    let blueprints: Blueprints
    let towerSlotImage: TowerSlotImage

    init(content: EditorContent, virtualCanvas: VirtualCanvas) {
        self.content = content
        self.virtualCanvas = virtualCanvas
        mapGeometry = MapGeometry(virtualCanvas: virtualCanvas)
        towerMenuLayout = TowerMenuLayout(virtualCanvas: virtualCanvas)
        blueprints = Blueprints(virtualCanvas: virtualCanvas)
        towerSlotImage = TowerSlotImage(virtualCanvas: virtualCanvas)
    }

    var mode: EditorMode = .edit
    var tool: EditorTool = .select
    var selection: EditorSelection = .none
    var visibleLayers: Set<EditorLayer> = Set(EditorLayer.allCases)
    var menuPreviewSlot: Int?

    var activeLayer: EditorLayer? { tool.layer }

    func isVisible(_ layer: EditorLayer) -> Bool { visibleLayers.contains(layer) }

    func toggleVisibility(_ layer: EditorLayer) {
        if visibleLayers.contains(layer) {
            visibleLayers.remove(layer)
        } else {
            visibleLayers.insert(layer)
        }
    }

    func selectTool(_ newTool: EditorTool) {
        tool = newTool
        if let layer = newTool.layer, !visibleLayers.contains(layer) {
            visibleLayers.insert(layer)
            flash("\(layer.title) layer shown - the \(newTool.title) works on it")
        }
    }

    var showGrid = true
    var snapToGrid = true
    var showRanges = true
    var showPlayArea = true

    /// The inspector sidebar. Hidden, it slides off the left edge so the
    /// canvas takes the full window; the canvas's own fit-scale reacts to
    /// the size change, so a "Fit" zoom refits automatically.
    var showInspector = true

    func toggleInspector() {
        withAnimation(.easeInOut(duration: 0.22)) {
            showInspector.toggle()
        }
    }

    var cursor: Point?
    var toast: String?
    var background: PlatformImage?
    var backgroundPixelSize: CGSize?
    var overlay: PlatformImage?
    var overlayPixelSize: CGSize?
    var guide: PlatformImage?
    var guidePixelSize: CGSize?

    /// Path each image was last loaded from. The document-path onChange
    /// handlers reload only when the path actually differs, so a pick that
    /// already loaded the file directly isn't immediately loaded a second
    /// time (which is wasted work, and would clobber the good image with
    /// nil if that redundant read ever failed).
    private var backgroundLoadedPath: String?
    private var overlayLoadedPath: String?
    private var guideLoadedPath: String?

    /// Canonical units between committed waypoints of a painted path.
    /// 2.4 is five times the density of the 12 that still read faceted on
    /// the iPad - denser than even the level 1 generator's 4.4-unit spacing,
    /// so the pencil, not the tool, is the resolution limit.
    var brushSpacing: Double = 2.4
    var showOuterEdge = true
    var stroke = BrushStroke()
    var paintWidth: Double = 60
    var paintStroke = BrushStroke()

    var zoom: Double?
    var fitScale: Double = 0.4
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
        guard let px = backgroundPixelSize, px != virtualCanvas.size else { return nil }
        return "Reference image is \(Int(px.width))×\(Int(px.height)) — artwork must be \(Int(virtualCanvas.size.width))×\(Int(virtualCanvas.size.height))"
    }

    /// The folder holding the open document, set by the view. Image paths
    /// stored by another device (an iPad's /private/var/mobile/… path in a
    /// document synced through iCloud) resolve to the same-named file
    /// beside the document here.
    var documentFolder: URL?

    /// THE image-path resolver, shared by every layer: the stored path if
    /// that file exists here, else the same filename beside the document.
    func resolveImage(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let stored = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: stored.path) { return stored }
        if let folder = documentFolder {
            let sibling = folder.appendingPathComponent(stored.lastPathComponent)
            if FileManager.default.fileExists(atPath: sibling.path) { return sibling }
        }
        return stored
    }

    /// Document-path driven: reloads only if `path` differs from what's
    /// already loaded. Pass `force` to reload the same path (a re-picked
    /// file updated in place).
    func loadBackground(from path: String?, force: Bool = false) {
        guard force || path != backgroundLoadedPath else { return }
        loadBackground(from: resolveImage(path), storedPath: path)
    }

    /// `storedPath` is what the document records (the loaded-path tracker
    /// compares against it); defaults to the URL's own path for a fresh pick.
    func loadBackground(from url: URL?, storedPath: String? = nil) {
        backgroundLoadedPath = storedPath ?? url?.path
        if let url, let loaded = PlatformImageLoader.load(url: url) {
            background = loaded.image
            backgroundPixelSize = loaded.pixelSize
        } else {
            background = nil
            backgroundPixelSize = nil
        }
    }

    func loadOverlay(from path: String?, force: Bool = false) {
        guard force || path != overlayLoadedPath else { return }
        loadOverlay(from: resolveImage(path), storedPath: path)
    }

    func loadOverlay(from url: URL?, storedPath: String? = nil) {
        overlayLoadedPath = storedPath ?? url?.path
        if let url, let loaded = PlatformImageLoader.load(url: url) {
            overlay = loaded.image
            overlayPixelSize = loaded.pixelSize
        } else {
            overlay = nil
            overlayPixelSize = nil
        }
    }

    func loadGuide(from path: String?, force: Bool = false) {
        guard force || path != guideLoadedPath else { return }
        loadGuide(from: resolveImage(path), storedPath: path)
    }

    func loadGuide(from url: URL?, storedPath: String? = nil) {
        guideLoadedPath = storedPath ?? url?.path
        if let url, let loaded = PlatformImageLoader.load(url: url) {
            guide = loaded.image
            guidePixelSize = loaded.pixelSize
        } else {
            guide = nil
            guidePixelSize = nil
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
    /// Where the document lives, so image paths stored by another device
    /// can be resolved to the copy sitting beside this document.
    var documentURL: URL?
    @State private var state: EditorState
    @State private var session: SimSession?

    init(document: MapDocument, documentURL: URL?,
         content: EditorContent, virtualCanvas: VirtualCanvas) {
        _document = ObservedObject(wrappedValue: document)
        self.documentURL = documentURL
        _state = State(initialValue: EditorState(content: content,
                                                 virtualCanvas: virtualCanvas))
    }

    enum ImageImportTarget {
        case background, overlay, guide
    }

    @State private var importingImage = false
    /// Which image the open file chooser is for. Read in the completion, so
    /// it survives the chooser's dismissal resetting `importingImage`.
    @State private var importTarget: ImageImportTarget = .background
    @State private var exportingGeoJSON = false
    @State private var geoJSONFile = GeoJSONFile(data: Data())
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Group {
            if state.mode == .playtest, let session {
                PlaytestView(session: session, slotArt: state.towerSlotImage) { recorded in
                    document.edit(undoManager) { $0.intendedSolution = recorded }
                    state.flash("Adopted steps as the intended solution")
                }
            } else {
                editorBody
            }
        }
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $importingImage,
                      allowedContentTypes: [.png, .jpeg, .tiff]) { result in
            // Loads run here directly (not only via the onChange handlers
            // below) so re-picking the SAME file, updated in place in iCloud,
            // reloads it even though its path string hasn't changed. The
            // loader owns the security scope and reads fresh bytes.
            if case let .success(url) = result {
                switch importTarget {
                case .background:
                    state.loadBackground(from: url)
                    document.edit(undoManager) { $0.backgroundImagePath = url.path }
                    if let px = state.backgroundPixelSize, px != state.virtualCanvas.size {
                        state.flash("Image is \(Int(px.width))×\(Int(px.height)) — artwork must be \(Int(state.virtualCanvas.size.width))×\(Int(state.virtualCanvas.size.height))")
                    }
                case .overlay:
                    state.loadOverlay(from: url)
                    document.edit(undoManager) { $0.overlayImagePath = url.path }
                    if let px = state.overlayPixelSize, px != state.virtualCanvas.size {
                        state.flash("Occlusion is \(Int(px.width))×\(Int(px.height)) — artwork must be \(Int(state.virtualCanvas.size.width))×\(Int(state.virtualCanvas.size.height))")
                    }
                case .guide:
                    state.loadGuide(from: url)
                    document.edit(undoManager) { $0.guideImagePath = url.path }
                }
            }
        }
        .fileExporter(isPresented: $exportingGeoJSON,
                      document: geoJSONFile,
                      contentType: .geoJSON,
                      defaultFilename: GeoJSONExport(virtualCanvas: state.virtualCanvas)
                          .filename(for: document.draft)) { result in
            switch result {
            case let .success(url):
                state.flash("Saved \(url.lastPathComponent)")
            case let .failure(error):
                state.flash("Save failed: \(error.localizedDescription)")
            }
        }
        .onAppear {
            document.draft.normalize(mapGeometry: state.mapGeometry)
            state.documentFolder = documentURL?.deletingLastPathComponent()
            state.loadBackground(from: document.draft.backgroundImagePath)
            state.loadOverlay(from: document.draft.overlayImagePath)
            state.loadGuide(from: document.draft.guideImagePath)
        }
        .onChange(of: documentURL) { _, url in
            state.documentFolder = url?.deletingLastPathComponent()
        }
        .onChange(of: document.draft.backgroundImagePath) { _, path in
            state.loadBackground(from: path)
        }
        .onChange(of: document.draft.overlayImagePath) { _, path in
            state.loadOverlay(from: path)
        }
        .onChange(of: document.draft.guideImagePath) { _, path in
            state.loadGuide(from: path)
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
        EditorSplit(showSidebar: state.showInspector) {
            InspectorView(document: document, state: state) { target in
                importTarget = target
                importingImage = true
            }
        } detail: {
            VStack(spacing: 0) {
                EditorCanvas(document: document, content: state.content, state: state)
                statusBar
            }
        }
    }

    private func exportGeoJSON() {
        do {
            geoJSONFile = GeoJSONFile(data: try GeoJSONExport(virtualCanvas: state.virtualCanvas)
                .data(for: document.draft))
            exportingGeoJSON = true
        } catch {
            state.flash("Could not build geojson: \(error.localizedDescription)")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                state.toggleInspector()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help(state.showInspector
                  ? "Hide the inspector so the canvas fills the window (⌃⌘S)"
                  : "Show the inspector (⌃⌘S)")
        }
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

                Picker("Tool", selection: Binding(
                    get: { state.tool },
                    set: { state.selectTool($0) }
                )) {
                    Image(systemName: "cursorarrow").tag(EditorTool.select)
                        .help("Select and move")
                    Image(systemName: "scribble").tag(EditorTool.brush)
                        .help("Path tool: draw an enemy path freehand; width is fixed by virtual_canvas")
                    Image(systemName: "paintbrush.pointed").tag(EditorTool.paint)
                        .help("Path painter: paint road area freehand at any width, added to the path layer")
                    Image(systemName: "eraser").tag(EditorTool.eraser)
                        .help("Path eraser: erase road wherever the brush passes, cutting the waypoints themselves")
                    (EditorResources.templateIcon("Images/tower_tool_icon.png", pointSize: 17)
                        ?? Image(systemName: "building.fill"))
                        .tag(EditorTool.slot)
                        .help("Place tower slots")
                    Image(systemName: "arrow.right.circle").tag(EditorTool.entrance)
                        .help("Place entrance points where enemies spawn")
                    Image(systemName: "flag.checkered").tag(EditorTool.exitPoint)
                        .help("Place exit points the enemies march for")
                    Image(systemName: "plus.magnifyingglass").tag(EditorTool.zoomIn)
                        .help("Zoom in centered on wherever you click the map")
                    Image(systemName: "minus.magnifyingglass").tag(EditorTool.zoomOut)
                        .help("Zoom out centered on wherever you click the map")
                }
                .pickerStyle(.segmented)

                if state.tool == .paint || state.tool == .eraser {
                    Slider(value: $s.paintWidth, in: 10...300, step: 5) {
                        Text("Brush width")
                    } minimumValueLabel: {
                        Text("10")
                    } maximumValueLabel: {
                        Text("\(Int(state.paintWidth))")
                    }
                    .frame(width: 200)
                    .help("Brush width in canvas units")
                }

                Toggle(isOn: $s.showOuterEdge) { Image(systemName: "square.dashed") }
                    .help("Show the generated outer-edge waypoints of each road")

                Toggle(isOn: $s.showPlayArea) { Image(systemName: "rectangle.dashed") }
                    .help("Highlight the \(Int(state.virtualCanvas.playAreaRect.width))×\(Int(state.virtualCanvas.playAreaRect.height)) play area and dim the bleed")
                Toggle(isOn: $s.showGrid) { Image(systemName: "grid") }
                    .help("Show grid (15 px minor, 120 px major)")
                Toggle(isOn: $s.snapToGrid) { Image(systemName: "dot.squareshape.split.2x2") }
                    .help("Snap to 6-unit grid")
                Toggle(isOn: $s.showRanges) { Image(systemName: "circle.dashed") }
                    .help("Show tower range circular overlays on the selected slot")

                Menu {
                    Button("Blank Map") { applyTemplate(nil) }
                    Divider()
                    ForEach(state.blueprints.all, id: \.name) { bp in
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
            session = SimSession(blueprint: document.draft.makeBlueprint(virtualCanvas: state.virtualCanvas))
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
        let warnings = state.mapGeometry.warnings(for: document.draft,
                                               maxTowerRange: state.content.maxTowerRange)
        return HStack(spacing: 14) {
            Text(cursorText)
                .monospacedDigit()
                .frame(width: 150, alignment: .leading)
            Text("canvas \(Int(state.virtualCanvas.size.width))×\(Int(state.virtualCanvas.size.height))")
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
        let inPlayable = state.virtualCanvas.playAreaRect.contains(CGPoint(x: c.x, y: c.y))
        return "\(Int(c.x.rounded())), \(Int(c.y.rounded())) px\(inPlayable ? "" : " · bleed")"
    }

    private var selectionText: String {
        switch state.selection {
        case .none: return "Nothing selected"
        case let .slot(i): return "Slot \(i)"
        case let .waypoint(r, p): return "Road \(r) · point \(p)"
        case let .road(r): return "Road \(r)"
        case let .entrance(i): return "Entrance \(i)"
        case let .exitPoint(i): return "Exit \(i)"
        }
    }
}
