import SwiftUI

@MainActor
struct InspectorView: View {
    @ObservedObject var document: MapDocument
    var state: EditorState
    var requestImport: (EditorView.ImageImportTarget) -> Void
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                layersBox
                levelBox
                roadsBox
                slotsBox
                entrancesBox
                exitsBox
                selectionBox
                wavesBox
                solutionBox
            }
            .padding(12)
        }
    }

    private var layersBox: some View {
        GroupBox("Layers") {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(EditorLayer.panelOrder) { layer in
                    layerRow(layer)
                    if layer == .background {
                        backgroundDetails
                    }
                    if layer == .occlusion {
                        occlusionDetails
                    }
                    if layer == .mapGuide {
                        guideDetails
                    }
                }
            }
            .padding(4)
        }
    }

    private func layerRow(_ layer: EditorLayer) -> some View {
        let isActive = state.activeLayer == layer
        let visible = state.isVisible(layer)
        return HStack(spacing: 8) {
            Button {
                state.toggleVisibility(layer)
            } label: {
                Image(systemName: visible ? "eye" : "eye.slash")
                    .foregroundStyle(visible ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: 20)
            }
            .buttonStyle(.plain)
            .help(visible ? "Hide layer" : "Show layer")

            Image(systemName: layer.icon)
                .foregroundStyle(isActive ? .cyan : .secondary)
                .frame(width: 20)

            Text(layer.title)
                .fontWeight(isActive ? .semibold : .regular)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer()

            Text(layerDetail(layer))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if isActive {
                Text("ACTIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.cyan.opacity(0.25), in: Capsule())
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isActive ? Color.cyan.opacity(0.10) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        .overlay(alignment: .leading) {
            if isActive {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.cyan)
                    .frame(width: 3)
            }
        }
        .opacity(visible ? 1 : 0.55)
    }

    private func layerDetail(_ layer: EditorLayer) -> String {
        switch layer {
        case .background:
            guard let path = document.draft.backgroundImagePath else { return "empty" }
            return (path as NSString).lastPathComponent
        case .path:
            let n = document.draft.roads.count
            return n == 1 ? "1 path" : "\(n) paths"
        case .slots:
            let n = document.draft.slots.count
            return n == 1 ? "1 slot" : "\(n) slots"
        case .entrances:
            let n = document.draft.entrances.count
            return n == 1 ? "1 entrance" : "\(n) entrances"
        case .exits:
            let n = document.draft.exits.count
            return n == 1 ? "1 exit" : "\(n) exits"
        case .occlusion:
            guard let path = document.draft.overlayImagePath else { return "empty" }
            return (path as NSString).lastPathComponent
        case .mapGuide:
            guard let path = document.draft.guideImagePath else { return "empty" }
            return (path as NSString).lastPathComponent
        }
    }

    @ViewBuilder
    private var occlusionDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Choose…") { requestImport(.overlay) }
                if document.draft.overlayImagePath != nil {
                    Button("Clear") {
                        document.edit(undoManager) { $0.overlayImagePath = nil }
                    }
                }
            }
            if document.draft.overlayImagePath != nil {
                if let px = state.overlayPixelSize, px != CanvasSpec.size {
                    Label("\(Int(px.width))×\(Int(px.height)) — must be \(Int(CanvasSpec.width))×\(Int(CanvasSpec.height))",
                          systemImage: "xmark.octagon.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.leading, 28)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var guideDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Choose…") { requestImport(.guide) }
                if document.draft.guideImagePath != nil {
                    Button("Clear") {
                        document.edit(undoManager) { $0.guideImagePath = nil }
                    }
                }
            }
            if let path = document.draft.guideImagePath {
                Text((path as NSString).lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack {
                    Text("Opacity")
                    Slider(value: document.binding(\.guideOpacity, undoManager), in: 0...1)
                }
            }
        }
        .padding(.leading, 28)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var backgroundDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Choose…") { requestImport(.background) }
                if document.draft.backgroundImagePath != nil {
                    Button("Clear") {
                        document.edit(undoManager) { $0.backgroundImagePath = nil }
                    }
                }
            }
            if document.draft.backgroundImagePath != nil {
                if let px = state.backgroundPixelSize {
                    if px != CanvasSpec.size {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("WRONG IMAGE SIZE")
                                    .font(.callout.weight(.heavy))
                                Text("This image is \(Int(px.width))×\(Int(px.height)) px. All map artwork must be exactly \(Int(CanvasSpec.width))×\(Int(CanvasSpec.height)) px. The art needs to be fixed.")
                                    .font(.caption.bold())
                            }
                        }
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.red.opacity(0.6)))
                    }
                }
            }
        }
        .padding(.leading, 34)
        .padding(.bottom, 6)
    }

    private var levelBox: some View {
        GroupBox("Level") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: document.binding(\.name, undoManager))
                HStack {
                    Text("Gold")
                    TextField("Gold", value: document.binding(\.startingGold, undoManager),
                              format: .number)
                        .frame(width: 70)
                    Spacer()
                    Text("Lives")
                    TextField("Lives", value: document.binding(\.lives, undoManager),
                              format: .number)
                        .frame(width: 70)
                }
            }
            .padding(4)
        }
    }

    private var roadsBox: some View {
        GroupBox("Paths") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(document.draft.roads.indices, id: \.self) { ri in
                    roadRow(ri)
                }
                Button {
                    document.edit(undoManager) { d in
                        d.roads.append(.init(
                            name: MapDraft.freeRoadName(taken: Set(d.roads.map(\.name))),
                            points: [Point(2520, 1032), Point(2130, 1032)]
                        ))
                    }
                    state.selection = .road(document.draft.roads.count - 1)
                } label: {
                    Label("Add Path", systemImage: "plus")
                }
                .padding(.top, 2)
            }
            .padding(4)
        }
    }

    private func roadRow(_ ri: Int) -> some View {
        let isSelected: Bool = switch state.selection {
        case let .road(r): r == ri
        case let .waypoint(r, _): r == ri
        default: false
        }
        return HStack(spacing: 6) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .foregroundStyle(isSelected ? .cyan : .secondary)
            Text("Path \(ri)")
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            Text("\(document.draft.roads.indices.contains(ri) ? document.draft.roads[ri].points.count : 0) pts")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                document.edit(undoManager) { d in
                    if d.roads.indices.contains(ri) { d.roads[ri].points.reverse() }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.plain)
            .help("Reverse direction (spawn becomes exit)")
            if ri < document.draft.roads.count - 1 {
                Button {
                    let message = document.mergeRoadDown(ri, undoManager)
                    state.selection = document.draft.roads.indices.contains(ri)
                        ? .road(ri) : .none
                    state.flash(message)
                } label: {
                    Image(systemName: "arrow.triangle.merge")
                }
                .buttonStyle(.plain)
                .help("Merge down: replace this road's stretch that overlaps the road below with that road's own waypoints, removing the redundant ones")
            }
            Button {
                document.deleteRoad(ri, undoManager)
                state.selection = .none
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("Delete road")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.cyan.opacity(0.12) : .clear,
                    in: RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture { state.selection = .road(ri) }
    }

    private var slotsBox: some View {
        let warnings = MapGeometry.warnings(for: document.draft, maxTowerRange: EditorContent.shared.maxTowerRange)
        return GroupBox("Tower Slots") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(document.draft.slots.indices, id: \.self) { i in
                    let slot = document.draft.slots[i]
                    let selected = state.selection == .slot(i)
                    HStack(spacing: 6) {
                        Text("\(i)")
                            .monospacedDigit()
                            .frame(width: 22, alignment: .trailing)
                        Text("(\(Int(slot.x)), \(Int(slot.y)))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if let issue = warnings[i] {
                            let isError = issue != .outOfRange
                            Image(systemName: isError
                                  ? "xmark.octagon.fill"
                                  : "exclamationmark.triangle.fill")
                                .foregroundStyle(isError ? .red : .orange)
                                .help(issue.message)
                        }
                        Spacer()
                        Button {
                            state.menuPreviewSlot = state.menuPreviewSlot == i ? nil : i
                        } label: {
                            Image(systemName: state.menuPreviewSlot == i
                                  ? "smallcircle.filled.circle.fill" : "smallcircle.filled.circle")
                                .foregroundStyle(state.menuPreviewSlot == i ? .cyan : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show the 4-tower radial menu at game size on this slot")
                        Button {
                            document.deleteSlot(i, undoManager)
                            state.selection = .none
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.callout)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 4)
                    .background(selected ? Color.yellow.opacity(0.15) : .clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { state.selection = .slot(i) }
                }
                Button {
                    state.selection = .slot(document.addSlot(
                        at: Point(CanvasSpec.playArea.midX, CanvasSpec.playArea.midY),
                        undoManager))
                } label: {
                    Label("Add Slot", systemImage: "plus")
                }
                .padding(.top, 2)
            }
            .padding(4)
        }
    }

    private var entrancesBox: some View {
        markerBox(title: "Entrances", points: document.draft.entrances,
                  select: { .entrance($0) }, isSelected: { state.selection == .entrance($0) },
                  delete: { document.deleteEntrance($0, undoManager) },
                  add: { p in document.edit(undoManager) { $0.entrances.append(p) } },
                  addLabel: "Add Entrance")
    }

    private var exitsBox: some View {
        markerBox(title: "Exits", points: document.draft.exits,
                  select: { .exitPoint($0) }, isSelected: { state.selection == .exitPoint($0) },
                  delete: { document.deleteExit($0, undoManager) },
                  add: { p in document.edit(undoManager) { $0.exits.append(p) } },
                  addLabel: "Add Exit")
    }

    private func markerBox(title: String, points: [Point],
                           select: @escaping (Int) -> EditorSelection,
                           isSelected: @escaping (Int) -> Bool,
                           delete: @escaping (Int) -> Void,
                           add: @escaping (Point) -> Void,
                           addLabel: String) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(points.indices, id: \.self) { i in
                    let point = points[i]
                    HStack(spacing: 6) {
                        Text("\(i)")
                            .monospacedDigit()
                            .frame(width: 22, alignment: .trailing)
                        Text("(\(Int(point.x)), \(Int(point.y)))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            delete(i)
                            state.selection = .none
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.callout)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 4)
                    .background(isSelected(i) ? Color.yellow.opacity(0.15) : .clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture { state.selection = select(i) }
                }
                Button {
                    add(Point(CanvasSpec.playArea.midX, CanvasSpec.playArea.midY))
                    state.selection = select(points.count)
                } label: {
                    Label(addLabel, systemImage: "plus")
                }
                .padding(.top, 2)
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var selectionBox: some View {
        if let (label, get, set) = selectedPointAccessor() {
            GroupBox("Selected: \(label)") {
                HStack {
                    Text("X")
                    TextField("X", value: Binding(
                        get: { get().x },
                        set: { nv in set(Point(nv, get().y)) }
                    ), format: .number)
                    Text("Y")
                    TextField("Y", value: Binding(
                        get: { get().y },
                        set: { nv in set(Point(get().x, nv)) }
                    ), format: .number)
                }
                .padding(4)
            }
        }
    }

    private func selectedPointAccessor() -> (String, () -> Point, (Point) -> Void)? {
        switch state.selection {
        case let .slot(i) where document.draft.slots.indices.contains(i):
            return ("Slot \(i)",
                    { document.draft.slots.indices.contains(i) ? document.draft.slots[i] : .zero },
                    { p in document.edit(undoManager) { d in
                        if d.slots.indices.contains(i) { d.slots[i] = p }
                    } })
        case let .waypoint(r, i)
            where document.draft.roads.indices.contains(r)
                && document.draft.roads[r].points.indices.contains(i):
            return ("Road \(r) · point \(i)",
                    {
                        guard document.draft.roads.indices.contains(r),
                              document.draft.roads[r].points.indices.contains(i)
                        else { return .zero }
                        return document.draft.roads[r].points[i]
                    },
                    { p in document.edit(undoManager) { d in
                        if d.roads.indices.contains(r), d.roads[r].points.indices.contains(i) {
                            d.roads[r].points[i] = p
                        }
                    } })
        case let .entrance(i) where document.draft.entrances.indices.contains(i):
            return ("Entrance \(i)",
                    { document.draft.entrances.indices.contains(i) ? document.draft.entrances[i] : .zero },
                    { p in document.edit(undoManager) { d in
                        if d.entrances.indices.contains(i) { d.entrances[i] = p }
                    } })
        case let .exitPoint(i) where document.draft.exits.indices.contains(i):
            return ("Exit \(i)",
                    { document.draft.exits.indices.contains(i) ? document.draft.exits[i] : .zero },
                    { p in document.edit(undoManager) { d in
                        if d.exits.indices.contains(i) { d.exits[i] = p }
                    } })
        default:
            return nil
        }
    }

    private var wavesBox: some View {
        GroupBox("Waves") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(document.draft.waves.indices, id: \.self) { wi in
                    waveGroup(wi)
                }
                Button {
                    document.edit(undoManager) { d in
                        d.waves.append(.init(breather: 14, lines: [
                            .init(foe: Foe.loyalistMilitia.rawValue, count: 6, every: 2.0,
                                  delay: 0, road: 0),
                        ]))
                    }
                } label: {
                    Label("Add Wave", systemImage: "plus")
                }
                .padding(.top, 2)
            }
            .padding(4)
        }
    }

    private func waveGroup(_ wi: Int) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Breather")
                    TextField("s", value: Binding(
                        get: { document.draft.waves.indices.contains(wi)
                            ? document.draft.waves[wi].breather : 0 },
                        set: { nv in document.edit(undoManager) { d in
                            if d.waves.indices.contains(wi) { d.waves[wi].breather = nv }
                        } }
                    ), format: .number)
                    .frame(width: 55)
                    Text("s").foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        document.edit(undoManager) { d in
                            if d.waves.indices.contains(wi) { d.waves.remove(at: wi) }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("Delete wave")
                }
                ForEach(lineIndices(wi), id: \.self) { li in
                    lineRow(wi, li)
                }
                Button {
                    document.edit(undoManager) { d in
                        guard d.waves.indices.contains(wi) else { return }
                        d.waves[wi].lines.append(.init(
                            foe: Foe.redcoatRegular.rawValue, count: 4, every: 2.0,
                            delay: 0, road: 0
                        ))
                    }
                } label: {
                    Label("Add Line", systemImage: "plus")
                        .font(.caption)
                }
            }
            .padding(.leading, 4)
        } label: {
            Text("Wave \(wi + 1)")
                .font(.callout.weight(.semibold))
        }
    }

    private func lineIndices(_ wi: Int) -> Range<Int> {
        document.draft.waves.indices.contains(wi)
            ? document.draft.waves[wi].lines.indices
            : 0..<0
    }

    private func lineRow(_ wi: Int, _ li: Int) -> some View {
        func with(_ mutate: @escaping (inout MapDraft.SpawnLine) -> Void) {
            document.edit(undoManager) { d in
                guard d.waves.indices.contains(wi),
                      d.waves[wi].lines.indices.contains(li) else { return }
                mutate(&d.waves[wi].lines[li])
            }
        }
        func line() -> MapDraft.SpawnLine? {
            guard document.draft.waves.indices.contains(wi),
                  document.draft.waves[wi].lines.indices.contains(li) else { return nil }
            return document.draft.waves[wi].lines[li]
        }

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Picker("", selection: Binding(
                    get: { line()?.foe ?? Foe.loyalistMilitia.rawValue },
                    set: { nv in with { $0.foe = nv } }
                )) {
                    ForEach(Foe.allCases, id: \.rawValue) { f in
                        Text(f.rawValue).tag(f.rawValue)
                    }
                }
                .labelsHidden()
                Spacer()
                Button {
                    document.edit(undoManager) { d in
                        guard d.waves.indices.contains(wi),
                              d.waves[wi].lines.indices.contains(li) else { return }
                        d.waves[wi].lines.remove(at: li)
                    }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                intField("×", Binding(
                    get: { line()?.count ?? 0 },
                    set: { nv in with { $0.count = max(1, nv) } }
                ))
                doubleField("every", Binding(
                    get: { line()?.every ?? 0 },
                    set: { nv in with { $0.every = max(0.1, nv) } }
                ))
                doubleField("delay", Binding(
                    get: { line()?.delay ?? 0 },
                    set: { nv in with { $0.delay = max(0, nv) } }
                ))
                if document.draft.roads.count > 1 {
                    Stepper(value: Binding(
                        get: { line()?.road ?? 0 },
                        set: { nv in with { $0.road = nv } }
                    ), in: 0...(document.draft.roads.count - 1)) {
                        Text("road \(line()?.road ?? 0)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }
            .font(.caption)
        }
        .padding(6)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }

    private var solutionBox: some View {
        GroupBox("Intended Solution") {
            VStack(alignment: .leading, spacing: 4) {
                if document.draft.intendedSolution.isEmpty {
                    Text("Hand-play in Playtest mode and press “Adopt Build”, or add steps here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(document.draft.intendedSolution.indices, id: \.self) { si in
                    stepRow(si)
                }
                HStack {
                    Button {
                        document.edit(undoManager) { d in
                            d.intendedSolution.append(.init(
                                at: (d.intendedSolution.last?.at ?? 0) + 10,
                                kind: "place",
                                emplacement: Emplacement.minutemanPost.rawValue,
                                slot: 0
                            ))
                        }
                    } label: {
                        Label("Place", systemImage: "plus")
                    }
                    Button {
                        document.edit(undoManager) { d in
                            d.intendedSolution.append(.init(
                                at: (d.intendedSolution.last?.at ?? 0) + 10,
                                kind: "upgrade",
                                emplacement: nil,
                                slot: 0
                            ))
                        }
                    } label: {
                        Label("Upgrade", systemImage: "plus")
                    }
                    Spacer()
                    if document.draft.intendedSolution.count > 1 {
                        Button("Sort by Time") {
                            document.edit(undoManager) {
                                $0.intendedSolution.sort { $0.at < $1.at }
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 2)
            }
            .padding(4)
        }
    }

    private func stepRow(_ si: Int) -> some View {
        func with(_ mutate: @escaping (inout MapDraft.BuildStep) -> Void) {
            document.edit(undoManager) { d in
                guard d.intendedSolution.indices.contains(si) else { return }
                mutate(&d.intendedSolution[si])
            }
        }
        func step() -> MapDraft.BuildStep? {
            document.draft.intendedSolution.indices.contains(si)
                ? document.draft.intendedSolution[si] : nil
        }
        let maxSlot = max(0, document.draft.slots.count - 1)

        return HStack(spacing: 6) {
            doubleField("t", Binding(
                get: { step()?.at ?? 0 },
                set: { nv in with { $0.at = max(0, nv) } }
            ))
            Picker("", selection: Binding(
                get: { step()?.kind ?? "place" },
                set: { nv in with {
                    $0.kind = nv
                    $0.emplacement = nv == "place"
                        ? ($0.emplacement ?? Emplacement.minutemanPost.rawValue) : nil
                } }
            )) {
                Text("Place").tag("place")
                Text("Upgrade").tag("upgrade")
            }
            .labelsHidden()
            .fixedSize()
            if step()?.kind == "place" {
                Picker("", selection: Binding(
                    get: { step()?.emplacement ?? Emplacement.minutemanPost.rawValue },
                    set: { nv in with { $0.emplacement = nv } }
                )) {
                    ForEach(Emplacement.allCases, id: \.rawValue) { e in
                        Text(e.rawValue).tag(e.rawValue)
                    }
                }
                .labelsHidden()
            }
            Stepper(value: Binding(
                get: { step()?.slot ?? 0 },
                set: { nv in with { $0.slot = nv } }
            ), in: 0...maxSlot) {
                Text("slot \(step()?.slot ?? 0)")
                    .font(.caption)
                    .monospacedDigit()
            }
            .fixedSize()
            Button {
                document.edit(undoManager) { d in
                    guard d.intendedSolution.indices.contains(si) else { return }
                    d.intendedSolution.remove(at: si)
                }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
    }

    private func intField(_ label: String, _ binding: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Text(label).foregroundStyle(.secondary)
            TextField("", value: binding, format: .number)
                .frame(width: 36)
        }
    }

    private func doubleField(_ label: String, _ binding: Binding<Double>) -> some View {
        HStack(spacing: 2) {
            Text(label).foregroundStyle(.secondary)
            TextField("", value: binding, format: .number)
                .frame(width: 42)
        }
    }
}
