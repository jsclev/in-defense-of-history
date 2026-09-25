import Foundation

/// One immutable authored input for both the interactive game and headless play.
/// No combat content is supplied by the simulator or its commander.
public struct BattleContent {
    public let level: LevelInfo
    public let playSpeeds: PlaySpeedConfiguration
    public let virtualCanvas: VirtualCanvas
    public let hudLayout: HudLayoutConfig
    public let arsenal: DesignArsenal
    public let enemies: [EnemyType]
    public let unlocks: [TowerKind: Int]
    public let reinforcementConfig: ReinforcementConfig
    public let chosenHeroes: HeroSelection
    public let deployments: [HeroDeployment]
    public let heroCombat: [UUID: HeroCombatStats]
    public let heroAI: [UUID: HeroAIConfiguration]
    public let heroControls: [HeroControlSetting]
    public let movementArea: HeroMovementArea
    public let callButtons: [CallWaveButtonPosition]
    public let exits: [Point]
    public let difficulty: Difficulty
    public let playerUpgrades: PlayerMetaUpgradeState

    public init(db: Db, levelID: UUID, draft: BattleDraft? = nil) throws {
        level = try draft?.level ?? db.levelLoader.load(id: levelID)
        playSpeeds = try db.playSpeedDao.get()
        virtualCanvas = try db.virtualCanvasDao.get()
        hudLayout = try db.hudLayoutDao.get()
        arsenal = try db.towerTypeDao.getDesignArsenal()
        enemies = try db.enemyTypeDao.getAll()
        guard let selected = try db.difficultyDao.getSelected() else {
            throw DbError.Db(message: "player_selected_difficulty: missing authored selection")
        }
        difficulty = selected
        playerUpgrades = try db.playerMetaUpgradeDao.get()
        reinforcementConfig = try db.reinforcementConfigDao.get()
        chosenHeroes = try HeroSelectionStore(dao: db.heroDao).load()
        let configuration = try draft?.heroes ?? db.levelGeoJSONDao.getHeroConfiguration(mapImageName: level.mapImageName)
        deployments = configuration.deployments(for: chosenHeroes)
        heroCombat = try Dictionary(uniqueKeysWithValues: deployments.map {
            ($0.hero.id, try db.heroDao.getCombatStats(heroID: $0.hero.id))
        })
        heroAI = try db.heroDao.getAIConfigurations()
        heroControls = try db.playerSettingsDao.getHeroControls()
        movementArea = try draft?.movementArea ?? db.levelGeoJSONDao.getHeroMovementArea(
            mapImageName: level.mapImageName, defaultPathWidth: virtualCanvas.pathWidth)
        callButtons = try draft?.callButtons ?? db.levelGeoJSONDao.getCallWaveButtons(mapImageName: level.mapImageName)
        exits = try draft?.exits ?? db.levelGeoJSONDao.getExitPoints(mapImageName: level.mapImageName).map(\.position)
        let rows = try db.towerUnlockDao.getUnlocksFor(levelInfoId: levelID)
        var mapped: [TowerKind: Int] = [:]
        for (key, value) in rows {
            guard let kind = TowerKind(rawValue: key) else {
                throw DbError.Db(message: "level_tower_unlock[\(levelID)]: unknown tower_kind '\(key)'")
            }
            mapped[kind] = value
        }
        for tower in arsenal.towers where mapped[tower.kind] == nil {
            throw DbError.Db(message: "level_tower_unlock[\(levelID)]: missing \(tower.kind.rawValue)")
        }
        unlocks = mapped
        try validate()
    }

    // An explicit complete snapshot constructor. No defaults or replacement
    // content: used to validate assembled inputs, including in-memory tests.
    init(level: LevelInfo, playSpeeds: PlaySpeedConfiguration, virtualCanvas: VirtualCanvas, hudLayout: HudLayoutConfig, arsenal: DesignArsenal,
         enemies: [EnemyType], unlocks: [TowerKind: Int], reinforcementConfig: ReinforcementConfig,
         chosenHeroes: HeroSelection, deployments: [HeroDeployment], heroCombat: [UUID: HeroCombatStats],
         heroAI: [UUID: HeroAIConfiguration], heroControls: [HeroControlSetting],
         movementArea: HeroMovementArea, callButtons: [CallWaveButtonPosition], exits: [Point],
         difficulty: Difficulty, playerUpgrades: PlayerMetaUpgradeState) throws {
        self.level = level; self.virtualCanvas = virtualCanvas; self.arsenal = arsenal
        self.playSpeeds = playSpeeds
        self.hudLayout = hudLayout
        self.enemies = enemies; self.unlocks = unlocks; self.reinforcementConfig = reinforcementConfig
        self.chosenHeroes = chosenHeroes; self.deployments = deployments; self.heroCombat = heroCombat
        self.heroAI = heroAI; self.heroControls = heroControls
        self.movementArea = movementArea; self.callButtons = callButtons; self.exits = exits
        self.difficulty = difficulty; self.playerUpgrades = playerUpgrades
        try validate()
    }

    /// Assemble an explicit pre-battle loadout without modifying the player's
    /// database. All prerequisites and star accounting belong to player state.
    public func selectingMetaUpgrades(_ selected: Set<MetaUpgrade>) throws -> Self {
        if selected == playerUpgrades.loadout.selected { return self }
        return try Self(level: level, playSpeeds: playSpeeds, virtualCanvas: virtualCanvas, hudLayout: hudLayout, arsenal: arsenal,
            enemies: enemies, unlocks: unlocks, reinforcementConfig: reinforcementConfig,
            chosenHeroes: chosenHeroes, deployments: deployments, heroCombat: heroCombat,
            heroAI: heroAI, heroControls: heroControls,
            movementArea: movementArea, callButtons: callButtons, exits: exits,
            difficulty: difficulty, playerUpgrades: playerUpgrades.selecting(selected))
    }

    private func validate() throws {
        for deployment in deployments {
            guard heroAI[deployment.hero.id] != nil else {
                throw DbError.Db(message: "hero_ai[\(deployment.hero.id)]: missing configuration")
            }
            guard heroControls.contains(where: { $0.id == deployment.hero.id }) else {
                throw DbError.Db(message: "player_hero_control[\(deployment.hero.id)]: missing ai_enabled")
            }
        }
        let levelID = level.id
        guard !level.paths.isEmpty, level.waves.count == level.numWaves else {
            throw DbError.Db(message: "level_info[\(levelID)]: missing paths or inconsistent authored waves")
        }
        _ = try WaveStartSchedule(waves: level.waves)
        let enemyIDs = Set(enemies.map(\.id))
        for (index, wave) in level.waves.enumerated() {
            for spawn in wave.spawns {
                guard enemyIDs.contains(spawn.enemyTypeID), level.paths.indices.contains(spawn.pathIndex) else {
                    throw DbError.Db(message: "level_wave[\(levelID),\(index)]: invalid enemy \(spawn.enemyTypeID) or path \(spawn.pathIndex) reference")
                }
            }
        }
    }
}

/// Explicit editor input; campaign settings and unlocks still come from SQLite.
public struct BattleDraft {
    public let level: LevelInfo
    public let heroes: LevelHeroConfiguration
    public let movementArea: HeroMovementArea
    public let callButtons: [CallWaveButtonPosition]
    public let exits: [Point]

    public init(level: LevelInfo, heroes: LevelHeroConfiguration, movementArea: HeroMovementArea,
                callButtons: [CallWaveButtonPosition], exits: [Point]) {
        self.level = level; self.heroes = heroes; self.movementArea = movementArea
        self.callButtons = callButtons; self.exits = exits
    }
}
