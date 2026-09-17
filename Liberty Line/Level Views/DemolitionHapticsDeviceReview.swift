#if DEBUG
import SwiftUI
import UIKit

/// Physical-device playback checks; never touches a saved player match.
struct DemolitionHapticsDeviceReview: View {
    let store: Store
    @State private var message = "Checking demolition haptics…"

    var body: some View {
        Text(message).padding().task { await runReview() }
    }

    @MainActor private func runReview() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("demolition-haptics-review", isDirectory: true)
        var record: [String: Any] = ["passed": false, "startedAt": Date().timeIntervalSince1970]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // An early read must never mistake an old successful run for this one.
            try save(record, in: directory)
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first,
                let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first
            else { throw NSError(domain: "DemolitionHapticsReview", code: 2) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                levelInfoID: level.id, mapImageName: level.mapImageName)
            record["demolition"] = try runner.verifyDemolitionOnDevice()
            record["haptics"] = try await runner.verifyDemolitionHapticsOnDevice()
            record["passed"] = true
            message = "Demolition haptics passed"
        } catch {
            record["error"] = error.localizedDescription
            message = "Demolition haptics failed: \(error.localizedDescription)"
        }
        record["completedAt"] = Date().timeIntervalSince1970
        do { try save(record, in: directory) }
        catch { message = "Unable to save haptic review: \(error.localizedDescription)" }
    }

    private func save(_ record: [String: Any], in directory: URL) throws {
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
    }
}
#endif
