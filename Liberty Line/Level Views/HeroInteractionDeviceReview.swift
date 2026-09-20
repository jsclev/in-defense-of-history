#if DEBUG
import SwiftUI
import UIKit

/// Measures cold hero selection through the live view hierarchy on a physical
/// device, then issues real movement orders. No alternate movement or UI model.
struct HeroInteractionDeviceReview: View {
    let store: Store
    let canvas: RuntimeCanvas
    @State private var runner: LevelRunner?
    @State private var node: CampaignNode?

    var body: some View {
        Group {
            if let runner, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node,
                    hudLayoutConfig: store.hudLayoutConfig, reviewRunner: runner, onExit: {})
            } else { Color.black }
        }.task { await review() }
    }

    @MainActor private func review() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hero-interaction-review", isDirectory: true)
        var result: [String: Any] = ["passed": false]
        let frames = HeroInteractionFrameMonitor()
        defer { frames.stop() }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")[14]
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                runtimeCanvas: canvas, hudLayoutConfig: store.hudLayoutConfig,
                levelInfoID: level.id, mapImageName: level.mapImageName)
            self.runner = runner
            self.node = CampaignNode(order: 15, level: level)
            try await Task.sleep(for: .seconds(2))
            guard let hero = runner.heroes.first else { throw failure("No authored hero deployed") }
            let origin = hero.position
            frames.start()
            var samples: [[String: Any]] = []
            func measure(_ name: String, action: () throws -> Void) async throws {
                frames.reset()
                let start = CACurrentMediaTime()
                try action()
                let handlerMS = (CACurrentMediaTime() - start) * 1_000
                try await Task.sleep(for: .seconds(1))
                let sample: [String: Any] = ["name": name, "handlerMS": handlerMS,
                    "maxFrameGapMS": frames.maxGap * 1_000, "frames": frames.count]
                samples.append(sample)
                print("Hero interaction: \(sample)")
            }
            for attempt in 1...3 {
                try await measure("select-\(attempt)") { runner.selectHero(hero.id) }
                guard runner.selectedHeroIndex == hero.id else { throw failure("Hero did not select") }
                try await measure("deselect-\(attempt)") { runner.selectHero(hero.id) }
            }
            let configuration = try store.db.levelGeoJSONDao.getHeroConfiguration(mapImageName: level.mapImageName)
            guard let destination = configuration.spawns.first(where: {
                $0.position.distance(to: Point(origin.x, origin.y)) > 10
            })?.position else { throw failure("Missing a second authored hero start") }
            runner.selectHero(hero.id)
            try await Task.sleep(for: .milliseconds(300))
            try await measure("first-move") {
                guard runner.commandSelectedHero(to: CGPoint(x: destination.x, y: destination.y))
                else { throw failure("Authored destination rejected") }
            }
            guard runner.selectedHeroIndex == nil,
                  runner.heroes.first(where: { $0.id == hero.id })?.position != origin
            else { throw failure("Hero did not begin walking") }
            result["samples"] = samples
            result["movementStarted"] = true
            result["passed"] = samples.allSatisfy {
                ($0["maxFrameGapMS"] as! Double) < 100 && ($0["handlerMS"] as! Double) < 100
            }
        } catch { result["error"] = error.localizedDescription }
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { print("Could not save hero interaction review: \(error)") }
    }

    private func failure(_ message: String) -> NSError {
        NSError(domain: "HeroInteractionReview", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@MainActor private final class HeroInteractionFrameMonitor: NSObject {
    private var link: CADisplayLink?
    private var previous: CFTimeInterval = 0
    private(set) var maxGap: CFTimeInterval = 0
    private(set) var count = 0

    func start() {
        link = CADisplayLink(target: self, selector: #selector(frame))
        link?.add(to: .main, forMode: .common)
        reset()
    }
    func reset() { previous = CACurrentMediaTime(); maxGap = 0; count = 0 }
    func stop() { link?.invalidate(); link = nil }
    @objc private func frame() {
        let now = CACurrentMediaTime()
        maxGap = max(maxGap, now - previous)
        previous = now
        count += 1
    }
}
#endif
