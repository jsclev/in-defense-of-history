
import Foundation
import SwiftUI
import AppKit
import Combine
import LevelEditorFormats

final class LevelRunner: ObservableObject {
    struct Clock { var tick: Int64 = 0 }
    var timer = Clock()
    var isReady = true
    var isDefeated = false
    var isCleared = false
    var money = 123
    var selectedHeroIndex: Int?
    var menuDismissals = 0
    var heroPublications = 0
    func dismissMenu() { menuDismissals += 1 }
    func publishHeroes() { heroPublications += 1 }
    func isOnPath(_ point: CGPoint) -> Bool {
        let target = Point(Double(point.x), Double(point.y))
        let reach = virtualCanvas.pathWidth / 2
        for path in paths {
            let nearest = path.point(atDistance: path.nearestDistance(to: target))
            if nearest.distance(to: target) <= reach { return true }
        }
        return false
    }
    var virtualCanvas: VirtualCanvas!
    var paths: [LevelEditorFormats.Path] = []
    var hudHeroes: [Hero] { [] }
    func hudHeroIndex(for id: UUID) -> Int? { nil }
    func selectHero(heroID: UUID) {}
    func load(_ db: Db, level: String) throws {
        virtualCanvas = try db.virtualCanvasDao.get()
        paths = try db.pathDao.getPathsFor(levelInfoId: db.levelInfoDao.getIdBy(levelName: level)!)
        towerLevels = Dictionary(uniqueKeysWithValues: try db.towerTypeDao.getTowerLevelsByBranch().compactMap { k,v in TowerKind(categoryName: k).map { ($0,v) } })
        reinforcementSchedule = ReinforcementSchedule(config: try db.reinforcementConfigDao.get())
    }
    private let meleeFormation = MeleeFormation()
    private static let reinforcementCount = 2
    private var nextReinforcementSlot = -1
    private var reinforcementSchedule: ReinforcementSchedule?
    @Published var reinforcementCooldown: ReinforcementCooldown = .ready
    @Published var isPlacingReinforcements = false
    private var garrisonsBySlot: [Int: MilitiaGarrison] = [:]
    @Published var militia: [MilitiaSoldier] = []
    private var militiaPrevPositions: [Int: CGPoint] = [:]
    private var militiaPoses: [Int: WalkPose] = [:]
    private var militiaRespawnedIDs: Set<Int> = []
    private var blockedWalkerIDs: Set<Int> = []
    private var damageTotalBySlot: [Int: Double] = [:]
    struct HeroFixture { var unit: MilitiaUnit }
    private var heroPosts: [HeroFixture] = []
    struct TowerFixture { var position: CGPoint = .zero }
    func placedTower(atSlot slot: Int) -> TowerFixture? { slot >= 0 ? TowerFixture() : nil }
    func towerLevel(for tower: TowerFixture) -> TowerLevel? { towerLevels[.melee]?[1]?[1] }
    var towerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [.melee: [1: [1:
        TowerLevel(cost: 100, range: 100, fireInterval: 1,
            meleeUnit: MeleeUnitStats(soldierCount: 2, attackRating: 5,
                defenseRating: 0, hp: 50, rallyPointRadius: 100, attackInterval: 1,
                respawnSeconds: 5, healPerSecond: 0))]]]

    init(lifetime: Double = 20, cooldown: Double = 20) throws {
        reinforcementSchedule = ReinforcementSchedule(config:
            try ReinforcementConfig(timeToLiveSeconds: lifetime, cooldownSeconds: cooldown))
    }
    func advance(to seconds: Int) {
        timer.tick = Int64(seconds * SimClock.ticksPerSecond)
        advanceReinforcements()
    }
    struct MilitiaSoldier: Identifiable {
        let id: Int
        let assetName: String
        var position: CGPoint
        var hp: Double
        var maxHP: Double
    }
private struct MilitiaGarrison {
        var rallyPoint: Point
        var units: [MilitiaUnit]
        var enemySwingTicks: [Int: Int] = [:]
        var stats: MeleeUnitStats? = nil
        var anchor: Point? = nil
    }
private struct WalkPose {
        var facing: UnitFacing
        var walkPhase: Double
        var isWalking: Bool
    }
var canCallReinforcements: Bool {
        isReady && !isDefeated && !isCleared && reinforcementStats != nil
            && reinforcementSchedule?.cooldown(at: timer.tick).isReady == true
    }
private var reinforcementStats: MeleeUnitStats? {
        guard let levels = towerLevels[.melee] else { return nil }
        for level in levels.keys.sorted() {
            guard let branches = levels[level] else { continue }
            for branch in branches.keys.sorted() {
                if let melee = branches[branch]?.meleeUnit { return melee }
            }
        }
        return nil
    }
private func garrisonMelee(slot: Int,
                               garrison: MilitiaGarrison) -> (stats: MeleeUnitStats,
                                                              anchor: Point)? {
        if let stats = garrison.stats, let anchor = garrison.anchor {
            return (stats, anchor)
        }
        guard let tower = placedTower(atSlot: slot),
              let stats = towerLevel(for: tower)?.meleeUnit else { return nil }
        return (stats, Point(Double(tower.position.x), Double(tower.position.y)))
    }
func callReinforcements(at point: CGPoint) -> Bool {
        guard canCallReinforcements, let melee = reinforcementStats,
              reinforcementSchedule?.deploy(slot: nextReinforcementSlot, at: timer.tick) == true
        else { return false }
        let anchor = Point(Double(point.x), Double(point.y))
        garrisonsBySlot[nextReinforcementSlot] = MilitiaGarrison(
            rallyPoint: anchor,
            units: (0..<Self.reinforcementCount).map { index in
                MilitiaUnit(position: meleeFormation.spawnPoint(
                    index: index, of: Self.reinforcementCount, building: anchor),
                            hp: melee.hp)
            },
            stats: melee,
            anchor: anchor)
        nextReinforcementSlot -= 1
        isPlacingReinforcements = false
        reinforcementCooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        publishMilitia()
        return true
    }
func toggleReinforcementPlacement() {
        guard canCallReinforcements else { return }
        dismissMenu()
        if selectedHeroIndex != nil {
            selectedHeroIndex = nil
            publishHeroes()
        }
        isPlacingReinforcements.toggle()
    }
func placeReinforcements(at point: CGPoint) {
        guard isPlacingReinforcements, isOnPath(point) else { return }
        callReinforcements(at: point)
    }
private func advanceReinforcements() {
        guard let expired = reinforcementSchedule?.expire(at: timer.tick) else { return }
        let cooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        if reinforcementCooldown != cooldown { reinforcementCooldown = cooldown }
        guard !expired.isEmpty else { return }
        for slot in expired {
            guard let garrison = garrisonsBySlot.removeValue(forKey: slot) else { continue }
            for index in garrison.units.indices {
                let id = slot * 8 + index
                militiaPrevPositions[id] = nil
                militiaPoses[id] = nil
                militiaRespawnedIDs.remove(id)
            }
            damageTotalBySlot[slot] = nil
        }
        // Release expired soldiers' targets before walkers move this frame.
        // Preserve any blocks still held by a tower soldier or hero.
        let fightingUnits = garrisonsBySlot.values.flatMap(\.units) + heroPosts.map(\.unit)
        blockedWalkerIDs = Set(fightingUnits.filter { $0.state == .fighting && $0.targetSpawnID >= 0 }
            .map(\.targetSpawnID))
        // Publish even when the last garrison expired, clearing its sprites.
        publishMilitia()
    }
private func publishMilitia(alpha: Double = 1) {
        var out: [MilitiaSoldier] = []
        for slot in garrisonsBySlot.keys.sorted() {
            guard let g = garrisonsBySlot[slot],
                  let resolved = garrisonMelee(slot: slot, garrison: g)
            else { continue }
            let melee = resolved.stats
            for (i, u) in g.units.enumerated() where u.state != .dead {
                let id = slot * 8 + i
                let cur = CGPoint(x: u.position.x, y: u.position.y)
                let prev = militiaPrevPositions[id] ?? cur
                let pose = militiaPoses[id]
                    ?? WalkPose(facing: .south, walkPhase: 0, isWalking: false)
                let stepDistance = hypot(Double(cur.x - prev.x),
                                         Double(cur.y - prev.y))
                let renderedPhase = MeleeWalkCycle.interpolatedPhase(
                    currentPhase: pose.walkPhase,
                    stepDistance: stepDistance,
                    alpha: alpha,
                    cycleDistance: MeleeWalkCycle.cycleDistance)
                out.append(MilitiaSoldier(
                    id: id,
                    assetName: MeleeWalkCycle.assetName(facing: pose.facing,
                                                        walkPhase: renderedPhase,
                                                        isWalking: pose.isWalking),
                    position: CGPoint(x: prev.x + (cur.x - prev.x) * alpha,
                                      y: prev.y + (cur.y - prev.y) * alpha),
                    hp: u.hp,
                    maxHP: melee.hp))
            }
        }
        militia = out
    }

    static func run() throws {
        let point = CGPoint(x: 120, y: 180)
        let placement = try LevelRunner()
        // Path taps are inert until the HUD button arms deployment.
        placement.placeReinforcements(at: point)
        precondition(placement.militia.isEmpty)
        placement.selectedHeroIndex = 0
        placement.toggleReinforcementPlacement()
        precondition(placement.isPlacingReinforcements && placement.militia.isEmpty)
        precondition(placement.selectedHeroIndex == nil && placement.menuDismissals == 1)
        placement.placeReinforcements(at: .zero)
        precondition(placement.militia.isEmpty && placement.isPlacingReinforcements)
        placement.toggleReinforcementPlacement()
        precondition(!placement.isPlacingReinforcements && placement.reinforcementCooldown.isReady)
        placement.toggleReinforcementPlacement()
        placement.placeReinforcements(at: point)
        precondition(placement.militia.count == 2 && !placement.isPlacingReinforcements)
        placement.toggleReinforcementPlacement()
        placement.placeReinforcements(at: point)
        precondition(placement.militia.count == 2 && !placement.isPlacingReinforcements)
        placement.advance(to: 20)
        placement.toggleReinforcementPlacement()
        placement.placeReinforcements(at: point)
        precondition(placement.militia.count == 2 && !placement.isPlacingReinforcements)
        let single = try LevelRunner()
        precondition(single.callReinforcements(at: point))
        precondition(single.militia.count == 2)
        precondition(single.militia.allSatisfy { $0.position == point })
        for _ in 0..<20 { precondition(!single.callReinforcements(at: .zero)) }
        precondition(single.garrisonsBySlot.count == 1 && single.nextReinforcementSlot == -2)
        single.garrisonsBySlot[-1]!.units[0].state = .fighting
        single.garrisonsBySlot[-1]!.units[0].targetSpawnID = 99
        single.blockedWalkerIDs = [99]
        single.militiaPrevPositions[-8] = point
        single.militiaPoses[-8] = WalkPose(facing: .south, walkPhase: 0, isWalking: false)
        single.militiaRespawnedIDs = [-8]
        single.damageTotalBySlot[-1] = 10
        single.advance(to: 19)
        precondition(single.militia.count == 2 && !single.canCallReinforcements)
        single.advance(to: 20)
        precondition(single.militia.isEmpty && single.garrisonsBySlot.isEmpty)
        precondition(single.blockedWalkerIDs.isEmpty && single.militiaPrevPositions.isEmpty)
        precondition(single.militiaPoses.isEmpty && single.militiaRespawnedIDs.isEmpty)
        precondition(single.damageTotalBySlot.isEmpty && single.money == 123)
        precondition(single.canCallReinforcements && single.reinforcementCooldown.isReady)
        precondition(single.callReinforcements(at: point))
        precondition(single.militia.count == 2 && !single.canCallReinforcements)

        let overlap = try LevelRunner(lifetime: 30, cooldown: 20)
        precondition(overlap.callReinforcements(at: point))
        overlap.advance(to: 20)
        precondition(overlap.callReinforcements(at: .zero))
        precondition(overlap.militia.count == 4)
        var towerUnit = MilitiaUnit(position: Point(5, 5), hp: 50)
        towerUnit.state = .fighting
        towerUnit.targetSpawnID = 100
        overlap.garrisonsBySlot[0] = MilitiaGarrison(rallyPoint: Point(5, 5), units: [towerUnit])
        var heroUnit = towerUnit
        heroUnit.targetSpawnID = 101
        overlap.heroPosts = [HeroFixture(unit: heroUnit)]
        overlap.blockedWalkerIDs = [99, 100, 101]
        overlap.advance(to: 30)
        precondition(overlap.garrisonsBySlot[-1] == nil && overlap.garrisonsBySlot[-2] != nil)
        precondition(overlap.militia.count == 3 && overlap.blockedWalkerIDs == [100, 101])
        overlap.advance(to: 50)
        precondition(overlap.militia.map(\.id) == [0] && overlap.garrisonsBySlot.count == 1)
        precondition(overlap.heroPosts.count == 1 && overlap.blockedWalkerIDs == [100, 101])

        let dead = try LevelRunner(lifetime: 5, cooldown: 20)
        precondition(dead.callReinforcements(at: point))
        for i in 0..<2 {
            dead.garrisonsBySlot[-1]!.units[i].state = .dead
            dead.garrisonsBySlot[-1]!.units[i].respawnTicksLeft = 100
        }
        dead.advance(to: 5)
        precondition(dead.garrisonsBySlot.isEmpty && dead.militia.isEmpty)
        precondition(!dead.canCallReinforcements)
        dead.advance(to: 200)
        precondition(dead.garrisonsBySlot.isEmpty && dead.militia.isEmpty)

        for state in 0..<4 {
            let unavailable = try LevelRunner()
            if state == 0 { unavailable.isReady = false }
            if state == 1 { unavailable.isDefeated = true }
            if state == 2 { unavailable.isCleared = true }
            if state == 3 { unavailable.towerLevels = [:] }
            precondition(!unavailable.callReinforcements(at: point))
            precondition(unavailable.garrisonsBySlot.isEmpty && unavailable.reinforcementCooldown.isReady)
        }
        print("PASS: HUD arm/cancel/place, invalid path, cooldown gating, runner deployment, repeated taps, expiry cleanup, dead groups, overlapping groups, tower/hero preservation, unavailable states")
    }
}

import SwiftUI

struct HeroHUDButton: View {
    let iconName: String
    let name: String
    let buttonSize: CGFloat
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(nsImage: Probe.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(nsImage: Probe.art(iconName))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize * 0.75, height: buttonSize * 0.75)
                    .grayscale(isAvailable ? 0 : 1)
            }
            .frame(width: buttonSize, height: buttonSize)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HeroHUDButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private struct HeroHUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

import SwiftUI

struct ReinforcementButton: View {
    let buttonSize: CGSize
    let cooldown: ReinforcementCooldown
    let isAvailable: Bool
    let action: () -> Void
    var isSelected = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(nsImage: Probe.art("tower_menu_square_frame"))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                Image(nsImage: Probe.art("action_icon_call_reinforcements"))
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize.width * 0.75, height: buttonSize.height * 0.75)
                    .grayscale(cooldown.isReady ? 0 : 1)
                if !cooldown.isReady {
                    cooldownOverlay
                }
            }
            .frame(width: buttonSize.width, height: buttonSize.height)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: buttonSize.width * 0.08)
                        .strokeBorder(.white, lineWidth: buttonSize.width * 0.04)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ReinforcementButtonStyle())
        .disabled(!isAvailable)
        .accessibilityLabel("Call reinforcements")
        .accessibilityValue(cooldown.isReady ? "Ready" : "\(cooldown.displaySeconds) seconds remaining")
    }

    private var cooldownOverlay: some View {
        // Keep the colored frame exposed. All progress stays inside a fixed
        // image box, so changing the countdown cannot affect menu/map layout.
        let width = buttonSize.width * 0.78
        let height = buttonSize.height * 0.78
        let remainingHeight = height * cooldown.remainingFraction
        let boundary = height - remainingHeight
        let labelHeight = buttonSize.height * 0.34
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55)
                .frame(width: width, height: remainingHeight)
                .offset(y: boundary)
            Text("\(cooldown.displaySeconds)")
                .font(.system(size: max(12, buttonSize.height * 0.26), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, buttonSize.width * 0.06)
                .frame(height: labelHeight)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: buttonSize.width * 0.06))
                .position(x: width / 2,
                          y: labelHeight / 2 + (height - labelHeight) * (1 - cooldown.remainingFraction))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: buttonSize.width * 0.04))
        .allowsHitTesting(false)
    }
}

private struct ReinforcementButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Availability changes the icon/overlay only, preserving the frame.
        configuration.label
    }
}

import SwiftUI

struct HudHeroesBarView: View {
    let layout: HeroBarLayout
    @ObservedObject var runner: LevelRunner

    var body: some View {
        let heroes = runner.hudHeroes
        HStack(spacing: layout.buttonSpacing) {
            ForEach(0..<2, id: \.self) { index in
                let hero = heroes.indices.contains(index) ? heroes[index] : nil
                let unitIndex = hero.flatMap { runner.hudHeroIndex(for: $0.id) }
                let role: HeroSelection.Role = index == 0 ? .primary : .secondary
                HeroHUDButton(iconName: hero?.iconImageName ?? "tower_locked_icon",
                              name: hero.map { "\(role.title), \($0.shortName), ranking \($0.ranking)" }
                                ?? "No \(role.title.lowercased()) chosen",
                              buttonSize: layout.buttonSize,
                              isAvailable: unitIndex != nil,
                              isSelected: unitIndex != nil && unitIndex == runner.selectedHeroIndex) {
                    if let hero { runner.selectHero(heroID: hero.id) }
                }
            }
            ReinforcementButton(buttonSize: CGSize(width: layout.buttonSize, height: layout.buttonSize),
                                cooldown: runner.reinforcementCooldown,
                                isAvailable: runner.canCallReinforcements,
                                action: { runner.toggleReinforcementPlacement() },
                                isSelected: runner.isPlacingReinforcements)
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
    }
}

import SwiftUI

/// Mounted above the level's ordinary content and HUD. Each entry creates its
/// own view subtree, with the most recently opened presentation drawn last.
/// An empty stack has no presentation views or input catchers.
struct PresentationLayers<Presentation: Equatable, LayerContent: View>: View {
    let stack: PresentationStack<Presentation>
    @ViewBuilder let content: (Presentation) -> LayerContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(stack.entries) { entry in
                ZStack(alignment: .topLeading) {
                    content(entry.content)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.identity)
            }
        }
    }
}

struct LevelMapProjection {
    /// The virtual canvas, from virtual_canvas. Map artwork is required to be
    /// exactly this size, so the projection never asks the image.
    var canvasSize: CGSize { virtualCanvas.size }
    let playArea: CGRect
    let fitRect: CGRect
    let virtualCanvas: VirtualCanvas

    var scale: CGFloat {
        min(fitRect.width / playArea.width, fitRect.height / playArea.height)
    }

    private var origin: CGPoint {
        // y is flipped by viewPoint, so the rect's centre is measured from the
        // top of the canvas here. Written out rather than relying on the rect
        // happening to be vertically centred.
        CGPoint(
            x: fitRect.midX - playArea.midX * scale,
            y: fitRect.midY - (canvasSize.height - playArea.midY) * scale
        )
    }

    /// Canonical (lower-left origin, +y up) to SwiftUI view space (+y down).
    /// The only place the game flips.
    func viewPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale,
                y: origin.y + (canvasSize.height - p.y) * scale)
    }

    func viewLength(_ l: CGFloat) -> CGFloat { l * scale }

    func mapPoint(_ v: CGPoint) -> CGPoint {
        CGPoint(x: (v.x - origin.x) / scale,
                y: canvasSize.height - (v.y - origin.y) / scale)
    }

    var viewTransform: CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
                          tx: origin.x, ty: origin.y + canvasSize.height * scale)
    }

    var imageFrameSize: CGSize {
        CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    var imageCenter: CGPoint {
        viewPoint(CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
    }
}
struct InputScene: View {
    @ObservedObject var runner: LevelRunner
    let runtimeCanvas: RuntimeCanvas
    @State private var stack = PresentationStack<Bool>()
    var body: some View {
        let projection = LevelMapProjection(playArea: runtimeCanvas.virtualCanvas.playAreaRect, fitRect: runtimeCanvas.playAreaRect, virtualCanvas: runtimeCanvas.virtualCanvas)
        let layout = HeroBarLayout(runtimeCanvas: runtimeCanvas)
        LevelViewport(size: runtimeCanvas.physicalRect.size) {
            Color.green
        } interface: {
            HudHeroesBarView(layout: layout, runner: runner).position(x: layout.frame.midX,y: layout.frame.midY)
        } presentations: {
            PresentationLayers(stack: stack) { _ in
                destinationCatcher(projection: projection) { runner.placeReinforcements(at: $0) }
            }
        }
        .onChange(of: runner.isPlacingReinforcements, initial: true) { _,active in stack.synchronize(active ? [true] : []) }
    }
private func destinationCatcher(projection: LevelMapProjection,
                                    action: @escaping (CGPoint) -> Void) -> some View {
        // Capture map commands while keeping all reserved HUD corners tappable.
        let area = SwiftUI.Path(runtimeCanvas.runtimePlayArea)
        return area
            .fill(Color.black.opacity(0.001))
            .contentShape(area)
            .frame(width: runtimeCanvas.physicalRect.width,
                   height: runtimeCanvas.physicalRect.height, alignment: .topLeading)
            .gesture(SpatialTapGesture().onEnded { value in
                action(projection.mapPoint(value.location))
            })
    }
}

@main struct Probe {
    @MainActor static func art(_ name: String) -> NSImage {
        let folder = URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/\(name).imageset")
        let contents = try! JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("Contents.json"))) as! [String:Any]
        let entry = (contents["images"] as! [[String:Any]]).first { $0["filename"] != nil }!
        return NSImage(contentsOf: folder.appendingPathComponent(entry["filename"] as! String))!
    }
    @MainActor static func flush() { RunLoop.main.run(until: Date(timeIntervalSinceNow:0.10)) }
    @MainActor static func main() throws {
        let app=NSApplication.shared;app.setActivationPolicy(.accessory);app.finishLaunching()
        let db=Db(dbPath:"/tmp/td-reinforcement-installed.sqlite",fullRefresh:false)
        let runner=try LevelRunner();try runner.load(db,level:"Battle Road")
        let rect=CGRect(x:0,y:0,width:874,height:402)
        let runtime=RuntimeCanvas(virtualCanvas:runner.virtualCanvas,physicalRect:rect,safeInsetsRect:CGRect(x:62,y:0,width:750,height:382))
        let projection=LevelMapProjection(playArea:runner.virtualCanvas.playAreaRect,fitRect:runtime.playAreaRect,virtualCanvas:runner.virtualCanvas)
        let host=NSHostingView(rootView:InputScene(runner:runner,runtimeCanvas:runtime))
        let window=NSWindow(contentRect:rect,styleMask:[.borderless],backing:.buffered,defer:false)
        window.contentView=host;window.makeKeyAndOrderFront(nil);host.layoutSubtreeIfNeeded();flush()
        defer { window.orderOut(nil) }
        var eventNumber=0
        func press(_ point: CGPoint) {
            let location=CGPoint(x:point.x,y:rect.height-point.y)
            for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
                eventNumber += 1
                let event=NSEvent.mouseEvent(with:type,location:location,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:eventNumber,clickCount:1,pressure:type == .leftMouseDown ? 1:0)!
                window.sendEvent(event);flush()
            }
        }
        let layout=HeroBarLayout(runtimeCanvas:runtime)
        let hud=CGPoint(x:layout.frame.minX+layout.buttonSize/2+2*(layout.buttonSize+layout.buttonSpacing),y:layout.frame.midY)
        let point=runner.paths.flatMap(\.points).map { CGPoint(x:$0.x,y:$0.y) }.first { runtime.runtimePlayArea.contains(projection.viewPoint($0)) && abs(projection.viewPoint($0).x-rect.midX)<80 }!
        print("ready \(runner.canCallReinforcements); button \(hud); road \(point), screen \(projection.viewPoint(point))")
        press(hud);print("after HUD tap: selected=\(runner.isPlacingReinforcements)")
        precondition(runner.isPlacingReinforcements,"HUD failed to select")
        press(projection.viewPoint(point));print("after road tap: selected=\(runner.isPlacingReinforcements), soldiers=\(runner.militia.count), cooldown=\(runner.reinforcementCooldown)")
        precondition(runner.militia.count == 2,"Road tap failed to deploy")
        print("PASS actual HUD pointer → production destination catcher → database road → two soldiers")
    }
}
