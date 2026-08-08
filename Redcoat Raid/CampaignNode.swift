import CoreGraphics
import Foundation

struct CampaignNode: Identifiable {
    var id: Int
    var title: String

    var imagePosition: CGPoint

    var levelInfoID: UUID?

    var mapImageName: String
    var mapImageSize: CGSize
}

extension CampaignNode {
    static let mainCampaignName = "Main"

    init(order: Int, level: CampaignLevel) {
        self.init(id: order,
                  title: level.name,
                  imagePosition: level.worldMapPosition,
                  levelInfoID: level.id,
                  mapImageName: level.mapImageName,
                  mapImageSize: level.mapImageSize)
    }

    static func load(campaignName: String = mainCampaignName) -> [CampaignNode] {
        let db = Db(
            dbPath: Db.getAbsolutePathToDb(dbFilename: "redcoat_raid", fullRefresh: true),
            fullRefresh: true
        )
        let levels = (try? db.levelInfoDao.getCampaignLevels(campaignName: campaignName)) ?? []
        return levels.enumerated().map { CampaignNode(order: $0.offset + 1, level: $0.element) }
    }
}
