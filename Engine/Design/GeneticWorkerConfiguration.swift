import Foundation

public struct GeneticWorkerConfiguration: Codable {
    public let runID: UUID
    public let levelID: UUID
    public let contentSHA256: String
    public let executableSHA256: String
    public let bountyFraction: Double
    public let money: Int
    public let maxSeconds: Double
    public let heroLoadout: GeneticHeroLoadout
}

