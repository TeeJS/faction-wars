class_name GameSession
extends RefCounted
## The composition root the autoload policy calls for (HANDOFF §6): one place
## that loads the catalogs in the source's order (GameManager._Ready), resets
## every per-game static, and starts a game - from a fresh day zero, or from a
## snapshot. The managers stay `class_name` statics (a straight translation of
## the source's static classes); this is where their lifecycle is owned.

const DATA := "res://data"


## Everything GameManager loads before day zero, in its order.
static func load_catalogs() -> void:
	FactionRegistry.EnsureLoaded()
	RuleManager.LoadRules("%s/game_rules.json" % DATA)
	MissionTableManager.Load("%s/mission_tables.json" % DATA)
	MissionCatalog.Load("%s/missions.json" % DATA)
	UprisingTable.Load("%s/uprising_start.json" % DATA)
	SideLotteryManager.LoadRules("%s/side_lottery.json" % DATA)
	SeedManager.Load("%s/day_zero_logistics.json" % DATA, "%s/defensive_facilities.json" % DATA, "%s/military_units.json" % DATA)
	FacilityCatalog.Load(["%s/production_facilities.json" % DATA, "%s/defensive_facilities.json" % DATA])


## Every per-game static, cleared - the source's Reset() calls plus the ones it
## relies on a fresh process for.
static func reset_game_state() -> void:
	Economy.Reset()
	ForceManager.Reset()
	Fleet.ResetSerials()
	Unit.ResetSerials()
	Facility.ResetSerials()
	Mission.ResetSerials()
	GameMessage.ResetSerials()
	RepairManager.Reset()
	IntelManager.Reset()
	ResearchManager.Reset()
	MissionManager.Clear()
	EventBus.Reset()
	BlockadeManager.Reset()
	AgentDroid.Reset()
	AiManager.Reset()
	LoyaltyManager.Reset()
	StoryManager.Reset()
	InformantManager.Reset()
	SmugglingManager.Reset()
	VictoryManager.Reset()
	FleetBattleManager.Reset()
	GameState.Reset()
	StrategicTickManager.Today = 1


static func _seed(seed: int) -> void:
	GameSettings.Seed = seed
	Prng.Session = Prng.new(seed)
	print("[Prng] seed=%d" % seed)


## The characters, exactly as GameManager loads them: majors flagged, then minors.
static func load_roster() -> Array[Character]:
	var roster: Array[Character] = []
	for c in Loaders.major_characters():
		c.IsMajor = true
		roster.append(c)
	for c in Loaders.minor_characters():
		roster.append(c)
	print("Successfully loaded %d characters from the databanks." % roster.size())
	return roster


## A fresh game: GameManager._Ready's order. Returns the tick manager.
static func new_game(player_faction_id: String, difficulty: int, size: int, seed: int) -> StrategicTickManager:
	reset_game_state()
	FactionRegistry.EnsureLoaded()
	GameSettings.PlayerFaction = FactionRegistry.ById(player_faction_id)
	GameSettings.HumanFactions = [GameSettings.PlayerFaction]
	GameSettings.SelectedDifficulty = difficulty
	GameSettings.SelectedSize = size
	_seed(seed)
	load_catalogs()
	print("Initializing Galaxy with -> Faction: %s | Difficulty: %s | Size: %s" % [str(GameSettings.PlayerFaction), JsonUtil.enum_name(Enums.Difficulty, difficulty), JsonUtil.enum_name(Enums.GalaxySize, size)])

	var galaxy := GalaxyFactory.LoadGalaxy("%s/sectors_data.json" % DATA, "%s/planets_data.json" % DATA, size)
	var roster := load_roster()
	GameState.ActiveRoster = roster
	DayZeroGenerator.InitializeGalaxyState(galaxy, GameSettings.PlayerFaction, difficulty, roster)
	GameState.ActiveGalaxy = galaxy
	return StrategicTickManager.new(galaxy)


## A game from a day-zero snapshot, seeded. Returns the tick manager.
static func start_from_snapshot(path: String, seed: int) -> StrategicTickManager:
	reset_game_state()
	load_catalogs()
	if not SnapshotLoader.Load(path):
		return null
	_seed(seed)
	return StrategicTickManager.new(GameState.ActiveGalaxy)
