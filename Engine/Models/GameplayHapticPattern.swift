import CoreHaptics
import Foundation

/// Patterns selected from the on-device audition: a build thuds; a loss rumbles.
public enum GameplayHapticPattern: CaseIterable {
    case build
    case lifeLoss
    case defeat

    public var events: [CHHapticEvent] {
        switch self {
        case .build:
            // Audition #3, "Heavy thud", with a slightly firmer attack. Intensity
            // is already at its maximum; sharpness adds definition to the impact.
            return [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 1),
                    .init(parameterID: .hapticSharpness, value: 0.35),
                ], relativeTime: 0, duration: 0.08),
            ]
        case .lifeLoss:
            // Audition #9, "Long low rumble", shortened from 450 to 400 ms.
            return [CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.85),
                .init(parameterID: .hapticSharpness, value: 0.08),
            ], relativeTime: 0, duration: 0.4)]
        case .defeat:
            // Preserve the separate final-life signal.
            let starts: [TimeInterval] = [0, 0.4]
            return starts.map { start in
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.8),
                    .init(parameterID: .hapticSharpness, value: 0.12),
                ], relativeTime: start, duration: 0.28)
            }
        }
    }

    public var duration: TimeInterval {
        events.map { $0.relativeTime + $0.duration }.max() ?? 0
    }

    public func makePattern() throws -> CHHapticPattern {
        let events = events
        guard self == .defeat else {
            return try CHHapticPattern(events: events, parameters: [])
        }
        // A rounded onset followed by a fade, rather than another pair of taps.
        let points = events.flatMap { event in
            [CHHapticParameterCurve.ControlPoint(relativeTime: event.relativeTime, value: 0),
             .init(relativeTime: event.relativeTime + 0.015, value: 1),
             .init(relativeTime: event.relativeTime + 0.10, value: 0.85),
             .init(relativeTime: event.relativeTime + event.duration, value: 0)]
        }
        let envelope = CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                              controlPoints: points, relativeTime: 0)
        return try CHHapticPattern(events: events, parameterCurves: [envelope])
    }
}
