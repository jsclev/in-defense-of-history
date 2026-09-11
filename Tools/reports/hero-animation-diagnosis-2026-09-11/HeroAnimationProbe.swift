import SwiftUI
import ImageIO
import UniformTypeIdentifiers

@main struct HeroAnimationProbe: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { Text("Checking hero animation").task { await captureAnimation() } }
    }
}

@MainActor private func captureAnimation() async {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var result: [String: Any] = ["runID": "PROBE_RUN_ID", "passed": false]
    do {
        let store = Store()
        let roster = try store.db.heroDao.getAll()
        let selected = roster.filter { ["George Washington", "Henry Knox"].contains($0.shortName) }
        _ = try HeroSelectionStore(dao: store.db.heroDao).save(HeroSelection(heroes: selected))
        let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main").last!
        let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
        let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: rect, safeInsetsRect: rect)
        let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas,
                                runtimeCanvas: canvas, levelInfoID: level.id, mapImageName: level.mapImageName)
        guard runner.isReady, runner.heroes.count == 2 else { throw ProbeError.message(runner.status) }
        // Exercise the production pose update and publish path at 30 ticks / 60 renders per second.
        let traces = UnitFacing.allCases.map { runner.probeAnimationFrames(facing: $0) }
        var checkedImages = Set<String>()
        var traceRows: [[String: Any]] = []
        for (direction, frames) in zip(UnitFacing.allCases, traces) {
            for (sample, heroes) in frames.enumerated() {
                for hero in heroes {
                    guard UIImage(named: hero.assetName) != nil else { throw ProbeError.message("Missing \(hero.assetName)") }
                    checkedImages.insert(hero.assetName)
                    traceRows.append(["direction": direction.assetSuffix, "sample": sample,
                                      "asset": hero.assetName, "position": [hero.position.x, hero.position.y]])
                }
            }
        }
        // Compare decoded shipped images against copied source PNGs to exclude stale compiled art.
        let references = try JSONSerialization.jsonObject(with: Data(contentsOf:
            Bundle.main.url(forResource: "animation-references", withExtension: "json")!)) as! [[String: String]]
        var pixelChecks: [[String: Any]] = []
        for reference in references {
            let source = UIImage(contentsOfFile: Bundle.main.bundleURL.appendingPathComponent(reference["file"]!).path)!
            let compiled = UIImage(named: reference["name"]!)!
            let a = pixels(source), b = pixels(compiled)
            let mean = a.count == b.count ? zip(a, b).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(a.count) : 255
            pixelChecks.append(["name": reference["name"]!, "meanByteDifference": mean,
                "sourcePixels": [source.cgImage!.width, source.cgImage!.height],
                "compiledPixels": [compiled.cgImage!.width, compiled.cgImage!.height]])
            if reference["name"]!.hasSuffix("_e_0") {
                try compiled.pngData()!.write(to: directory.appendingPathComponent(reference["name"]! + "-compiled.png"))
            }
        }
        result["pixelChecks"] = pixelChecks
        let projection = LevelMapProjection(playArea: store.virtualCanvas.playAreaRect,
                                            fitRect: canvas.playAreaRect, virtualCanvas: store.virtualCanvas)
        let file = directory.appendingPathComponent("native-minimum-animation.gif")
        let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.gif.identifier as CFString, 126, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for sample in 0..<126 {
            var units: [LevelRunner.HeroSoldier] = []
            for direction in 0..<8 {
                for (row, hero) in traces[direction][sample].enumerated() {
                    // Freeze only the world anchor for gait inspection. All frame names come from LevelRunner.
                    let screenFoot = CGPoint(x: 43 + CGFloat(direction) * 74, y: 93 + CGFloat(row) * 96)
                    units.append(.init(id: direction * 2 + row, assetName: hero.assetName,
                        baseAssetName: hero.baseAssetName, imageAspectRatio: hero.imageAspectRatio,
                        position: projection.mapPoint(screenFoot), hp: hero.maxHP, maxHP: hero.maxHP, isSelected: false))
                }
            }
            let view = ZStack(alignment: .topLeading) {
                Color(red: 0.70, green: 0.74, blue: 0.63)
                HeroMapLayer(heroes: units, runtimeCanvas: canvas, projection: projection, onSelect: { _ in })
                Text("Current production frames · normal speed · minimum gameplay size")
                    .font(.system(size: 13)).foregroundStyle(.black).offset(x: 12, y: 8)
                ForEach(Array(UnitFacing.allCases.enumerated()), id: \.offset) { i, facing in
                    Text(facing.assetSuffix.uppercased()).font(.system(size: 11)).foregroundStyle(.black)
                        .position(x: 43 + CGFloat(i) * 74, y: 37)
                }
                Text("Washington").font(.system(size: 11)).foregroundStyle(.black).offset(x: 12, y: 106)
                Text("Knox").font(.system(size: 11)).foregroundStyle(.black).offset(x: 12, y: 202)
            }.frame(width: rect.width, height: 225)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let image = renderer.uiImage?.cgImage else { throw ProbeError.message("Rendering failed") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary:
                [kCGImagePropertyGIFDelayTime: 1.0 / 60, kCGImagePropertyGIFUnclampedDelayTime: 1.0 / 60]] as CFDictionary)
            if sample == 8 || sample == 32 {
                renderer.scale = 3
                try renderer.uiImage!.pngData()!.write(to: directory.appendingPathComponent("native-sample-\(sample)@3x.png"))
            }
            if sample % 12 == 0 { await Task.yield() }
        }
        guard CGImageDestinationFinalize(destination) else { throw ProbeError.message("GIF export failed") }
        try JSONSerialization.data(withJSONObject: traceRows, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("runtime-trace.json"))
        result.merge(["passed": true, "samplesPerDirection": 126, "directions": 8,
                      "uniqueImages": checkedImages.count, "compiledPixelComparisons": references.count,
                      "cycleSeconds": HeroWalkCycle.cycleDistance / 180,
                      "playableHeight": canvas.playAreaRect.height,
                      "limitation": "Physical iPhone executes production pose/publish and HeroMapLayer with deterministic movement samples. Frozen world anchors isolate gait; this does not measure live display-link performance or touch input."])
            { _, new in new }
    } catch { result["error"] = String(describing: error) }
    try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("animation-check.json"))
}

private enum ProbeError: Error { case message(String) }

private func pixels(_ image: UIImage) -> Data {
    let cg = image.cgImage!
    var data = Data(count: cg.width * cg.height * 4)
    data.withUnsafeMutableBytes { bytes in
        let context = CGContext(data: bytes.baseAddress, width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    }
    return data
}
