import XCTest
@testable import LevelEditorFormats

final class EngineerUpgradeMenuLayoutTests: XCTestCase {
    func testThreeSpecialtiesNeverOccupyTheBottomPlacementSeat() throws {
        let fixture = try AuthoredDatabaseFixture()
        let canvas = try fixture.db.virtualCanvasDao.get()
        let layout = TowerMenuLayout(virtualCanvas: canvas)
        for height: CGFloat in [340, 373, 790] {
            let scale = height / canvas.playAreaRect.height
            let size = layout.getTowerButtonSize(playAreaScalingFactor: scale)
            let center = CGPoint(x: 300, y: 180)
            let bottom = layout.getButtonSeatCenterPoint(index: 1, count: 2,
                menuCenterPoint: center, playAreaScalingFactor: scale)
            for count in 1...3 {
                var frames: [CGRect] = [CGRect(x: bottom.x - size.width / 2,
                    y: bottom.y - size.height / 2, width: size.width, height: size.height)]
                for index in 0..<count {
                    let point = layout.getEngineerUpgradeButtonCenterPoint(index: index, offerCount: count,
                        menuCenterPoint: center, playAreaScalingFactor: scale, towerButtonSize: size.width)
                    let frame = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                        width: size.width, height: size.height)
                    XCTAssertLessThanOrEqual(point.y, center.y + 0.001)
                    XCTAssertTrue(frames.allSatisfy { !$0.intersects(frame) })
                    frames.append(frame)
                }
            }
        }
    }
}
