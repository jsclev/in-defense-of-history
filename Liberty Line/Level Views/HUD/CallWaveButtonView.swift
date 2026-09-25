import SwiftUI

struct CallWaveButtonView: View {
    let layout: CallWaveButtonLayout
    let waveNumber: Int
    let countdownSeconds: Int?
    let seconds: Double
    var isSelected = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            icon.accessibilityHidden(true)
        }
        .buttonStyle(HUDButtonStyle())
        .accessibilityLabel(isSelected ? "Confirm call wave \(waveNumber)" : "Select wave \(waveNumber)")
        .accessibilityValue(countdownSeconds.map { "Starts automatically in \($0) seconds" }
                            ?? "Waiting for you to start")
        .accessibilityHint(isSelected ? "Activate to start this wave now" : "Activate to select, then activate again to call this wave")
        .position(x: layout.frame.midX, y: layout.frame.midY)
    }

    private var icon: some View {
        CallWaveArtwork(side: layout.frame.width, isSelected: isSelected)
        .scaleEffect(isSelected || reduceMotion ? 1 : 0.94 + 0.14 * (1 - cos(2 * .pi * seconds / 1.4)) / 2)
        .overlay(alignment: .bottomTrailing) {
            if let countdownSeconds {
                Text("\(countdownSeconds)s")
                    .font(.system(size: layout.countdownFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, layout.countdownHorizontalPadding)
                    .padding(.vertical, layout.countdownVerticalPadding)
                    .background(Capsule().fill(.black.opacity(0.85)))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Circle())
    }
}

/// The source contains both the horn and its rim. Reuse its pixels in two
/// display layers so adding interior space does not resize the outer frame.
struct CallWaveArtwork: View {
    let side: CGFloat
    var isSelected = false

    private var source: some View {
        Image(CallWaveButtonLayout.imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: side, height: side)
    }

    var body: some View {
        if isSelected {
            Image(CallWaveButtonLayout.confirmationImageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(Circle().inset(by: side * 0.006))
        } else {
            horn
        }
    }

    private var horn: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.75, green: 0.04, blue: 0.015),
                             Color(red: 0.30, green: 0, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(side * 0.04)
            source
                .mask(Circle().padding(side * 0.045))
                .scaleEffect(0.80)
            source
                .mask(Circle().strokeBorder(lineWidth: side * 0.055))
        }
        .frame(width: side, height: side)
    }
}
