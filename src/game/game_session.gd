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
	# ORDER IS THE SOURCE'S. Kept deliberately: this used to read a pile of
	# data/*.json and now reads the pack, but the sequence is unchanged.
	FactionRegistry.EnsureLoaded()
	RuleManager.LoadFromPack(FactionRegistry.Pack)
	MissionTableManager.LoadFromPack(FactionRegistry.Pack)
	MissionCatalog.LoadFromPack(FactionRegistry.Pack)
	UprisingTable.LoadFromPack(FactionRegistry.Pack)
	SideLotteryManager.LoadFromPack(FactionRegistry.Pack)
	SeedManager.Load(FactionRegistry.Pack, "%s/defensive_facilities.json" % DATA, "%s/military_units.json" % DATA)
	FacilityCatalog.LoadFromPack(FactionRegistry.Pack)
	MilitaryCatalog.LoadFromPack(FactionRegistry.Pack)
	Gid.LoadFromPack(FactionRegistry.Pack)


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
	CommandBus.Reset()
	StrategicTickManager.Today = 1


static func _seed(seed: int) -> void:
	GameSettings.Seed = seed
	Prng.Session = Prng.new(seed)
	print("[Prng] seed=%d" % seed)


## The characters, from the pack. The two-file major/minor split became an
## is_major flag; the pack file keeps majors first, which is the order
## GameManager loaded them in and the order day zero consumes the PRNG in.
static func load_roster() -> Array[Character]:
	var roster: Array[Character] = []
	for def in FactionRegistry.Pack.Characters:
		roster.append(Character.FromPack(def))
	print("Successfully loaded %d characters from the databanks." % roster.size())
	return roster


## A fresh game: GameManager._Ready's order. Returns the tick manager.
## humans: the human sides (default: the local one); host: the host's side in a
## head-to-head game (default: none). Both must be identical on both clients.
static func new_game(player_faction_id: String, difficulty: int, size: int, seed: int, humans: Array = [], host_id: String = "") -> StrategicTickManager:
	reset_game_state()
	FactionRegistry.EnsureLoaded()
	GameSettings.PlayerFaction = FactionRegistry.ById(player_faction_id)
	GameSettings.HumanFactions = []
	for h in humans:
		GameSettings.HumanFactions.append(FactionRegistry.ById(h))
	if GameSettings.HumanFactions.is_empty():
		GameSettings.HumanFactions = [GameSettings.PlayerFaction]
	GameSettings.HostFaction = FactionRegistry.ById(host_id) if not host_id.is_empty() else null
	GameSettings.SelectedDifficulty = difficulty
	GameSettings.SelectedSize = size
	_seed(seed)
	load_catalogs()
	print("Initializing Galaxy with -> Faction: %s | Difficulty: %s | Size: %s" % [str(GameSettings.PlayerFaction), JsonUtil.enum_name(Enums.Difficulty, difficulty), JsonUtil.enum_name(Enums.GalaxySize, size)])

	var galaxy := GalaxyFactory.LoadFromPack(FactionRegistry.Pack, size)
	var roster := load_roster()
	GameState.ActiveRoster = roster
	DayZeroGenerator.InitializeGalaxyState(galaxy, GameSettings.SeedingFaction(), difficulty, roster)
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
