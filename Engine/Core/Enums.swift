import CoreGraphics
import SpriteKit

public enum Action {
    case Attack
    case CreateWorker1
    case CreateWorker2
    case CreateInfantry1
    case CreateNaval1
    case Defend
    case Move
    case CreateCity
    case BuildRoad
}

public enum BuildingDomain: CustomStringConvertible {
    case Combat
    case Income
    case Population
    case Production
    case Science
    case Trade
    
    public var description : String {
        switch self {
        case .Combat: return "Combat"
        case .Income: return "Income"
        case .Population: return "Population"
        case .Production: return "Production"
        case .Science: return "Science"
        case .Trade: return "Trade"
        }
    }
}

public enum BuildingType: CustomStringConvertible {
    case Airport
    case Aqueduct
    case Bank
    case Barracks
    case Capitalization
    case Cathedral
    case CityWalls
    case CoastalFortress
    case Colosseum
    case Courthouse
    case Factory
    case Granary
    case Harbor
    case HydroPlant
    case Library
    case ManufacturingPlant
    case Marketplace
    case MassTransit
    case NuclearPlant
    case OffshorePlatform
    case Palace
    case PoliceStation
    case PortFacility
    case PowerPlant
    case RecyclingCenter
    case ResearchLab
    case SAMMissileBattery
    case SDIDefense
    case SewerSystem
    case SolarPlant
    case SSComponent
    case SSModule
    case SSStructural
    case StockExchange
    case Superhighways
    case Supermarket
    case Temple
    case University
    
    public var description: String {
        switch self {
        case .Airport: return "Airport"
        case .Aqueduct: return "Aqueduct"
        case .Bank: return "Bank"
        case .Barracks: return "Barracks"
        case .Capitalization: return "Capitalization"
        case .Cathedral: return "Cathedral"
        case .CityWalls: return "City Walls"
        case .CoastalFortress: return "Coastal Fortress"
        case .Colosseum: return "Colosseum"
        case .Courthouse: return "Courthouse"
        case .Factory: return "Factory"
        case .Granary: return "Granary"
        case .Harbor: return "Harbor"
        case .HydroPlant: return "Hydro Plant"
        case .Library: return "Library"
        case .ManufacturingPlant: return "Manufacturing Plant"
        case .Marketplace: return "Marketplace"
        case .MassTransit: return "Mass Transit"
        case .NuclearPlant: return "Nuclear Plant"
        case .OffshorePlatform: return "Offshore Platform"
        case .Palace: return "Palace"
        case .PoliceStation: return "Police Station"
        case .PortFacility: return "Port Facility"
        case .PowerPlant: return "Power Plant"
        case .RecyclingCenter: return "Recycling Center"
        case .ResearchLab: return "Research Lab"
        case .SAMMissileBattery: return "SAM Missile Battery"
        case .SDIDefense: return "SDI Defense"
        case .SewerSystem: return "Sewer System"
        case .SolarPlant: return "Solar Plant"
        case .SSComponent: return "SS Component"
        case .SSModule: return "SS Module"
        case .SSStructural: return "SS Structural"
        case .StockExchange: return "Stock Exchange"
        case .Superhighways: return "Superhighways"
        case .Supermarket: return "Supermarket"
        case .Temple: return "Temple"
        case .University: return "University"
        }
    }
}

public enum CityProductionType: CustomStringConvertible {
    case Building
    case Trade
    case Unit
    case Wonder
    
    public var description : String {
        switch self {
        case .Building: return "Building"
        case .Trade: return "Trade"
        case .Unit: return "Unit"
        case .Wonder: return "Wonder"
        }
    }
}

public enum ColorType: CustomStringConvertible {
    case Blue
    case Green
    case Orange
    case Red
    case Purple
    case White
    case Yellow
    
    public var color: SKColor {
        switch self {
        case .Blue: return SKColor.blue
        case .Green: return SKColor.green
        case .Orange: return SKColor.orange
        case .Red: return SKColor.red
        case .Purple: return SKColor.purple
        case .White: return SKColor.white
        case .Yellow: return SKColor.yellow
        }
    }
    
    public var description: String {
        switch self {
        case .Blue: return "Blue"
        case .Green: return "Green"
        case .Orange: return "Orange"
        case .Red: return "Red"
        case .Purple: return "Purple"
        case .White: return "White"
        case .Yellow: return "Yellow"
        }
    }
}

public enum CommandType {
    case AI
    case Normal
    case Replay
}

public enum DifficultyLevel {
    case One
    case Two
    case Three
    case Four
    case Five
    case Six
}

public enum DiplomacyStatus {
    case Same
    case Ally
    case DeclaredFriend
    case Friendly
    case Neutral
    case Unfriendly
    case Denounced
    case AtWar
}

public enum EffectType {
    case NewCity
    case TileRevealed
    case LandAttackIncreased
    case LandDefenseIncreased
    case Worker1Created
    case Infantry1Created
    case Infantry2Created
    case Naval1Created
}

public enum WorkerTaskType: CustomStringConvertible {
    case Airbase
    case Farmland
    case Fortress
    case Irrigation
    case Mine
    case Pollution
    case Railroad
    case Road
    case TerraformDesertToPlains
    case TerraformForestToGrassland
    case TerraformGlacierToTundra
    case TerraformGrasslandToHills
    case TerraformHillsToPlains
    case TerraformJungleToPlains
    case TerraformMountainsToHills
    case TerraformPlainsToGrassland
    case TerraformSwampToPlains
    case TerraformTundraToDesert
    
    public var description : String {
        switch self {
        case .Airbase: return "airbase"
        case .Farmland: return "farmland"
        case .Fortress: return "fortress"
        case .Irrigation: return "irrigation"
        case .Mine: return "mine"
        case .Pollution: return "pollution"
        case .Railroad: return "railroad"
        case .Road: return "road"
        case .TerraformDesertToPlains: return "terraform desert to plains"
        case .TerraformForestToGrassland: return "terraform forest to grassland"
        case .TerraformGlacierToTundra: return "terraform glacier to tundra"
        case .TerraformGrasslandToHills: return "terraform grassland to hills"
        case .TerraformHillsToPlains: return "terraform hills to plains"
        case .TerraformJungleToPlains: return "terraform jungle to plains"
        case .TerraformMountainsToHills: return "terraform mountains to hills"
        case .TerraformPlainsToGrassland: return "terraform plains to grassland"
        case .TerraformSwampToPlains: return "terraform swamp to plains"
        case .TerraformTundraToDesert: return "terraform tundra to desert"
        }
    }
}

public enum Era: CustomStringConvertible {
    case AncientWorld
    case Renaissance
    case IndustrialRevolution
    case ModernWorld
    
    public var description: String {
        switch self {
        case .AncientWorld: return "Ancient World"
        case .Renaissance: return "Renaissance"
        case .IndustrialRevolution: return "Indistrial Revolution"
        case .ModernWorld: return "Modern World"
        }
    }
}

public enum GameAIAutoplayState {
    case IsReadyToStart
    case IsRunning
    case IsPaused
    case IsDone
    case None
    
//    public var description: String {
//        switch self {
//        case .IsCreated: return "Is Created"
//        case .IsLoaded: return "Is Loaded"
//        case .IsInMatch: return "Is In Match"
//        case .IsReadyToPlay: return "Is Ready to Play"
//        }
//    }
}

public enum GameMode: CustomStringConvertible {
    case IsComplete
    case IsCreated
    case IsLoaded
    case IsInMatch
    case IsReadyToPlay
    
    public var description: String {
        switch self {
        case .IsComplete: return "Is Complete"
        case .IsCreated: return "Is Created"
        case .IsLoaded: return "Is Loaded"
        case .IsInMatch: return "Is In Match"
        case .IsReadyToPlay: return "Is Ready to Play"
        }
    }
}

public enum GameState: CustomStringConvertible {
    case AIProcessing
    case AITurnComplete
    case AwaitingAI
    case AwaitingHuman
    case HumanTurnComplete
    case Done
    
    public var description: String {
        switch self {
        case .AIProcessing: return "AI Processing"
        case .AITurnComplete: return "AI Turn Complete"
        case .AwaitingAI: return "Awaiting AI"
        case .AwaitingHuman: return "Awaiting Human"
        case .Done: return "Done"
        case .HumanTurnComplete: return "Human Turn Complete"
        }
    }
}

public enum GameType {
    case Normal
    case AIAllTurns
    case AIOneTurn
}

public enum GenderType: CustomStringConvertible {
    case Male
    case Female
    case Unknown
    case Indeterminate
    case MaleOnceFemale
    case FemaleOnceMale
    case MaleBeenBoth
    case FemaleBeenBoth
    case Hermaphrodite
    
    public var pronoun: String {
        switch self {
        case .Female: return "her"
        case .Male: return "his"
        case .Unknown: return "???"
        case .Indeterminate: return "her"
        case .MaleOnceFemale: return "his"
        case .FemaleOnceMale: return "her"
        case .MaleBeenBoth: return "his"
        case .FemaleBeenBoth: return "her"
        case .Hermaphrodite: return "???"
        }
    }
    
    public var description: String {
        switch self {
        case .Male: return "Male"
        case .Female: return "Female"
        case .Unknown: return "Unknown"
        case .Indeterminate: return "Indeterminate"
        case .MaleOnceFemale: return "Male Once Female"
        case .FemaleOnceMale: return "Female Once Male"
        case .MaleBeenBoth: return "Male Been Both"
        case .FemaleBeenBoth: return "Female Been Both"
        case .Hermaphrodite: return "Hermaphrodite"
        }
    }
}

public enum Government {
    case Anarchy
    case Communism
    case Democracy
    case Despotism
    case Fundamentalism
    case Monarchy
    case Republic
}

public enum HUDPosition {
    case Northwest
    case West
    case SouthWest
    case South
    case Southeast
    case East
    case Northeast
    case North
}

public enum HUDControl {
    case Minimap
    case Turn
    
}

public enum IrrigationStatus: CustomStringConvertible {
    case None
    case Irrigation
    case IrrigationPartial
    case IrrigationPillaged
    case Farmland
    case FarmlandPartial
    case FarmlandPillaged
    
    public var description : String {
        switch self {
        case .None: return "None"
        case .Irrigation: return "Irrigation"
        case .IrrigationPartial: return "Irrigation Partial"
        case .IrrigationPillaged: return "Irrigation Pillaged"
        case .Farmland: return "Farmland"
        case .FarmlandPartial: return "Farmland Partial"
        case .FarmlandPillaged: return "Farmland Pillaged"
        }
    }
}

public enum Layer {
    public static let terrain = 100.0
    public static let terrainTransitions = 110.0
    public static let terrainFeatures = 125.0
    public static let irrigation = 140.0
    public static let rivers = 150.0
    public static let roads = 190.0
    public static let fortresses = 195.0
    public static let cities = 200.0
    public static let cityLabels = 451.0
    public static let cityWorkedTilesStatuses = 452.0
    public static let cityNames = 250.0
    public static let goodieHuts = 280.0
    public static let unitMovementIndicators = 290.0
    public static let unitSelection = 299.0
    public static let units = 300.0
    public static let specialResources = 325.0
    public static let unitPath = 400.0
    public static let frontier = 425.0
    public static let tileAnalysis = 435.0
    public static let fogOfWar = 450.0
    public static let hud = 500.0
    public static let contextMenu = 600.0
    public static let contextMenuItem = 601.0
    public static let techTree = 700.0
    public static let loadingScreen = 1000.0
    public static let tileCoordinates = 2000.0
    public static let tileStats = 3500.0
}

public enum LogCategory: CustomStringConvertible {
    case AI
    case Core
    case Db
    case IO
    case UI
    
    public var description: String {
        switch self {
        case .AI: return "AI"
        case .Core: return "Core"
        case .Db: return "Db"
        case .IO: return "IO"
        case .UI: return "UI"
        }
    }
}

public enum LogLevel {
    case One
    case Two
}

public enum MineStatus: CustomStringConvertible {
    case None
    case Mine
    case Pillaged
    
    public var description : String {
        switch self {
        case .None: return "None"
        case .Mine: return "Mine"
        case .Pillaged: return "Mine Pillaged"
        }
    }
}

public enum NotificationType {
    case None
    case Info
    case Error
    case Success
}

public enum ObjectiveType: CustomStringConvertible {
    case AirCombatAttack
    case AirCombatDefense
    case BuildAirbase
    case BuildFortress
    case BuildMine
    case BuildRoad
    case BuildPyramids
    case CleanUpPollution
    case CreateCity
    case GroundCombatAttack
    case GroundCombatDefense
    case ExploreLand
    case ExploreWater
    case IncreaseFood
    case NavalCombatAttack
    case NavalCombatDefense
    case Random
    case TransformTerrain
    
    public var description: String {
        switch self {
        case .AirCombatAttack: return "Air Combat Attack"
        case .AirCombatDefense: return "Air Combat Defense"
        case .BuildAirbase: return "Build Airbase"
        case .BuildFortress: return "Build Fortress"
        case .BuildMine: return "Build Mine"
        case .BuildRoad: return "Build Road"
        case .BuildPyramids: return "Build Pyramids"
        case .CleanUpPollution: return "Clean Up Pollution"
        case .CreateCity: return "Create City"
        case .GroundCombatAttack: return "Ground Combat Attack"
        case .GroundCombatDefense: return "Ground Combat Defense"
        case .ExploreLand: return "Explore Ground"
        case .ExploreWater: return "Explore Water"
        case .IncreaseFood: return "Increase Food"
        case .NavalCombatAttack: return "Naval Combat Attack"
        case .NavalCombatDefense: return "Naval Combat Defense"
        case .Random: return "Random"
        case .TransformTerrain: return "Transform Terrain"
        }
    }
}

public enum PlayerType: CustomStringConvertible {
    case AI
    case AICopy
    case Human
    case HumanCopy
    
    public var description: String {
        switch self {
        case .AI: return "AI"
        case .AICopy: return "AI Copy"
        case .Human: return "Human"
        case .HumanCopy: return "Human Copy"
        }
    }
}

public enum Personality {
    case Aggressive
    case Neutral
    case Rational
}

public enum PopulationUnitMood: CustomStringConvertible {
    case Angry
    case Content
    case Happy
    case Unhappy
    
    public var description : String {
        switch self {
        case .Angry: return "Angry"
        case .Content: return "Content"
        case .Happy: return "Happy"
        case .Unhappy: return "Unhappy"
        }
    }
}

public enum PopulationUnitType {
    case Worker
    case Entertainer
    case Scientist
    case TaxCollector
}

public enum ProductionState {
    case AwaitingNextProduction
    case Busy
}

public enum ResourceType: CustomStringConvertible {
    case Buffalo
    case Coal
    case Fish
    case Fruit
    case Furs
    case Game
    case Gems
    case Gold
    case Iron
    case Ivory
    case Oasis
    case Oil
    case Peat
    case Pheasant
    case Production
    case Silk
    case Spice
    case Whales
    case Wheat
    case Wine
    
    public var description : String {
        switch self {
        case .Buffalo: return "Buffalo"
        case .Coal: return "Coal"
        case .Fish: return "Fish"
        case .Fruit: return "Fruit"
        case .Furs: return "Furs"
        case .Game: return "Game"
        case .Gems: return "Gems"
        case .Gold: return "Gold"
        case .Iron: return "Iron"
        case .Ivory: return "Ivory"
        case .Oasis: return "Oasis"
        case .Oil: return "Oil"
        case .Peat: return "Peat"
        case .Pheasant: return "Pheasant"
        case .Production: return "Production"
        case .Silk: return "Silk"
        case .Spice: return "Spice"
        case .Whales: return "Whales"
        case .Wheat: return "Wheat"
        case .Wine: return "Wine"
        }
    }
}

public enum RoadStatus: CustomStringConvertible {
    case None
    case Road
    case RoadPartial
    case RoadPillaged
    case Railroad
    case RailroadPartial
    case RailroadPillaged
    
    public var description : String {
        switch self {
        case .None: return "None"
        case .Road: return "Road"
        case .RoadPartial: return "Road Partial"
        case .RoadPillaged: return "Road Pillaged"
        case .Railroad: return "Railroad"
        case .RailroadPartial: return "Railroad Partial"
        case .RailroadPillaged: return "Railroad Pillaged"
        }
    }
}

public enum RunMode: CustomStringConvertible {
    case Debug
    case Normal
    case Replay
    
    public var description: String {
        switch self {
        case .Debug: return "Debug"
        case .Normal: return "Normal"
        case .Replay: return "Replay"
        }
    }
}

public enum SkillLevel {
    case One
    case Two
    case Three
    case Four
    case Five
    case Six
    case Seven
    case Eight
}

public enum StrategicGoalType: CustomStringConvertible {
    case Anarchy
    case Communism
    case Democracy
    case Despotism
    case Fundamentalism
    case Monarchy
    case Republic
    case ConquerPlayer
//    case ThreatenPlayer
    case Wide
    case Defensive
//    case IncreaseScience
//    case IncreaseEconomy
    case Explore
    case Tall
//    case ExploreWater
//    case BuildAdamSmithsTradingCo
//    case BuildApolloProgram
//    case BuildColossus
//    case BuildCopernicusObservatory
//    case BuildCureForCancer
//    case BuildDarwinsVoyage
//    case BuildEiffelTower
//    case BuildGreatLibrary
//    case BuildGreatWall
//    case BuildHangingGardens
//    case BuildHooverDam
//    case BuildIsaacNewtonsCollege
//    case BuildJSBachsCathedral
//    case BuildKingRichardsCrusade
//    case BuildLeonardosWorkshop
//    case BuildLighthouse
//    case BuildMagellansExpedition
//    case BuildManhattenProject
//    case BuildMarcoPolosEmbassy
//    case BuildMichelangelosChapel
//    case BuildOracle
//    case BuildPyramids
//    case BuildSETIProgram
//    case BuildShakespearesTheatre
//    case BuildStatueOfLiberty
//    case BuildSunTzusWarAcademy
//    case BuildUnitedNations
//    case BuildWomensSuffrage
    
    public var description: String {
        switch self {
        case .Anarchy: return "anarchy"
        case .Communism: return "communism"
        case .ConquerPlayer: return "conquer player"
        case .Defensive: return "defensive"
        case .Democracy: return "democracy"
        case .Despotism: return "despotism"
        case .Fundamentalism: return "fundamentalism"
        case .Monarchy: return "monarchy"
        case .Republic: return "republic"
        case .Explore: return "explore"
        case .Tall: return "tall"
        case .Wide: return "wide"
        }
    }
}

public enum TechTreeState {
    case Awaiting
    case Researching
}

public enum TechType: CustomStringConvertible {
    case AdvancedFlight
    case Alphabet
    case AmphibiousWarfare
    case Astronomy
    case AtomicTheory
    case Automobile
    case Banking
    case BridgeBuilding
    case BronzeWorking
    case CeremonialBurial
    case Chemistry
    case Chivalry
    case CodeOfLaws
    case CombinedArms
    case Combustion
    case Communism
    case Computers
    case Conscription
    case Construction
    case Corporation
    case Currency
    case Democracy
    case Economics
    case Electricity
    case Electronics
    case Engineering
    case Environmentalism
    case Error
    case Espionage
    case Explosives
    case Feudalism
    case Flight
    case Fundamentalism
    case FusionPower
    case FutureTechnology
    case GeneticEngineering
    case GuerrillaWarfare
    case Gunpowder
    case HorsebackRiding
    case Industrialization
    case Invention
    case IronWorking
    case LaborUnion
    case Laser
    case Leadership
    case Literacy
    case MachineTools
    case Magnetism
    case MapMaking
    case Masonry
    case MassProduction
    case Mathematics
    case Medicine
    case Metallurgy
    case Miniaturization
    case MobileWarfare
    case Monarchy
    case Monotheism
    case Mysticism
    case Navigation
    case NuclearFission
    case NuclearPower
    case Philosophy
    case Physics
    case Plastics
    case Polytheism
    case Pottery
    case Radio
    case Railroad
    case Recycling
    case Refining
    case Refrigeration
    case Republic
    case Robotics
    case Rocketry
    case Sanitation
    case Seafaring
    case SpaceFlight
    case Stealth
    case SteamEngine
    case Steel
    case Superconductor
    case Tactics
    case Theology
    case TheoryOfGravity
    case Trade
    case University
    case WarriorCode
    case Wheel
    case Writing
    
    public var description: String {
        switch self {
        case .AdvancedFlight: return "AdvancedFlight"
        case .Alphabet: return "Alphabet"
        case .AmphibiousWarfare: return "Amphibious Warfare"
        case .Astronomy: return "Astronomy"
        case .AtomicTheory: return "Atomic Theory"
        case .Automobile: return "Automobile"
        case .Banking: return "Banking"
        case .BridgeBuilding: return "Bridge Building"
        case .BronzeWorking: return "Bronze Working"
        case .CeremonialBurial: return "Ceremonial Burial"
        case .Chemistry: return "Chemistry"
        case .Chivalry: return "Chivalry"
        case .CodeOfLaws: return "Code of Laws"
        case .CombinedArms: return "Combined Arms"
        case .Combustion: return "Combustion"
        case .Communism: return "Communism"
        case .Computers: return "Computers"
        case .Conscription: return "Conscription"
        case .Construction: return "Construction"
        case .Corporation: return "Corporation"
        case .Currency: return "Currency"
        case .Democracy: return "Democracy"
        case .Economics: return "Economics"
        case .Electricity: return "Electricity"
        case .Electronics: return "Electronics"
        case .Engineering: return "Engineering"
        case .Environmentalism: return "Environmentalism"
        case .Error: return "Error"
        case .Espionage: return "Espionage"
        case .Explosives: return "Explosives"
        case .Feudalism: return "Feudalism"
        case .Flight: return "Flight"
        case .Fundamentalism: return "Fundamentalism"
        case .FusionPower: return "Fusion Power"
        case .FutureTechnology: return "Future Technology"
        case .GeneticEngineering: return "Genetic Engineering"
        case .GuerrillaWarfare: return "Guerralla Warfare"
        case .Gunpowder: return "Gunpowder"
        case .HorsebackRiding: return "Horseback Riding"
        case .Industrialization: return "Industrialization"
        case .Invention: return "Invention"
        case .IronWorking: return "Iron Working"
        case .LaborUnion: return "Labor Union"
        case .Laser: return "Laser"
        case .Leadership: return "Leadership"
        case .Literacy: return "Literacy"
        case .MachineTools: return "Machine Tools"
        case .Magnetism: return "Magnetism"
        case .MapMaking: return "Map Making"
        case .Masonry: return "Masonry"
        case .MassProduction: return "Mass Production"
        case .Mathematics: return "Mathematics"
        case .Medicine: return "Medicine"
        case .Metallurgy: return "Metallurgy"
        case .Miniaturization: return "Miniaturization"
        case .MobileWarfare: return "Mobile Warfare"
        case .Monarchy: return "Monarchy"
        case .Monotheism: return "Monotheism"
        case .Mysticism: return "Mysticism"
        case .Navigation: return "Navigation"
        case .NuclearFission: return "Nuclear Fission"
        case .NuclearPower: return "Nuclear Power"
        case .Philosophy: return "Philosophy"
        case .Physics: return "Physics"
        case .Plastics: return "Plastics"
        case .Polytheism: return "Polytheism"
        case .Pottery: return "Pottery"
        case .Radio: return "Radio"
        case .Railroad: return "Railroad"
        case .Recycling: return "Recycling"
        case .Refining: return "Refining"
        case .Refrigeration: return "Refrigeration"
        case .Republic: return "Republic"
        case .Robotics: return "Robotics"
        case .Rocketry: return "Rocketry"
        case .Sanitation: return "Sanitation"
        case .Seafaring: return "Seafaring"
        case .SpaceFlight: return "Space Flight"
        case .Stealth: return "Stealth"
        case .SteamEngine: return "Steam Engine"
        case .Steel: return "Steel"
        case .Superconductor: return "Superconductor"
        case .Tactics: return "Tactics"
        case .Theology: return "Theology"
        case .TheoryOfGravity: return "Theory of Gravity"
        case .Trade: return "Trade"
        case .University: return "University"
        case .WarriorCode: return "Warrior Code"
        case .Wheel: return "Wheel"
        case .Writing: return "Writing"
        }
    }
}

public enum TerrainType: CustomStringConvertible {
    case Desert
    case Forest
    case Glacier
    case Grassland
    case Hills
    case Jungle
    case Mountains
    case Ocean
    case Plains
    case Swamp
    case Tundra
    
    public var description: String {
        switch self {
        case .Desert: return "Desert"
        case .Forest: return "Forest"
        case .Glacier: return "Glacier"
        case .Grassland: return "Grassland"
        case .Hills: return "Hills"
        case .Jungle: return "Jungle"
        case .Mountains: return "Mountain"
        case .Ocean: return "Ocean"
        case .Plains: return "Plains"
        case .Swamp: return "Swamp"
        case .Tundra: return "Tundra"
        }
    }

}

public enum TileImprovement: CustomStringConvertible {
    case Irrigation
    case Farmland
    
    public var description : String {
        switch self {
        case .Farmland: return "Farmland"
        case .Irrigation: return "Irrigation"
        }
    }
}

public enum UnitActionType: CustomStringConvertible {
    case Attack
    case DoNothing
    case Fortify
    case Move
    
    public var description : String {
        switch self {
        case .Attack: return "Attack"
        case .DoNothing: return "Do Nothing"
        case .Fortify: return "Fortify"
        case .Move: return "Move"
        }
    }
}

public enum UnitCategory {
    case AirCombat
    case Espionage
    case GroundCombat
    case NavalCombat
    case NavalTransport
    case Trade
    case Transport
    case Weapon
    case Worker

}

public enum UnitDomain: CustomStringConvertible {
    case Air
    case Ground
    case Sea
    
    public var description : String {
        switch self {
        case .Air: return "Air"
        case .Ground: return "Ground"
        case .Sea: return "Sea"
        }
    }
}

public enum UnitRole: CustomStringConvertible {
    case Defense
    case Espionage
    case Offense
    case Trade
    
    public var description : String {
        switch self {
        case .Defense: return "Defense"
        case .Espionage: return "Espionage"
        case .Offense: return "Offense"
        case .Trade: return "Trade"
        }
    }
}

public enum UnitOrderType {
    case Move
    case Fortify
    case CreateCity
    case DefendCity
}

public enum UnitType: CustomStringConvertible {
    /// Equivalent to the Carrier unit in Civilization II
    case AircraftCarrier
    /// Equivalent to the Fighter unit in Civilization II
    case Air1
    /// Equivalent to the Bomber unit in Civilization II
    case Air2
    /// Equivalent to the Stealth Fighter unit in Civilization II
    case Air3
    /// Equivalent to the Stealth Bomber unit in Civilization II
    case Air4
    /// Equivalent to the Helicopter unit in Civilization II
    case Helicopter
    /// Equivalent to the Horsemen unit in Civilization II
    case Cavalry1
    /// Equivalent to the Chariot unit in Civilization II
    case Cavalry2
    /// Equivalent to the Elephant unit in Civilization II
    case Cavalry3
    /// Equivalent to the Knights unit in Civilization II
    case Cavalry4
    /// Equivalent to the Dragoons unit in Civilization II
    case Cavalry5
    /// Equivalent to the Crusaders unit in Civilization II
    case Cavalry6
    /// Equivalent to the Cavalry unit in Civilization II
    case Cavalry7
    /// Equivalent to the Armor unit in Civilization II
    case Cavalry8
    /// Equivalent to the Cruise Missile unit in Civilization II
    case CruiseMissile
    /// Equivalent to the Diplomat unit in Civilization II
    case Diplomat
    /// Equivalent to the Explorer unit in Civilization II
    case Explorer
    /// Equivalent to the Warrior unit in Civilization II
    case Infantry1
    /// Equivalent to the Phalanx unit in Civilization II
    case Infantry2
    /// Equivalent to the Archers unit in Civilization II
    case Infantry3
    /// Equivalent to the Pikemen unit in Civilization II
    case Infantry4
    /// Equivalent to the Legion unit in Civilization II
    case Infantry5
    /// Equivalent to the Musketeers unit in Civilization II
    case Infantry6
    /// Equivalent to the Alpine Troops unit in Civilization II
    case Infantry7
    /// Equivalent to the Fanatics unit in Civilization II
    case Infantry8  // FIXME: Should we make Fanatics its own unit type?
    /// Equivalent to the Riflemen unit in Civilization II
    case Infantry9
    /// Equivalent to the Partisans unit in Civilization II
    case Infantry10
    /// Equivalent to the Mechanized Infantry unit in Civilization II
    case Infantry11
    /// Equivalent to the Marines unit in Civilization II
    case Marines
    /// Equivalent to the Trireme unit in Civilization II
    case Naval1
    /// Equivalent to the Caravel unit in Civilization II
    case Naval2
    /// Equivalent to the Galleon unit in Civilization II
    case Naval3
    /// Equivalent to the Frigate unit in Civilization II
    case Naval4
    /// Equivalent to the Ironclad unit in Civilization II
    case Naval5
    /// Equivalent to the Destroyer unit in Civilization II
    case Naval6
    /// Equivalent to the Cruiser unit in Civilization II
    case Naval7
    /// Equivalent to the Battleship unit in Civilization II
    case Naval8
    /// Equivalent to the AEGIS Cruiser unit in Civilization II
    case Naval9
    /// Equivalent to the Transport unit in Civilization II
    case NavalTransport
    /// Equivalent to the Nuclear Missile unit in Civilization II
    case NuclearMissile
    /// Equivalent to the Paratroopers unit in Civilization II
    case Paratroopers
    /// Equivalent to the Catapult unit in Civilization II
    case Siege1
    /// Equivalent to the Cannon unit in Civilization II
    case Siege2
    /// Equivalent to the Artillery unit in Civilization II
    case Siege3
    /// Equivalent to the Howitzer unit in Civilization II
    case Siege4
    /// Equivalent to the Spy unit in Civilization II
    case Spy
    /// Equivalent to the Submarine unit in Civilization II
    case Submarine
    /// Equivalent to the Trade unit in Civilization II
    case Trade1
    /// Equivalent to the Freight unit in Civilization II
    case Trade2
    /// Equivalent to the Settlers unit in Civilization II
    case Worker1
    /// Equivalent to the Engineers unit in Civilization II
    case Worker2
    
    public func assetName(skinName: String) -> String {
        switch self {
        case .AircraftCarrier: return "Themes/Default/Skins/\(skinName)/Units/Naval/aircraft-carrier"
        case .Air1: return "Themes/Default/Skins/\(skinName)/Units/Air/air-1"
        case .Air2: return "Themes/Default/Skins/\(skinName)/Units/Air/air-2"
        case .Air3: return "Themes/Default/Skins/\(skinName)/Units/Air/air-3"
        case .Air4: return "Themes/Default/Skins/\(skinName)/Units/Air/air-4"
        case .Helicopter: return "Themes/Default/Skins/\(skinName)/Units/Air/helicopter"
        case .Cavalry1: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-1"
        case .Cavalry2: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-2"
        case .Cavalry3: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-3"
        case .Cavalry4: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-4"
        case .Cavalry5: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-5"
        case .Cavalry6: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-6"
        case .Cavalry7: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-7"
        case .Cavalry8: return "Themes/Default/Skins/\(skinName)/Units/Cavalry/cavalry-8"
        case .CruiseMissile: return "Themes/Default/Skins/\(skinName)/Units/Misc/cruise-missile"
        case .Diplomat: return "Themes/Default/Skins/\(skinName)/Units/Misc/diplomat"
        case .Explorer: return "Themes/Default/Skins/\(skinName)/Units/Misc/explorer"
        case .Infantry1: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-1"
        case .Infantry2: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-2"
        case .Infantry3: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-3"
        case .Infantry4: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-4"
        case .Infantry5: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-5"
        case .Infantry6: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-6"
        case .Infantry7: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-7"
        case .Infantry8: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-8"
        case .Infantry9: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-9"
        case .Infantry10: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-10"
        case .Infantry11: return "Themes/Default/Skins/\(skinName)/Units/Infantry/infantry-11"
        case .Marines: return "Themes/Default/Skins/\(skinName)/Units/Infantry/marines"
        case .Naval1: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-1"
        case .Naval2: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-2"
        case .Naval3: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-3"
        case .Naval4: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-4"
        case .Naval5: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-5"
        case .Naval6: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-6"
        case .Naval7: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-7"
        case .Naval8: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-8"
        case .Naval9: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-9"
        case .NavalTransport: return "Themes/Default/Skins/\(skinName)/Units/Naval/naval-transport"
        case .NuclearMissile: return "Themes/Default/Skins/\(skinName)/Units/Naval/nuclear-missile"
        case .Paratroopers: return "Themes/Default/Skins/\(skinName)/Units/Naval/paratroopers"
        case .Siege1: return "Themes/Default/Skins/\(skinName)/Units/Siege/siege-1"
        case .Siege2: return "Themes/Default/Skins/\(skinName)/Units/Siege/siege-2"
        case .Siege3: return "Themes/Default/Skins/\(skinName)/Units/Siege/siege-3"
        case .Siege4: return "Themes/Default/Skins/\(skinName)/Units/Siege/siege-4"
        case .Spy: return "Themes/Default/Skins/\(skinName)/Units/Misc/spy"
        case .Submarine: return "Themes/Default/Skins/\(skinName)/Units/Naval/submarine"
        case .Trade1: return "Themes/Default/Skins/\(skinName)/Units/Naval/trade-1"
        case .Trade2: return "Themes/Default/Skins/\(skinName)/Units/Naval/trade-2"
        case .Worker1: return "Themes/Default/Skins/\(skinName)/Units/Misc/worker-1"
        case .Worker2: return "Themes/Default/Skins/\(skinName)/Units/Misc/worker-2"
        }
    }
    
    public var description: String {
        switch self {
        case .AircraftCarrier: return "Aircraft Carrier"
        case .Air1: return "Air1"
        case .Air2: return "Air2"
        case .Air3: return "Air3"
        case .Air4: return "Air4"
        case .Helicopter: return "Helicopter"
        case .Cavalry1: return "Cavalry1"
        case .Cavalry2: return "Cavalry2"
        case .Cavalry3: return "Cavalry3"
        case .Cavalry4: return "Cavalry4"
        case .Cavalry5: return "Cavalry5"
        case .Cavalry6: return "Cavalry6"
        case .Cavalry7: return "Cavalry7"
        case .Cavalry8: return "Cavalry8"
        case .CruiseMissile: return "Cruise Missile"
        case .Diplomat: return "Diplomat"
        case .Explorer: return "Explorer"
        case .Infantry1: return "Infantry1"
        case .Infantry2: return "Infantry2"
        case .Infantry3: return "Infantry3"
        case .Infantry4: return "Infantry4"
        case .Infantry5: return "Infantry5"
        case .Infantry6: return "Infantry6"
        case .Infantry7: return "Infantry7"
        case .Infantry8: return "Infantry8"
        case .Infantry9: return "Infantry9"
        case .Infantry10: return "Infantry10"
        case .Infantry11: return "Infantry11"
        case .Marines: return "Marines"
        case .Naval1: return "Naval1"
        case .Naval2: return "Naval2"
        case .Naval3: return "Naval3"
        case .Naval4: return "Naval4"
        case .Naval5: return "Naval5"
        case .Naval6: return "Naval6"
        case .Naval7: return "Naval7"
        case .Naval8: return "Naval8"
        case .Naval9: return "Naval9"
        case .NavalTransport: return "Naval Transport"
        case .NuclearMissile: return "Nuclear Missile"
        case .Paratroopers: return "Paratroopers"
        case .Siege1: return "Siege1"
        case .Siege2: return "Siege2"
        case .Siege3: return "Siege3"
        case .Siege4: return "Siege4"
        case .Spy: return "Spy"
        case .Submarine: return "Submarine"
        case .Trade1: return "Trade1"
        case .Trade2: return "Trade2"
        case .Worker1: return "Worker1"
        case .Worker2: return "Worker2"
        }
    }
}

public enum VictoryGoalType: CustomStringConvertible {
    case Conquer
    case SpaceRace
    case Score
    
    public var description: String {
        switch self {
        case .Conquer: return "win by conquer"
        case .SpaceRace: return "win by space race"
        case .Score: return "win by score"
        }
    }
}

public enum Visibility: CustomStringConvertible {
    case DebugRevealed
    case FogOfWar
    case SemiRevealed
    case FullyRevealed
    
    public var description: String {
        switch self {
        case .DebugRevealed: return "Debug-revealed"
        case .FogOfWar: return "Fog of War"
        case .SemiRevealed: return "Semi-revealed"
        case .FullyRevealed: return "Fully-revealed"
        }
    }
}

public enum WonderType: CustomStringConvertible {
    case AdamSmithsTradingCo
    case ApolloProgram
    case Colossus
    case CopernicusObservatory
    case CureForCancer
    case DarwinsVoyage
    case EiffelTower
    case GreatLibrary
    case GreatWall
    case HangingGardens
    case HooverDam
    case IsaacNewtonsCollege
    case JSBachsCathedral
    case KingRichardsCrusade
    case LeonardosWorkshop
    case Lighthouse
    case MagellansExpedition
    case ManhattenProject
    case MarcoPolosEmbassy
    case MichelangelosChapel
    case Oracle
    case Pyramids
    case SETIProgram
    case ShakespearesTheatre
    case StatueOfLiberty
    case SunTzusWarAcademy
    case UnitedNations
    case WomensSuffrage
    
    public var description: String {
        switch self {
        case .AdamSmithsTradingCo: return "Adam Smith's Trading Co"
        case .ApolloProgram: return "Apollo Program"
        case .Colossus: return "Colossus"
        case .CopernicusObservatory: return "Copernicus' Observatory"
        case .CureForCancer: return "Cure for Cancer"
        case .DarwinsVoyage: return "Darwin's Voyage"
        case .EiffelTower: return "Eiffel Tower"
        case .GreatLibrary: return "Great Library"
        case .GreatWall: return "Great Wall"
        case .HangingGardens: return "Hanging Gardens"
        case .HooverDam: return "Hoover Dam"
        case .IsaacNewtonsCollege: return "Isaac Newtons College"
        case .JSBachsCathedral: return "JS Bachs Cathedral"
        case .KingRichardsCrusade: return "King Richards Crusade"
        case .LeonardosWorkshop: return "Leonardos Workshop"
        case .Lighthouse: return "Lighthouse"
        case .MagellansExpedition: return "Magellans Expedition"
        case .ManhattenProject: return "Manhatten Project"
        case .MarcoPolosEmbassy: return "Marco Polos Embassy"
        case .MichelangelosChapel: return "Michelangelos Chapel"
        case .Oracle: return "Oracle"
        case .Pyramids: return "Pyramids"
        case .SETIProgram: return "SETI Program"
        case .ShakespearesTheatre: return "Shakespeares Theatre"
        case .StatueOfLiberty: return "Statue of Liberty"
        case .SunTzusWarAcademy: return "Sun Tzu's War Academy"
        case .UnitedNations: return "United Nations"
        case .WomensSuffrage: return "Womens Suffrage"
        }
    }
    
}
