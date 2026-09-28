extends SceneTree
## A character sent to a fleet at another system travels to it (BACKLOG #58;
## manual p046: "move that character onto the fleet as well. It will take the
## characters some time to get to the fleet, and significantly longer if they
## are traveling between sectors"). It was refused: "X is not at <system>".
##   - sent to a far fleet: on the way, its travel days, aboard on arrival;
##   - the Millennium Falcon effect with it (manual p094: Han alone, twice as fast);
##   - the fleet gone by then: a world their side holds instead;
##   - a battle that wipes the fleet out does not kill one still on the way;
##   - one in the fleet's own orbit boards at once, as before.
##
##   .\tools\run-gd.ps1 tests/character_to_distant_fleet.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[character_to_distant_fleet] ok   %s" % what)
	else:
		_fails += 1
		print("[character_to_distant_fleet] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and fleet == null:
				fleet = f
	var orbit: Planet = fleet.Attached if fleet != null else null
	var free := func(c: Character) -> bool:
		return c.Faction == us and c.Attached is Planet and c.Attached != orbit and c.Status == Enums.Status.AwaitingOrders and not c.IsCaptured()
	var walker: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return free.call(c) and not c.HasRole("smuggler"))
	var han: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return free.call(c) and c.HasRole("smuggler"))
	_check(fleet != null and walker != null, "a fleet of ours, and a character of ours at another system")
	if fleet == null or walker == null:
		_finish()
		return

	var from: Planet = walker.Attached
	var days: int = maxi(1, OrderManager.CharacterTravelDays([walker], from, orbit))
	var r: Result = CommandBus.issue("board_fleet", { "characters": [walker.Name], "fleet": fleet.ID })
	_check(r.ok and walker.Attached == fleet and walker.Destination == fleet and walker.Status == Enums.Status.Enroute and walker.DaysToDestination == days,
		"%s at %s sent to %s at %s: on the way, %d days ('%s')" % [walker.Name, from.Name, fleet.Name, orbit.Name, walker.DaysToDestination, r.error])
	if han != null:
		var alone: int = OrderManager.CharacterTravelDays([han], han.Attached, orbit)
		var plain: int = han.Attached.TravelDaysTo(orbit, 0, Planet.StandardTravelSpeed(us))
		CommandBus.issue("board_fleet", { "characters": [han.Name], "fleet": fleet.ID })
		_check(han.DaysToDestination == maxi(1, alone) and alone <= plain, "Han Solo alone: the Millennium Falcon's pace (%d days against %d)" % [alone, plain])

	# A battle that wipes the fleet out before they arrive does not take them.
	var report := FleetBattleManager.BattleReport.new()
	report.Ours = fleet
	report.OurLosses = FleetBattleManager.Casualties.new()
	report.TheirLosses = FleetBattleManager.Casualties.new()
	var kept: Array = fleet.Ships.duplicate()
	fleet.Ships.clear()
	FleetBattleManager.LoseCrews(report)
	_check(walker.Status != Enums.Status.Dead, "the fleet wiped out before %s arrives: not aboard, not lost" % walker.Name)
	for s in kept:
		fleet.Ships.append(s)

	for _d in walker.DaysToDestination:
		engine.AdvanceDay()
	_check(walker.Status == Enums.Status.AwaitingOrders and walker.Attached == fleet and walker.Destination == null,
		"%s arrives and is aboard %s" % [walker.Name, fleet.Name])

	# The fleet gone before they arrive: a world their side holds.
	var other: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return free.call(c) and c != han)
	if other != null:
		CommandBus.issue("board_fleet", { "characters": [other.Name], "fleet": fleet.ID })
		orbit.OrbitingFleets.erase(fleet)
		for _d in other.DaysToDestination:
			engine.AdvanceDay()
		_check(other.Attached is Planet and (other.Attached as Planet).ControllingFaction == us and other.Status == Enums.Status.AwaitingOrders,
			"%s's fleet gone before arrival: at %s, a world of ours" % [other.Name, other.Attached.Name if other.Attached != null else "nowhere"])
		orbit.OrbitingFleets.append(fleet)

	# The fleet's own orbit: aboard at once.
	var local: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.Attached == orbit and c.Status == Enums.Status.AwaitingOrders and not c.IsCaptured())
	if local == null:
		local = walker
		OrderManager.Disembark([walker])
	r = CommandBus.issue("board_fleet", { "characters": [local.Name], "fleet": fleet.ID })
	_check(r.ok and local.Attached == fleet and local.Status == Enums.Status.AwaitingOrders, "%s in %s's orbit boards at once" % [local.Name, fleet.Name])
	_finish()


func _finish() -> void:
	print("[character_to_distant_fleet] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
