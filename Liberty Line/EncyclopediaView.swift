import SwiftUI

@available(iOS 26.0, *)
struct EncyclopediaView: View {
    @EnvironmentObject private var settings: PlayerSettingsStore
    let db: Db
    let runtimeCanvas: RuntimeCanvas
    let onExit: () -> Void

    enum Category {
        case towers, enemies
    }

    @State private var selectedCategory: Category?
    @State private var arsenal: DesignArsenal?
    @State private var demonstrations: TowerDemonstrationCatalog?
    @State private var enemies: [EnemyEncyclopediaEntry]?
    @State private var enemyDemonstrations: EnemyDemonstrationCatalog?
    @State private var rules: CombatRules?

    private static let layoutSize = CGSize(width: 3840, height: 2160)
    private static let titleFrame = CGRect(x: 1220, y: 8, width: 1400, height: 622)
    private static let towersFrame = CGRect(x: 675, y: 620, width: 1138, height: 1420)
    private static let enemiesFrame = CGRect(x: 2027, y: 620, width: 1138, height: 1420)

    var body: some View {
        Group {
            if selectedCategory == .towers, let arsenal, let demonstrations {
                TowerEncyclopediaView(arsenal: arsenal, demonstrations: demonstrations, runtimeCanvas: runtimeCanvas,
                    onExit: onExit)
            } else if selectedCategory == .enemies, let enemies, let enemyDemonstrations, let rules {
                EnemyEncyclopediaView(entries: enemies, rules: rules, demonstrations: enemyDemonstrations,
                    runtimeCanvas: runtimeCanvas, onExit: onExit)
            } else {
                categoryPicker
            }
        }
        .overlay(alignment: .topLeading) {
            if settings.values.showDebugLayoutGuides {
                DebugLayoutGuidesView(runtimeCanvas: runtimeCanvas)
                    .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("encyclopedia-screen")
        .accessibilityValue(settings.values.showDebugLayoutGuides ? "Layout guides on" : "Layout guides off")
        .onAppear {
            guard arsenal == nil else { return }
            do {
                arsenal = try db.towerTypeDao.getDesignArsenal()
                demonstrations = TowerDemonstrationCatalog(db: db)
                enemies = try db.enemyTypeDao.getEncyclopedia()
                enemyDemonstrations = EnemyDemonstrationCatalog(db: db)
                rules = try db.combatRulesDao.get()
            }
            catch { fatalError("Invalid authored encyclopedia content: \(error)") }
            #if DEBUG
            if CommandLine.arguments.contains("--tower-encyclopedia-review") ||
                CommandLine.arguments.contains("--tower-demo-review") { selectedCategory = .towers }
            if CommandLine.arguments.contains("--enemy-encyclopedia-review") { selectedCategory = .enemies }
            #endif
        }
        #if DEBUG
        .task(id: selectedCategory) { await captureGuidesReview() }
        #endif
    }

    #if DEBUG
    @MainActor private func captureGuidesReview() async {
        guard CommandLine.arguments.contains("--encyclopedia-guides-review") else { return }
        do {
            try await Task.sleep(for: .milliseconds(800))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw NSError(domain: "EncyclopediaGuidesReview", code: 1)
            }
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("encyclopedia-guides-review", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let screen: String
            switch selectedCategory {
            case .towers: screen = "towers"
            case .enemies: screen = "enemies"
            case nil: screen = "categories"
            }
            let prefix = "\(settings.values.showDebugLayoutGuides ? "on" : "off")-\(screen)"
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let png = image.pngData() else { throw NSError(domain: "EncyclopediaGuidesReview", code: 2) }
            try png.write(to: directory.appendingPathComponent(prefix + ".png"))
        } catch is CancellationError {
            // Navigation can dismiss a screen before its review capture is ready.
        } catch { fatalError("Encyclopedia guides review failed: \(error)") }
    }
    #endif

    private var categoryPicker: some View {
        let scale = runtimeCanvas.playAreaRect.width / Self.layoutSize.width
        let origin = runtimeCanvas.playAreaRect.origin
        return ZStack(alignment: .topLeading) {
            ZStack {
                Image("hero_screen_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)
                    .clipped()

                element("encyclopedia_title_plaque", frame: Self.titleFrame,
                        scale: scale, origin: origin)

                categoryButton(.towers,
                               asset: "encyclopedia_towers_category",
                               frame: Self.towersFrame,
                               scale: scale, origin: origin)
                categoryButton(.enemies,
                               asset: "encyclopedia_enemies_category",
                               frame: Self.enemiesFrame,
                               scale: scale, origin: origin)
            }
            .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)

            DoneButton(runtimeCanvas: runtimeCanvas, action: onExit)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
    }

    private func element(_ name: String, frame: CGRect,
                         scale: CGFloat, origin: CGPoint) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: frame.width * scale, height: frame.height * scale)
            .position(x: origin.x + frame.midX * scale,
                      y: origin.y + frame.midY * scale)
    }

    private func categoryButton(_ category: Category, asset: String, frame: CGRect,
                                scale: CGFloat, origin: CGPoint) -> some View {
        Button {
            selectedCategory = selectedCategory == category ? nil : category
        } label: {
            Image(selectedCategory == category ? asset + "_selected" : asset)
                .resizable()
                .scaledToFit()
                .frame(width: frame.width * scale, height: frame.height * scale)
        }
        .buttonStyle(EncyclopediaButtonStyle())
        .position(x: origin.x + frame.midX * scale,
                  y: origin.y + frame.midY * scale)
        .accessibilityLabel(category == .towers ? "Towers" : "Enemies")
        .accessibilityIdentifier(category == .towers ? "encyclopedia-towers" : "encyclopedia-enemies")
    }
}

/// A read-only reference: browsing never purchases a tower or changes progress.
@available(iOS 26.0, *)
private struct TowerEncyclopediaView: View {
    let arsenal: DesignArsenal
    let families: [DesignArsenal.Definition]
    let demonstrations: TowerDemonstrationCatalog
    let runtimeCanvas: RuntimeCanvas
    let onExit: () -> Void

    @State private var familyID: UUID
    @State private var tierID: UUID
    @State private var detailPage = 0
    @State private var showingDetails = false
    @State private var reviewElapsed: Double?
    @State private var reviewSceneFrame = CGRect.zero
    #if DEBUG
    @State private var reviewListFrame = CGRect.zero
    @State private var reviewRowFrames: [UUID: CGRect] = [:]
    @State private var reviewHistoryFrame = CGRect.zero
    @State private var reviewHistoryTextFrame = CGRect.zero
    @State private var reviewContentFrame = CGRect.zero
    #endif

    private static let ink = Color(red: 0.22, green: 0.12, blue: 0.055)
    private static let paper = Color(red: 0.97, green: 0.88, blue: 0.66)
    private static let gold = Color(red: 0.48, green: 0.23, blue: 0.07)

    init(arsenal: DesignArsenal, demonstrations: TowerDemonstrationCatalog, runtimeCanvas: RuntimeCanvas,
         onExit: @escaping () -> Void) {
        self.arsenal = arsenal
        self.demonstrations = demonstrations
        self.runtimeCanvas = runtimeCanvas
        self.onExit = onExit
        // Match the established build-menu order: ranged, melee, artillery,
        // special, supply. All content still comes from the authored arsenal.
        let families = TowerKind.allCases.map { kind in
            guard let definition = arsenal.towers.first(where: { $0.kind == kind }) else {
                fatalError("tower_type[\(kind.rawValue)]: missing encyclopedia family")
            }
            return definition
        }
        guard families.count == TowerEncyclopediaLayout.rows,
              families.allSatisfy({ $0.tiers.count <= TowerEncyclopediaLayout.columns }) else {
            fatalError("tower_type.level_layout: encyclopedia requires five families with at most six entries each")
        }
        self.families = families
        // DAO validation guarantees every family has a first tier.
        let first = families[0]
        _familyID = State(initialValue: first.id)
        _tierID = State(initialValue: first.tiers[0].id)
    }

    private var family: DesignArsenal.Definition {
        guard let value = families.first(where: { $0.id == familyID }) else {
            fatalError("tower_type[\(familyID)]: encyclopedia selection is missing")
        }
        return value
    }

    private var tier: DesignArsenal.Tier {
        guard let value = family.tiers.first(where: { $0.id == tierID }) else {
            fatalError("tower[\(tierID)]: encyclopedia selection is missing")
        }
        return value
    }

    private var demonstration: TowerDemonstration {
        do { return try demonstrations.recording(kind: family.kind, tier: tier) }
        catch { fatalError("Invalid tower demonstration [\(tierID)]: \(error)") }
    }

    var body: some View {
        let layout = TowerEncyclopediaLayout(runtimeCanvas: runtimeCanvas, doneAspect: DoneButton.aspect)
        let scale = layout.typeScale
        ZStack(alignment: .topLeading) {
            Image(uiImage: DemonstrationArtwork.image("tower_encyclopedia_background"))
                .resizable().interpolation(.high)
                .frame(width: layout.backgroundFrame.width, height: layout.backgroundFrame.height)
                .position(x: layout.backgroundFrame.midX, y: layout.backgroundFrame.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Image(uiImage: DemonstrationArtwork.image("tower_encyclopedia_scroll"))
                .resizable().interpolation(.high)
                .frame(width: layout.scrollFrame.width, height: layout.scrollFrame.height)
                .position(x: layout.scrollFrame.midX, y: layout.scrollFrame.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if showingDetails {
                detailPages(scale: scale)
                    .foregroundStyle(Self.ink)
                    .frame(width: layout.detailFrame.width, height: layout.detailFrame.height)
                    .position(x: layout.detailFrame.midX, y: layout.detailFrame.midY)
                    .accessibilityIdentifier("tower-encyclopedia-details-screen")

                Text(tier.details.name)
                    .font(.custom("Baskerville-Bold", size: 23 * scale))
                    .foregroundStyle(Self.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: layout.titleFrame.width, height: layout.titleFrame.height)
                    .position(x: layout.titleFrame.midX, y: layout.titleFrame.midY)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("tower-selection-name")

                Button {
                    showingDetails = false
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 25 * scale, weight: .bold))
                        .foregroundStyle(Self.ink)
                        .frame(width: layout.backFrame.width, height: layout.backFrame.height)
                        .background(Self.paper, in: Circle())
                        .overlay { Circle().strokeBorder(Self.gold, lineWidth: 2 * scale) }
                        .contentShape(Circle())
                }
                .buttonStyle(EncyclopediaButtonStyle())
                .position(x: layout.backFrame.midX, y: layout.backFrame.midY)
                .accessibilityLabel("Back to towers")
                .accessibilityIdentifier("tower-encyclopedia-back")
            } else {
                towerGrid(cellSize: layout.cellSize, iconSide: layout.iconSide, gap: layout.gridGap, scale: scale)
                    .frame(width: layout.gridFrame.width, height: layout.gridFrame.height)
                    .position(x: layout.gridFrame.midX, y: layout.gridFrame.midY)

                DoneButton(runtimeCanvas: runtimeCanvas, action: onExit, frame: layout.doneFrame)
            }
        }
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height,
               alignment: .topLeading)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onChange(of: tierID) { _, _ in detailPage = 0 }
        #if DEBUG
        .task { await captureDeviceReview() }
        #endif
    }

    private func detailPages(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            TabView(selection: $detailPage) {
                TowerDemonstrationPage(demonstration: demonstration,
                    tier: tier, kind: family.kind, isActive: detailPage == 0, reviewElapsed: reviewElapsed)
                    .id(tierID)
                    .aspectRatio(demonstration.bounds.width / demonstration.bounds.height, contentMode: .fit)
                    .overlay {
                        Rectangle().strokeBorder(Self.gold, lineWidth: 1.5 * scale)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reviewSceneFrame = $0 }
                    .tag(0)
                detail(scale: scale).tag(1)
                history(scale: scale).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityIdentifier("tower-encyclopedia-pages")
            EncyclopediaCarouselIndicators(selection: $detailPage, detailTitle: "Stats",
                scale: scale, ink: Self.ink, accent: Self.gold, identifierPrefix: "tower-encyclopedia")
        }
        .background(Self.paper.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        #if DEBUG
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reviewContentFrame = $0 }
        #endif
    }

    private func towerGrid(cellSize: CGSize, iconSide: CGFloat, gap: CGFloat, scale: CGFloat) -> some View {
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            ForEach(families, id: \.id) { definition in
                GridRow {
                    ForEach(0..<TowerEncyclopediaLayout.columns, id: \.self) { column in
                        if column < definition.tiers.count {
                            towerButton(definition.tiers[column], family: definition, cellSize: cellSize,
                                        iconSide: iconSide, scale: scale)
                        } else {
                            // An unauthored position is empty, never a fabricated tower.
                            Color.clear.frame(width: cellSize.width, height: cellSize.height)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .overlay {
            // Draw each shared boundary once, without separate button rims.
            GeometryReader { geometry in
                SwiftUI.Path { path in
                    for column in 1..<TowerEncyclopediaLayout.columns {
                        let x = CGFloat(column) * cellSize.width
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for row in 1..<families.count {
                        let y = CGFloat(row) * cellSize.height
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Self.ink.opacity(0.8), lineWidth: 1.25 * scale)
                Rectangle().strokeBorder(Self.ink.opacity(0.8), lineWidth: 1.25 * scale)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("All towers")
        .accessibilityIdentifier("tower-encyclopedia-grid")
        #if DEBUG
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reviewListFrame = $0 }
        #endif
    }

    private func towerButton(_ entry: DesignArsenal.Tier, family definition: DesignArsenal.Definition,
                             cellSize: CGSize, iconSide: CGFloat, scale: CGFloat) -> some View {
        let selected = tierID == entry.id
        let name = iconName(for: entry, kind: definition.kind)
        guard let artwork = TowerMenuIconArtwork.image(named: name) else {
            fatalError("Missing required encyclopedia tower artwork: \(name)")
        }
        return Button {
            detailPage = 0
            familyID = definition.id
            tierID = entry.id
            showingDetails = true
        } label: {
            ZStack {
                EncyclopediaTowerCellBackground(kind: definition.kind, level: entry.level)
                Image(uiImage: artwork)
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: iconSide, height: iconSide)
                if selected {
                    Rectangle()
                        .strokeBorder(Color(red: 1, green: 0.77, blue: 0.20), lineWidth: 2.5 * scale)
                        .padding(1.25 * scale)
                }
            }
            .frame(width: cellSize.width, height: cellSize.height)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
        }
        .buttonStyle(EncyclopediaGridButtonStyle())
        .accessibilityLabel("Level \(entry.level), \(entry.details.name)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("tower-entry-\(definition.kind.rawValue)-\(entry.level)-\(entry.branch)")
        #if DEBUG
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reviewRowFrames[entry.id] = $0 }
        #endif
    }

    private func iconName(for entry: DesignArsenal.Tier, kind: TowerKind) -> String {
        guard let name = kind.assetName(atLevel: entry.level, branch: entry.branch) else {
            fatalError("tower[\(entry.id)]: missing encyclopedia grid icon")
        }
        _ = DemonstrationArtwork.image(name)
        return name
    }

    private func detail(scale: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16 * scale) {
                Text("\(tier.level == 1 ? "Build" : "Upgrade") cost: \(tier.tuning.cost) coins")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(Self.gold)
                    .accessibilityIdentifier("tower-stat-cost")
                baseStats(scale: scale)

                if !tier.tuning.upgradePaths.isEmpty {
                    sectionTitle("Specialization upgrades", scale: scale)
                    ForEach(tier.tuning.upgradePaths) { path in
                        upgrade(path, scale: scale)
                    }
                }

                // Keep the numerical reference first; descriptive copy follows
                // the stats and authored specialization values.
                Text(tier.details.description)
                    .font(.system(size: 16 * scale))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tower-detail-description")
                if let guide = tier.history.guide {
                    sectionTitle("Using the battery", scale: scale)
                    Text(guide.strategy)
                        .font(.system(size: 16 * scale))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("tower-detail-strategy")
                }
            }
            .padding(12 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(tierID)
        .scrollIndicatorsFlash(onAppear: true)
        .accessibilityIdentifier("tower-encyclopedia-detail")
        .clipped()
        .background(Self.paper.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }

    private func baseStats(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            ForEach(TowerEncyclopediaStat.values(for: tier.tuning)) { stat in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(stat.label).foregroundStyle(Self.ink.opacity(0.85))
                    Spacer(minLength: 6)
                    Text(stat.value).fontWeight(.semibold).monospacedDigit()
                }
                .font(.system(size: 15 * scale))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("tower-stat-\(stat.id)")
            }
            Text("Before optional upgrades and support bonuses. Distances use map units.")
                .font(.system(size: 12 * scale))
                .foregroundStyle(Self.ink.opacity(0.7))
        }
    }

    private func history(scale: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(tier.history.description)
                    .font(.system(size: 16 * scale))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tower-history-description")
                    #if DEBUG
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reviewHistoryTextFrame = $0 }
                    #endif
                if let guide = tier.history.guide {
                    sectionTitle("Why we included it", scale: scale)
                        .padding(.top, 18 * scale)
                        .padding(.bottom, 8 * scale)
                    Text(guide.inclusionReason)
                        .font(.system(size: 16 * scale))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("tower-history-inclusion")
                }
                Link(destination: tier.history.sourceURL) {
                    HStack(spacing: 8 * scale) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 20 * scale, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(tier.history.sourceTitle)
                            .font(.system(size: 14 * scale, weight: .semibold))
                            .accessibilityIdentifier("tower-history-source-title")
                    }
                    .frame(minHeight: 44 * scale, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .foregroundStyle(Self.gold)
                .padding(.top, 12 * scale)
                .accessibilityLabel("Historical source: \(tier.history.sourceTitle)")
                .accessibilityHint("Opens the source website")
                .accessibilityIdentifier("tower-history-source")
            }
            .padding(.horizontal, 14 * scale)
            .padding(.top, 8 * scale)
            .padding(.bottom, 8 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(tierID)
        .accessibilityIdentifier("tower-encyclopedia-history")
        .clipped()
        #if DEBUG
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { reviewHistoryFrame = $0 }
        #endif
    }

    private func sectionTitle(_ title: String, scale: CGFloat) -> some View {
        Text(title)
            .font(.custom("Baskerville-Bold", size: 20 * scale))
            .foregroundStyle(Self.gold)
            .accessibilityAddTraits(.isHeader)
    }

    private func upgrade(_ path: TowerUpgradePath, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            Text(path.name)
                .font(.custom("Baskerville-Bold", size: 20 * scale))
            Text(path.description)
                .font(.system(size: 15 * scale))
            ForEach(path.ranks, id: \.rank) { rank in
                VStack(alignment: .leading, spacing: 3 * scale) {
                    Text("Rank \(rank.rank) · \(rank.cost) coins")
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .foregroundStyle(Self.gold)
                    Text(rank.description)
                        .font(.system(size: 15 * scale))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12 * scale)
        .background(Self.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    #if DEBUG
    /// Captures the production view on the physical device. This checks
    /// rendering and catalog loading; it does not replace touch-driven UI tests.
    @MainActor private func captureDeviceReview() async {
        let animationReview = CommandLine.arguments.contains("--tower-demo-review")
        let supplyReview = CommandLine.arguments.contains("--tower-demo-review-supply")
        let comparisonReview = CommandLine.arguments.contains("--tower-demo-ranged-comparison")
        let framingReview = CommandLine.arguments.contains("--tower-demo-framing-review")
        let layoutReview = CommandLine.arguments.contains("--tower-layout-review")
        let timingReview = CommandLine.arguments.contains("--tower-demo-timing-review")
        let mortarReview = CommandLine.arguments.contains("--tower-mortar-review")
        let siegeReview = CommandLine.arguments.contains("--tower-siege-review")
        let grenadierReview = CommandLine.arguments.contains("--grenadier-review")
        guard animationReview || CommandLine.arguments.contains("--tower-encyclopedia-review") else { return }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(grenadierReview ? "grenadier-review" : siegeReview ? "tower-siege-review" : mortarReview ? (timingReview ? "tower-mortar-live-review" : "tower-mortar-review") : layoutReview ? "tower-layout-review" : animationReview
                ? (comparisonReview ? "tower-ranged-framing-review" : framingReview ? "tower-demos-framing-check"
                    : timingReview ? "tower-demos-timing-review"
                    : (supplyReview ? "tower-demos-review-supply" : "tower-demos-framing-review"))
                : "tower-history-review", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let reportURL = directory.appendingPathComponent("result.json")
            if FileManager.default.fileExists(atPath: reportURL.path) {
                try FileManager.default.removeItem(at: reportURL)
            }
            try await Task.sleep(for: .milliseconds(400))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw NSError(domain: "TowerEncyclopediaReview", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Missing device window"])
            }
            var records: [[String: Any]] = []
            let layout = TowerEncyclopediaLayout(runtimeCanvas: runtimeCanvas, doneAspect: DoneButton.aspect)
            guard runtimeCanvas.playAreaRect.contains(layout.scrollFrame),
                  layout.scrollFrame.contains(layout.contentFrame) else {
                throw NSError(domain: "TowerEncyclopediaReview", code: 9,
                              userInfo: [NSLocalizedDescriptionKey: "Scroll or content escapes the authored play area"])
            }
            func scrollViews(in view: UIView) -> [UIScrollView] {
                // Page-style TabView introduces a horizontal scroll ancestor.
                // Keep traversing it to reach the vertical details scroll view.
                let own = (view as? UIScrollView).map { [$0] } ?? []
                return own + view.subviews.flatMap { scrollViews(in: $0) }
            }
            func capture(_ filename: String, crop: CGRect? = nil) throws {
                window.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat()
                format.scale = window.screen.scale
                let rect = crop ?? window.bounds
                let image = UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
                    context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let png = image.pngData() else { throw NSError(domain: "TowerEncyclopediaReview", code: 2) }
                try png.write(to: directory.appendingPathComponent(filename))
            }
            try capture("tower-list.png")
            showingDetails = true
            for definition in families {
                if supplyReview && definition.kind != .supply { continue }
                if comparisonReview && definition.kind != .ranged { continue }
                for entry in definition.tiers {
                    if grenadierReview && !(definition.kind == .special && entry.level == 4 && entry.branch == 1) { continue }
                    if mortarReview && entry.history.guide?.style != .mortarStudy { continue }
                    if siegeReview && entry.tuning.attackMode != .solidShot { continue }
                    if comparisonReview && entry.level > 3 { continue }
                    if layoutReview && entry.level != 1 &&
                        !(definition.kind == .supply && entry.level == 4 && entry.branch == 3) { continue }
                    familyID = definition.id
                    tierID = entry.id
                    detailPage = 0
                    reviewElapsed = (animationReview || layoutReview) && !timingReview ? 0 : nil
                    try await Task.sleep(for: .milliseconds(200))
                    if grenadierReview {
                        let menu = TowerMenuLayout(virtualCanvas: runtimeCanvas.virtualCanvas)
                        let size = menu.getTowerButtonSize(playAreaScalingFactor:
                            340 / runtimeCanvas.virtualCanvas.playAreaRect.height)
                        let proof = HStack(spacing: 12) {
                            ForEach([true, false], id: \.self) { affordable in
                                UpgradeMenuItem(towerMenuLayout: menu, iconName: "grenadier_grenade",
                                    dropKind: .special, cost: entry.tuning.cost, isArmed: false,
                                    isAffordable: affordable, buttonSize: size, action: {})
                            }
                        }.padding(12).background(Color(red: 0.22, green: 0.28, blue: 0.2))
                        let renderer = ImageRenderer(content: proof)
                        renderer.scale = window.screen.scale
                        guard let png = renderer.uiImage?.pngData() else {
                            throw NSError(domain: "TowerEncyclopediaReview", code: 8,
                                userInfo: [NSLocalizedDescriptionKey: "Unable to capture minimum grenade menu proof"])
                        }
                        try png.write(to: directory.appendingPathComponent("minimum-menu@3x.png"))
                    }
                    window.layoutIfNeeded()
                    guard runtimeCanvas.playAreaRect.insetBy(dx: -0.5, dy: -0.5).contains(reviewContentFrame) else {
                        throw NSError(domain: "TowerEncyclopediaReview", code: 7,
                                      userInfo: [NSLocalizedDescriptionKey: "Tower encyclopedia extends outside the authored play area"])
                    }
                    guard families.flatMap(\.tiers).allSatisfy({ entry in
                        guard let frame = reviewRowFrames[entry.id] else { return false }
                        return frame.width >= TouchTarget.minimum && frame.height >= TouchTarget.minimum
                            && reviewListFrame.insetBy(dx: -0.5, dy: -0.5).contains(frame)
                    }) else {
                        throw NSError(domain: "TowerEncyclopediaReview", code: 3,
                                      userInfo: [NSLocalizedDescriptionKey: "Tower grid cells are clipped or below minimum touch size"])
                    }
                    try await Task.sleep(for: .milliseconds(100))
                    let prefix = "\(definition.kind.rawValue)-\(entry.level)-\(entry.branch)"
                    let filename = timingReview ? "\(prefix)-live-start.png" : "\(prefix).png"
                    let liveCaptureStart = Date()
                    try capture(filename, crop: timingReview || framingReview ? reviewSceneFrame : nil)
                    let demo = try demonstrations.recording(kind: definition.kind, tier: entry)
                    var liveCaptureInterval = 0.0
                    var animationFrameCount = 0
                    var animationFrameInterval = 0.0
                    if animationReview {
                        guard reviewSceneFrame.width > 0, reviewSceneFrame.height > 0 else {
                            throw NSError(domain: "TowerEncyclopediaReview", code: 5,
                                userInfo: [NSLocalizedDescriptionKey: "Missing animation capture bounds"])
                        }
                        if timingReview {
                            // Keep TimelineView on its real display clock, so
                            // these captures exercise normal live playback.
                            try await Task.sleep(for: .seconds(1))
                            try capture("\(prefix)-live-later.png", crop: reviewSceneFrame)
                            liveCaptureInterval = Date().timeIntervalSince(liveCaptureStart)
                            animationFrameCount = 2
                        } else {
                            animationFrameCount = (comparisonReview || mortarReview || siegeReview) ? Int(ceil(demo.loopDuration * 12)) : framingReview ? 12 : 72
                            animationFrameInterval = (comparisonReview || mortarReview || siegeReview) ? 1.0 / 12 : demo.loopDuration / Double(animationFrameCount)
                            for index in 0..<animationFrameCount {
                                reviewElapsed = Double(index) * animationFrameInterval
                                try await Task.sleep(for: .milliseconds(35))
                                try capture(String(format: "\(prefix)-animation-%03d.png", index), crop: reviewSceneFrame)
                            }
                            if siegeReview {
                                for (label, offset) in [("loop-end", -0.5), ("loop-restart", 0.5)] {
                                    reviewElapsed = demo.loopDuration + offset * SimClock.dt
                                    try await Task.sleep(for: .milliseconds(35))
                                    try capture("\(prefix)-\(label).png", crop: reviewSceneFrame)
                                }
                            }
                        }
                    }
                    reviewElapsed = nil
                    if !timingReview && !framingReview {
                        detailPage = 1
                        try await Task.sleep(for: .milliseconds(200))
                        try capture("\(definition.kind.rawValue)-\(entry.level)-\(entry.branch)-details.png")
                        if mortarReview || siegeReview, let detail = scrollViews(in: window).first(where: {
                            $0.convert($0.bounds, to: window).intersection(reviewSceneFrame).width > reviewSceneFrame.width * 0.8
                                && $0.contentSize.height > $0.bounds.height + 10
                        }) {
                            let bottom = max(0, detail.contentSize.height - detail.bounds.height)
                            for (name, fraction) in [("stats", 0.22), ("strategy", 0.44)] {
                                detail.setContentOffset(CGPoint(x: 0, y: bottom * fraction), animated: false)
                                try await Task.sleep(for: .milliseconds(150))
                                try capture("\(prefix)-\(name).png")
                            }
                        }
                        if !entry.tuning.upgradePaths.isEmpty {
                            guard let detail = scrollViews(in: window).first(where: {
                                $0.convert($0.bounds, to: window).intersection(layout.detailFrame).width > layout.detailFrame.width * 0.8
                                    && $0.contentSize.height > $0.bounds.height + 10
                            }) else {
                                throw NSError(domain: "TowerEncyclopediaReview", code: 4,
                                    userInfo: [NSLocalizedDescriptionKey: "Missing tower detail scroll view"])
                            }
                            detail.setContentOffset(CGPoint(x: 0, y: max(0, detail.contentSize.height - detail.bounds.height)),
                                                    animated: false)
                            try await Task.sleep(for: .milliseconds(100))
                            try capture("\(definition.kind.rawValue)-\(entry.level)-\(entry.branch)-upgrades.png")
                        }
                        detailPage = 2
                        try await Task.sleep(for: .milliseconds(200))
                        try capture("\(prefix)-history.png")
                        if mortarReview || siegeReview, let history = scrollViews(in: window).first(where: {
                            $0.convert($0.bounds, to: window).intersection(reviewSceneFrame).width > reviewSceneFrame.width * 0.8
                                && $0.contentSize.height > $0.bounds.height + 10
                        }) {
                            let bottom = max(0, history.contentSize.height - history.bounds.height)
                            history.setContentOffset(CGPoint(x: 0, y: bottom * 0.5), animated: false)
                            try await Task.sleep(for: .milliseconds(150))
                            try capture("\(prefix)-purpose.png")
                            history.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                            try await Task.sleep(for: .milliseconds(150))
                            try capture("\(prefix)-inclusion.png")
                        }
                    }
                    let projection = DemonstrationProjection(bounds: demo.bounds, size: reviewSceneFrame.size, virtualCanvas: demo.virtualCanvas)
                    let range = demo.tower.tuning.meleeUnit?.rallyPointRadius ?? demo.tower.tuning.range
                    let entrance = projection.point(demo.frames.first!.enemies.first!.position)
                    records.append(["id": entry.id.uuidString, "name": entry.details.name,
                                    "screenshot": filename, "upgradePaths": entry.tuning.upgradePaths.count,
                                    "lesson": demo.lesson.rawValue, "frames": demo.frames.count,
                                    "engineSeconds": demo.frames.last!.seconds,
                                    "loopSeconds": demo.loopDuration,
                                    "firstFrameEnemyCount": demo.frames.first!.enemies.count,
                                    "liveCaptureInterval": liveCaptureInterval,
                                    "animationFrameCount": animationFrameCount,
                                    "animationFrameInterval": animationFrameInterval,
                                    "rangeWidthFraction": range * 2 * projection.scale / reviewSceneFrame.width,
                                    "firstEnemyScreenPoint": [entrance.x, entrance.y],
                                    "towerImageHeight": projection.towerHeight,
                                    "enemyImageHeight": projection.unitHeight,
                                    "firstShotSeconds": demo.frames.first(where: { $0.shots > 0 }).map { $0.seconds as Any } ?? NSNull(),
                                    "gridEntriesVisible": families.flatMap(\.tiers).count,
                                    "gridIcon": iconName(for: entry, kind: definition.kind),
                                    "rowHeight": reviewRowFrames[entry.id]!.height,
                                    "history": entry.history.description,
                                    "historySource": entry.history.sourceURL.absoluteString,
                                    "historyFits": reviewHistoryTextFrame.height > 0 && reviewHistoryFrame.contains(reviewHistoryTextFrame),
                                    "historyFrame": [reviewHistoryFrame.minX, reviewHistoryFrame.minY,
                                                     reviewHistoryFrame.width, reviewHistoryFrame.height],
                                    "historyTextFrame": [reviewHistoryTextFrame.minX, reviewHistoryTextFrame.minY,
                                                         reviewHistoryTextFrame.width, reviewHistoryTextFrame.height],
                                    "shots": demo.frames.last!.shots,
                                    "escaped": demo.escaped])
                }
            }
            if !mortarReview && !siegeReview {
                guard let ranged = families.first(where: { $0.kind == .ranged }),
                      let first = ranged.tiers.first(where: { $0.level == 1 && $0.branch == 1 }) else {
                    fatalError("Missing ranged review entry")
                }
                familyID = ranged.id
                tierID = first.id
            }
            detailPage = 0
            if layoutReview {
                showingDetails = false
                try await Task.sleep(for: .milliseconds(200))
                try capture("tower-list-return.png")
            }
            let report: [String: Any] = ["renderedEntries": records, "interactionVerified": false,
                                        "animationReview": animationReview,
                                        "rangedComparisonReview": comparisonReview,
                                        "framingReview": framingReview,
                                        "layoutReview": layoutReview,
                                        "gridColumns": TowerEncyclopediaLayout.columns, "gridRows": families.count,
                                        "gridIconSide": layout.iconSide,
                                        "gridIconInsetFraction": TowerEncyclopediaLayout.iconInsetFraction,
                                        "scrollFrame": [layout.scrollFrame.minX, layout.scrollFrame.minY,
                                                        layout.scrollFrame.width, layout.scrollFrame.height],
                                        "backgroundFrame": [layout.backgroundFrame.minX, layout.backgroundFrame.minY,
                                                            layout.backgroundFrame.width, layout.backgroundFrame.height],
                                        "gridButtons": families.flatMap { definition in
                                            definition.tiers.map { entry in
                                                let frame = reviewRowFrames[entry.id]!
                                                return ["name": entry.details.name,
                                                        "icon": iconName(for: entry, kind: definition.kind),
                                                        "frame": [frame.minX, frame.minY, frame.width, frame.height]] as [String: Any]
                                            }
                                        },
                                        "playFrame": [runtimeCanvas.playAreaRect.minX, runtimeCanvas.playAreaRect.minY,
                                                      runtimeCanvas.playAreaRect.width, runtimeCanvas.playAreaRect.height],
                                        "safeFrame": [runtimeCanvas.safeInsetsRect.minX, runtimeCanvas.safeInsetsRect.minY,
                                                      runtimeCanvas.safeInsetsRect.width, runtimeCanvas.safeInsetsRect.height],
                                        "hudFrame": [runtimeCanvas.hudPlayArea.bounds.minX, runtimeCanvas.hudPlayArea.bounds.minY,
                                                     runtimeCanvas.hudPlayArea.bounds.width, runtimeCanvas.hudPlayArea.bounds.height],
                                        "contentFrame": [reviewContentFrame.minX, reviewContentFrame.minY,
                                                         reviewContentFrame.width, reviewContentFrame.height],
                                        "playbackSpeed": 1, "liveTimingReview": timingReview,
                                        "listFrame": [reviewListFrame.minX, reviewListFrame.minY,
                                                      reviewListFrame.width, reviewListFrame.height],
                                        "sceneFrame": [reviewSceneFrame.minX, reviewSceneFrame.minY,
                                                       reviewSceneFrame.width, reviewSceneFrame.height],
                                        "width": window.bounds.width, "height": window.bounds.height,
                                        "density": window.screen.scale]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch {
            fatalError("Tower encyclopedia device review failed: \(error)")
        }
    }
    #endif
}

@available(iOS 26.0, *)
private struct EncyclopediaTowerCellBackground: View {
    let kind: TowerKind
    let level: Int

    // Presentation colors only. The authored DAO tier supplies the progression;
    // level-four specialties have equal strength regardless of branch or row.
    private var strength: Double {
        switch level {
        case 1: return 0.15
        case 2: return 0.43
        case 3: return 0.72
        case 4: return 1
        default: fatalError("tower[\(kind.rawValue)].level: unsupported encyclopedia color tier \(level)")
        }
    }

    private var hue: Double {
        switch kind {
        case .ranged: return 0.49
        case .melee: return 0.035
        case .areaOfEffect: return 0.615
        case .special: return 0.78
        case .supply: return 0.265
        }
    }

    var body: some View {
        let saturation = 0.18 + 0.50 * strength
        let brightness = 0.91 - 0.17 * strength
        ZStack {
            LinearGradient(stops: [
                .init(color: Color(hue: hue - 0.015, saturation: saturation * 0.78,
                                   brightness: brightness + 0.10), location: 0),
                .init(color: Color(hue: hue, saturation: saturation,
                                   brightness: brightness), location: 0.46),
                .init(color: Color(hue: hue + 0.02, saturation: saturation + 0.08,
                                   brightness: brightness - 0.16), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            // A broad irregular wash gives the face a painted color plane.
            // Keep it quiet and large; fine grain disappears behind these icons.
            GeometryReader { geometry in
                SwiftUI.Path { path in
                    let w = geometry.size.width, h = geometry.size.height
                    path.move(to: CGPoint(x: 0, y: h * 0.09))
                    path.addLine(to: CGPoint(x: w * 0.57, y: 0))
                    path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.13))
                    path.addLine(to: CGPoint(x: w * 0.39, y: h * 0.36))
                    path.addLine(to: CGPoint(x: 0, y: h * 0.52))
                    path.closeSubpath()
                }
                .fill(Color(red: 1, green: 0.95, blue: 0.77).opacity(0.14))
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@available(iOS 26.0, *)
private struct EncyclopediaGridButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Keep the shared grid edges stationary while a cell is pressed.
            .brightness(configuration.isPressed ? -0.12 : 0)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}

@available(iOS 26.0, *)
private struct EncyclopediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}
