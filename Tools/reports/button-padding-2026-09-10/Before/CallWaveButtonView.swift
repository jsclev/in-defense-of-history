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
        Image(CallWaveButtonLayout.imageName)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(width: layout.frame.width, height: layout.frame.height)
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
