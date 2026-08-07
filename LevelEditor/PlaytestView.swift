// PlaytestView.swift
// Playtest mode: run the current draft in the design-lab simulation — hand
// play or autopilot, seeds, speed, quick batches, report card — and adopt a
// recorded hand-played run as the blueprint's intended solution.
import SwiftUI

@MainActor
struct PlaytestView: View {
    let session: SimSession
    var onAdopt: ([MapDraft.BuildStep]) -> Void

    var body: some View {
        TimelineView(.animation) { timeline in
            VStack(spacing: 0) {
                topBar
                ZStack {
                    PlaytestCanvas(session: session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let banner = session.banner {
                        Text(banner)
                            .font(.title2.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.6), in: Capsule())
                            .foregroundStyle(.white)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 14)
                    }
                    if session.sim.outcome != nil {
                        reportCard
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Top bar

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

    // MARK: - Bottom bar

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

            Picker("", selection: Binding(get: { session.speed }, set: { session.speed = $0 })) {
                ForEach([1, 2, 4, 8], id: \.self) { s in
                    Text("\(s)×").tag(s)
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
            if let (type, lvl) = session.towerType(at: slot) {
                HStack(spacing: 10) {
                    Text("\(type.name) L\(lvl + 1)")
                        .font(.callout.weight(.semibold))
                    if lvl + 1 < type.levels.count {
                        Button("Upgrade $\(type.levels[lvl + 1].cost)") {
                            session.upgrade(slot: slot)
                        }
                        .disabled(session.sim.gold < type.levels[lvl + 1].cost)
                    } else {
                        Text("Max").foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text("Slot \(slot)").font(.callout.weight(.semibold))
                    ForEach(Emplacement.allCases, id: \.self) { e in
                        let cost = DesignArsenal.type(e).levels[0].cost
                        Button {
                            session.build(e, at: slot)
                        } label: {
                            VStack(spacing: 1) {
                                Circle()
                                    .fill(Palette.towerColors[e] ?? .white)
                                    .frame(width: 12, height: 12)
                                Text(shortName(e)).font(.caption2)
                                Text("$\(cost)").font(.caption2).monospacedDigit()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(session.sim.gold < cost)
                    }
                }
            }
        } else {
            Text("Click a slot to build")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func shortName(_ e: Emplacement) -> String {
        switch e {
        case .minutemanPost: return "Minute"
        case .longRifles: return "Rifle"
        case .fieldBattery: return "Cannon"
        case .libertyPole: return "Liberty"
        }
    }

    // MARK: - Report

    private var reportCard: some View {
        let sim = session.sim
        let won = sim.outcome == .victory
        return VStack(spacing: 12) {
            Text(won ? "Victory" : (sim.outcome == .defeat ? "Defeat" : "Timeout"))
                .font(.largeTitle.weight(.black))
                .foregroundStyle(won ? .green : .red)
            Text(String(format: "%.0fs · %d lives left · %d gold banked",
                        sim.time, max(0, sim.lives), sim.gold))
                .foregroundStyle(.secondary)
            HStack(spacing: 18) {
                fateStat("Shot", sim.killed, .blue)
                fateStat("Routed", sim.routed, .purple)
                fateStat("Captured", sim.captured, .teal)
                fateStat("Leaked", sim.leaked, .red)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Tension — how far each wave pushed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(sim.waveMaxProgress.enumerated()), id: \.offset) { i, v in
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
