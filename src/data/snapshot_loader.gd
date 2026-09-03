class_name SnapshotLoader
extends RefCounted
## HANDOFF step 1B: hydrate the source's day-zero snapshot (backend/Snapshot.cs
## output) into live game objects. Names are resolved to references along the
## ownership spine the writer used: a Planet/Sector/Character reference is a name;
## a Fleet a character is aboard was written inline and is resolved by its name
## inside the planet's orbit list.

static var _planets_by_name: Dictionary = {}


static func Load(path: String) -> bool:
	var data: Variant = JsonUtil.parse(path)
	if data == null:
		push_error("snapshot: cannot read %s" % path)
		return false

	FactionRegistry.EnsureLoaded()

	GameSettings.Seed = int(data.get("seed", 0))
	GameSettings.SelectedDifficulty = JsonUtil.enum_or(data, "difficulty", Enums.Difficulty, Enums.Difficulty.Medium)
	GameSettings.SelectedSize = JsonUtil.enum_or(data, "galaxySize", Enums.GalaxySize, Enums.GalaxySize.Large)
	GameSettings.HQOnlyVictory = bool(data.get("hqOnlyVictory", false))
	GameSettings.PlayerFaction = FactionRegistry.ById(data.get("playerFaction"))
	GameSettings.HumanFactions = [GameSettings.PlayerFaction] if GameSettings.PlayerFaction != null else []

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


static func _faction(v: Variant) -> Faction:
	return null if v == null else FactionRegistry.ById(str(v))


static func _planet(pd: Dictionary, deferred: Array) -> Planet:
	var p := Planet.new()
	p.Name = str(pd.get("Name", ""))
	p.MapX = float(pd.get("MapX", 0))
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
		f.Type = JsonUtil.enum_or(fd, "Type", Enums.FacilityType, Enums.FacilityType.Mine)
		f.Tier = int(fd.get("Tier", 1))
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


static func _character(cd: Dictionary, deferred: Array) -> Character:
	var c := Character.new()
	_hydrate_unit_fields(c, cd)
	c.CapturedBy = _faction(cd.get("CapturedBy"))
	deferred.append([c, "Attached", cd.get("Attached")])
	deferred.append([c, "Destination", cd.get("Destination")])
	deferred.append([c, "Commanding", cd.get("Commanding")])
	return c
