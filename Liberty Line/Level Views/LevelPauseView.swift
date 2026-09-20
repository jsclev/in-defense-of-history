import SwiftUI

/// A modal over the current battlefield; every route keeps the level paused
/// until the player explicitly returns to it or starts a new attempt.
struct LevelPauseView: View {
    @EnvironmentObject private var settings: PlayerSettingsStore
    @State private var showingSettings = false
    @State private var settingsError: String?
    let runtimeCanvas: RuntimeCanvas
    let onResume: () -> Void
    let onRestart: () -> Void
    let onCampaign: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .contentShape(Rectangle())
                .onTapGesture { }
                .accessibilityHidden(true)

            if showingSettings {
                SettingsView(runtimeCanvas: runtimeCanvas) { showingSettings = false }
            } else {
                menu
                    .frame(width: min(420, runtimeCanvas.safeInsetsRect.width - 32))
                    .position(x: runtimeCanvas.safeInsetsRect.midX,
                              y: runtimeCanvas.safeInsetsRect.midY)
            }
        }
        .frame(width: runtimeCanvas.physicalRect.width, height: runtimeCanvas.physicalRect.height)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            if showingSettings { showingSettings = false } else { onResume() }
        }
        .alert("Unable to save settings", isPresented: Binding(
            get: { settingsError != nil }, set: { if !$0 { settingsError = nil } }
        )) { Button("OK", role: .cancel) { settingsError = nil } } message: {
            Text(settingsError ?? "")
        }
    }

    private var menu: some View {
        VStack(spacing: 12) {
            HStack {
                Image("pause_icon_glyph").resizable().scaledToFit()
                    .frame(width: 20, height: 25).accessibilityHidden(true)
                Text("PAUSED").font(.custom("Baskerville-Bold", size: 28))
                Spacer()
                Button { showingSettings = true } label: {
                    CampaignButtonArt(name: "main_menu_settings")
                        .frame(width: 40, height: 40).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("pause-settings")
            }

            Button(action: onResume) {
                HStack(spacing: 14) {
                    Image(systemName: "play.fill").font(.system(size: 30, weight: .bold))
                    Text("Return to level").font(.custom("Baskerville-Bold", size: 23))
                }
                .frame(maxWidth: .infinity).frame(height: 66)
                .background(Color(red: 0.09, green: 0.38, blue: 0.29), in: CouncilCutCorner())
                .overlay(CouncilCutCorner().stroke(CouncilPalette.gold, lineWidth: 2))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pause-resume")

            HStack(spacing: 12) {
                Button(action: onRestart) {
                    VStack(spacing: 5) {
                        CouncilGlyph(kind: .reset).frame(width: 29, height: 29)
                        Text("Restart level").font(.custom("Baskerville-Bold", size: 17))
                    }
                    .frame(maxWidth: .infinity).frame(height: 76)
                    .background(CouncilPanel()).contentShape(Rectangle())
                }
                .accessibilityIdentifier("pause-restart")

                Button(action: onCampaign) {
                    VStack(spacing: 5) {
                        Image(systemName: "map.fill").font(.system(size: 27, weight: .bold))
                        Text("Main campaign").font(.custom("Baskerville-Bold", size: 17))
                    }
                    .frame(maxWidth: .infinity).frame(height: 76)
                    .background(CouncilPanel()).contentShape(Rectangle())
                }
                .accessibilityLabel("Back to main campaign")
                .accessibilityIdentifier("pause-campaign")
            }
            .buttonStyle(.plain)

            Button {
                do { try settings.set(\.enemyEscapeHapticsEnabled, to: !settings.values.enemyEscapeHapticsEnabled) }
                catch { settingsError = error.localizedDescription }
            } label: {
                Image(systemName: settings.values.enemyEscapeHapticsEnabled
                      ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .font(.system(size: 23, weight: .bold))
                    .frame(width: 52, height: 44)
                    .foregroundStyle(settings.values.enemyEscapeHapticsEnabled
                                     ? CouncilPalette.gold : CouncilPalette.cream.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Life-loss haptics")
            .accessibilityValue(settings.values.enemyEscapeHapticsEnabled ? "On" : "Off")
            .accessibilityIdentifier("pause-haptics")
        }
        .foregroundStyle(CouncilPalette.cream)
        .padding(20)
        .background(CouncilPanel())
        .shadow(color: .black.opacity(0.55), radius: 16, y: 8)
    }
}
