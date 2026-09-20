extends SceneTree
## "A fleet can explore an unexplored system. When you move a fleet to such a
## system, when the fleet arrives you learn the same information about the system
## that you do from a Recon mission ... except any characters or SpecForces that
## may be present and information concerning current manufacturing" (manual p121).
## A charted system is updated the same way (manual p069: "if you send a fleet or
## a mission to a system to investigate"). ON ARRIVAL ONLY - a fleet that stays
## does not keep the sighting fresh; no source says it does.
##
##   Godot_console.exe --headless --path . -s tests/fleet_explore.gd

const Seen := [
	Enums.IntelSection.SystemStatus, Enums.IntelSection.Troopers, Enums.IntelSection.Fighters,
	Enums.IntelSection.OrbitingShips, Enums.IntelSection.DefensiveFacilities,
	Enums.IntelSection.ProductionFacilities,
]
const Unseen := [
	Enums.IntelSection.SpecForces, Enums.IntelSection.Characters, Enums.IntelSection.Manufacturing,
]

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	# Both sides human, so no AI moves anything while the fleets are in hyperspace.
	var engine := GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243, ["alliance", "empire"], "alliance")
	var alliance: Faction = FactionRegistry.ById("alliance")
	var empire: Faction = FactionRegistry.ById("empire")

	var fleet := _first_fleet(alliance)
	_check(fleet != null, "the Alliance has a fleet at rest")
	if fleet == null:
		_finish(); return
	var home: Planet = fleet.Attached

	# --- 1. AN UNEXPLORED SYSTEM (manual p121) ---
	var dark: Planet = _first(func(p): return not p.ExploredBy(alliance) and p.ControllingFaction != empire and p.OrbitingFleets.is_empty())
	_check(dark != null, "an unexplored system with no Imperial presence exists")
	if dark == null:
		_finish(); return
	var empire_knew := dark.ExploredBy(empire)

	# Someone the fleet must NOT learn of: an Imperial character standing on it.
	var hidden: Character = _first_char(func(c): return c.Faction == empire and c.Status == Enums.Status.AwaitingOrders and c.Attached is Planet)
	_check(hidden != null, "an Imperial character is free to stand on it")
	if hidden != null:
		hidden.Attached = dark

	OrderManager.Transit([fleet], home, dark, 2, OrderManager.CascadeFleetPayloads(dark))
	engine.AdvanceDay()
	_check(fleet.Status == Enums.Status.Enroute, "day 1: the fleet is still in hyperspace")
	_check(not dark.ExploredBy(alliance), "day 1: a fleet in hyperspace has charted nothing")
	_check(not IntelManager.Knows(alliance, dark, Enums.IntelSection.SystemStatus), "day 1: and knows nothing of the system")

	engine.AdvanceDay()
	var arrival := StrategicTickManager.Today
	_check(fleet.Status == Enums.Status.AwaitingOrders and fleet.Attached == dark, "day 2: the fleet has arrived")
	_check(dark.ExploredBy(alliance), "arrival charts the system for the fleet's side")
	_check(dark.ExploredBy(empire) == empire_knew, "and for nobody else")
	for s in Seen:
		var v := IntelManager.View(alliance, dark, s)
		_check(v.Known and v.Day == arrival, "%s is known, dated the day of arrival" % JsonUtil.enum_name(Enums.IntelSection, s))
	for s in Unseen:
		_check(not IntelManager.Knows(alliance, dark, s), "%s is NOT revealed" % JsonUtil.enum_name(Enums.IntelSection, s))
	if hidden != null:
		_check(hidden.Attached == dark, "the Imperial character was standing there the whole time")
	var orbit := IntelManager.View(alliance, dark, Enums.IntelSection.OrbitingShips)
	_check(orbit.Groups.size() == 1 and orbit.Groups[0].Name == fleet.Name, "the ships in orbit are our own fleet and nothing else")

	# --- 2. ON ARRIVAL ONLY: a fleet that stays does not keep the sighting fresh ---
	engine.AdvanceDay()
	_check(fleet.Attached == dark and fleet.Status == Enums.Status.AwaitingOrders, "the fleet stays where it was sent (manual p121)")
	_check(IntelManager.View(alliance, dark, Enums.IntelSection.SystemStatus).Day == arrival, "a day in orbit does not re-date the sighting")

	# --- 3. A CHARTED SYSTEM WE DO NOT HOLD is updated the same way (manual p069) ---
	var known: Planet = _first(func(p): return p != dark and p.ExploredBy(alliance) and p.ControllingFaction != alliance and p.ControllingFaction != empire \
		and p.OrbitingFleets.is_empty() and IntelManager.Knows(alliance, p, Enums.IntelSection.SystemStatus))
	_check(known != null, "a charted neutral system exists")
	if known != null:
		var before := IntelManager.View(alliance, known, Enums.IntelSection.SystemStatus).Day
		OrderManager.Transit([fleet], dark, known, 1, OrderManager.CascadeFleetPayloads(known))
		engine.AdvanceDay()
		var after := IntelManager.View(alliance, known, Enums.IntelSection.SystemStatus).Day
		_check(fleet.Attached == known and fleet.Status == Enums.Status.AwaitingOrders, "the fleet has arrived at the charted system")
		_check(after == StrategicTickManager.Today and after > before, "its sighting is re-dated from day %d to day %d" % [before, after])
		_check(not IntelManager.Knows(alliance, known, Enums.IntelSection.Characters), "and still reveals no characters")

	# --- 4. OUR OWN SYSTEM reports itself; arrival there is not a sighting ---
	OrderManager.Transit([fleet], fleet.Attached, home, 1, OrderManager.CascadeFleetPayloads(home))
	engine.AdvanceDay()
	_check(fleet.Attached == home and home.ControllingFaction == alliance, "the fleet is home")
	_check(IntelManager.View(alliance, home, Enums.IntelSection.SystemStatus).Live, "a system we hold is live, not a snapshot")

	_finish()


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _first_fleet(faction: Faction) -> Fleet:
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == faction and f.Status != Enums.Status.Enroute and not f.Ships.is_empty() and p.ControllingFaction == faction:
				return f
	return null


func _first_char(pred: Callable) -> Character:
	for c in GameState.ActiveRoster:
		if pred.call(c):
			return c
	return null


func _finish() -> void:
	print("[fleet_explore] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
