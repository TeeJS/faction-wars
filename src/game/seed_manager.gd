class_name SeedManager
extends RefCounted
## backend/SeedManager.cs - the day-zero logistics tables. It also used to load
## the defensive-facility and military-unit profiles from data/*.json; those
## are the pack's facilities.json and units.json now (Facility.Def, MilitaryCatalog).

static var Logistics: Dictionary = {}       # table id -> LogisticsFile


static func Load(pack: PackLoader.LoadedPack) -> void:
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
