extends SceneTree
## Troops land from a fleet on the world it orbits (manual p120: "Select the
## troops and drag them onto the system, or right-click -> Move"), even with a
## regiment already landed still among those picked (TeeJ, 2026-09-27: the
## Coruscant fleet's troops refused, "Already at Coruscant."). The Fleet
## window kept a landed regiment selected, and the move took its place - the
## ground - as where the rest started from.
##   - the order: a landed regiment and one aboard, onto the world below: the
##     one aboard lands; with nothing left to move, "Already at" as before;
##   - the Fleet window: a regiment landed leaves its selection.
##
##   .\tools\run-gd.ps1 tests/fleet_troops_land.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_troops_land] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_troops_land] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById("empire")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var briefing: Node = ui.Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	await process_frame
	var us: Faction = GameSettings.PlayerFaction
	var fleet: Fleet = null
	var world: Planet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and _aboard(f).size() >= 2:
				fleet = f
				world = p
				break
		if fleet != null:
			break
	_check(fleet != null, "a fleet of ours with two regiments aboard")
	if fleet == null:
		_finish(main)
		return
	var held: Array = _aboard(fleet)

	# The Fleet window: pick the first regiment, land it; it leaves the selection.
	ui.OnFleetClicked(world)
	for _i in 3:
		await process_frame
	var fw: Node = ui._openWindows.get(world.Name + " Fleets")
	fw.DisplayFleetContents(fleet)
	fw.SelectedTroops.append(held[0])
	ui.ExecuteUnitMove([held[0]], world, false)
	for _i in 2:
		await process_frame
	fw.DisplayFleetContents(fleet)
	_check(world.Garrison.has(held[0]) and not fw.SelectedTroops.has(held[0]), "a regiment landed from %s on %s leaves the Fleet window's selection" % [fleet.Name, world.Name])

	# The order itself, with the landed one still picked first.
	var r: Result = OrderManager.MoveUnits([held[0], held[1]], world)
	_check(r.ok and world.Garrison.has(held[1]) and OrderManager.CarrierOf(held[1]) == null,
		"a landed regiment and one aboard, onto %s: the one aboard lands ('%s')" % [world.Name, r.error])
	var again: Result = OrderManager.MoveUnits([held[0], held[1]], world)
	_check(not again.ok and again.error == "Already at %s." % world.Name, "both on the ground already: \"%s\"" % again.error)
	_finish(main)


static func _aboard(f: Fleet) -> Array:
	var out: Array = []
	for s in f.Ships:
		if s.Hangar != null:
			out.append_array(Lq.where(s.Hangar, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop))
	return out


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	print("[fleet_troops_land] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
