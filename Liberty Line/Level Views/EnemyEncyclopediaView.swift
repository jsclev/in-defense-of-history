import SwiftUI

@available(iOS 26.0, *)
struct EnemyEncyclopediaView: View {
    let entries: [EnemyEncyclopediaEntry]
    let rules: CombatRules
    let demonstrations: EnemyDemonstrationCatalog
    let runtimeCanvas: RuntimeCanvas
    let onExit: () -> Void
    @State private var selection: UUID
    @State private var page = 0
    @State private var reviewElapsed: Double?
    @State private var sceneFrame = CGRect.zero
    private static let ink = Color(red: 0.045, green: 0.095, blue: 0.13)
    private static let paper = Color(red: 0.97, green: 0.91, blue: 0.76)
    private static let gold = Color(red: 0.91, green: 0.69, blue: 0.32)

    init(entries: [EnemyEncyclopediaEntry], rules: CombatRules, demonstrations: EnemyDemonstrationCatalog,
         runtimeCanvas: RuntimeCanvas, onExit: @escaping () -> Void) {
        precondition(!entries.isEmpty, "enemy_encyclopedia: missing authored roster")
        self.entries = entries
        self.rules = rules
        self.demonstrations = demonstrations
        self.runtimeCanvas = runtimeCanvas
        self.onExit = onExit
        _selection = State(initialValue: entries[0].id)
    }

    private var entry: EnemyEncyclopediaEntry {
        guard let entry = entries.first(where: { $0.id == selection }) else {
            fatalError("enemy_encyclopedia[\(selection)]: missing selected record")
        }
        return entry
    }

    private var demo: TowerDemonstration {
        do { return try demonstrations.recording(enemyID: selection) }
        catch { fatalError("Invalid enemy demonstration [\(selection)]: \(error)") }
    }

    var body: some View {
        let padding = HudSizing.hudPadding.resolved(at: HudScale(playableHeight: runtimeCanvas.playAreaRect.height).value)
        // Encyclopedia controls belong inside the authored play area, including
        // on phones whose HUD is allowed to extend into the side gutters.
        let play = runtimeCanvas.playAreaRect.intersection(runtimeCanvas.safeInsetsRect)
            .insetBy(dx: padding, dy: padding)
        let doneSize = DoneButtonLayout(runtimeCanvas: runtimeCanvas, aspect: DoneButton.aspect).frame.size
        let footer = CGRect(x: play.maxX - doneSize.width, y: play.maxY - doneSize.height,
                            width: doneSize.width, height: doneSize.height)
        let rect = CGRect(x: play.minX, y: play.minY, width: play.width,
                          height: max(0, footer.minY - padding - play.minY))
        let scale = min(1.5, max(1, rect.height / 340))
        ZStack(alignment: .topLeading) {
            Image("hero_screen_background").resizable().scaledToFill()
                .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)
                .clipped().overlay(Color.black.opacity(0.22))
            HStack(spacing: 8 * scale) {
                roster(scale: scale).frame(width: rect.width * 0.42)
                pages(scale: scale).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(Self.paper)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            DoneButton(runtimeCanvas: runtimeCanvas, action: onExit, frame: footer)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onChange(of: selection) { _, _ in page = 0 }
        #if DEBUG
        .task { await captureReview() }
        #endif
    }

    private func roster(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            title("Enemies", scale: scale).padding(.horizontal, 12 * scale).padding(.top, 8 * scale)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3 * scale) {
                        ForEach(entries) { item in
                            Button { selection = item.id } label: {
                                HStack(spacing: 8 * scale) {
                                    Image(uiImage: DemonstrationArtwork.image(item.enemy.imageName))
                                        .resizable().interpolation(.high).scaledToFit()
                                        .frame(width: 38 * scale, height: 42 * scale)
                                        .accessibilityHidden(true)
                                    Text(item.enemy.name).font(.custom("Baskerville-Bold", size: 17 * scale))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 8 * scale).padding(.vertical, 3 * scale)
                                .frame(minHeight: 48 * scale)
                                .background(selection == item.id ? Color.white.opacity(0.13) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selection == item.id ? Self.gold : .clear, lineWidth: 2))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                            .accessibilityLabel(item.enemy.name)
                            .accessibilityAddTraits(selection == item.id ? [.isSelected] : [])
                            .accessibilityIdentifier("enemy-entry-\(item.enemy.key)")
                        }
                    }.padding(4 * scale)
                }
                .accessibilityIdentifier("enemy-encyclopedia-list")
                .onChange(of: selection) { _, id in proxy.scrollTo(id, anchor: .center) }
            }
        }
        .background(Self.ink.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
    }

    private func pages(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                EnemyDemonstrationPage(demo: demo, entry: entry, isActive: page == 0, reviewElapsed: reviewElapsed)
                    .id(selection)
                    .tag(0)
                strategy(scale: scale).tag(1)
                history(scale: scale).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sceneFrame = $0 }
            .accessibilityIdentifier("enemy-encyclopedia-pages")
            EncyclopediaCarouselIndicators(selection: $page, detailTitle: "Tactics",
                scale: scale, ink: Self.paper, accent: Self.gold, identifierPrefix: "enemy-encyclopedia")
        }
        .background(Self.ink.opacity(0.97), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func strategy(scale: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12 * scale) {
                title(entry.enemy.name, scale: scale).accessibilityIdentifier("enemy-detail-name")
                copy(entry.enemy.description, scale: scale)
                title("Facing this enemy", scale: scale)
                copy(entry.strategy, scale: scale).accessibilityIdentifier("enemy-detail-strategy")
                title("Base stats", scale: scale)
                ForEach(EnemyEncyclopediaStats(enemy: entry.enemy, rules: rules).rows) { stat in
                    HStack(alignment: .top, spacing: 12) {
                        Text(stat.label).foregroundStyle(Self.paper.opacity(0.82))
                        Spacer(minLength: 4)
                        Text(stat.value).fontWeight(.semibold).monospacedDigit().multilineTextAlignment(.trailing)
                    }
                    .font(.system(size: 15 * scale)).accessibilityElement(children: .combine)
                    .accessibilityIdentifier("enemy-stat-\(stat.id)")
                }
                copy("Base enemy values before difficulty scaling. The demonstration uses your selected difficulty and upgrades. Distances use map units. Cover reduces melee damage; explosive weapons apply their own cover penetration. Discipline reduces artillery morale shock.", scale: scale)
                    .foregroundStyle(Self.paper.opacity(0.72))
            }
            .padding(14 * scale).frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(selection).accessibilityIdentifier("enemy-encyclopedia-detail").clipped()
    }

    private func history(scale: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12 * scale) {
                HStack {
                    title("History", scale: scale)
                    Spacer()
                    Link(destination: entry.sourceURL) {
                        Image(systemName: "book.closed").font(.system(size: 20 * scale, weight: .semibold))
                            .frame(width: 44 * scale, height: 44 * scale)
                    }
                    .foregroundStyle(Self.gold)
                    .accessibilityLabel("Historical source: \(entry.sourceTitle)")
                    .accessibilityIdentifier("enemy-history-source")
                }
                copy(entry.history, scale: scale).accessibilityIdentifier("enemy-history-description")
                title("Why we included it", scale: scale)
                copy(entry.inclusionReason, scale: scale).accessibilityIdentifier("enemy-history-inclusion")
                title("History and game rules", scale: scale)
                copy(entry.adaptation, scale: scale).accessibilityIdentifier("enemy-history-adaptation")
                Link(entry.sourceTitle, destination: entry.sourceURL)
                    .font(.system(size: 14 * scale, weight: .semibold)).foregroundStyle(Self.gold)
                    .frame(minHeight: 44 * scale, alignment: .leading)
                    .accessibilityIdentifier("enemy-history-source-title")
            }
            .padding(14 * scale).frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(selection).accessibilityIdentifier("enemy-encyclopedia-history").clipped()
    }

    private func title(_ text: String, scale: CGFloat) -> some View {
        Text(text).font(.custom("Baskerville-Bold", size: 20 * scale))
            .foregroundStyle(Self.gold).accessibilityAddTraits(.isHeader)
    }

    private func copy(_ text: String, scale: CGFloat) -> some View {
        Text(text).font(.system(size: 16 * scale)).fixedSize(horizontal: false, vertical: true)
    }

    #if DEBUG
    @MainActor private func captureReview() async {
        guard CommandLine.arguments.contains("--enemy-encyclopedia-review") else { return }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("enemy-encyclopedia-review")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await Task.sleep(for: .milliseconds(400))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw NSError(domain: "EnemyReview", code: 1)
            }
            func capture(_ name: String, crop: CGRect? = nil) throws {
                window.layoutIfNeeded()
                let rect = crop ?? window.bounds
                let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
                let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
                    context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let data = image.pngData() else { throw NSError(domain: "EnemyReview", code: 2) }
                try data.write(to: directory.appendingPathComponent(name + ".png"))
            }
            func scrollViews(_ view: UIView) -> [UIScrollView] {
                ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrollViews)
            }
            var records: [[String: Any]] = []
            for item in entries {
                selection = item.id; page = 0; reviewElapsed = 2
                try await Task.sleep(for: .milliseconds(250))
                let recording = try demonstrations.recording(enemyID: item.id)
                try capture(item.enemy.key + "-demo")
                if CommandLine.arguments.contains("--enemy-demo-review") {
                    for index in 0..<Int(ceil(recording.loopDuration * 8)) {
                        reviewElapsed = Double(index) / 8
                        try await Task.sleep(for: .milliseconds(35))
                        try capture(String(format: "%@-frame-%04d", item.enemy.key, index), crop: sceneFrame)
                    }
                }
                for detail in 1...2 {
                    page = detail
                    try await Task.sleep(for: .milliseconds(250))
                    try capture(item.enemy.key + "-page-\(detail + 1)")
                    if let scroll = scrollViews(window).first(where: {
                        $0.convert($0.bounds, to: window).intersection(sceneFrame).width > sceneFrame.width * 0.8
                            && $0.contentSize.height > $0.bounds.height + 10
                    }) {
                        let bottom = max(0, scroll.contentSize.height - scroll.bounds.height)
                        for (label, fraction) in [("middle", 0.5), ("bottom", 1.0)] {
                            scroll.setContentOffset(CGPoint(x: 0, y: bottom * fraction), animated: false)
                            try await Task.sleep(for: .milliseconds(100))
                            try capture(item.enemy.key + "-page-\(detail + 1)-" + label)
                        }
                    }
                }
                records.append(["key": item.enemy.key, "asset": item.enemy.imageName,
                                "duration": recording.loopDuration, "escaped": recording.escaped,
                                "frames": recording.frames.count, "source": item.sourceURL.absoluteString])
            }
            try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
            selection = entries[0].id; page = 0; reviewElapsed = nil
        } catch {
            try? String(describing: error).write(to: directory.appendingPathComponent("failure.txt"), atomically: true, encoding: .utf8)
        }
    }
    #endif
}

@available(iOS 26.0, *)
private struct EnemyDemonstrationPage: View {
    let demo: TowerDemonstration
    let entry: EnemyEncyclopediaEntry
    let isActive: Bool
    let reviewElapsed: Double?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date()
    @State private var playing = true
    @State private var pausedAt = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isActive || !playing || scenePhase != .active)) { timeline in
            TowerDemonstrationScene(demo: demo,
                elapsed: reviewElapsed ?? (playing ? timeline.date.timeIntervalSince(began) : pausedAt))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.enemy.name). \(entry.enemy.description) \(entry.strategy) Demonstration repeats automatically.")
        .accessibilityIdentifier("enemy-demonstration-animation")
        .overlay(alignment: .topTrailing) {
            Button {
                if playing { pausedAt = Date().timeIntervalSince(began) }
                else { began = Date().addingTimeInterval(-pausedAt) }
                playing.toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .frame(width: 44, height: 44).background(.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain).padding(8)
            .accessibilityLabel(playing ? "Pause demonstration" : "Play demonstration")
            .accessibilityIdentifier("enemy-demonstration-playback")
        }
        .clipped()
        .onAppear { playing = !reduceMotion; if reduceMotion { pausedAt = 2 } }
        .onChange(of: reduceMotion) { _, reduce in
            if reduce { pausedAt = Date().timeIntervalSince(began); playing = false }
        }
        .onChange(of: isActive) { _, active in if active { began = Date(); pausedAt = 0 } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { began = Date(); pausedAt = 0 } }
    }
}
