import SwiftUI

@MainActor
struct PlaytestView: View {
    let session: SimSession
    let slotArt: TowerSlotImage
    var onAdopt: ([MapDraft.BuildStep]) -> Void

    var body: some View {
        TimelineView(.animation) { timeline in
            VStack(spacing: 0) {
                topBar
                ZStack {
                    PlaytestCanvas(session: session, slotArt: slotArt)
                    if let banner = session.banner {
                        Text(banner)
                            .font(.title2.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.6), in: Capsule())
                            .foregroundStyle(.white)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                            .padding(.top, 14)
                    }
                    if session.sim.outcome != nil {
                        reportCard
                    }
                }
                .background(Color(red: 0.07, green: 0.09, blue: 0.07))
                bottomBar
            }
            .onChange(of: timeline.date) { _, date in
                session.advance(to: date)
            }
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Label(session.blueprint.name, systemImage: "map")
                .font(.headline)

            Spacer()

            statPill("dollarsign.circle.fill", "\(session.sim.gold)",
                     session.goldDenied ? .red : .yellow)
            statPill("heart.fill", "\(session.sim.lives)", .red)
            statPill("flag.fill", "\(session.currentWave)/\(session.level.waves.count)", .cyan)
            statPill("clock.fill", String(format: "%.0fs", session.sim.time), .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func statPill(_ icon: String, _ text: String, _ color: Color) -> some View {
        Label {
            Text(text).monospacedDigit().fontWeight(.semibold)
        } icon: {
            Image(systemName: icon).foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.06), in: Capsule())
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Button {
                session.restart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Restart with the same seed")

            Button {
                session.paused.toggle()
            } label: {
                Image(systemName: session.paused ? "play.fill" : "pause.fill")
            }

            Button { session.sim.startNextWave() } label: {
                Image(systemName: "flag.fill")
            }
            .disabled(!session.sim.canStartWave)
            .help("Call the next wave")

            Picker("", selection: Binding(get: { session.speed }, set: { session.speed = $0 })) {
                ForEach([0.5, 1, 2, 4, 8], id: \.self) { s in
                    Text("\(s.formatted())×").tag(s)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Stepper {
                Text("Seed \(session.seed)").monospacedDigit().font(.callout)
            } onIncrement: {
                session.seed += 1
                session.restart()
            } onDecrement: {
                if session.seed > 0 { session.seed -= 1 }
                session.restart()
            }
            .fixedSize()

            Toggle(isOn: Binding(
                get: { session.autopilot },
                set: { session.autopilot = $0; session.restart() }
            )) {
                Text("Autopilot")
            }
            .toggleStyle(.switch)
            .fixedSize()
            .help("Play the intended solution")

            Button("Batch 100") {
                session.runQuickBatch()
            }
            .help("Run 100 headless seeds of the intended solution")

            if !session.recording.isEmpty, !session.autopilot {
                Button("Adopt Build (\(session.recording.count))") {
                    onAdopt(session.recording)
                }
                .help("Save this run's hand-built towers as the intended solution")
            }

            if let summary = session.batchSummary {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            buildPanel
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var buildPanel: some View {
        if let slot = session.selectedSlot {
            if let tower = session.tower(at: slot) {
                HStack(spacing: 10) {
                    Text("\(tower.name) L\(tower.level)").font(.callout.weight(.semibold))
                    ForEach(session.sim.upgradeOffers(at: slot), id: \.branch) { offer in
                        Button("Branch \(offer.branch) $\(offer.cost)") {
                            session.upgrade(slot: slot, branch: offer.branch)
                        }
                        .disabled(session.sim.gold < offer.cost)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text("Slot \(slot)").font(.callout.weight(.semibold))
                    ForEach(session.sim.buildOffers, id: \.kind) { offer in
                        Button {
                            session.build(offer.kind, at: slot)
                        } label: {
                            VStack(spacing: 1) {
                                Circle().fill(Palette.towerColors[offer.kind] ?? .white).frame(width: 12, height: 12)
                                Text(session.arsenal.type(offer.kind).name).font(.caption2)
                                Text("$\(offer.cost)").font(.caption2).monospacedDigit()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(session.sim.gold < offer.cost)
                    }
                }
            }
        } else {
            Text("Click a slot to build")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var reportCard: some View {
        let sim = session.sim
        let result = sim.result()
        let won = sim.outcome == .victory
        return VStack(spacing: 12) {
            Text(won ? "Victory" : (sim.outcome == .defeat ? "Defeat" : "Timeout"))
                .font(.largeTitle.weight(.black))
                .foregroundStyle(won ? .green : .red)
            Text(String(format: "%.0fs · %d lives left · %d gold banked",
                        sim.time, max(0, sim.lives), sim.gold))
                .foregroundStyle(.secondary)
            HStack(spacing: 18) {
                fateStat("Shot", result.killed, .blue)
                fateStat("Leaked", result.leaked, .red)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Tension — how far each wave pushed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(result.waveMaxProgress.enumerated()), id: \.offset) { i, v in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(v >= 0.999 ? Color.red : Color.cyan)
                                .frame(width: 18, height: max(3, 64 * v))
                            Text("\(i + 1)").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            HStack {
                Button("Run Again") { session.restart() }
                    .buttonStyle(.borderedProminent)
                Button("Next Seed") {
                    session.seed += 1
                    session.restart()
                }
                if !session.recording.isEmpty, !session.autopilot, won {
                    Button("Adopt Build (\(session.recording.count))") {
                        onAdopt(session.recording)
                    }
                }
            }
        }
        .padding(24)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15)))
    }

    private func fateStat(_ label: String, _ n: Int, _ color: Color) -> some View {
        VStack {
            Text("\(n)").font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
