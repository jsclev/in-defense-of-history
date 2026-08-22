import SwiftUI

@available(iOS 26.0, *)
struct LevelBriefingView: View {
    let db: Db
    let virtualCanvas: VirtualCanvas
    let screen: ScreenGeometry
    let node: CampaignNode
    let onStart: (Difficulty) -> Void

    @State private var difficulties: [Difficulty] = []
    @State private var selected: Difficulty?

    private static let ink = Color(red: 0.16, green: 0.12, blue: 0.08)
    private static let brass = Color(red: 0.87, green: 0.72, blue: 0.35)

    var body: some View {
        let metrics = HudMetrics(screen: screen)
        ZStack(alignment: .topLeading) {
            ZStack {
                Image("level_briefing_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.physicalRect.width,
                           height: screen.physicalRect.height)
                    .clipped()

                Color.black.opacity(0.55)

                HStack(spacing: 32 * metrics.scale) {
                    VStack(spacing: 14 * metrics.scale) {
                        Text(node.title)
                            .font(.custom("Baskerville-Bold",
                                          size: Typography.size(44 * metrics.scale)))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 3 * metrics.scale)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        levelPortrait(metrics: metrics)
                    }

                    difficultyGrid(metrics: metrics)
                }
                .padding(24 * metrics.scale)
            }
            .frame(width: screen.physicalRect.width, height: screen.physicalRect.height)

            DoneButton {
                if let selected {
                    onStart(selected)
                }
            }
            .disabled(selected == nil)
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: loadDifficulties)
    }

    /// Two cards per row: four difficulties stacked singly would overrun a
    /// phone's height, and one row of four crowds the portrait off center.
    /// Cards get their own scale floor — at the phone HUD scale the fixed
    /// card cannot hold three lines of floor-size text, truncating every
    /// difficulty description mid-sentence.
    private func difficultyGrid(metrics: HudMetrics) -> some View {
        let cardMetrics = HudMetrics(scale: max(metrics.scale, 0.92))
        let rows = stride(from: 0, to: difficulties.count, by: 2).map {
            Array(difficulties[$0..<min($0 + 2, difficulties.count)])
        }
        return Grid(horizontalSpacing: 12 * cardMetrics.scale,
                    verticalSpacing: 12 * cardMetrics.scale) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { difficulty in
                        DifficultyCard(
                            difficulty: difficulty,
                            isSelected: selected?.id == difficulty.id,
                            metrics: cardMetrics
                        ) {
                            selected = difficulty
                        }
                    }
                }
            }
        }
    }

    private func levelPortrait(metrics: HudMetrics) -> some View {
        let height = 260 * metrics.scale
        let aspect = virtualCanvas.playAreaRect.width / virtualCanvas.playAreaRect.height
        let frame = CGSize(width: height * aspect, height: height)
        let art = LevelMapArt(mapImageName: node.mapImageName)
        return ZStack {
            if art.hasArt {
                // The map exactly as the level screen composites it — same
                // compositor, same tiers, same projection rule — fitted to
                // this smaller frame instead of the screen.
                art.complete(in: LevelMapArt.projection(
                    virtualCanvas: virtualCanvas,
                    fitting: CGRect(origin: .zero, size: frame)))
            } else {
                Rectangle().fill(Self.ink.opacity(0.55))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: 10 * metrics.scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10 * metrics.scale, style: .continuous)
                .stroke(Self.brass.opacity(0.75), lineWidth: 2 * metrics.scale)
        )
        .shadow(color: .black.opacity(0.6), radius: 8 * metrics.scale, y: 4 * metrics.scale)
    }

    private func loadDifficulties() {
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
                    .font(.custom("Baskerville-Bold",
                                  size: Typography.size(22 * metrics.scale)))
                    .foregroundStyle(Self.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(difficulty.detail)
                    .font(.system(size: Typography.size(12 * metrics.scale)))
                    .foregroundStyle(Self.ink.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

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
