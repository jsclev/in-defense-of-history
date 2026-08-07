import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

public struct Constants {
    public static let gameType = GameType.AIOneTurn
    public static let appIdentifier = "com.zippyzen.td"
    public static let headless = true
    public static let runMode = RunMode.Debug
    public static let uiRunMode = RunMode.Replay
//    public static let db = Db(dbPath: Db.getAbsolutePathToDb(dbFilename: "game", fullRefresh: false), fullRefresh: false)
    public static let heightInTiles = 61
    public static let widthInTiles = 80
    public static let skin = "Upgraded"
    public static let numConsecutiveTurns = 10
    public static let noId = -1
    public static let tiledMapFilename = "earth-map"
    public static let tiledTilesetName = "map"
    public static let tiledMapExtension = "tmx"
    public static let tiledTilesetExtension = "tsx"
    public static let minDefense: Double = 0.001
    public static let minMovementCost: Double = 0.0
    public static let mapWidth: CGFloat = 1000.0 / 3.0
    public static let mapHeight: CGFloat = 1000.0 / 3.0
    public static let noScore = 0.0
    public static let riverTiledId = 50
    public static let maxCommandCost = 1000000.0
    public static let maxUtility = 100.0
    public static let numAITurns = 441
    
    // Scale and zoom are different
    // Zoom grows logarithmically to scale
    // Having zoom level is necessary in animations because animations need to have linear control over the map
    public static let minScale = 0.4
    public static let maxScale = CGSize(width: 512, height: 286).width / 20.0
    public static let minZoom = log2(Constants.minScale)
    public static let maxZoom = log2(Constants.maxScale)
    
    #if canImport(UIKit)
    
    #if os(visionOS)
    public static let maxFps = 90
    #else
    public static let maxFps = UIScreen.main.maximumFramesPerSecond
    #endif
    
    #else
    public static let maxFps: Int = {
        if let mode = CGDisplayCopyDisplayMode(CGMainDisplayID())
        {
            return Int(mode.refreshRate)
        }
        return 60
    }()
    #endif
    
    public static let rubberBandClampCoefficient: CGFloat = 0.3
    public static let mapMomentumPanDecelerationConstant: CGFloat = 0.996
    public static let mapMomentumPanSpringMass: CGFloat = 22

    public static let mapMomentumScaleDecelerationConstant: CGFloat = 0.985
    public static let mapMomentumScaleSpringMass: CGFloat = 25
    
    // Max time allowed between both fingers leaving screen for it to still be considered part of the scale gesture
    public static let mapMomentumScaleGestureMaxTimeDifference = 0.15

    public static let terrainTypes: [String: TerrainType] = [
        "0": TerrainType.Grassland,
        "1": TerrainType.Forest,
        "2": TerrainType.Forest,
        "3": TerrainType.Forest,
        "4": TerrainType.Forest,
        "5": TerrainType.Forest,
        "6": TerrainType.Forest,
        "7": TerrainType.Forest,
        "8": TerrainType.Forest,
        "9": TerrainType.Forest,
        "10": TerrainType.Forest,
        "11": TerrainType.Forest,
        "12": TerrainType.Forest,
        "13": TerrainType.Forest,
        "14": TerrainType.Forest,
        "15": TerrainType.Forest,
        "16": TerrainType.Forest,
        "17": TerrainType.Mountains,
        "18": TerrainType.Mountains,
        "19": TerrainType.Hills,
        "20": TerrainType.Forest,
        "21": TerrainType.Desert,
        "22": TerrainType.Jungle,
        "23": TerrainType.Swamp,
        "24": TerrainType.Ocean,
        "47": TerrainType.Glacier,
        "48": TerrainType.Glacier,
        "49": TerrainType.Plains,
        "52": TerrainType.Tundra,
        "53": TerrainType.Forest,
        "54": TerrainType.Jungle,
        "55": TerrainType.Mountains,
        "56": TerrainType.Hills
    ]
    
    public static let tiledResources: [String: ResourceType] = [
        "28": ResourceType.Wine,
        "29": ResourceType.Wheat,
        "30": ResourceType.Whales,
        "31": ResourceType.Spice,
        "32": ResourceType.Silk,
        "33": ResourceType.Pheasant,
        "34": ResourceType.Peat,
        "35": ResourceType.Oil,
        "36": ResourceType.Oasis,
        "37": ResourceType.Ivory,
        "38": ResourceType.Iron,
        "39": ResourceType.Gold,
        "40": ResourceType.Gems,
        "41": ResourceType.Game,
        "42": ResourceType.Furs,
        "43": ResourceType.Fruit,
        "44": ResourceType.Fish,
        "45": ResourceType.Coal,
        "46": ResourceType.Buffalo,
        "58": ResourceType.Production
    ]
    
    public static let tiles: [String: String] = [
        "0": "Grass",
        "1": "Forest",
        "2": "Forest",
        "3": "Forest",
        "4": "Forest",
        "5": "Forest",
        "6": "Forest",
        "7": "Forest",
        "8": "Forest",
        "9": "Forest",
        "10": "Forest",
        "11": "Forest",
        "12": "Forest",
        "13": "Forest",
        "14": "Forest",
        "15": "Forest",
        "16": "Forest",
        "17": "Mountain",
        "18": "Mountain",
        "19": "Hills",
        "20": "Forest",
        "21": "Forest",
        "22": "Forest",
        "23": "Forest",
        "24": "Water",
        "25": "Tank",
        "26": "Battleship",
        "27": "Explorer",
        "53": "Forest",
        "54": "Jungle",
        "55": "Mountain",
        "56": "Hills",
    ]
}

public struct Events {
    public static let START_GAME = "Start Game"
    public static let PLAYER_TOGGLE_TECH_TREE = "Toggle Tech Tree"
    public static let PLAYER_RESEARCH_TECH = "Research Tech"
    public static let CITY_CREATE_WORKER1 = "City: Create Worker1"
    public static let CITY_CREATE_WORKER2 = "City: Create Worker2"
    public static let CITY_CREATE_INFANTRY1 = "City: Create Infantry1"
    public static let CITY_CREATE_INFANTRY2 = "City: Create Infantry2"
    public static let CITY_CREATE_INFANTRY3 = "City: Create Infantry3"
    public static let CITY_CREATE_INFANTRY4 = "City: Create Infantry4"
    public static let CITY_CREATE_INFANTRY5 = "City: Create Infantry5"
    public static let CITY_CREATE_INFANTRY6 = "City: Create Infantry6"
    public static let CITY_CREATE_INFANTRY7 = "City: Create Infantry7"
    public static let CITY_CREATE_INFANTRY8 = "City: Create Infantry8"
    public static let CITY_CREATE_CAVALRY1 = "City: Create Cavalry1"
    public static let CITY_CREATE_CAVALRY2 = "City: Create Cavalry2"
    public static let CITY_CREATE_CAVALRY3 = "City: Create Cavalry3"
    public static let CITY_CREATE_CAVALRY4 = "City: Create Cavalry4"
    public static let CITY_CREATE_CAVALRY5 = "City: Create Cavalry5"
    public static let CITY_CREATE_CAVALRY6 = "City: Create Cavalry6"
    public static let CITY_CREATE_CAVALRY7 = "City: Create Cavalry7"
    public static let CITY_CREATE_CAVALRY8 = "City: Create Cavalry8"
    public static let CITY_CREATE_NAVAL1 = "City: Create Naval1"
    public static let CITY_CREATE_NAVAL2 = "City: Create Naval2"
    public static let CITY_CREATE_NAVAL3 = "City: Create Naval3"
    public static let CITY_CREATE_NAVAL4 = "City: Create Naval4"
    public static let CITY_CREATE_NAVAL5 = "City: Create Naval5"
    public static let CITY_CREATE_NAVAL6 = "City: Create Naval6"
    public static let CITY_CREATE_NAVAL7 = "City: Create Naval7"
    public static let CITY_CREATE_NAVAL8 = "City: Create Naval8"
    public static let CITY_BUILD_BARRACKS = "City: Build Barracks"
    public static let CITY_BUILD_GRANARY = "City: Build Granary"
    public static let WORKER_CREATE_CITY = "Worker: Create City"
    public static let WORKER_BUILD_ROAD = "Worker: Build Road"
    public static let MOVE_UNIT = "Move Unit"
    public static let NEXT_TURN = "End Turn"
    public static let PAUSE_GAME = "Pause Game"
    public static let PROCESS_MULTIPLE_TURNS = "Process Multiple Turns"
    public static let PROCESS_ALL_TURNS = "Process All Turns"
    public static let TOGGLE_AI_DEBUG = "Toggle AI Debug"
    public static let TOGGLE_TILE_COORDS = "Toggle Tile Coords"
    public static let TOGGLE_FOG_OF_WAR = "Toggle Fog of War"
    public static let TOGGLE_PLAYER1_VIEWPOINT = "Toggle Player 1 Viewpoint"
    public static let TOGGLE_PLAYER2_VIEWPOINT = "Toggle Player 2 Viewpoint"
    public static let TOGGLE_PLAYER3_VIEWPOINT = "Toggle Player 3 Viewpoint"
    public static let TOGGLE_PLAYER4_VIEWPOINT = "Toggle Player 4 Viewpoint"
    public static let TOGGLE_PLAYER5_VIEWPOINT = "Toggle Player 5 Viewpoint"
    public static let TOGGLE_PLAYER6_VIEWPOINT = "Toggle Player 6 Viewpoint"
    public static let TOGGLE_PLAYER7_VIEWPOINT = "Toggle Player 7 Viewpoint"
    public static let TOGGLE_PLAYER8_VIEWPOINT = "Toggle Player 8 Viewpoint"
    public static let TOGGLE_PLAYER9_VIEWPOINT = "Toggle Player 9 Viewpoint"
    public static let TOGGLE_PLAYER10_VIEWPOINT = "Toggle Player 10 Viewpoint"
    public static let TOGGLE_UNIT_PATH = "Toggle Unit Path"
}
