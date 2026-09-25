#if DEBUG
import SwiftUI
import UIKit

struct DemolitionDeviceReview: View {
    let store: Store
    @State private var runner: LevelRunner?
    @State private var canvas: RuntimeCanvas?
    @State private var node: CampaignNode?
    @State private var message = "Checking charge-placement tower…"

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
            if let runner, let canvas, let node {
                LevelMapView(db: store.db, virtualCanvas: store.virtualCanvas,
                    runtimeCanvas: canvas, towerMenuLayout: store.towerMenuLayout,
                    node: node, hudLayoutConfig: .standard,
                    reviewRunner: runner, runsAutomatically: false, onExit: {})
            }
            if !CommandLine.arguments.contains("--demolition-ui-review")
                && !CommandLine.arguments.contains("--artillery-menu-review") {
                Text(message).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white).padding(5).background(.black.opacity(0.85))
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .task { await runReview() }
    }

    @MainActor private func runReview() async {
        let readinessOnly = CommandLine.arguments.contains("--demolition-ready-review")
        let automationOnly = CommandLine.arguments.contains("--demolition-auto-review")
            || CommandLine.arguments.contains("--demolition-interaction-review")
        let menuOnly = CommandLine.arguments.contains("--artillery-menu-review")
        let uiOnly = CommandLine.arguments.contains("--demolition-ui-review")
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(menuOnly ? "artillery-menu-review" : automationOnly ? "demolition-auto-review"
                : uiOnly ? "demolition-ui-review"
                : readinessOnly ? "demolition-ready-review" : "demolition-review", isDirectory: true)
        var record: [String: Any] = ["passed": false]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: record).write(to: directory.appendingPathComponent("result.json"))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first,
                let level = try store.db.levelInfoDao.getCampaignLevels(campaignName: "Main")
                    .dropFirst(uiOnly || automationOnly || menuOnly ? 14 : 0).first
            else { throw NSError(domain: "DemolitionReview", code: 6) }
            let canvas = RuntimeCanvas(virtualCanvas: store.virtualCanvas, physicalRect: window.bounds,
                safeInsetsRect: window.bounds.inset(by: window.safeAreaInsets))
            let runner = LevelRunner(db: store.db, virtualCanvas: store.virtualCanvas, runtimeCanvas: canvas,
                levelInfoID: level.id, mapImageName: level.mapImageName)
            record["checks"] = try runner.verifyDemolitionOnDevice()
            record["displayScale"] = window.screen.scale
            let sapperSlotWidth = runner.slotSize.width * canvas.scaleFactor
            record["towerHeightPoints"] = DemolitionTowerView.artworkHeight(
                slotWidth: sapperSlotWidth, assetName: "special_tower_level_4_branch_3")
            record["towerWidthPoints"] = sapperSlotWidth
            record["detonationControl"] = "Automatic when an enemy is about to leave the blast along its route"
            record["automationChecks"] = try runner.verifyDemolitionAutomationOnDevice()
            record["chargeUpIndicator"] = "Continuous green bar filling left to right over a black track beneath the tower; no visible timer text"
            record["placementControl"] = "Shared rally flag at the bottom center of the tower radial menu"
            record["readyToPlaceCue"] = "Tower pulse; no separate icon"
            guard DemolitionExplosionFrames.images.count == DemolitionExplosion.frameCount,
                  DemolitionExplosionFrames.images.allSatisfy({ $0.size == CGSize(width: 160, height: 160) })
            else { throw NSError(domain: "DemolitionReview", code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Explosion atlas missing or cropped incorrectly"]) }
            self.runner = runner; self.canvas = canvas; self.node = CampaignNode(order: uiOnly || automationOnly || menuOnly ? 15 : 1, level: level)
            if menuOnly {
                record["siege"] = try runner.verifySiegeOnDevice()
                record["range"] = try runner.verifyArtilleryRangeOnDevice()
                record["morale"] = try runner.verifyArtilleryMoraleOnDevice().checks
                record["menu"] = try await captureArtilleryMenu(runner: runner, canvas: canvas,
                    window: window, directory: directory)
                record["passed"] = true
                record["completedAt"] = Date().timeIntervalSince1970
                try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
                return
            }
            if automationOnly {
                try runner.prepareDemolitionAutomaticReview()
                record["automation"] = try await captureAutomation(runner: runner, canvas: canvas,
                    window: window, directory: directory)
                record["passed"] = true
                record["completedAt"] = Date().timeIntervalSince1970
                try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
                message = "Automatic detonation verified"
                return
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
            if readinessOnly || uiOnly {
                record["readiness"] = try await captureReadiness(runner: runner, canvas: canvas,
                    window: window, format: format, directory: directory)
                if uiOnly {
                    for stage in ["unplaced", "unplaced-menu", "unplaced-placement", "first-placement", "menu", "placement", "relocated"] {
                        try runner.prepareDemolitionReview(stage: stage)
                        try await Task.sleep(for: .milliseconds(450))
                        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        guard let data = image.pngData() else { throw NSError(domain: "DemolitionReview", code: 7) }
                        try data.write(to: directory.appendingPathComponent("\(stage).png"))
                    }
                }
                record["passed"] = true
                record["completedAt"] = Date().timeIntervalSince1970
                try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("result.json"), options: .atomic)
                message = "Charge readiness review passed"
                return
            }
            for stage in ["upgrade", "preparing", "ready", "blast", "after", "menu", "placement"] {
                try runner.prepareDemolitionReview(stage: stage)
                message = "Demolition review · \(stage)"
                try await Task.sleep(for: .milliseconds(450))
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let data = image.pngData() else { throw NSError(domain: "DemolitionReview", code: 7) }
                try data.write(to: directory.appendingPathComponent("\(stage).png"))
            }
            try runner.prepareExplosionReview()
            let hp = runner.walkers.map(\.hp)
            let cash = runner.money
            let ages = stride(from: 0.0, through: 1.4, by: 1.0 / 30.0).map { $0 }
            var previousAge = 0.0
            for (index, age) in ages.enumerated() {
                runner.advanceExplosionReview(seconds: age - previousAge)
                previousAge = age
                message = "Explosion · \(String(format: "%.2f", age)) s"
                try await Task.sleep(for: .milliseconds(50))
                let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let data = image.pngData() else { throw NSError(domain: "DemolitionReview", code: 7) }
                try data.write(to: directory.appendingPathComponent(String(format: "explosion-%02d.png", index)))
            }
            guard runner.artilleryImpacts.isEmpty, runner.walkers.map(\.hp) == hp, runner.money == cash else {
                throw NSError(domain: "DemolitionReview", code: 12,
                    userInfo: [NSLocalizedDescriptionKey: "Animation changed damage or failed to finish"])
            }

            try runner.prepareExplosionReview(ended: true)
            let victoryHP = runner.walkers.map(\.hp)
            runner.start()
            try await Task.sleep(for: .milliseconds(1600))
            guard runner.artilleryImpacts.isEmpty, runner.walkers.map(\.hp) == victoryHP else {
                throw NSError(domain: "DemolitionReview", code: 13,
                    userInfo: [NSLocalizedDescriptionKey: "Victory interrupted the explosion"])
            }
            runner.stop()
            record["animation"] = ["frames": DemolitionExplosionFrames.images.count,
                "durationGameSeconds": DemolitionExplosion.duration, "captureAges": ages,
                "captureMode": "Controlled native frames at 30 game-time samples per second",
                "finishesAfterVictory": true, "damageAndRewardsUnchangedDuringAnimation": true]
            record["passed"] = true
            try runner.prepareDemolitionReview(stage: "ready")
            runner.start()
            message = "Demolition review passed · automatic charge armed"
        } catch {
            message = "Demolition review failed: \(error.localizedDescription)"
            record["error"] = error.localizedDescription
        }
        do {
            record["completedAt"] = Date().timeIntervalSince1970
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: directory.appendingPathComponent("result.json"))
        } catch { message = "Unable to save demolition review: \(error.localizedDescription)" }
    }

    @MainActor private func captureArtilleryMenu(runner: LevelRunner, canvas: RuntimeCanvas,
        window: UIWindow, directory: URL) async throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "ArtilleryMenuReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
        func capture(_ name: String) async throws {
            try await Task.sleep(for: .milliseconds(300))
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let data = image.pngData() else { throw NSError(domain: "ArtilleryMenuReview", code: 2) }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
        }
        let slot = try runner.prepareTowerUpgradeReview(kind: .areaOfEffect)
        let offers = runner.upgradeOffers
        try require(offers.map(\.branch) == [1, 2, 4], "Artillery choices changed")
        try await capture("artillery-menu")
        let minimumSize = store.towerMenuLayout.getTowerButtonSize(
            playAreaScalingFactor: 340 / store.virtualCanvas.playAreaRect.height)
        @MainActor func export<V: View>(_ view: V, name: String, density: Int) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = CGFloat(density)
            guard let data = renderer.uiImage?.pngData() else {
                throw NSError(domain: "ArtilleryMenuReview", code: 4)
            }
            try data.write(to: directory.appendingPathComponent("\(name)@\(density)x.png"))
        }
        for density in 1...3 {
            for kind in TowerKind.allCases {
                try export(TowerMenuItem(towerMenuLayout: store.towerMenuLayout, kind: kind,
                    isAvailable: true, isArmed: false, isAffordable: true, cost: 100,
                    buttonSize: minimumSize, action: {}).padding(.bottom, 10),
                    name: "basic-\(kind.rawValue)", density: density)
            }
            try export(TowerMenuItem(towerMenuLayout: store.towerMenuLayout, kind: .special,
                isAvailable: false, isArmed: false, isAffordable: false, cost: nil,
                buttonSize: minimumSize, action: {}), name: "locked", density: density)
            try export(RallyMenuItem(towerMenuLayout: store.towerMenuLayout,
                buttonSize: minimumSize, action: {}), name: "rally", density: density)
            let names = TowerKind.allCases.map(\.menuIconName) + ["tower_locked_icon", "rally_point_icon"]
            for name in names {
                try export(TowerMenuIcon(towerMenuLayout: store.towerMenuLayout,
                    name: name, buttonSize: minimumSize.width), name: name, density: density)
            }
        }
        for offer in offers {
            guard let name = TowerKind.areaOfEffect.specializationMenuIconName(atLevel: 4, branch: offer.branch),
                  UIImage(named: name) != nil else {
                throw NSError(domain: "ArtilleryMenuReview", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Missing artillery menu icon"])
            }
            for density in 1...3 {
                for affordable in [true, false] {
                    let renderer = ImageRenderer(content: UpgradeMenuItem(
                        towerMenuLayout: store.towerMenuLayout, iconName: name, dropKind: .areaOfEffect,
                        cost: offer.cost, isArmed: false, isAffordable: affordable,
                        buttonSize: minimumSize, action: {})
                        .padding(.bottom, 10))
                    renderer.scale = CGFloat(density)
                    guard let data = renderer.uiImage?.pngData() else {
                        throw NSError(domain: "ArtilleryMenuReview", code: 4)
                    }
                    let suffix = affordable ? "ready" : "unaffordable"
                    try data.write(to: directory.appendingPathComponent(
                        "button-\(offer.branch)-\(suffix)@\(density)x.png"))
                }
                let icon = ImageRenderer(content: TowerMenuIcon(towerMenuLayout: store.towerMenuLayout,
                    name: name, buttonSize: minimumSize.width))
                icon.scale = CGFloat(density)
                guard let data = icon.uiImage?.pngData() else { throw NSError(domain: "ArtilleryMenuReview", code: 5) }
                try data.write(to: directory.appendingPathComponent("icon-\(offer.branch)@\(density)x.png"))
            }
            try runner.prepareTowerUpgradeReview(kind: .areaOfEffect)
            let moneyBefore = runner.money
            runner.tapUpgradeButton(branch: offer.branch)
            try require(runner.armedUpgradeBranch == offer.branch && runner.money == moneyBefore,
                        "Icon selection did not preview the intended branch")
            try await capture("confirm-\(offer.branch)")
            runner.tapUpgradeButton(branch: offer.branch)
            try require(runner.placedTower(atSlot: slot)?.level == 4
                && runner.placedTower(atSlot: slot)?.branch == offer.branch
                && runner.money == moneyBefore - offer.cost, "Confirmation upgraded the wrong branch")
        }
        try runner.prepareDemolitionReview(stage: "upgrade")
        try require(runner.upgradeOffers.map(\.branch) == [1, 2, 3], "Wrong engineer branches")
        try await capture("engineers-menu")
        for offer in runner.upgradeOffers {
            guard let name = TowerKind.special.specializationMenuIconName(atLevel: 4, branch: offer.branch),
                  UIImage(named: name) != nil else { throw NSError(domain: "ArtilleryMenuReview", code: 6) }
            for density in 1...3 {
                try export(UpgradeMenuItem(towerMenuLayout: store.towerMenuLayout,
                    iconName: name, dropKind: .special, cost: offer.cost, isArmed: false,
                    isAffordable: true, buttonSize: minimumSize, action: {}).padding(.bottom, 10),
                    name: "engineer-\(offer.branch)", density: density)
            }
        }
        try runner.prepareDemolitionReview(stage: "unplaced-menu")
        try await capture("engineers-sapper")
        try runner.prepareTowerUpgradeReview(kind: .areaOfEffect)
        runner.tapUpgradeButton(branch: 4); runner.tapUpgradeButton(branch: 4)
        try await capture("siege-tower")
        return ["branches": [1, 2, 4], "compiledIconsPresent": true,
                "previewAndConfirmationVerified": true, "minimumButtonSizePoints": minimumSize.width,
                "minimumIconSizePoints": store.towerMenuLayout.getTowerIconSize(towerButtonSize: minimumSize.width),
                "sharedInsetPoints": minimumSize.width * TowerMenuLayout.iconInsetFraction,
                "basicTowerKindsRendered": TowerKind.allCases.map(\.rawValue),
                "lockedAndRallyRendered": true]
    }

    @MainActor private func captureAutomation(runner: LevelRunner, canvas: RuntimeCanvas,
        window: UIWindow, directory: URL) async throws -> [String: Any] {
        guard let tower = runner.placedTowers.first(where: { $0.demolitionCharge != nil }),
              let charge = tower.demolitionCharge, charge.isReady else {
            throw NSError(domain: "DemolitionAutoReview", code: 4)
        }
        let hpBefore = runner.walkers.map(\.hp)
        let format = UIGraphicsImageRendererFormat(); format.scale = window.screen.scale
        func capture(_ name: String) throws {
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let data = image.pngData() else { throw NSError(domain: "DemolitionAutoReview", code: 5) }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
        }
        message = "Waiting for the enemy to reach the outgoing edge"
        try await Task.sleep(for: .milliseconds(300))
        try capture("approaching")
        var elapsed = 0.0
        while runner.placedTower(atSlot: tower.slotIndex)?.demolitionCharge?.isReady == true && elapsed < 2 {
            runner.advanceDemolitionAutomaticReview(seconds: SimClock.dt)
            elapsed += SimClock.dt
            try await Task.sleep(for: .milliseconds(34))
        }
        guard runner.artilleryImpacts.count == 1,
              runner.artilleryImpacts[0].isDemolition,
              runner.artilleryImpacts[0].position == charge.position,
              runner.walkers.map(\.hp) != hpBefore,
              runner.placedTower(atSlot: tower.slotIndex)?.demolitionCharge?.isReady == false
        else { throw NSError(domain: "DemolitionAutoReview", code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Outgoing enemy failed to trigger one automatic blast"]) }
        message = "Automatic blast · charge-up on tower"
        runner.advanceDemolitionAutomaticReview(seconds: 0.1)
        try await Task.sleep(for: .milliseconds(100))
        try capture("automatic-blast")
        runner.advanceDemolitionAutomaticReview(seconds: DemolitionExplosion.duration)
        try await Task.sleep(for: .milliseconds(100))
        try capture("cooldown")
        runner.stop()
        return ["noTouchOrDirectDetonationCall": true, "singleExplosionAtCharge": true,
                "damageApplied": true, "preparationRestarted": true,
                "elapsedGameSecondsToTrigger": elapsed,
                "hapticSensation": "Requires the user's report"]
    }

    @MainActor private func captureReadiness(runner: LevelRunner, canvas: RuntimeCanvas,
        window: UIWindow, format: UIGraphicsImageRendererFormat, directory: URL) async throws -> [String: Any] {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "ChargeReadinessReview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func capture(_ name: String) async throws {
            message = "Charge readiness · \(name)"
            try await Task.sleep(for: .milliseconds(180))
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let data = image.pngData() else { throw NSError(domain: "ChargeReadinessReview", code: 2) }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
        }
        let slot = try runner.prepareDemolitionReview(stage: "preparing", includeEnemies: false)
        let preparing = runner.placedTower(atSlot: slot)!.demolitionCharge!
        guard let position = preparing.position else { throw NSError(domain: "ChargeReadinessReview", code: 6) }
        let site = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
            .viewPoint(position)
        try await capture("preparing")
        runner.advanceDemolitionReadinessReview(seconds: preparing.remainingSeconds - 0.001)
        try require(runner.placedTower(atSlot: slot)?.demolitionCharge?.isReady == false, "Charge armed early")
        try await capture("almost-ready")
        runner.advanceDemolitionReadinessReview(seconds: 0.002)
        try require(runner.placedTower(atSlot: slot)?.demolitionCharge?.isReady == true, "Charge did not arm")
        let ready = runner.placedTower(atSlot: slot)!.demolitionCharge!
        var sampleTimes: [Double] = []
        let started = Date()
        for index in 0..<8 {
            try await capture("ready-\(index)")
            sampleTimes.append(Date().timeIntervalSince(started))
        }
        try require(runner.detonateDemolition(atSlot: slot), "Ready charge did not detonate")
        runner.advanceDemolitionReadinessReview(seconds: DemolitionExplosion.duration + 0.01)
        try require(runner.artilleryImpacts.isEmpty && runner.placedTower(atSlot: slot)?.demolitionCharge?.isReady == false,
                    "Expected a recharging charge after the blast finished")
        try await capture("recharging")
        runner.advanceDemolitionReadinessReview(seconds: 8)
        try require(runner.placedTower(atSlot: slot)?.demolitionCharge?.isReady == true, "Second charge did not arm")
        try await capture("ready-again")

        let pulseSlot = try runner.prepareDemolitionReview(stage: "unplaced", includeEnemies: false)
        let pulseStarted = Date()
        var pulseSampleTimes: [Double] = []
        for index in 0..<8 {
            try await capture("pulse-\(index)")
            pulseSampleTimes.append(Date().timeIntervalSince(pulseStarted))
        }
        let towerPoint = LevelMapArt.projection(virtualCanvas: store.virtualCanvas, fitting: canvas.playAreaRect)
            .viewPoint(runner.placedTower(atSlot: pulseSlot)!.position)
        let placementButtonPoint = store.towerMenuLayout.getButtonSeatCenterPoint(
            index: 1, count: 2, menuCenterPoint: towerPoint, playAreaScalingFactor: canvas.scaleFactor)
        try require(abs(placementButtonPoint.x - towerPoint.x) < 0.001
                    && placementButtonPoint.y > towerPoint.y, "Placement button is not at bottom center")

        for density in 1...3 {
            for isOn in [true, false] {
                let renderer = ImageRenderer(content: DemolitionGroundChargeSymbol(lightIsOn: isOn))
                renderer.scale = CGFloat(density)
                guard let data = renderer.uiImage?.pngData() else { throw NSError(domain: "ChargeReadinessReview", code: 3) }
                try data.write(to: directory.appendingPathComponent("prop-\(isOn ? "on" : "off")@\(density)x.png"))
            }
            for (name, charge) in [("preparing", preparing), ("ready", ready)] {
                let renderer = ImageRenderer(content: DemolitionSiteView(charge: charge, radius: 60, showBlastRadius: false)
                    .frame(width: 32, height: 40))
                renderer.scale = CGFloat(density)
                guard let data = renderer.uiImage?.pngData() else { throw NSError(domain: "ChargeReadinessReview", code: 4) }
                try data.write(to: directory.appendingPathComponent("site-\(name)@\(density)x.png"))
            }

            let minimumSlotWidth = store.virtualCanvas.towerSlotSize.width
                * 340 / store.virtualCanvas.playAreaRect.height
            let minimumHeight = DemolitionTowerView.artworkHeight(
                slotWidth: minimumSlotWidth, assetName: "special_tower_level_4_branch_3")
            for elapsed in [0.0, 3.0, 7.0, 8.0] {
                var charge = DemolitionCharge(preparationSeconds: 8)
                charge.place(at: .zero)
                charge.detonate()
                charge.advance(seconds: elapsed)
                let renderer = ImageRenderer(content: DemolitionTowerView(
                    assetName: "special_tower_level_4_branch_3", charge: charge, height: minimumHeight)
                    .padding(.bottom, 8))
                renderer.scale = CGFloat(density)
                guard let data = renderer.uiImage?.pngData() else { throw NSError(domain: "ChargeReadinessReview", code: 5) }
                try data.write(to: directory.appendingPathComponent("tower-\(Int(elapsed))@\(density)x.png"))
            }
            let unplaced = DemolitionCharge(preparationSeconds: 8)
            for frame in 0..<32 {
                let elapsed = Double(frame) * DemolitionTowerView.pulsePeriod / 32
                let renderer = ImageRenderer(content: DemolitionTowerView(
                    assetName: "special_tower_level_4_branch_3", charge: unplaced, height: minimumHeight)
                    .artwork(readinessPulse: DemolitionTowerView.readinessPulse(at: elapsed))
                    .padding(.top, minimumHeight * DemolitionTowerView.pulseScaleAmplitude)
                    .padding(.horizontal, minimumSlotWidth * DemolitionTowerView.pulseScaleAmplitude / 2)
                    .padding(.bottom, 8))
                renderer.scale = CGFloat(density)
                guard let data = renderer.uiImage?.pngData() else { throw NSError(domain: "ChargeReadinessReview", code: 5) }
                try data.write(to: directory.appendingPathComponent("tower-pulse-\(frame)@\(density)x.png"))
            }
        }
        return ["sitePoint": [site.x, site.y], "kegSizePoints": [18, 22],
                "markerDiameterPoints": DemolitionGroundChargeSymbol.lightDiameter,
                "blinkPeriodSeconds": DemolitionGroundChargeSymbol.blinkPeriod, "capturedBlinkTimes": sampleTimes,
                "towerPulsePeriodSeconds": DemolitionTowerView.pulsePeriod,
                "towerPulsePeakScale": 1 + DemolitionTowerView.pulseScaleAmplitude,
                "capturedPulseTimes": pulseSampleTimes, "towerPoint": [towerPoint.x, towerPoint.y],
                "placementButtonPoint": [placementButtonPoint.x, placementButtonPoint.y],
                "placementButtonBottomCentered": true,
                "cooldownBoundaryVerified": true, "rearmsAfterDetonation": true]
    }
}
#endif
