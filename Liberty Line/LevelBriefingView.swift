import SwiftUI

@available(iOS 26.0, *)
struct LevelBriefingView: View {
    let node: CampaignNode
    let onStart: (Difficulty) -> Void

    @State private var difficulties: [Difficulty] = []
    @State private var selected: Difficulty?

    private static let ink = Color(red: 0.16, green: 0.12, blue: 0.08)
    private static let brass = Color(red: 0.87, green: 0.72, blue: 0.35)

    var body: some View {
        GeometryReader { geometry in
            let screen = ScreenGeometry(proxy: geometry)
            let metrics = HudMetrics(viewSize: geometry.size)
            ZStack(alignment: .topLeading) {
                Image("hero_screen_background")
                    .resizable()
                    .frame(width: screen.physical.size.width,
                           height: screen.physical.size.height)
                    .ignoresSafeArea()

                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(spacing: 16 * metrics.scale) {
                    Text(node.title)
                        .font(.custom("Baskerville-Bold", size: 44 * metrics.scale))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 3 * metrics.scale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    levelPortrait(metrics: metrics)

                    HStack(spacing: 12 * metrics.scale) {
                        ForEach(difficulties) { difficulty in
                            DifficultyCard(
                                difficulty: difficulty,
                                isSelected: selected?.id == difficulty.id,
                                metrics: metrics
                            ) {
                                selected = difficulty
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24 * metrics.scale)

                DoneButton {
                    if let selected {
                        onStart(selected)
                    }
                }
                .disabled(selected == nil)
                .hudFrame(DoneButtonLayout(screen: screen,
                                           aspect: DoneButton.aspect).frame,
                          in: screen)
                .ignoresSafeArea()
            }
        }
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: loadDifficulties)
    }

    private func levelPortrait(metrics: HudMetrics) -> some View {
        let height = 190 * metrics.scale
        return ZStack {
            if node.mapImageName.isEmpty {
                Rectangle().fill(Self.ink.opacity(0.55))
            } else {
                Image(node.mapImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: height * 16 / 9, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10 * metrics.scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10 * metrics.scale, style: .continuous)
                .stroke(Self.brass.opacity(0.75), lineWidth: 2 * metrics.scale)
        )
        .shadow(color: .black.opacity(0.6), radius: 8 * metrics.scale, y: 4 * metrics.scale)
    }

    private func loadDifficulties() {
        let db = Db(
            dbPath: Db.getAbsolutePathToDb(dbFilename: "in_defense_of_history", fullRefresh: true),
            fullRefresh: true
        )
        difficulties = (try? db.difficultyDao.getAll()) ?? []
        if selected == nil {
            selected = (try? db.difficultyDao.getSelected()) ?? difficulties.last
        }
    }
}

@available(iOS 26.0, *)
private struct DifficultyCard: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let metrics: HudMetrics
    let action: () -> Void

    private static let parchment = Color(red: 0.90, green: 0.84, blue: 0.71)
    private static let ink = Color(red: 0.16, green: 0.12, blue: 0.08)
    private static let brass = Color(red: 0.87, green: 0.72, blue: 0.35)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6 * metrics.scale) {
                Text(difficulty.name)
                    .font(.custom("Baskerville-Bold", size: 22 * metrics.scale))
                    .foregroundStyle(Self.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(difficulty.detail)
                    .font(.system(size: Typography.size(12 * metrics.scale)))
                    .foregroundStyle(Self.ink.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxHeight: .infinity, alignment: .top)

                Text("Enemy HP \(Self.percentText(difficulty.enemyHPMultiplier))")
                    .font(.system(size: Typography.size(12 * metrics.scale), weight: .bold))
                    .foregroundStyle(Self.ink.opacity(0.9))
                    .monospacedDigit()
            }
            .padding(12 * metrics.scale)
            .frame(width: 160 * metrics.scale, height: 150 * metrics.scale)
            .background(Self.parchment,
                        in: RoundedRectangle(cornerRadius: 10 * metrics.scale, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10 * metrics.scale, style: .continuous)
                    .stroke(isSelected ? Self.brass : Self.ink.opacity(0.35),
                            lineWidth: (isSelected ? 4 : 1.5) * metrics.scale)
            )
            .shadow(color: .black.opacity(isSelected ? 0.7 : 0.35),
                    radius: (isSelected ? 10 : 4) * metrics.scale,
                    y: 3 * metrics.scale)
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func percentText(_ multiplier: Double) -> String {
        "\(Int((multiplier * 100).rounded()))%"
    }
}
