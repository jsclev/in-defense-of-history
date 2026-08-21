import SwiftUI

@available(iOS 26.0, *)
struct HeroesView: View {
    let db: Db
    let screen: ScreenGeometry
    let onExit: () -> Void

    @State private var heroes: [Hero] = []
    @State private var selectedHero: Hero?

    private static let columns = 5
    private static let rows = 3

    var body: some View {
        if let selectedHero {
            HeroDetailsView(db: db, screen: screen, hero: selectedHero) {
                self.selectedHero = nil
            }
        } else {
            heroGrid
        }
    }

    private var heroGrid: some View {
        let rectHeight = screen.playable.height
        let rectWidth = screen.playable.width
        let margin = rectHeight * 0.028
        let gap = rectHeight * 0.02
        let cellWidth = (rectWidth - 2 * margin - CGFloat(Self.columns - 1) * gap)
            / CGFloat(Self.columns)
        let cellHeight = (rectHeight - 2 * margin - CGFloat(Self.rows - 1) * gap)
            / CGFloat(Self.rows)
        return ZStack(alignment: .topLeading) {
            ZStack {
                Image("hero_screen_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.physical.width, height: screen.physical.height)
                    .clipped()

                VStack(spacing: gap) {
                    ForEach(0..<Self.rows, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<Self.columns, id: \.self) { column in
                                let index = row * Self.columns + column
                                HeroSlot(
                                    hero: index < heroes.count ? heroes[index] : nil,
                                    width: cellWidth,
                                    height: cellHeight,
                                    unlockFontSize: Self.unlockFontSize(
                                        heroes: heroes,
                                        cellWidth: cellWidth,
                                        cellHeight: cellHeight
                                    )
                                ) { hero in
                                    selectedHero = hero
                                }
                            }
                        }
                    }
                }
                .frame(width: rectWidth, height: rectHeight)
                .position(x: screen.physical.width / 2, y: screen.physical.height / 2)
            }
            .frame(width: screen.physical.width, height: screen.physical.height)

            DoneButton(action: onExit)
                .hudFrame(DoneButtonLayout(screen: screen,
                                           aspect: DoneButton.aspect).frame,
                          in: screen)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: loadHeroes)
    }

    static func unlockFontSize(heroes: [Hero], cellWidth: CGFloat,
                               cellHeight: CGFloat) -> CGFloat {
        let wrapWidth = cellWidth * (1 - 2 * 0.04) - 1
        let messages = heroes.compactMap(heroUnlockMessage)
        var size = cellHeight * 0.098
        let minSize = size * 0.75
        while size > minSize {
            let font = UIFont(name: "Cochin-Bold", size: size)
                ?? UIFont.systemFont(ofSize: size)
            let fits = messages.allSatisfy { message in
                (message as NSString).boundingRect(
                    with: CGSize(width: wrapWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: [.font: font],
                    context: nil
                ).height <= font.lineHeight * 2 + 1
            }
            if fits { break }
            size -= 0.25
        }
        return size
    }

    private func loadHeroes() {
        guard heroes.isEmpty else { return }
        guard Bundle.main.url(forResource: "in_defense_of_history", withExtension: "sqlite") != nil else {
            return
        }
        heroes = (try? db.heroDao.getAll()) ?? []

        let unlocked = Set(heroes.filter(\.unlocked).map(\.id.uuidString))
        var selection = (UserDefaults.standard.string(forKey: "selectedHeroIDs") ?? "")
            .split(separator: ",").map(String.init)
            .filter { unlocked.contains($0) }
        if selection.isEmpty {
            selection = ((try? db.heroDao.getSelectedHeroIds()) ?? [])
                .map(\.uuidString)
                .filter { unlocked.contains($0) }
        }
        UserDefaults.standard.set(selection.joined(separator: ","),
                                  forKey: "selectedHeroIDs")
    }
}

fileprivate func heroUnlockMessage(_ hero: Hero) -> String? {
    if hero.fromMiniCampaign {
        return hero.unlockedAtCampaignName.map {
            $0.hasPrefix("The ")
                ? "Unlocked at the\n" + $0.dropFirst(4)
                : "Unlocked at\n" + $0
        }
    }
    return hero.unlockedAtLevelName.map { "Unlocked at\n\($0)" }
}

enum HeroSelection {
    static let maxSelected = 2
    private static let key = "selectedHeroIDs"

    static func ids() -> [String] {
        (UserDefaults.standard.string(forKey: key) ?? "")
            .split(separator: ",").map(String.init)
    }

    static func isSelected(_ hero: Hero) -> Bool {
        ids().contains(hero.id.uuidString)
    }

    static func toggle(_ hero: Hero) {
        guard hero.unlocked else { return }
        var current = ids()
        if let index = current.firstIndex(of: hero.id.uuidString) {
            current.remove(at: index)
        } else {
            current.append(hero.id.uuidString)
            while current.count > maxSelected {
                current.removeFirst()
            }
        }
        UserDefaults.standard.set(current.joined(separator: ","), forKey: key)
    }
}

@available(iOS 26.0, *)
private struct HeroSlot: View {
    let hero: Hero?
    let width: CGFloat
    let height: CGFloat
    let unlockFontSize: CGFloat
    let onSelect: (Hero) -> Void

    @AppStorage("selectedHeroIDs") private var selectedIDs = ""

    private var hasArt: Bool {
        guard let hero else { return false }
        return UIImage(named: hero.primaryImageName) != nil
    }

    private var isLocked: Bool {
        guard let hero else { return true }
        return !hero.unlocked || !hasArt
    }

    private var isSelected: Bool {
        guard let hero else { return false }
        return selectedIDs.split(separator: ",").map(String.init)
            .contains(hero.id.uuidString)
    }

    var body: some View {
        Group {
            if let hero {
                Button(action: { onSelect(hero) }) { slotContent }
                    .buttonStyle(HeroCardButtonStyle())
                    .accessibilityLabel(isLocked ? "\(hero.shortName), locked" : hero.shortName)
            } else {
                slotContent
                    .accessibilityLabel("Locked hero slot")
            }
        }
    }

    private var slotContent: some View {
        ZStack {
            if let hero {
                Group {
                    if hasArt {
                        Image(hero.primaryImageName)
                            .resizable()
                            .frame(width: width, height: width * 15 / 16)
                            .offset(y: height * 0.045)
                    } else {
                        lockedPanel
                            .frame(width: width, height: height)
                    }
                }
                .frame(width: width, height: height, alignment: .top)
                .clipped()

                VStack {
                    Spacer()
                    nameBar(hero.shortName)
                }

                if isLocked, hasArt {
                    Rectangle().fill(.black.opacity(0.468))
                    Image("tower_locked_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(width, height) * 0.27)
                        .offset(y: height * 0.03)
                }

                if isLocked {
                    VStack {
                        unlockRibbon(hero)
                        Spacer()
                    }
                }
            } else {
                lockedPanel
            }
        }
        .frame(width: width, height: height)
        .overlay(MusketSteelFrame(width: width, height: height))
        .overlay {
            if isSelected {
                let inset = height * 0.05
                Rectangle()
                    .strokeBorder(Self.shinyGold,
                                  lineWidth: max(2.5, height * 0.016))
                    .padding(inset)
                    .shadow(color: Self.goldGlow.opacity(0.85),
                            radius: height * 0.02)
                ZStack {
                    Circle().fill(Self.plateColor)
                    Circle().strokeBorder(Self.shinyGold,
                                          lineWidth: max(1.5, height * 0.01))
                    Image(systemName: "star.fill")
                        .font(.system(size: Typography.size(height * 0.085), weight: .bold))
                        .foregroundStyle(Self.shinyGoldStar)
                }
                .frame(width: height * 0.17, height: height * 0.17)
                .shadow(color: Self.goldGlow.opacity(0.9), radius: height * 0.025)
                .position(x: width - height * 0.15, y: height * 0.15)
            }
        }
        .contentShape(Rectangle())
    }

    private static let goldGlow = Color(red: 1.0, green: 0.84, blue: 0.3)

    private static let shinyGold = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.96, blue: 0.7),
            Color(red: 1.0, green: 0.83, blue: 0.25),
            Color(red: 0.72, green: 0.52, blue: 0.1),
            Color(red: 1.0, green: 0.88, blue: 0.42)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    private static let shinyGoldStar = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.98, blue: 0.82),
            Color(red: 1.0, green: 0.84, blue: 0.25),
            Color(red: 0.85, green: 0.6, blue: 0.12)
        ],
        startPoint: .top, endPoint: .bottom
    )

    private static let plateColor = Color(red: 8 / 255, green: 30 / 255, blue: 58 / 255)

    private func unlockRibbon(_ hero: Hero) -> some View {
        Group {
            if let message = heroUnlockMessage(hero) {
                Text(message)
                    .font(.custom("Cochin-Bold", size: unlockFontSize))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .white.opacity(0.65), radius: 0.4)
                    .shadow(color: .black.opacity(0.8), radius: 1.5, y: 1)
                    .padding(.horizontal, width * 0.04)
                    .padding(.top, height * 0.075)
            }
        }
    }

    private func nameBar(_ name: String) -> some View {
        Text(name)
            .font(.custom("Baskerville-SemiBold", size: height * 0.0946))
            .foregroundStyle(Color(red: 0.93, green: 0.87, blue: 0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.horizontal, width * 0.04)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, height * 0.038)
            .frame(height: height * 0.196)
            .background(Self.plateColor)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(red: 0.93, green: 0.87, blue: 0.72).opacity(0.8))
                    .frame(height: max(1.2, height * 0.007))
            }
    }

    private var lockedPanel: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.45))
            Image("tower_locked_icon")
                .resizable()
                .scaledToFit()
                .frame(width: min(width, height) * 0.4)
        }
    }

}

@available(iOS 26.0, *)
private struct MusketSteelFrame: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let thickness = height * 0.05

        ZStack {
            Image("steel_bar_h").resizable()
                .frame(width: width - 2 * thickness, height: thickness)
                .position(x: width / 2, y: thickness / 2)
            Image("steel_bar_h").resizable()
                .frame(width: width - 2 * thickness, height: thickness)
                .position(x: width / 2, y: height - thickness / 2)
            Image("steel_bar_v").resizable()
                .frame(width: thickness, height: height - 2 * thickness)
                .position(x: thickness / 2, y: height / 2)
            Image("steel_bar_v").resizable()
                .frame(width: thickness, height: height - 2 * thickness)
                .position(x: width - thickness / 2, y: height / 2)

            corner(rotation: 0, x: thickness / 2, y: thickness / 2)
            corner(rotation: 90, x: width - thickness / 2, y: thickness / 2)
            corner(rotation: 180, x: width - thickness / 2, y: height - thickness / 2)
            corner(rotation: 270, x: thickness / 2, y: height - thickness / 2)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    private func corner(rotation: Double, x: CGFloat, y: CGFloat) -> some View {
        let thickness = height * 0.05
        return Image("steel_corner")
            .resizable()
            .frame(width: thickness, height: thickness)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
    }
}

@available(iOS 26.0, *)
private struct HeroCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
            .animation(configuration.isPressed
                ? .easeOut(duration: 0.09)
                : .spring(response: 0.28, dampingFraction: 0.55),
                value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

@available(iOS 26.0, *)
struct HeroDetailsView: View {
    let db: Db
    let screen: ScreenGeometry
    let hero: Hero
    let onExit: () -> Void

    @AppStorage("selectedHeroIDs") private var selectedIDs = ""

    private var isSelected: Bool {
        selectedIDs.split(separator: ",").map(String.init)
            .contains(hero.id.uuidString)
    }

    var body: some View {
        let metrics = HudMetrics(screen: screen)
        ZStack(alignment: .topLeading) {
            ZStack {
                Image("hero_screen_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.physical.width, height: screen.physical.height)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.48),
                        .init(color: .black.opacity(0.34), location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                HStack(spacing: 36 * metrics.scale) {
                    Image(UIImage(named: hero.detailsImageName) != nil
                          ? hero.detailsImageName : hero.primaryImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 380 * metrics.scale)
                        .clipShape(RoundedRectangle(cornerRadius: 12 * metrics.scale))
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 4)

                    VStack(alignment: .leading, spacing: 14 * metrics.scale) {
                        Text(hero.longName)
                            .font(.custom("HoeflerText-Black", size: 39 * metrics.scale))
                            .foregroundStyle(Color(red: 0.93, green: 0.87, blue: 0.72))
                        Text(hero.generalDescription)
                            .font(.custom("HoeflerText-Regular", size: 23 * metrics.scale))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(hero.historicalText)
                            .font(.custom("HoeflerText-Regular", size: 19.5 * metrics.scale))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineSpacing(4 * metrics.scale)

                        if hero.unlocked {
                            Button {
                                HeroSelection.toggle(hero)
                                selectedIDs = UserDefaults.standard
                                    .string(forKey: "selectedHeroIDs") ?? ""
                                let ids = selectedIDs.split(separator: ",")
                                    .compactMap { UUID(uuidString: String($0)) }
                                try? db.heroDao.setSelectedHeroes(ids)
                            } label: {
                                Text(isSelected ? "Selected — tap to remove" : "Select Hero")
                                    .font(.custom("HoeflerText-Black", size: 20 * metrics.scale))
                                    .foregroundStyle(isSelected
                                        ? Color(red: 0.16, green: 0.12, blue: 0.05)
                                        : Color(red: 0.93, green: 0.87, blue: 0.72))
                                    .padding(.horizontal, 22 * metrics.scale)
                                    .padding(.vertical, 10 * metrics.scale)
                                    .background(isSelected
                                        ? Color(red: 0.87, green: 0.72, blue: 0.35)
                                        : Color(red: 8 / 255, green: 30 / 255, blue: 58 / 255))
                                    .clipShape(RoundedRectangle(cornerRadius: 8 * metrics.scale))
                                    .overlay(RoundedRectangle(cornerRadius: 8 * metrics.scale)
                                        .strokeBorder(Color(red: 0.87, green: 0.72, blue: 0.35),
                                                      lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 430 * metrics.scale, alignment: .leading)
                    .shadow(color: .black.opacity(0.8), radius: 1.5, y: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: screen.physical.width, height: screen.physical.height)

            DoneButton(action: onExit)
                .hudFrame(DoneButtonLayout(screen: screen,
                                           aspect: DoneButton.aspect).frame,
                          in: screen)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
    }
}
