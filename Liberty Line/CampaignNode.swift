import CoreGraphics
import Foundation

struct CampaignNode: Identifiable {
    var id: Int
    var title: String

    var imagePosition: CGPoint

    var levelInfoID: UUID?

    var mapImageName: String
}

extension CampaignNode {
    static let mainCampaignName = "Main"

    init(order: Int, level: CampaignLevel) {
        self.init(id: order,
                  title: level.name,
                  imagePosition: level.worldMapPosition,
                  levelInfoID: level.id,
                  mapImageName: level.mapImageName)
    }

    static func load(db: Db, campaignName: String = mainCampaignName) -> [CampaignNode] {
        do {
            let levels = try db.levelInfoDao.getCampaignLevels(campaignName: campaignName)
            guard !levels.isEmpty else {
                throw DbError.Db(message: "campaign[\(campaignName)]: missing authored levels")
            }
            return levels.enumerated().map { CampaignNode(order: $0.offset + 1, level: $0.element) }
        } catch {
            fatalError("Campaign map database error: \(error)")
        }
    }
}
