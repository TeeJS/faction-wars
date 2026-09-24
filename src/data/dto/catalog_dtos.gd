class_name CatalogDtos
extends RefCounted
## The rule-table DTOs the pack path still hydrates - rules.json rows
## (GameRuleData), the side lottery (SideRuleData) and the day-zero logistics
## tables (LogisticsAsset/Entry/File) - one inner class per C# class, with the
## exact defaults and nullability of its C# declaration. Where C# says `int?`,
## the field here is Variant and stays null (HANDOFF risk 8). The other eleven
## DTOs read data/*.json, which is gone (2026-09-22): PackDefs is the contract.


## the C# property is By_Faction and the loader is case-insensitive.
class GameRuleData:
	var EntryId: int
	var Name: String
	var ParameterId: int
	var Development: int
	var Multiplayer: int
	var By_Faction: Dictionary = {}

	static func from_dict(d: Dictionary) -> GameRuleData:
		var o := GameRuleData.new()
		o.EntryId = JsonUtil.int_or(d, "EntryId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.ParameterId = JsonUtil.int_or(d, "ParameterId")
		o.Development = JsonUtil.int_or(d, "Development")
		o.Multiplayer = JsonUtil.int_or(d, "Multiplayer")
		var bf: Variant = JsonUtil.get_ci(d, "By_Faction")
		if bf != null:
			for faction_id in JsonUtil.data_keys(bf):
				o.By_Faction[str(faction_id)] = JsonUtil.str_int_dict(bf, str(faction_id))
		return o


## By_Faction: faction id -> difficulty -> {faction id -> value}.
class SideRuleData:
	var EntryId: int
	var Name: String
	var GroupId: int
	## Easy / Medium / Hard per player side (manual p067: the three campaigns).
	var By_Faction: Dictionary = {}
	## The two pairs the binary carries beyond the three difficulties. The manual
	## has no fourth difficulty; open-rebellion's dumper labels slots 3-4 dev and
	## slots 17-18 multiplayer, the same reading the rules parser chose for
	## GNPRTB. Unsettled at the source (docs/m0-audit.md question 2).
	var Dev: Dictionary = {}
	var Mp: Dictionary = {}

	static func from_dict(d: Dictionary) -> SideRuleData:
		var o := SideRuleData.new()
		o.EntryId = JsonUtil.int_or(d, "EntryId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.GroupId = JsonUtil.int_or(d, "GroupId")
		var bf: Variant = JsonUtil.get_ci(d, "By_Faction")
		if bf != null:
			for faction_id in JsonUtil.data_keys(bf):
				var by_diff := {}
				var inner: Variant = bf[faction_id]
				if inner != null:
					for diff in JsonUtil.data_keys(inner):
						by_diff[str(diff)] = JsonUtil.str_int_dict(inner, str(diff))
				o.By_Faction[str(faction_id)] = by_diff
		o.Dev = JsonUtil.str_int_dict(d, "dev")
		o.Mp = JsonUtil.str_int_dict(d, "mp")
		return o


## backend/LogisticsModels.cs - setup.json logistics. What a seeding row places,
## BY PACK ID (SCHEMA.md section 12 Q1): a `unit` from units.json or a
## `facility` from facilities.json. The original's FamilyId/AssetId numbers are
## gone - they were the last place a pack row named a thing by the binary's
## table position rather than by its id.
class LogisticsAsset:
	var UnitId: String = ""
	var FacilityId: String = ""

	static func from_dict(d: Dictionary) -> LogisticsAsset:
		var o := LogisticsAsset.new()
		o.UnitId = JsonUtil.str_or(d, "unit", "")
		o.FacilityId = JsonUtil.str_or(d, "facility", "")
		return o

	## A "None" row in the original tables - a band that places nothing.
	func IsEmpty() -> bool:
		return UnitId.is_empty() and FacilityId.is_empty()


class LogisticsEntry:
	var ParentId: int
	var ProbabilityThreshold: int
	var SpawnChancePercent: int          # SYFC files
	var Asset: LogisticsAsset            # SYFC files
	var Multiplier: int = 1              # CMUN / FACL files
	var Assets: Variant = null           # List<LogisticsAsset>, no initialiser -> null

	static func from_dict(d: Dictionary) -> LogisticsEntry:
		var o := LogisticsEntry.new()
		o.ParentId = JsonUtil.int_or(d, "ParentId")
		o.ProbabilityThreshold = JsonUtil.int_or(d, "ProbabilityThreshold")
		o.SpawnChancePercent = JsonUtil.int_or(d, "SpawnChancePercent")
		var a: Variant = JsonUtil.get_ci(d, "Asset")
		o.Asset = LogisticsAsset.from_dict(a) if a != null else null
		o.Multiplier = JsonUtil.int_or(d, "Multiplier", 1)
		var list: Variant = JsonUtil.get_ci(d, "Assets")
		if list != null:
			var assets: Array[LogisticsAsset] = []
			for e in list:
				# null = the original's "None" child: an empty carrier slot.
				assets.append(LogisticsAsset.from_dict(e) if e is Dictionary else LogisticsAsset.new())
			o.Assets = assets
		return o


class LogisticsFile:
	var Name: String                     # stamped from the dictionary key at load
	var Type: String                     # a CATEGORY, not a name
	var Description: String
	var Entries: Variant = null          # List<LogisticsEntry>, no initialiser -> null
	## The two GNPRTB entry ids bounding this table's FIXED LIST, [first, max],
	## or empty for a table drawn by random band. Pack data (setup.json) - it
	## used to be decided by matching the .DAT filename in DayZeroGenerator.
	var FixedRange: Array[int] = []

	static func from_dict(d: Dictionary) -> LogisticsFile:
		var o := LogisticsFile.new()
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.Type = JsonUtil.str_or(d, "Type", "")
		o.Description = JsonUtil.str_or(d, "Description", "")
		var fr: Variant = JsonUtil.get_ci(d, "fixed_range")
		if fr is Array and fr.size() == 2:
			o.FixedRange = [int(fr[0]), int(fr[1])]
		var list: Variant = JsonUtil.get_ci(d, "Entries")
		if list != null:
			var entries: Array[LogisticsEntry] = []
			for e in list:
				entries.append(LogisticsEntry.from_dict(e))
			o.Entries = entries
		return o
