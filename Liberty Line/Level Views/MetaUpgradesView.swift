import SwiftUI

/// A full campaign tree with inspectable nodes and a nearby purchase/refund panel.
struct MetaUpgradesView: View {
    @ObservedObject var upgrades: MetaUpgradeStore
    let runtimeCanvas: RuntimeCanvas
    let onExit: () -> Void
    @State private var focusedID: MetaUpgrade = .crossfire
    @State private var historicalUpgrade: MetaUpgradeDefinition?
    private var catalog: MetaUpgradeCatalog { upgrades.loadout.catalog }
    private var focused: MetaUpgradeDefinition { catalog[focusedID] }

    private let gold = CouncilPalette.gold
    private let cream = CouncilPalette.cream

    var body: some View {
        let safe = runtimeCanvas.safeInsetsRect.insetBy(dx: 12, dy: 6)
        ZStack(alignment: .topLeading) {
            Image(uiImage: CampaignButtonArt.requiredImage(named: "meta_council_background"))
                .resizable().scaledToFill()
                .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)
                .clipped()
            VStack(spacing: 8) {
                header
                HStack(alignment: .top, spacing: 12) {
                    tree.frame(maxWidth: .infinity, maxHeight: .infinity)
                    inspector.frame(width: max(210, min(280, safe.width * 0.32)))
                }.frame(maxHeight: .infinity)
                footer
            }
            .frame(width: safe.width, height: safe.height)
            .position(x: safe.midX, y: safe.midY)
        }
        .foregroundStyle(cream)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onAppear { update { try upgrades.reload() } }
        .sheet(item: $historicalUpgrade) { upgrade in
            MetaUpgradeHistoryView(upgrade: upgrade)
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .init("MetaUpgradeFocusReview"))) { notification in
            if let id = notification.object as? MetaUpgrade { focusedID = id }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("MetaUpgradeHistoryReview"))) { notification in
            // Device review presents the production sheet through the same state as the info button.
            if let id = notification.object as? MetaUpgrade {
                focusedID = id
                historicalUpgrade = catalog[id]
            } else { historicalUpgrade = nil }
        }
        #endif
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("WAR COUNCIL").font(.custom("Baskerville-Bold", size: 27))
            Text("\(upgrades.loadout.selected.count)/\(catalog.upgrades.count) learned")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(cream.opacity(0.75))
            Spacer(minLength: 0)
            CouncilGlyph(kind: .star).frame(width: 26, height: 26)
            Text("\(upgrades.loadout.availableStars)")
                .font(.custom("Baskerville-Bold", size: 27))
            Text("AVAILABLE\n\(upgrades.loadout.starBudget) total")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(cream.opacity(0.75))
        }
        .padding(.horizontal, 10).frame(height: 38)
        .background(CouncilPalette.ink.opacity(0.82), in: CouncilCutCorner())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("War Council. \(upgrades.loadout.selected.count) of \(catalog.upgrades.count) upgrades learned. \(upgrades.loadout.availableStars) of \(upgrades.loadout.starBudget) stars available.")
    }

    private var tree: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(catalog.tracks) { track in
                    VStack(spacing: 0) {
                        Text(track.shortTitle)
                            .font(.custom("Baskerville-Bold", size: 11))
                            .frame(width: 64, height: 24)
                        ForEach(catalog.upgrades(in: track.id)) { upgrade in
                            if upgrade.tier > 1 {
                                Rectangle()
                                    .fill(upgrades.loadout.selected.contains(upgrade.id) ? gold : cream.opacity(0.17))
                                    .frame(width: 3, height: 9)
                                    .accessibilityHidden(true)
                            }
                            node(upgrade)
                        }
                    }
                    .padding(.vertical, 9)
                    .background(CouncilPanel())
                }
            }.padding(6)
        }
        .defaultScrollAnchor(.center, for: .alignment)
    }

    private func node(_ upgrade: MetaUpgradeDefinition) -> some View {
        let learned = upgrades.loadout.selected.contains(upgrade.id)
        let isFocused = focusedID == upgrade.id
        let locked: Bool = if case .prerequisite = upgrades.loadout.availability(of: upgrade.id) { true } else { false }
        return Button { focusedID = upgrade.id } label: {
            CouncilNodeArt(upgrade: upgrade, learned: learned, locked: locked, focused: isFocused)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meta-node-\(upgrade.id.rawValue)")
        .accessibilityLabel(upgrade.title)
        .accessibilityValue(learned ? "Learned" : locked ? "Prerequisite required" : "\(upgrade.cost) stars")
        .accessibilityHint("Inspect the effect and purchase or refund this upgrade.")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MetaUpgradeIcon(upgrade: focused).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(catalog[focused.track].title.uppercased())
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(gold)
                    Text(focused.title).font(.custom("Baskerville-Bold", size: 23))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 4) {
                        Text(focused.detail).font(.system(size: 14))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { historicalUpgrade = focused } label: {
                            CampaignButtonArt(name: "main_menu_encyclopedia")
                                .frame(width: 36, height: 36).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("meta-history-info")
                        .accessibilityLabel("Historical background for \(focused.title)")
                        .accessibilityHint("Shows more information and the historical source.")
                    }
                    Text(statusText).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(gold)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(action: applySelection) {
                CouncilButtonLabel(title: actionTitle,
                    glyph: upgrades.loadout.selected.contains(focused.id) ? .reset : .star)
                    .saturation(actionEnabled ? 1 : 0).opacity(actionEnabled ? 1 : 0.55)
            }
            .buttonStyle(.plain)
            .disabled(!actionEnabled)
            .accessibilityIdentifier("meta-purchase-refund")
        }
        .padding(15)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(CouncilPanel())
    }

    private var statusText: String {
        switch upgrades.loadout.availability(of: focused.id) {
        case .selected:
            let dependents = upgrades.loadout.refunding(focused.id).count - 1
            return dependents == 0 ? "Learned · active in your next battle."
                : "Learned · refund also removes \(dependents) later upgrade\(dependents == 1 ? "" : "s") in this track."
        case .available: return "\(focused.cost) stars · applies to your next battle."
        case .prerequisite(let prerequisite): return "Learn \(catalog[prerequisite].title) first."
        case .insufficientStars: return "Needs \(focused.cost) stars. Refund another upgrade to reassign its stars."
        }
    }
    private var actionTitle: String {
        if upgrades.loadout.selected.contains(focused.id) {
            return "Refund \(upgrades.loadout.refunding(focused.id).reduce(0) { $0 + catalog[$1].cost }) stars"
        }
        return "Learn · \(focused.cost) stars"
    }
    private var actionEnabled: Bool {
        let state = upgrades.loadout.availability(of: focused.id)
        return state == .available || state == .selected
    }
    private func applySelection() {
        update {
            if upgrades.loadout.selected.contains(focused.id) { try upgrades.refund(focused.id) }
            else { try upgrades.purchase(focused.id) }
        }
    }
    private func update(_ action: () throws -> Void) {
        do { try action() }
        catch { fatalError("Meta upgrade database error: \(error)") }
    }
    private var footer: some View {
        HStack(spacing: 12) {
            Button { update { try upgrades.reset() } } label: {
                CouncilButtonLabel(title: "Reset", glyph: .reset).fixedSize(horizontal: true, vertical: false)
            }.accessibilityIdentifier("meta-reset")
            Button { update { try upgrades.restoreLevel15() } } label: {
                CouncilButtonLabel(title: "Level 15 preset", glyph: .flag).fixedSize(horizontal: true, vertical: false)
            }.accessibilityIdentifier("meta-preset")
            Spacer(minLength: 0)
            Text("Free respec · preset restored on relaunch")
                .font(.system(size: 10)).foregroundStyle(cream.opacity(0.6))
            Button(action: onExit) {
                CouncilButtonLabel(title: "Done", glyph: .check).fixedSize(horizontal: true, vertical: false)
            }.accessibilityIdentifier("meta-done")
        }
        .font(.system(size: 13, weight: .semibold))
        .buttonStyle(.plain)
        .foregroundStyle(gold)
        .frame(height: 44)
    }

}


/// History remains separate from the gameplay description, both supplied by the DAO.
struct MetaUpgradeHistoryView: View {
    let upgrade: MetaUpgradeDefinition
    @Environment(\.dismiss) private var dismiss
    private let gold = CouncilPalette.gold
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                MetaUpgradeIcon(upgrade: upgrade).frame(width: 44, height: 44)
                Text(upgrade.title).font(.custom("Baskerville-Bold", size: 25))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button { dismiss() } label: {
                    CouncilGlyph(kind: .close).padding(13).frame(width: 44, height: 44)
                        .background(CouncilPanel())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("meta-history-close")
                .accessibilityLabel("Close historical background")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(upgrade.historicalInformation)
                        .font(.system(size: 17)).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("meta-history-text")
                    Link(destination: upgrade.sourceURL) {
                        HStack(spacing: 10) {
                            CouncilGlyph(kind: .link).frame(width: 22, height: 22)
                            Text(upgrade.sourceTitle).font(.custom("Baskerville-Bold", size: 17))
                                .fixedSize(horizontal: false, vertical: true)
                        }.padding(12).frame(minHeight: 44, alignment: .leading)
                            .background(CouncilPanel())
                    }
                    .foregroundStyle(gold)
                    .accessibilityIdentifier("meta-history-source")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .foregroundStyle(CouncilPalette.cream)
        .background(CouncilPanel())
        .presentationBackground(CouncilPalette.ink)
    }
}
