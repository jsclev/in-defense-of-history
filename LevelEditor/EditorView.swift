import SwiftUI
import UniformTypeIdentifiers

enum EditorTool: Hashable {
    case select, pan, slot, brush, paint, eraser, entrance, exitPoint, callWaveButton, primaryHero, secondaryHero, zoomIn, zoomOut
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
    case callWaveButton(Int)
    case hero(HeroSelection.Role)
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
    let grid: EditorGrid

    init(content: EditorContent, virtualCanvas: VirtualCanvas) {
        self.content = content
        self.virtualCanvas = virtualCanvas
        mapGeometry = MapGeometry(virtualCanvas: virtualCanvas)
        towerMenuLayout = TowerMenuLayout(virtualCanvas: virtualCanvas)
        blueprints = Blueprints(virtualCanvas: virtualCanvas)
        towerSlotImage = TowerSlotImage(virtualCanvas: virtualCanvas)
        grid = EditorGrid(unit: 4, major: 120,
                          origin: Point(virtualCanvas.playAreaRect.minX,
                                        virtualCanvas.playAreaRect.minY))
    }

    var mode: EditorMode = .edit
    var tool: EditorTool = .select
    var selection: EditorSelection = .none
    private(set) var canvasFocusRequest = 0
    var visibleLayers: Set<EditorLayer> = Set(EditorLayer.allCases)
    var menuPreviewSlot: Int?

    var activeLayer: EditorLayer? { tool.layer }

    /// An explicit inspector selection returns keyboard control to the map,
    /// including clicking the same row after editing a coordinate field.
    func selectFromInspector(_ selection: EditorSelection) {
        self.selection = selection
        canvasFocusRequest += 1
    }

    func isVisible(_ layer: EditorLayer) -> Bool { visibleLayers.contains(layer) }

    func toggleVisibility(_ layer: EditorLayer) {
        setVisibility(layer, !isVisible(layer))
    }

    func setVisibility(_ layer: EditorLayer, _ visible: Bool) {
        if visible {
            visibleLayers.insert(layer)
        } else {
            visibleLayers.remove(layer)
        }
    }

    func selectTool(_ newTool: EditorTool) {
        tool = newTool
        if let layer = newTool.layer, !visibleLayers.contains(layer) {
            visibleLayers.insert(layer)
            flash("\(layer.title) layer shown - the \(newTool.title) works on it")
        }
    }

    var snapToGrid = true
    var showRanges = true

    func snapped(_ point: Point) -> Point {
        snapToGrid ? grid.snap(point) : point
    }
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
    var paintGesture = EditorPaintGesture()

    var zoom: Double?
    var fitRequest = 0
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

    func zoomFit() {
        zoom = nil
        fitRequest += 1
    }

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

    func loadImages(from draft: MapDraft) {
        if let data = draft.backgroundImageData, draft.backgroundImagePath != nil {
            let loaded = PlatformImageLoader.load(data: data)
            background = loaded?.image
            backgroundPixelSize = loaded?.pixelSize
        } else { loadBackground(from: draft.backgroundImagePath, force: true) }
        if let data = draft.overlayImageData, draft.overlayImagePath != nil {
            let loaded = PlatformImageLoader.load(data: data)
            overlay = loaded?.image
            overlayPixelSize = loaded?.pixelSize
        } else { loadOverlay(from: draft.overlayImagePath, force: true) }
        if let data = draft.guideImageData, draft.guideImagePath != nil {
            let loaded = PlatformImageLoader.load(data: data)
            guide = loaded?.image
            guidePixelSize = loaded?.pixelSize
        } else { loadGuide(from: draft.guideImagePath, force: true) }
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
    @State private var importingGeoJSON = false
    @State private var geoJSONFile: GeoJSONFile?
    @State private var fileError: String?
    @Environment(\.undoManager) private var undoManager

    private var modeContent: some View {
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
    }

    private var fileControls: some View {
        modeContent
            .toolbar { toolbarContent }
            .fileImporter(isPresented: $importingImage,
                          allowedContentTypes: [.png, .jpeg, .tiff], onCompletion: importImage)
            .fileImporter(isPresented: $importingGeoJSON,
                          allowedContentTypes: [.geoJSON, .json], onCompletion: importGeoJSON)
            .fileExporter(isPresented: $exportingGeoJSON, document: geoJSONFile,
                          contentType: .geoJSON,
                          defaultFilename: GeoJSONExport(virtualCanvas: state.virtualCanvas)
                              .filename(for: document.draft)) { result in
                switch result {
                case let .success(url): state.flash("Exported \(url.lastPathComponent)")
                case let .failure(error): fileError = error.localizedDescription
                }
            }
            .alert("File operation failed", isPresented: Binding(
                get: { fileError != nil }, set: { if !$0 { fileError = nil } }
            )) { Button("OK", role: .cancel) { fileError = nil } }
            message: { Text(fileError ?? "") }
    }

    private func importImage(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard let data = PlatformImageLoader.freshRead(url),
                  let loaded = PlatformImageLoader.load(data: data) else {
                throw LevelGeoJSON.ValidationError(message: "The selected image could not be read.")
            }
            document.edit(undoManager) { draft in
                switch importTarget {
                case .background:
                    draft.backgroundImagePath = url.path
                    draft.backgroundImageData = data
                case .overlay:
                    draft.overlayImagePath = url.path
                    draft.overlayImageData = data
                case .guide:
                    draft.guideImagePath = url.path
                    draft.guideImageData = data
                }
            }
            if importTarget != .guide, loaded.pixelSize != state.virtualCanvas.size {
                state.flash("Image is \(Int(loaded.pixelSize.width))×\(Int(loaded.pixelSize.height)) — artwork must be \(Int(state.virtualCanvas.size.width))×\(Int(state.virtualCanvas.size.height))")
            }
        } catch { fileError = error.localizedDescription }
    }

    private func importGeoJSON(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var imported = try GeoJSONImport.draft(from: Data(contentsOf: url))
            imported.normalize(mapGeometry: state.mapGeometry)
            document.edit(undoManager) { $0 = imported }
            state.selection = .none
            state.flash("Imported \(url.lastPathComponent). Save the editable document as .tdmap.")
        } catch { fileError = error.localizedDescription }
    }

    var body: some View {
        fileControls
        .onAppear {
            document.canvas = state.virtualCanvas
            document.sourceFolder = documentURL?.deletingLastPathComponent()
            var normalized = document.draft
            normalized.normalize(mapGeometry: state.mapGeometry)
            // Publishing an unchanged draft marks a pristine untitled document
            // as edited in DocumentGroup, preventing placeholder replacement.
            if normalized != document.draft { document.draft = normalized }
            state.documentFolder = document.sourceFolder
            if document.draft.backgroundImagePath?.isEmpty ?? true,
               let terrain = EditorResources.url(
                "../in-defense-of-history-data/Levels/grass_bastion.png") {
                document.edit(undoManager) {
                    $0.backgroundImagePath = terrain.path
                    $0.backgroundImageData = nil
                }
            }
            state.visibleLayers = Set(EditorLayer.allCases).subtracting(
                document.draft.hiddenLayers.compactMap(EditorLayer.init(rawValue:)))
            state.loadImages(from: document.draft)
        }
        .onChange(of: documentURL) { _, url in
            document.sourceFolder = url?.deletingLastPathComponent()
            state.documentFolder = document.sourceFolder
        }
        .onChange(of: [document.draft.backgroundImagePath, document.draft.overlayImagePath,
                       document.draft.guideImagePath]) { _, _ in
            state.loadImages(from: document.draft)
        }
        .onChange(of: [document.draft.backgroundImageData, document.draft.overlayImageData,
                       document.draft.guideImageData]) { _, _ in
            state.loadImages(from: document.draft)
        }
        .onChange(of: state.visibleLayers) { _, layers in
            let hidden = EditorLayer.allCases.filter { !layers.contains($0) }.map(\.rawValue)
            if document.draft.hiddenLayers != hidden {
                document.edit(undoManager) { $0.hiddenLayers = hidden }
            }
        }
        .onChange(of: document.draft.hiddenLayers) { _, hidden in
            state.visibleLayers = Set(EditorLayer.allCases).subtracting(
                hidden.compactMap(EditorLayer.init(rawValue:)))
        }
        .focusedSceneValue(\.editorFileActions, EditorFileActions(
            importGeoJSON: { importingGeoJSON = true }, exportGeoJSON: exportGeoJSON))
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
            geoJSONFile = GeoJSONFile(document: try GeoJSONExport(virtualCanvas: state.virtualCanvas)
                .document(for: document.draft))
            exportingGeoJSON = true
        } catch {
            fileError = error.localizedDescription
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
                    Image(systemName: "hand.draw").tag(EditorTool.pan)
                        .help("Pan: drag the map without changing zoom or moving its entities")
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
                    Image(systemName: "megaphone.fill").tag(EditorTool.callWaveButton)
                        .help("Place call wave buttons; drag to move or edit exact X/Y in the inspector")
                    Image(systemName: "flag.checkered").tag(EditorTool.exitPoint)
                        .help("Place exit points the enemies march for")
                    HeroPlacementIcon.image(for: .primary).tag(EditorTool.primaryHero)
                        .accessibilityLabel("Primary hero start (1)")
                        .help("Primary hero (1): click anywhere to place its start; drag to move")
                    HeroPlacementIcon.image(for: .secondary).tag(EditorTool.secondaryHero)
                        .accessibilityLabel("Secondary hero start (2)")
                        .help("Secondary hero (2): click anywhere to place its start; drag to move")
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
                    .help("Highlight the \(Int(state.virtualCanvas.playAreaRect.width))×\(Int(state.virtualCanvas.playAreaRect.height)) play area in purple, tap area in cyan, and dim the bleed")
                Toggle(isOn: Binding(
                    get: { state.isVisible(.grid) },
                    set: { state.setVisibility(.grid, $0) }
                )) { Image(systemName: "grid") }
                    .help("Show the \(Int(state.grid.unit))-unit grid over every layer, with major lines every \(Int(state.grid.major))")
                Toggle(isOn: $s.snapToGrid) { Image(systemName: "dot.squareshape.split.2x2") }
                    .help("Snap moves, placements and arrow-key nudges to the \(Int(state.grid.unit))-unit grid")
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

                Button { importingGeoJSON = true } label: {
                    Label("Import GeoJSON…", systemImage: "square.and.arrow.down")
                }
                Button { exportGeoJSON() } label: {
                    Label("Export GeoJSON…", systemImage: "square.and.arrow.up")
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
        case let .callWaveButton(i): return "Call wave button \(i)"
        case let .hero(role): return "\(role.title) start"
        }
    }
}
