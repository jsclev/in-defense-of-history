import SwiftUI

struct CallWaveButtonView: View {
    let layout: CallWaveButtonLayout
    let waveNumber: Int
    let countdownSeconds: Int?
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        icon
        .onTapGesture(count: 2, perform: action)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Call wave \(waveNumber)")
        .accessibilityValue(countdownSeconds.map { "Starts automatically in \($0) seconds" }
                            ?? "Waiting for you to start")
        .accessibilityAction { action() }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .position(x: layout.frame.midX, y: layout.frame.midY)
    }

    private var icon: some View {
        CallWaveArtwork(side: layout.frame.width)
        .scaleEffect(isPulsing ? 1.08 : 0.94)
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

    private var source: some View {
        Image(CallWaveButtonLayout.imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: side, height: side)
    }

    var body: some View {
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
