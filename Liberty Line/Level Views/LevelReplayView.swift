#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit
import AVFoundation

/// Movies consume the database recording. No gameplay engine or strategy runs.
struct LevelReplayView: View {
    let store: Store
    let canvas: RuntimeCanvas
    let runID: UUID
    @State private var playback: LevelReplayer?
    @State private var frame: LevelReplayFrame?
    @State private var road: CGPath?
    @State private var message = "Loading recorded level…"
    @State private var finished = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if let playback, let frame, let road {
                LevelReplayScene(setup: playback.setup, frame: frame, road: road, canvas: canvas)
            } else { Color.black }
            Text(message).font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.8), in: Capsule()).padding(.bottom, 8)
        }
        .allowsHitTesting(false)
        .task { await play() }
    }

    @MainActor private func play() async {
        guard playback == nil, !finished else { return }
        let output = Self.argument("--movie-output").map { URL(fileURLWithPath: $0) }
        let evidence = output?.deletingPathExtension().appendingPathExtension("json")
        var movie: ReplayMovieWriter?
        do {
            var speedOverride: PlaySpeed?
            if CommandLine.arguments.contains("--play-speed") {
                guard let argument = Self.argument("--play-speed"), let factor = Double(argument) else {
                    throw DbError.Db(message: "--play-speed requires a numeric factor")
                }
                speedOverride = try PlaySpeed(factor)
            }
            let replay = try LevelReplayer(dao: store.db.levelRunDao, runID: runID, playSpeedOverride: speedOverride)
            road = try replay.setup.roadSurface()
            playback = replay
            guard try replay.advance(), let first = replay.frame else {
                throw DbError.Db(message: "Recorded run has no frames")
            }
            frame = first
            message = replay.setup.level.name + " · " + runID.uuidString
            try await Task.sleep(for: .seconds(1))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw DbError.Db(message: "No visible replay window")
            }
            if let output { movie = try ReplayMovieWriter(url: output, size: CGSize(width: 2388, height: 1668), fps: replay.setup.ticksPerSecond) }
            var timing = LevelReplayTiming(framesPerSecond: replay.setup.ticksPerSecond)
            let clock = ContinuousClock()
            let started = clock.now
            var sourceFrames = 0
            repeat {
                try Task.checkCancellation()
                guard let current = replay.frame else { throw DbError.Db(message: "Missing recorded frame") }
                frame = current
                let seconds = Int(current.tick) / replay.setup.ticksPerSecond
                message = replay.setup.level.name + String(format: " · %02d:%02d · %d lives · %d coins", seconds / 60, seconds % 60, current.lives, current.money)
                let outputFrames = timing.append(gameSeconds: 1 / Double(replay.setup.ticksPerSecond), speed: replay.playSpeed)
                if let movie {
                    if !outputFrames.isEmpty {
                        // Allow SwiftUI to install this stored pose before capture.
                        try await Task.sleep(for: .milliseconds(1))
                        for _ in outputFrames { try await movie.append(window: window) }
                    }
                } else {
                    // Absolute deadlines prevent rendering overhead accumulating
                    // into a slower-than-requested playback rate.
                    try await clock.sleep(until: started.advanced(by: .seconds(timing.wallSeconds)))
                }
                sourceFrames += 1
            } while try replay.advance()
            message = replay.run.status.rawValue.capitalized + " · Recorded run " + runID.uuidString
            if let movie { try await movie.finish() }
            if let evidence {
                try Self.write(["status": "complete", "source": "database-level-actions", "runID": runID.uuidString,
                    "level": replay.setup.level.name, "frames": timing.outputFrames, "sourceFrames": sourceFrames,
                    "fps": replay.setup.ticksPerSecond, "playbackSeconds": timing.wallSeconds,
                    "recordedPlaySpeed": replay.run.playSpeed.factor,
                    "playSpeedOverride": speedOverride.map { $0.factor as Any } ?? NSNull(),
                    "width": 2388, "height": 1668, "lastSequence": replay.run.lastSequence,
                    "lastTick": replay.run.lastTick, "outcome": replay.run.status.rawValue], to: evidence)
            }
            finished = true
        } catch {
            movie?.cancel(); finished = true
            message = "Replay failed: \(error)"
            if let evidence { try? Self.write(["status": "failed", "runID": runID.uuidString, "error": String(describing: error)], to: evidence) }
        }
    }

    static func argument(_ flag: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: flag), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }
    private static func write(_ value: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
}

/// Records only the game window, without screen-recording permission or desktop
/// content. Backpressure delays encoding; the replay timeline decides which
/// stored poses belong in the movie, independent of export wall-clock speed.
@MainActor private final class ReplayMovieWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let size: CGSize
    private var frame: Int64 = 0
    private let fps: Int32

    init(url: URL, size: CGSize, fps: Int) throws {
        self.size = size
        self.fps = Int32(fps)
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000,
                                              AVVideoMaxKeyFrameIntervalKey: 60]])
        input.expectsMediaDataInRealTime = false
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
        guard writer.canAdd(input) else { throw DbError.Db(message: "Movie encoder cannot accept video input") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? DbError.Db(message: "Movie encoder failed to start") }
        writer.startSession(atSourceTime: .zero)
    }

    func snapshot(window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = size.width / window.bounds.width
        format.opaque = true
        // H.264 export is SDR. Avoid an extended-range intermediate and an
        // expensive floating-point color conversion for every movie frame.
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    func append(window: UIWindow) async throws {
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else { throw writer.error ?? DbError.Db(message: "Movie writer stopped") }
            try await Task.sleep(for: .milliseconds(2))
        }
        guard let pool = adaptor.pixelBufferPool else { throw DbError.Db(message: "Movie pixel buffer pool unavailable") }
        var optional: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optional) == kCVReturnSuccess, let buffer = optional else {
            throw DbError.Db(message: "Movie frame allocation failed")
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width),
            height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue),
            let image = snapshot(window: window).cgImage else { throw DbError.Db(message: "Movie frame capture failed") }
        context.draw(image, in: CGRect(origin: .zero, size: size))
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: frame, timescale: fps)) else {
            throw writer.error ?? DbError.Db(message: "Movie frame encoding failed")
        }
        frame += 1
    }

    func finish() async throws {
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? DbError.Db(message: "Movie did not finish") }
    }

    func cancel() { writer.cancelWriting() }
}
#endif
