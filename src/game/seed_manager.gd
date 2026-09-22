class_name SeedManager
extends RefCounted
## backend/SeedManager.cs - the day-zero logistics tables, the defensive
## facility profiles and the military unit profiles.

static var Logistics: Dictionary = {}       # file name -> LogisticsFile
static var DefenseStats: Dictionary = {}    # "family|tier" -> DefenseStatRule
static var MilitaryStats: Dictionary = {}   # Vector2i(FamilyId, Id) -> UnitStatRule


static func Load(pack: PackLoader.LoadedPack, defenses_path: String, military_path: String) -> void:
	# The TABLE ID is the dictionary key and lives nowhere on the object - it is
	# stamped on at load. These were .DAT filenames; they are role ids now
	# (SCHEMA.md section 12 Q2) and factions.json names them.
	Logistics = {}
	if pack != null and pack.Setup != null:
		for key in pack.Setup.Logistics:
			var f := CatalogDtos.LogisticsFile.from_dict(pack.Setup.Logistics[key])
			f.Name = str(key)
			Logistics[str(key)] = f
	print("[SeedManager] Loaded %d Logistics Files." % Logistics.size())

	DefenseStats = {}
	if not JsonUtil.read_text(defenses_path).strip_edges().is_empty():
		for rule in Loaders._list(defenses_path, CatalogDtos.DefenseStatRule.from_dict):
			var type: Variant = null
			match rule.FamilyId:
				34: type = "ion_cannon"
				35: type = "turbolaser_battery"
				36: type = "planetary_shield"
			if type != null:
				DefenseStats["%s|%d" % [type, rule.Tier]] = rule
		print("[SeedManager] Loaded %d Defensive Facility profiles." % DefenseStats.size())

	MilitaryStats = {}
	if not JsonUtil.read_text(military_path).strip_edges().is_empty():
		for rule in Loaders._list(military_path, CatalogDtos.UnitStatRule.from_dict):
			MilitaryStats[Vector2i(rule.FamilyId, rule.Id)] = rule
		print("[SeedManager] Loaded %d Military Unit profiles." % MilitaryStats.size())
