import Foundation

public struct Hero: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let shortName: String
    public let longName: String
    public let nickname: String?
    public let unlockedAtLevelId: UUID?
    public let unlockedAtLevelName: String?
    public let unlockedAtCampaignName: String?
    public let unlockedAtWave: Int
    public let unlocked: Bool
    public let fromMiniCampaign: Bool
    public let generalDescription: String
    public let historicalDescription: String
    public let historicalText: String
    public let primaryImageName: String
    public let detailsImageName: String
    public let iconImageName: String
    public let abilityIconImageName: String

    public init(
        id: UUID,
        shortName: String,
        longName: String,
        nickname: String?,
        unlockedAtLevelId: UUID?,
        unlockedAtLevelName: String?,
        unlockedAtCampaignName: String?,
        unlockedAtWave: Int,
        unlocked: Bool,
        fromMiniCampaign: Bool,
        generalDescription: String,
        historicalDescription: String,
        historicalText: String,
        primaryImageName: String,
        detailsImageName: String,
        iconImageName: String,
        abilityIconImageName: String
    ) {
        self.id = id
        self.shortName = shortName
        self.longName = longName
        self.nickname = nickname
        self.unlockedAtLevelId = unlockedAtLevelId
        self.unlockedAtLevelName = unlockedAtLevelName
        self.unlockedAtCampaignName = unlockedAtCampaignName
        self.unlockedAtWave = unlockedAtWave
        self.unlocked = unlocked
        self.fromMiniCampaign = fromMiniCampaign
        self.generalDescription = generalDescription
        self.historicalDescription = historicalDescription
        self.historicalText = historicalText
        self.primaryImageName = primaryImageName
        self.detailsImageName = detailsImageName
        self.iconImageName = iconImageName
        self.abilityIconImageName = abilityIconImageName
    }
}
