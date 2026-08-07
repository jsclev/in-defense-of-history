import CoreGraphics
import Foundation

/// A tappable campaign event on the main campaign map.
struct CampaignNode: Identifiable {
    var id: Int
    var title: String

    /// The node's marker center, in the campaign map image's own pixel
    /// coordinates (see `CampaignMapAsset.imageSize`).
    var imagePosition: CGPoint

    /// The `level_info.id` this node opens. Links the map badge to the row the
    /// level view loads its path, tower slots, and playable rect from.
    var levelInfoID: UUID?

    /// Asset-catalog image for the level's map, and its pixel dimensions —
    /// the coordinate space the level's paths, tower slots, and playable rect
    /// are authored in. Keep the size in sync if the art is replaced.
    var mapImageName: String
    var mapImageSize: CGSize

    /// Whether the campaign artwork has a painted badge at `imagePosition`.
    /// The current art has none — every node draws its own badge and a
    /// generated callout label.
    var hasPaintedBadge: Bool = false
}

extension CampaignNode {
    /// Positions in `main_campaign_map_02` pixel space. The art is an
    /// oblique view with no painted labels, so rather than eyeballing each
    /// spot these were projected from the battles' real latitude/longitude
    /// through a fit against four coastline landmarks read off the
    /// artwork — Cape Cod's tip, the Hudson's mouth, Cape Charles, and the
    /// Savannah River's mouth — which reproduces those landmarks to within
    /// 14px. Redo that fit if the map art changes.
    /// (level_info.world_map_x/y still holds the previous art's numbers;
    /// nothing reads them.)
    static let all: [CampaignNode] = [
        CampaignNode(
            id: 1,
            title: "Lexington & Concord",
            imagePosition: CGPoint(x: 2189, y: 865),
            levelInfoID: UUID(uuidString: "be3cf809-f71e-4209-bc4d-8b25b0b5f2a0"),
            mapImageName: "level_001_lexington_and_concord",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 2,
            title: "Bunker Hill",
            imagePosition: CGPoint(x: 2203, y: 873),
            levelInfoID: UUID(uuidString: "9d692af7-345d-419a-bc04-16112c3f0b74"),
            mapImageName: "level_002_bunker_hill",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 3,
            title: "Great Bridge",
            imagePosition: CGPoint(x: 1822, y: 1192),
            levelInfoID: UUID(uuidString: "55a5d12d-3cea-475f-aa8d-125271a8a0c2"),
            mapImageName: "level_003_great_bridge",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 4,
            title: "Moore's Creek Bridge",
            imagePosition: CGPoint(x: 1682, y: 1322),
            levelInfoID: UUID(uuidString: "4cbeebf1-cd0c-4818-84b1-cb62f246d1ed"),
            mapImageName: "level_004_moores_creek_bridge",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 5,
            title: "Dorchester Heights",
            imagePosition: CGPoint(x: 2203, y: 877),
            levelInfoID: UUID(uuidString: "17914ebc-7052-490d-b606-afc1746da512"),
            mapImageName: "level_005_dorchester_heights",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 6,
            title: "Sullivan's Island",
            imagePosition: CGPoint(x: 1557, y: 1416),
            levelInfoID: UUID(uuidString: "35916460-914a-457b-beb9-1c5bfe95e61a"),
            mapImageName: "level_006_sullivans_island",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 7,
            title: "Long Island",
            imagePosition: CGPoint(x: 2001, y: 951),
            levelInfoID: UUID(uuidString: "99633efd-f135-44fc-8248-b8635a6db957"),
            mapImageName: "level_007_long_island",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 8,
            title: "Trenton",
            imagePosition: CGPoint(x: 1948, y: 971),
            levelInfoID: UUID(uuidString: "537aba11-6201-4fe9-b789-36607de98e41"),
            mapImageName: "level_008_trenton",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 9,
            title: "Princeton",
            imagePosition: CGPoint(x: 1956, y: 963),
            levelInfoID: UUID(uuidString: "9c6679ab-c028-48ab-95b7-93318f37c1a9"),
            mapImageName: "level_009_princeton",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 10,
            title: "Fort Ann",
            imagePosition: CGPoint(x: 2058, y: 767),
            levelInfoID: UUID(uuidString: "42e95fce-6da1-416d-bf69-24f70bb4dc52"),
            mapImageName: "level_010_fort_ann",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 11,
            title: "Saratoga",
            imagePosition: CGPoint(x: 2049, y: 788),
            levelInfoID: UUID(uuidString: "549a67d9-f721-4cdf-8ba7-8916ba71b040"),
            mapImageName: "level_011_saratoga",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 12,
            title: "Kettle Creek",
            imagePosition: CGPoint(x: 1400, y: 1330),
            levelInfoID: UUID(uuidString: "33d900c6-c6ff-409a-973b-f09ddc8a6f6a"),
            mapImageName: "level_012_kettle_creek",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 13,
            title: "New Haven",
            imagePosition: CGPoint(x: 2074, y: 921),
            levelInfoID: UUID(uuidString: "96170d0e-6983-47e0-bf80-93cd4c91ad3a"),
            mapImageName: "level_013_new_haven",
            mapImageSize: CGSize(width: 5760, height: 3240)
        ),
        CampaignNode(
            id: 14,
            title: "Savannah",
            imagePosition: CGPoint(x: 1471, y: 1445),
            levelInfoID: UUID(uuidString: "46157f59-b21b-4b03-9151-d404c6cd6d0b"),
            mapImageName: "level_014_savannah_bastion_v7",
            mapImageSize: CGSize(width: 1672, height: 940)
        ),
        CampaignNode(
            id: 15,
            title: "Siege of Charleston",
            imagePosition: CGPoint(x: 1551, y: 1413),
            levelInfoID: UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e"),
            mapImageName: "level_014_siege_of_charleston",
            mapImageSize: CGSize(width: 6240, height: 4320)
        ),
    ]
}
