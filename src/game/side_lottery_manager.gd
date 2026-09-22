class_name SideLotteryManager
extends RefCounted
## backend/SideLotteryManager.cs - SDPRTB as the pack's setup.json side lottery: faction id ->
## difficulty -> {faction id -> value}. `perspective` is WHOSE GAME THIS IS (the
## human player's side); `for_side` is WHOSE VALUE YOU WANT out of the pair.

## SDPRTB entry ids the codebase reads by name (the source's SideRule class).
const CoreBucketStrong := 30
const CoreBucketWeak := 31
const StrongSupportBase := 32
const StrongSupportVar := 33
const WeakSupportBase := 34
const WeakSupportVar := 35

static var _rules: Dictionary = {}   # EntryId -> SideRuleData


## From the pack's setup.json (SCHEMA.md section 8).
static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_rules.clear()
	if pack == null or pack.Setup == null:
		push_error("[SideLottery] no pack loaded!")
		return
	for row in pack.Setup.SideLottery:
		var rule := CatalogDtos.SideRuleData.from_dict(row)
		_rules[rule.EntryId] = rule
	print("Loaded %d Side Lottery Probabilities." % _rules.size())


static func GetProbability(entry_id: int, perspective: Faction, diff: int, for_side: Faction) -> int:
	if not _rules.has(entry_id):
		return 0
	var rule: CatalogDtos.SideRuleData = _rules[entry_id]
	if for_side == null:
		return 0
	# Head-to-head reads the one multiplayer pair - no player-side row, so both
	# clients read the same number whichever side is local (M0 gate).
	if diff == Enums.Difficulty.Multiplayer:
		return rule.Mp.get(for_side.Id, 0)
	if perspective == null:
		return 0
	if not rule.By_Faction.has(perspective.Id):
		return 0
	var by_difficulty: Dictionary = rule.By_Faction[perspective.Id]
	var key: String
	match diff:
		Enums.Difficulty.Easy:        key = "easy"
		Enums.Difficulty.Hard:        key = "hard"
		_:                            key = "medium"
	if not by_difficulty.has(key):
		return 0
	var by_side: Dictionary = by_difficulty[key]
	return by_side.get(for_side.Id, 0)
