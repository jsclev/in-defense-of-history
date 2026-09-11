import Combine
import CoreHaptics
import Foundation

@MainActor
protocol HapticAuditionPlayback: AnyObject {
    /// Returns only after the actual pattern player finishes.
    func play(_ sample: HapticAuditionSample) async throws
    func stop()
}

@MainActor
public final class HapticAuditionPlayer: ObservableObject {
    /// Retained for future comparisons; enables both the panel and launch audition.
    public nonisolated static let enabled = false
    public static let gap: Duration = .milliseconds(1250)

    @Published public private(set) var current: HapticAuditionSample?
    @Published public private(set) var isRunning = false
    @Published public private(set) var status = "Waiting for the main screen"

    private let playback: any HapticAuditionPlayback
    private let pause: (Duration) async throws -> Void
    private let isEnabled: Bool
    private var isActive = false
    private var hasAutoStarted = false
    private var task: Task<Void, Never>?
    private var runID: UUID?

    public convenience init() {
        self.init(playback: CoreHapticAuditionPlayback(), pause: { try await Task.sleep(for: $0) })
    }

    init(playback: any HapticAuditionPlayback, isEnabled: Bool = HapticAuditionPlayer.enabled,
         pause: @escaping (Duration) async throws -> Void) {
        self.playback = playback
        self.isEnabled = isEnabled
        self.pause = pause
    }

    public func setActive(_ active: Bool) {
        isActive = active
        guard active else { stop(); return }
        guard isEnabled, !hasAutoStarted else { return }
        hasAutoStarted = true
        playAll()
    }

    public func playAll() { play(HapticAuditionSample.allCases) }
    public func replay(_ sample: HapticAuditionSample) { play([sample]) }

    public func stop() {
        runID = nil
        task?.cancel()
        task = nil
        playback.stop()
        if isRunning { status = "Stopped" }
        isRunning = false
    }

    private func play(_ samples: [HapticAuditionSample]) {
        guard isActive else { return }
        stop()
        let id = UUID()
        runID = id
        isRunning = true
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for (index, sample) in samples.enumerated() {
                    try Task.checkCancellation()
                    current = sample
                    status = "Playing"
                    await Task.yield()
                    try Task.checkCancellation()
                    try await playback.play(sample)
                    try Task.checkCancellation()
                    if index < samples.count - 1 {
                        status = "1.25-second pause"
                        try await pause(Self.gap)
                    }
                }
                guard runID == id else { return }
                status = samples.count == 1 ? "Finished #\(samples[0].id)" : "Finished all 20 · Choose one to replay"
            } catch {
                guard runID == id else { return }
                status = error is CancellationError ? "Stopped" : error.localizedDescription
            }
            guard runID == id else { return }
            isRunning = false
            runID = nil
            task = nil
            playback.stop()
        }
    }
}

@MainActor
private final class CoreHapticAuditionPlayback: HapticAuditionPlayback {
    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?
    private var completion: CheckedContinuation<Void, Error>?
    private var playbackID: UUID?

    enum Failure: LocalizedError {
        case unsupported, interrupted
        var errorDescription: String? {
            switch self {
            case .unsupported: return "Custom haptics unavailable on this device"
            case .interrupted: return "Playback interrupted · Replay when ready"
            }
        }
    }

    func play(_ sample: HapticAuditionSample) async throws {
        try Task.checkCancellation()
        let engine = try prepareEngine()
        try await engine.start()
        guard self.engine === engine, !Task.isCancelled else {
            try? await engine.stop()
            throw CancellationError()
        }
        let player = try engine.makeAdvancedPlayer(with: sample.makePattern())
        let id = UUID()
        playbackID = id
        self.player = player
        try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            player.completionHandler = { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.finish(id: id, result: error.map { .failure($0) } ?? .success(()))
                }
            }
            do { try player.start(atTime: CHHapticTimeImmediate) }
            catch { finish(id: id, result: .failure(error)) }
        }
    }

    func stop() {
        let previousPlayer = player
        let previousEngine = engine
        engine = nil
        if let playbackID { finish(id: playbackID, result: .failure(CancellationError())) }
        try? previousPlayer?.stop(atTime: CHHapticTimeImmediate)
        previousEngine?.stop()
    }

    private func finish(id: UUID, result: Result<Void, Error>) {
        guard playbackID == id else { return }
        playbackID = nil
        player = nil
        let continuation = completion
        completion = nil
        continuation?.resume(with: result)
    }

    private func prepareEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { throw Failure.unsupported }
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        let interrupted: @Sendable () -> Void = { [weak self, weak engine] in
            Task { @MainActor [weak self, weak engine] in
                guard let self, self.engine === engine, let id = self.playbackID else { return }
                self.finish(id: id, result: .failure(Failure.interrupted))
            }
        }
        engine.stoppedHandler = { _ in interrupted() }
        engine.resetHandler = interrupted
        self.engine = engine
        return engine
    }
}
