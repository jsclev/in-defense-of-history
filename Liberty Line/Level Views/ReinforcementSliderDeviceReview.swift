#if DEBUG
import SwiftUI
import UIKit

extension LevelRunner {
    /// Run with --play-level 15 --reinforcement-slider-review on a physical
    /// device. Exercises the production HUD and display clock; exports PNG/JSON.
    func reviewReinforcementSlider(buttonSize: CGFloat) async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("reinforcement-slider-review", isDirectory: true)
        var report: [String: Any] = ["passed": false]
        var samples: [[String: Any]] = []
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw DbError.Db(message: message) }
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await Task.sleep(for: .seconds(1))
            try require(isReady && canCallReinforcements, "Reinforcements unavailable at battle entry")
            // Reproduce the old banked-charge failure through complete engine
            // ticks, then observe the cooldown on the real display clock.
            stop()
            advance(ticks: Int((content.reinforcementConfig.cooldownSeconds * Double(SimClock.ticksPerSecond)).rounded(.up)) * 3,
                    interpolation: 0)
            start()
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else {
                throw DbError.Db(message: "No native window for reinforcement slider review")
            }
            func buttonPNG(size: CGFloat, scale: CGFloat, cooldown: ReinforcementCooldown,
                           available: Bool) throws -> Data {
                let renderer = ImageRenderer(content: ReinforcementButton(
                    buttonSize: CGSize(width: size, height: size), cooldown: cooldown,
                    isAvailable: available, action: {}))
                renderer.scale = scale
                guard let png = renderer.uiImage?.pngData() else {
                    throw DbError.Db(message: "Reinforcement button did not render")
                }
                return png
            }
            func capture(_ name: String) throws {
                let cooldown = reinforcementCooldown
                try require(canCallReinforcements == cooldown.isReady, "HUD readiness differs from deployment eligibility")
                samples.append(["name": name, "tick": timer.tick,
                    "remainingFraction": cooldown.remainingFraction,
                    "remainingSeconds": cooldown.remainingSeconds,
                    "available": canCallReinforcements])
                for size in [CGFloat(44), buttonSize] {
                    for scale in [CGFloat(1), CGFloat(2), window.screen.scale] {
                        try buttonPNG(size: size, scale: scale, cooldown: cooldown,
                            available: canCallReinforcements)
                            .write(to: directory.appendingPathComponent("\(name)-\(size)pt@\(Int(scale))x.png"))
                    }
                }
                window.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
                let screenshot = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let png = screenshot.pngData() else { throw DbError.Db(message: "HUD capture failed") }
                try png.write(to: directory.appendingPathComponent("\(name)-game.png"))
            }
            try capture("ready-before")
            let path = content.level.paths[0]
            let point = path.point(atDistance: path.totalLength / 2)
            try require(perform(.reinforcements(point: point)) == .ok, "Deployment failed")
            try require(reinforcementCooldown.remainingFraction == 1, "Deployment did not start a full cooldown")
            let afterDeployment = reinforcementCooldown
            try require(perform(.reinforcements(point: point)) == .invalid, "Waiting banked an extra deployment")
            try require(reinforcementCooldown == afterDeployment, "A rejected call changed the cooldown")
            pause()
            let pausedTick = timer.tick
            let pausedCooldown = reinforcementCooldown
            try await Task.sleep(for: .milliseconds(350))
            try require(timer.tick == pausedTick && reinforcementCooldown == pausedCooldown,
                        "Cooldown advanced while paused")
            resume()
            start()
            try await Task.sleep(for: .milliseconds(100))
            try capture("deployed")
            let deadline = Date().addingTimeInterval(pausedCooldown.remainingSeconds + 10)
            for fraction in [0.75, 0.5, 0.25, 0.1, 0] {
                while reinforcementCooldown.remainingFraction > fraction {
                    try require(Date() < deadline, "Native display-clock cooldown stopped advancing")
                    try await Task.sleep(for: .milliseconds(50))
                }
                try capture("remaining-\(Int(fraction * 100))")
            }
            try require(canCallReinforcements, "Button did not become available after cooldown")
            try require(perform(.reinforcements(point: point)) == .ok, "Ready button could not deploy again")
            try require(reinforcementCooldown.remainingFraction == 1, "The second deployment did not start a full cooldown")
            try require(perform(.reinforcements(point: point)) == .invalid, "A second cooldown or reserve allowed a duplicate call")
            report["passed"] = true
            report["oneFullCooldownPerDeployment"] = true
            report["waitingDoesNotStoreDeployments"] = true
            report["pauseFreezesCooldown"] = true
            report["redeploymentSucceeded"] = true
            report["buttonPoints"] = buttonSize
            report["screenScale"] = window.screen.scale
        } catch { report["error"] = String(describing: error) }
        report["samples"] = samples
        report["capturedAt"] = ISO8601DateFormatter().string(from: Date())
        do {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
        } catch { print("Unable to save reinforcement slider review: \(error)") }
    }
}
#endif
