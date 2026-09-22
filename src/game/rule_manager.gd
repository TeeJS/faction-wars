class_name RuleManager
extends RefCounted
## backend/RuleManager.cs - GNPRTB.DAT's 213 tuning constants, as the pack's rules.json.
## The entry ids this codebase reads by name live in RuleId; values live in the
## pack, NOT here.

static var _rules: Dictionary = {}   # EntryId -> CatalogDtos.GameRuleData


## From the pack (SCHEMA.md section 8). Rows keep their integer EntryId - Q6 -
## and rule_id.gd stays the way engine code names one.
static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_rules.clear()
	if pack == null:
		push_error("[RuleManager] no pack loaded!")
		return
	for row in pack.Rules:
		var rule := CatalogDtos.GameRuleData.from_dict(row)
		_rules[rule.EntryId] = rule
	print("Successfully loaded %d standard RTS rules." % _rules.size())

	if GameSettings.LocalFaction() == null:
		return   # Main.tscn run directly
	var sample := GetRule(RuleId.SpaceTravelBase, GameSettings.LocalFaction(), GameSettings.SelectedDifficulty)
	if sample <= 0:
		push_error("ERROR: rules loaded but per-faction values are empty - entry 1 (Space Travel Time: Base) read as 0. Check the JSON key casing against GameRuleData.")
	else:
		print("  rule sanity: entry 1 = %d for %s/%s." % [sample, GameSettings.LocalFaction().Id, JsonUtil.enum_name(Enums.Difficulty, GameSettings.SelectedDifficulty)])


## The accessor. Difficulty picks the column; Multiplayer is the shared one.
static func GetRule(entry_id: int, faction: Faction, difficulty: int) -> int:
	if not _rules.has(entry_id):
		push_error("WARNING: Tried to access missing Rule ID %d" % entry_id)
		return 0
	var rule: CatalogDtos.GameRuleData = _rules[entry_id]
	if difficulty == Enums.Difficulty.Multiplayer:
		return rule.Multiplayer
	if faction == null:
		return 0
	if not rule.By_Faction.has(faction.Id):
		return 0
	var by_difficulty: Dictionary = rule.By_Faction[faction.Id]
	var key: String
	match difficulty:
		Enums.Difficulty.Easy:
			key = "easy"
		Enums.Difficulty.Hard:
			key = "hard"
		_:
			key = "medium"
	return by_difficulty[key] if by_difficulty.has(key) else 0


## What almost every caller wants: this game's difficulty, and a faction that
## defaults to the player's when the caller has no particular side in mind.
static func Get(entry_id: int, faction: Faction = null) -> int:
	return GetRule(entry_id, faction if faction != null else GameSettings.PlayerFaction, GameSettings.SelectedDifficulty)


## FOR ENTRIES THAT ARE STRUCTURAL RATHER THAN PER-SIDE: falls back to the
## Development column, which is safe because all 213 shipped entries are uniform
## across every value column (RULES-TABLE.md).
static func GetShared(entry_id: int) -> int:
	var v := GetRule(entry_id, GameSettings.PlayerFaction, GameSettings.SelectedDifficulty)
	if v != 0:
		return v
	return _rules[entry_id].Development if _rules.has(entry_id) else 0


## THE TABLE'S DOMINANT SHAPE: a "Base" entry paired with a "Max Random Extra" /
## "Random Spread" entry. Inclusive at both ends. No engine-RNG fallback: a null
## rng is a bug and must fail loudly (HANDOFF step 0b).
static func Roll(base_id: int, spread_id: int, rng: Prng, faction: Faction = null) -> int:
	var b := Get(base_id, faction)
	var spread := Get(spread_id, faction)
	if spread <= 0:
		return b
	assert(rng != null, "RuleManager.Roll: null rng")
	return b + rng.NextRange(0, spread + 1)


## The name the pack gives an entry - for logs and debug readouts only.
static func NameOf(entry_id: int) -> String:
	return _rules[entry_id].Name if _rules.has(entry_id) else "Unknown Rule %d" % entry_id


static func IsLoaded() -> bool:
	return _rules.size() > 0
