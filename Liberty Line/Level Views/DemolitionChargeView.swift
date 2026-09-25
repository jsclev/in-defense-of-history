import SwiftUI

/// One continuous charge-up bar beneath the tower; no visible timer text.
struct DemolitionTowerView: View {
    let assetName: String
    let charge: DemolitionCharge
    let height: CGFloat
    var virtualSeconds: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearedAt = Date()

    static let pulsePeriod = 1.4
    static let pulseScaleAmplitude: CGFloat = 0.12

    /// Size this emplacement from the slot footprint rather than the smaller
    /// generic artillery height. The exported artwork has tight alpha bounds.
    static func artworkHeight(slotWidth: CGFloat, assetName: String) -> CGFloat {
        guard let image = UIImage(named: assetName), image.size.width > 0 else { return slotWidth }
        return slotWidth * image.size.height / image.size.width
    }

    static func readinessPulse(at elapsed: TimeInterval) -> Double {
        (1 - cos(2 * .pi * max(0, elapsed) / pulsePeriod)) / 2
    }

    var body: some View {
        Group {
            if let virtualSeconds {
                artwork(readinessPulse: reduceMotion ? 1 : Self.readinessPulse(at: virtualSeconds))
            } else if charge.isReadyForPlacement {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                    paused: reduceMotion || scenePhase != .active)) { context in
                    artwork(readinessPulse: reduceMotion ? 1 : Self.readinessPulse(
                        at: context.date.timeIntervalSince(appearedAt)))
                }
            } else {
                artwork(readinessPulse: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(charge.isReadyForPlacement ? "Charge ready to place"
            : charge.isReady ? "Charge ready" : "Preparing, \(Int(ceil(charge.remainingSeconds))) seconds")
        .allowsHitTesting(false)
    }

    /// The shared production artwork also supplies deterministic native motion
    /// frames to the readability review. The tower's base stays anchored.
    func artwork(readinessPulse: Double) -> some View {
        Image(assetName).resizable().scaledToFit().frame(height: height)
            .scaleEffect(charge.isReadyForPlacement ? 1 + Self.pulseScaleAmplitude * readinessPulse : 1,
                         anchor: .bottom)
            .brightness(charge.isReadyForPlacement ? 0.15 * readinessPulse : 0)
            .overlay(alignment: .bottom) {
                if !charge.isReady {
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black)
                        Capsule().fill(Color(red: 0.15, green: 0.9, blue: 0.3))
                            .frame(width: 28 * charge.progress)
                    }
                    .frame(width: 28, height: 4)
                    .padding(1)
                    .background(.black, in: Capsule())
                    .offset(y: 8)
                }
            }
    }
}

/// A broad keg silhouette: no tiny fuse sparks, fragments or decoration carry state.
struct PowderKegSymbol: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.20)
                    .fill(Color(red: 0.78, green: 0.39, blue: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: w * 0.20)
                        .stroke(Color(red: 0.12, green: 0.16, blue: 0.20), lineWidth: w * 0.09))
                RoundedRectangle(cornerRadius: w * 0.10)
                    .fill(Color(red: 1.0, green: 0.71, blue: 0.31))
                    .frame(width: w * 0.28, height: h * 0.81).offset(x: -w * 0.13)
                VStack {
                    Capsule().fill(Color(red: 0.15, green: 0.21, blue: 0.28))
                        .frame(height: h * 0.13)
                    Spacer(minLength: 0)
                    Capsule().fill(Color(red: 0.15, green: 0.21, blue: 0.28))
                        .frame(height: h * 0.13)
                }
                .frame(height: h * 0.65)
                .padding(.horizontal, w * 0.015)
                VStack {
                    Ellipse().fill(Color(red: 0.98, green: 0.69, blue: 0.33))
                        .frame(height: h * 0.18)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, w * 0.13).padding(.top, h * 0.03)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The ground prop appears only when a complete charge is available.
struct DemolitionSiteView: View {
    let charge: DemolitionCharge
    let radius: CGFloat
    let showBlastRadius: Bool
    var virtualSeconds: Double? = nil
    static let kegLift: CGFloat = 8

    var body: some View {
        ZStack {
            if showBlastRadius && charge.position != nil {
                Circle().fill(Color.orange.opacity(0.12))
                    .overlay(Circle().stroke(Color.orange, lineWidth: 2))
                    .frame(width: radius * 2, height: radius * 2)
                    .allowsHitTesting(false)
            }
            if charge.isReady && charge.position != nil {
                DemolitionReadyChargeView(virtualSeconds: virtualSeconds)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Armed demolition charge")
                    .accessibilityHint("Automatically explodes before an enemy leaves its blast area")
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fixed point sizes keep the ready marker readable on the smallest phone layout.
struct DemolitionGroundChargeSymbol: View {
    let lightIsOn: Bool
    static let lightDiameter: CGFloat = 12
    static let blinkPeriod = 0.9
    static let lightOnDuration = 0.55

    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.45)).frame(width: 27, height: 12)
            PowderKegSymbol().frame(width: 18, height: 22)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(lightIsOn ? Color(red: 1, green: 0.09, blue: 0.13)
                                       : Color(red: 0.28, green: 0.035, blue: 0.045))
                        .overlay(Circle().stroke(Color(red: 0.08, green: 0.10, blue: 0.13), lineWidth: 1.2))
                        .frame(width: Self.lightDiameter, height: Self.lightDiameter)
                        .padding(.top, 1).padding(.trailing, -2)
                }
                .offset(y: -DemolitionSiteView.kegLift)
        }
        .frame(width: 32, height: 40)
        .accessibilityHidden(true)
    }
}

private struct DemolitionReadyChargeView: View {
    var virtualSeconds: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appearedAt = Date()

    var body: some View {
        if let virtualSeconds {
            symbol(at: virtualSeconds)
        } else {
            TimelineView(.animation(minimumInterval: 0.1, paused: reduceMotion || scenePhase != .active)) { context in
                symbol(at: max(0, context.date.timeIntervalSince(appearedAt)))
            }
        }
    }

    private func symbol(at seconds: Double) -> some View {
        DemolitionGroundChargeSymbol(lightIsOn: reduceMotion
            || seconds.truncatingRemainder(dividingBy: DemolitionGroundChargeSymbol.blinkPeriod)
                < DemolitionGroundChargeSymbol.lightOnDuration)
    }
}
