import CoreHaptics
import Foundation

/// Stable numbers for the temporary, on-device comparison. These are custom
/// signals; their names describe intent, not verified perceptual effects.
public enum HapticAuditionSample: Int, CaseIterable, Identifiable, Sendable {
    case buildReference = 1, sharpTap, heavyThud, softTap, roundedThump
    case quietBuzz, heavyBuzz, escapeReference, longRumble, crispBuzz
    case softDouble, hardDouble, tripleKnock, accelerating, slowing
    case doubleRumble, rattle, fadingRumble, risingRumble, impactAndTail

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .buildReference: return "Original build double tap"
        case .sharpTap: return "Sharp crack"
        case .heavyThud: return "Heavy thud"
        case .softTap: return "Soft tap"
        case .roundedThump: return "Rounded thump"
        case .quietBuzz: return "Quiet buzz · 80ms"
        case .heavyBuzz: return "Heavy buzz · 140ms"
        case .escapeReference: return "Previous escape rumble · 280ms"
        case .longRumble: return "Long low rumble · 450ms"
        case .crispBuzz: return "Crisp buzz · 200ms"
        case .softDouble: return "Two soft taps · 120ms apart"
        case .hardDouble: return "Two hard knocks · 180ms apart"
        case .tripleKnock: return "Three even knocks"
        case .accelerating: return "Accelerating taps"
        case .slowing: return "Slowing taps"
        case .doubleRumble: return "Two short rumbles"
        case .rattle: return "Five-part rattle"
        case .fadingRumble: return "Fading rumble · 400ms"
        case .risingRumble: return "Rising rumble · 400ms"
        case .impactAndTail: return "Sharp impact with a low tail"
        }
    }

    public func makePattern() throws -> CHHapticPattern {
        switch self {
        // Freeze the historical references so gameplay choices cannot change
        // their names, numbers, or feel in a future comparison.
        case .buildReference:
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.7),
                    .init(parameterID: .hapticSharpness, value: 0.45),
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: 0.8),
                ], relativeTime: 0.055),
            ], parameters: [])
        case .escapeReference:
            return try CHHapticPattern(events: [Self.continuous(at: 0, duration: 0.28,
                                                                intensity: 0.8, sharpness: 0.12)],
                parameterCurves: [CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                    controlPoints: [.init(relativeTime: 0, value: 0),
                                    .init(relativeTime: 0.015, value: 1),
                                    .init(relativeTime: 0.1, value: 0.85),
                                    .init(relativeTime: 0.28, value: 0)], relativeTime: 0)])
        case .sharpTap: return try Self.taps([0], intensity: [0.9], sharpness: 1)
        case .heavyThud: return try Self.taps([0], intensity: [1], sharpness: 0.2)
        case .softTap: return try Self.taps([0], intensity: [0.35], sharpness: 0.05)
        case .roundedThump: return try Self.taps([0], intensity: [0.75], sharpness: 0.1)
        case .quietBuzz: return try Self.buzz(duration: 0.08, intensity: 0.45, sharpness: 0.15)
        case .heavyBuzz: return try Self.buzz(duration: 0.14, intensity: 0.85, sharpness: 0.15)
        case .longRumble: return try Self.buzz(duration: 0.45, intensity: 0.85, sharpness: 0.08)
        case .crispBuzz: return try Self.buzz(duration: 0.2, intensity: 0.7, sharpness: 0.9)
        case .softDouble: return try Self.taps([0, 0.12], intensity: [0.7, 0.7], sharpness: 0.1)
        case .hardDouble: return try Self.taps([0, 0.18], intensity: [0.9, 0.9], sharpness: 0.85)
        case .tripleKnock: return try Self.taps([0, 0.12, 0.24], intensity: [0.8, 0.8, 0.8], sharpness: 0.7)
        case .accelerating: return try Self.taps([0, 0.18, 0.28], intensity: [0.5, 0.7, 0.9], sharpness: 0.6)
        case .slowing: return try Self.taps([0, 0.08, 0.26], intensity: [0.9, 0.7, 0.5], sharpness: 0.6)
        case .doubleRumble:
            return try CHHapticPattern(events: [0.0, 0.24].map {
                Self.continuous(at: $0, duration: 0.12, intensity: 0.8, sharpness: 0.15)
            }, parameters: [])
        case .rattle:
            return try CHHapticPattern(events: (0..<5).map {
                Self.continuous(at: Double($0) * 0.07, duration: 0.035, intensity: 0.8, sharpness: 0.55)
            }, parameters: [])
        case .fadingRumble, .risingRumble:
            let points: [CHHapticParameterCurve.ControlPoint] = self == .fadingRumble
                ? [.init(relativeTime: 0, value: 1), .init(relativeTime: 0.4, value: 0)]
                : [.init(relativeTime: 0, value: 0.1), .init(relativeTime: 0.35, value: 1),
                   .init(relativeTime: 0.4, value: 0)]
            return try CHHapticPattern(events: [Self.continuous(at: 0, duration: 0.4, intensity: 0.9, sharpness: 0.2)],
                                      parameterCurves: [CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                                                              controlPoints: points, relativeTime: 0)])
        case .impactAndTail:
            return try CHHapticPattern(events: [
                Self.transient(at: 0, intensity: 1, sharpness: 0.85),
                Self.continuous(at: 0.03, duration: 0.27, intensity: 0.7, sharpness: 0.08),
            ], parameterCurves: [CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                controlPoints: [.init(relativeTime: 0, value: 1), .init(relativeTime: 0.08, value: 0.8),
                                .init(relativeTime: 0.3, value: 0)], relativeTime: 0)])
        }
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: intensity),
            .init(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: 0.08)
    }

    private static func continuous(at time: TimeInterval, duration: TimeInterval,
                                   intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: intensity),
            .init(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private static func taps(_ starts: [TimeInterval], intensity: [Float], sharpness: Float) throws -> CHHapticPattern {
        try CHHapticPattern(events: zip(starts, intensity).map {
            transient(at: $0.0, intensity: $0.1, sharpness: sharpness)
        }, parameters: [])
    }

    private static func buzz(duration: TimeInterval, intensity: Float, sharpness: Float) throws -> CHHapticPattern {
        try CHHapticPattern(events: [continuous(at: 0, duration: duration, intensity: intensity, sharpness: sharpness)],
                            parameters: [])
    }
}
