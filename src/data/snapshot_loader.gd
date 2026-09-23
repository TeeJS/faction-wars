class_name SnapshotLoader
extends RefCounted
## HANDOFF step 1B: hydrate the source's day-zero snapshot (backend/Snapshot.cs
## output) into live game objects. Names are resolved to references along the
## ownership spine the writer used: a Planet/Sector/Character reference is a name;
## a Fleet a character is aboard was written inline and is resolved by its name
## inside the planet's orbit list.

static var _planets_by_name: Dictionary = {}

## Enums.FacilityType member names, as the C# snapshot writer spells them, mapped
## onto this pack's facility families (SCHEMA.md section 5).
const LEGACY_FACILITY_FAMILIES := {
	"Headquarters": "headquarters", "Mine": "mine", "Refinery": "refinery",
	"ConstructionYard": "construction_yard", "Shipyard": "shipyard",
	"TrainingFacility": "training_facility", "PlanetaryShield": "planetary_shield",
	"TurbolaserBattery": "turbolaser_battery", "IonCannon": "ion_cannon",
	"DeathStarShield": "death_star_shield",
}


static func Load(path: String) -> bool:
	var data: Variant = JsonUtil.parse(path)
	if data == null:
		push_error("snapshot: cannot read %s" % path)
		return false

	var mismatch := FactionRegistry.HeaderMismatch(data)
	if not mismatch.is_empty():
		push_error("snapshot: %s" % mismatch)
		return false
	if not FactionRegistry.EnsureLoaded(str(data.get("pack", ""))):
		return false

	GameSettings.Seed = int(data.get("seed", 0))
	GameSettings.SelectedDifficulty = JsonUtil.enum_or(data, "difficulty", Enums.Difficulty, Enums.Difficulty.Medium)
	GameSettings.SelectedSize = JsonUtil.enum_or(data, "galaxySize", Enums.GalaxySize, Enums.GalaxySize.Large)
	GameSettings.HQOnlyVictory = bool(data.get("hqOnlyVictory", false))
	GameSettings.PlayerFaction = FactionRegistry.ById(data.get("playerFaction"))
	# A ternary yields an UNTYPED Array, which will not assign to Array[Faction];
	# that rejection took the whole snapshot path down (bench_1b, soak --snapshot).
	var humans: Array[Faction] = []
	if GameSettings.PlayerFaction != null:
		humans.append(GameSettings.PlayerFaction)
	GameSettings.HumanFactions = humans

	_planets_by_name.clear()
	var galaxy: Array[Sector] = []
	var deferred: Array = []   # [obj, field, name] to resolve once every planet exists

	for sd in data["sectors"]:
		var s := Sector.new()
		s.SectorId = int(sd.get("SectorId", 0))
		s.Name = str(sd.get("Name", ""))
		s.GalaxyRing = int(sd.get("GalaxyRing", 0))
		s.StartsNeutral = bool(sd.get("StartsNeutral", false))
		s.MapX = int(sd.get("MapX", 0))
		s.MapY = int(sd.get("MapY", 0))
		s.MinX = float(sd.get("MinX", 0))
		s.MaxX = float(sd.get("MaxX", 0))
		s.MinY = float(sd.get("MinY", 0))
		s.MaxY = float(sd.get("MaxY", 0))
		for pd in sd.get("Planets", []):
			var p := _planet(pd, deferred)
			s.Planets.append(p)
			_planets_by_name[p.Name] = p
		galaxy.append(s)

	var roster: Array[Character] = []
	for cd in data["characters"]:
		roster.append(_character(cd, deferred))

	# Second pass: names -> references.
	for d in deferred:
		var obj: Object = d[0]
		var field: String = d[1]
		var ref: Variant = d[2]
		obj.set(field, _resolve_location(ref))

	GameState.ActiveGalaxy = galaxy
	GameState.ActiveRoster = roster

	# The serial counter must continue past the highest fleet serial in the
	# snapshot, or a new fleet would repeat a name.
	var highest := 0
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			var tail := f.Name.substr(f.Name.rfind("_") + 1)
			if tail.is_valid_int():
				highest = max(highest, int(tail))
	Fleet.ResetSerials()
	for i in highest:
		Fleet.NextSerial()

	print("[Snapshot] %d sectors, %d planets, %d characters from %s (seed %d)." % [galaxy.size(), _planets_by_name.size(), roster.size(), path, GameSettings.Seed])
	return true


static func _resolve_location(ref: Variant) -> Location:
	if ref == null:
		return null
	if ref is String:
		return _planets_by_name.get(ref)
	if ref is Dictionary:
		# An inline Fleet: find it by name in its planet's orbit list.
		var planet: Planet = _planets_by_name.get(str(ref.get("Attached", "")))
		if planet == null:
			return null
		for f in planet.OrbitingFleets:
			if f.Name == str(ref.get("Name", "")):
				return f
	return null


## The snapshot is the C# writer's format and names worlds and people by DISPLAY
## NAME. The pack references them by id, so each is looked up once here.
static func _planet_id_for(display_name: String) -> String:
	var pack := FactionRegistry.Pack
	if pack != null and pack.Map != null:
		for pd in pack.Map.Planets:
			if pd.DisplayName == display_name:
				return pd.Id
	return ""


static func _character_id_for(display_name: String) -> String:
	var pack := FactionRegistry.Pack
	if pack != null:
		for cd in pack.Characters:
			if cd.DisplayName == display_name:
				return cd.Id
	return ""


static func _faction(v: Variant) -> Faction:
	return null if v == null else FactionRegistry.ById(str(v))


static func _planet(pd: Dictionary, deferred: Array) -> Planet:
	var p := Planet.new()
	p.Name = str(pd.get("Name", ""))
	p.PackId = _planet_id_for(p.Name)
	p.MapX = float(pd.get("MapX", 0))
	p.ArtworkId = int(pd.get("ArtworkId", 0))
	p.MapY = float(pd.get("MapY", 0))
	p.StartsInhabited = bool(pd.get("StartsInhabited", false))
	p.IsInhabited = bool(pd.get("IsInhabited", false))
	p.SectorId = int(pd.get("SectorId", 0))
	p.BaseEnergy = int(pd.get("BaseEnergy", 0))
	p.BaseRawMaterials = int(pd.get("BaseRawMaterials", 0))
	p.ControllingFaction = _faction(pd.get("ControllingFaction"))
	# The C# snapshot carries ONE chart - the human's. The other side's chart is
	# not in the file, so a snapshot start is a hydration check, not a parity path.
	for h in GameSettings.HumanFactions:
		p.SetExplored(h, bool(pd.get("IsExplored", false)))
	p.IsInUprising = bool(pd.get("IsInUprising", false))
	p.IsNearUprising = bool(pd.get("IsNearUprising", false))

	var support: Variant = pd.get("Support")
	if support is Dictionary:
		for k in support.keys():
			p._support[str(k)] = int(support[k])

	for fd in pd.get("Facilities", []):
		var f := Facility.new()
		f.Attached = p
		# The C# snapshot writes the old Enums.FacilityType NAME ("TurbolaserBattery").
		# Mapped to a pack family here, as with the character aptitude fields above:
		# an external format keeps its own spelling.
		var fam: String = LEGACY_FACILITY_FAMILIES.get(str(fd.get("Type", "")), "mine")
		f.Tier = int(fd.get("Tier", 1))
		f.Def = FacilityCatalog.Get(fam, f.Tier)
		f.IsDamaged = bool(fd.get("IsDamaged", false))
		f.IsSelected = bool(fd.get("IsSelected", false))
		f.ConstructionCost = int(fd.get("ConstructionCost", 0))
		f.MaintenanceCost = int(fd.get("MaintenanceCost", 0))
		f.WeaponRating = int(fd.get("WeaponRating", 0))
		f.ShieldStrength = int(fd.get("ShieldStrength", 0))
		f.BombardmentDefense = int(fd.get("BombardmentDefense", 0))
		p.Facilities.append(f)

	for ud in pd.get("Garrison", []):
		p.Garrison.append(_unit(ud, deferred))
	for ud in pd.get("FighterSquadrons", []):
		p.FighterSquadrons.append(_unit(ud, deferred))

	for fd in pd.get("OrbitingFleets", []):
		var fl := Fleet.new()
		fl.Name = str(fd.get("Name", ""))
		fl.Commander = str(fd.get("Commander", "")) if fd.get("Commander") != null else ""
		fl.Status = JsonUtil.enum_or(fd, "Status", Enums.Status, Enums.Status.AwaitingOrders)
		fl.DaysToDestination = int(fd.get("DaysToDestination", 0))
		fl.Faction = _faction(fd.get("Faction"))
		fl.MapX = float(fd.get("MapX", 0))
		fl.MapY = float(fd.get("MapY", 0))
		var tail := fl.Name.substr(fl.Name.rfind("_") + 1)
		fl.ID = Fleet.IdFor(int(tail)) if tail.is_valid_int() else ""
		for sd in fd.get("Ships", []):
			fl.Ships.append(_unit(sd, deferred))
		deferred.append([fl, "Attached", fd.get("Attached")])
		deferred.append([fl, "Destination", fd.get("Destination")])
		p.OrbitingFleets.append(fl)

	# Queues and in-transit shipments are empty at day zero; the writer proves
	# it (Snapshot.cs comment). Assert rather than silently drop.
	assert(pd.get("BuildingQueue", []).is_empty() and pd.get("ShipyardQueue", []).is_empty() and pd.get("TrainingQueue", []).is_empty(), "snapshot has queued work - not a day-zero snapshot")
	return p


const UNIT_SKIP := ["Hangar", "Attached", "Destination", "Faction", "Damage", "CapturedBy", "Commanding"]


static func _hydrate_unit_fields(u: Unit, ud: Dictionary) -> void:
	JsonUtil.hydrate(u, ud, u._enum_fields(), {}, UNIT_SKIP)
	u.Faction = _faction(ud.get("Faction"))
	# The C# snapshot predates pack ids: it names units by display name. Map
	# that onto the pack here, at the format boundary, so nothing downstream
	# has to match a name.
	if u.PackId.is_empty():
		var def: Variant = Lq.first_or_null(MilitaryCatalog.All(), func(d): return d.DisplayName == u.Name)
		if def != null:
			u.PackId = def.Id


static func _unit(ud: Dictionary, deferred: Array) -> Unit:
	var u := Unit.new()
	_hydrate_unit_fields(u, ud)
	deferred.append([u, "Attached", ud.get("Attached")])
	deferred.append([u, "Destination", ud.get("Destination")])
	var hangar: Variant = ud.get("Hangar")
	if hangar is Array:
		for hd in hangar:
			u.Hangar.append(_unit(hd, deferred))
	return u


## The C# snapshot writer's names for the character aptitude fields, which this
## engine renamed to "special power" (SCHEMA.md section 12 Q5). The snapshot is an
## EXTERNAL format produced by the other repo, so it keeps its own spelling and is
## mapped here. Without this, `hydrate` drops the keys silently and every
## snapshot-loaded character comes back with a zeroed aptitude - no error, no hint.
const LEGACY_POWER_FIELDS := {
	"JediLevel": "SpecialPowerLevel",
	"JediLevelBase": "SpecialPowerLevelBase",
	"JediLevelVar": "SpecialPowerLevelVar",
	"JediProbability": "SpecialPowerProbability",
	"IsKnownJedi": "IsKnownSpecialPowerUser",
	"CanTrainJedi": "CanTrainSpecialPower",
}


static func _character(cd: Dictionary, deferred: Array) -> Character:
	var c := Character.new()
	_hydrate_unit_fields(c, cd)
	c.PackId = _character_id_for(c.Name)
	for legacy in LEGACY_POWER_FIELDS:
		if cd.has(legacy):
			c.set(LEGACY_POWER_FIELDS[legacy], cd[legacy])
	c.CapturedBy = _faction(cd.get("CapturedBy"))
	deferred.append([c, "Attached", cd.get("Attached")])
	deferred.append([c, "Destination", cd.get("Destination")])
	deferred.append([c, "Commanding", cd.get("Commanding")])
	return c
