extends SceneTree
## The original's names (TeeJ, 2026-09-24: "switch to original"): each side's
## fleets are "Fleet 1", "Fleet 2" ... ("I don't believe you can have more
## than 1 fleet with the same name ... on the same side at least"); capital
## ships are numbered in their class ("Victory Destroyer 2"). Orders name a
## fleet by its ID, and a save's older name ("Empire Fleet_0004") still finds it.
##
##   .\tools\run-gd.ps1 tests/original_names.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_names] ok   %s" % what)
	else:
		_fails += 1
		print("[original_names] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 12345)
	var fleets: Array = []
	for p in GameState.AllPlanets():
		fleets.append_array(p.OrbitingFleets)
	_check(fleets.size() > 2, "%d fleets at day zero" % fleets.size())

	# Each side's names: "Fleet N", unique on the side.
	var bySide: Dictionary = {}
	var wellFormed := true
	for f: Fleet in fleets:
		var side: String = f.Faction.Id if f.Faction != null else ""
		if not bySide.has(side):
			bySide[side] = []
		bySide[side].append(f.Name)
		if not (f.Name.begins_with("Fleet ") and f.Name.substr(6).is_valid_int()):
			wellFormed = false
	_check(wellFormed, "every fleet is 'Fleet N' (%s)" % ", ".join(fleets.slice(0, 4).map(func(f: Fleet) -> String: return f.Name)))
	for side in bySide:
		var names: Array = bySide[side]
		var unique: Dictionary = {}
		for n in names:
			unique[n] = true
		_check(unique.size() == names.size(), "%s: %d fleets, no two named alike" % [side, names.size()])

	# Capital ships: "<class> N", unique in the class on a side.
	var ships: Dictionary = {}
	var numbered := true
	var twice: Array = []
	for f: Fleet in fleets:
		for s in f.Ships:
			if s.Type != Enums.UnitType.CapitalShip:
				continue
			var key: String = "%s|%s" % [s.Faction.Id if s.Faction != null else "", s.Name]
			if ships.has(key):
				twice.append(s.Name)
			ships[key] = true
			var tail: String = s.Name.substr(s.Name.rfind(" ") + 1)
			if not tail.is_valid_int():
				numbered = false
	_check(numbered and ships.size() > 0, "%d capital ships, each numbered in its class" % ships.size())
	_check(twice.is_empty(), "no two ships of a side named alike %s" % str(twice))

	# Orders find a fleet by its ID; an older save's name by its serial.
	var f0: Fleet = Lq.first_or_null(fleets, func(f: Fleet) -> bool:
		return f.Ships.size() > 1 and Lq.any(f.Ships, func(u: Unit) -> bool: return u.Type == Enums.UnitType.CapitalShip))
	if f0 == null:
		f0 = fleets[0]
	_check(EntityIndex.fleet(f0.ID) == f0, "%s found by its ID" % f0.Name)
	var serial: int = f0.ID.substr(0, 8).hex_to_int()
	_check(EntityIndex.fleet("%s Fleet_%04d" % [f0.Faction.DisplayName, serial]) == f0,
		"'%s Fleet_%04d' (an older save's name) finds %s" % [f0.Faction.DisplayName, serial, f0.Name])

	# A new fleet takes its side's next number.
	var side0: Faction = f0.Faction
	var highest := 0
	for n in bySide[side0.Id]:
		highest = maxi(highest, int(str(n).substr(6)))
	var home: Planet = f0.Attached as Planet
	var ship: Unit = Lq.first_or_null(f0.Ships, func(u: Unit) -> bool: return u.Type == Enums.UnitType.CapitalShip)
	_check(f0.Ships.size() > 1 and ship != null and home != null, "%s has a ship to split off" % f0.Name)
	if f0.Ships.size() > 1 and ship != null and home != null:
		var made: Fleet = home.DetachIntoOwnFleet(ship)
		_check(made != null and made.Name == "Fleet %d" % (highest + 1), "a new %s fleet is 'Fleet %d' (%s)" % [side0.Id, highest + 1, made.Name if made != null else "-"])
	print("[original_names] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
