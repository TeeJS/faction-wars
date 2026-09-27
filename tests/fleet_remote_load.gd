extends SceneTree
## A regiment sent to a fleet at another system joins it (TeeJ, 2026-09-27:
## the fleet "is not taking troops, even though it can hold 2" - troops at
## Umgul dropped on Fleet 2 at Orto, "Nothing there could be loaded."). Manual
## p122: "If you move a ship onto a fleet in a different sector, that ship will
## immediately be considered a member of the fleet but will still be in
## hyperspace for several days until it arrives" - a regiment the same way:
##   - dropped on the far fleet it is aboard at once, its berth taken, in
##     hyperspace for the travel days;
##   - until it arrives it cannot land, and an assault leaves it out;
##   - it arrives on its day and is there;
##   - a fleet with no room left says so;
##   - one from the world below still goes aboard at once.
##
##   .\tools\run-gd.ps1 tests/fleet_remote_load.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_remote_load] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_remote_load] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var engine: StrategicTickManager = GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	# A fleet of ours with a berth free, and a regiment of ours on another world.
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and Lq.any(f.Ships, func(s: Unit) -> bool: return OrderManager.HasRoomFor(s, Enums.UnitType.Troop)):
				fleet = f
				break
		if fleet != null:
			break
	var orbit: Planet = fleet.Attached if fleet != null else null
	var troop: Unit = null
	for p in GameState.AllPlanets():
		if p == orbit or p.ControllingFaction != us:
			continue
		troop = Lq.first_or_null(p.Garrison, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop and u.Faction == us and u.Status != Enums.Status.Enroute)
		if troop != null:
			break
	_check(fleet != null and troop != null, "a fleet of ours with room, and a regiment of ours elsewhere")
	if fleet == null or troop == null:
		_finish()
		return
	var from: Planet = troop.Attached
	var days: int = OrderManager.UnitTravelDays([troop], from, orbit)

	var r: Result = OrderManager.LoadAboard([troop], fleet)
	_check(r.ok and OrderManager.CarrierOf(troop) == fleet and not from.Garrison.has(troop),
		"%s at %s dropped on %s at %s: aboard at once ('%s')" % [troop.Name, from.Name, fleet.Name, orbit.Name, r.error])
	_check(troop.Status == Enums.Status.Enroute and OrderManager.Inbound(troop) and troop.DaysToDestination == maxi(1, days),
		"... in hyperspace for %d days" % troop.DaysToDestination)
	_check(not AssaultManager.LandingForce(fleet).has(troop), "... an assault leaves it out until it arrives")
	var landing: Result = OrderManager.UnloadUnits([troop])
	_check(not landing.ok and OrderManager.CarrierOf(troop) == fleet, "... it cannot land before it arrives")

	for _d in troop.DaysToDestination:
		engine.AdvanceDay()
	_check(troop.Status == Enums.Status.AwaitingOrders and not OrderManager.Inbound(troop) and OrderManager.CarrierOf(troop) == fleet
		and AssaultManager.LandingForce(fleet).has(troop), "it arrives on its day, and is there")

	# Full: says so.
	var room: int = 0
	for s in fleet.Ships:
		room += s.TroopCapacity - Lq.count(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Troop)
	var more: Array = []
	for p in GameState.AllPlanets():
		if p == orbit or p.ControllingFaction != us:
			continue
		for u in p.Garrison:
			if u.Type == Enums.UnitType.Troop and u.Faction == us and u.Status != Enums.Status.Enroute:
				more.append(u)
	if more.size() > room:
		var full: Result = OrderManager.LoadAboard(more.slice(0, room + 1), fleet)
		_check(full.error == "%s has no room left." % fleet.Name and int(full.value) == room,
			"a fleet filled up says so ('%s', %d aboard)" % [full.error, int(full.value)])

	# The world below: aboard at once, as before.
	var below: Unit = Lq.first_or_null(orbit.Garrison, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop and u.Faction == us)
	if below != null:
		OrderManager.Unload(fleet)
		var here: Result = OrderManager.LoadAboard([below], fleet)
		_check(here.ok and OrderManager.CarrierOf(below) == fleet and below.Status != Enums.Status.Enroute, "one from the world below: aboard at once")
	_finish()


func _finish() -> void:
	print("[fleet_remote_load] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
