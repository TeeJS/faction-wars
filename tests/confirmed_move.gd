extends SceneTree
## Confirmed Move for fleets, ships and units (manual p122: "This option brings
## up a window that tells you the transit time (in days) it will take for the
## fleet to reach its destination. To confirm the move, click the checkmark.
## To cancel, click the X button"; p115 a ship's, p045 a unit's). A fleet's
## Confirmed Move went at once ("accepted and ignored"); a ship's and a unit's
## too. The window is the characters' own (TransitConfirmWindow, p110).
##   - a fleet: the window with its days; nothing moves until the check; the X
##     leaves it where it is;
##   - a ship, a regiment: the same, their own days;
##   - onto a fleet at another system: the days to it;
##   - plain Move: no window.
##
##   .\tools\run-gd.ps1 tests/confirmed_move.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[confirmed_move] ok   %s" % what)
	else:
		_fails += 1
		print("[confirmed_move] FAIL %s" % what)


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
	var fleets: Array = []
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us:
				fleets.append(f)
	var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	# The regiment, and a fleet elsewhere with a berth for it - set aside first.
	var troop: Unit = null
	for p in ours:
		if troop == null:
			troop = Lq.first_or_null(p.Garrison, func(u: Unit) -> bool: return u.Type == Enums.UnitType.Troop and u.Faction == us and u.Status != Enums.Status.Enroute)
	var far: Fleet = Lq.first_or_null(fleets, func(f: Fleet) -> bool: return troop != null and f.Attached != troop.Attached)
	if far != null:
		OrderManager.Unload(far)
		if not Lq.any(far.Ships, func(s: Unit) -> bool: return OrderManager.HasRoomFor(s, Enums.UnitType.Troop)):
			far.Ships[0].TroopCapacity = 2   # a berth, for the test
	var movers: Array = Lq.where(fleets, func(f: Fleet) -> bool: return f != far)
	# Two fleets to move whatever the galaxy: a ship of the first one's class,
	# built into it and split off (Create Fleet).
	while far != null and movers.size() < 2:
		var base: Fleet = movers[0] if not movers.is_empty() else far
		var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(x) -> bool: return x.Id == base.Ships[0].PackId)
		var extra: Unit = MilitaryCatalog.Create(def, us, base.Attached)
		base.AddShip(extra)
		OrderManager.CreateFleet([extra])
		movers.append(OrderManager.FleetOfShip(extra))
	_check(troop != null and far != null and movers.size() >= 2 and ours.size() >= 3,
		"a regiment, a fleet elsewhere to send it to, two more fleets, three worlds of ours")
	if troop == null or far == null or movers.size() < 2 or ours.size() < 3:
		_finish(main)
		return

	# A fleet: the window, then the X.
	var fleet: Fleet = movers[0]
	var home: Planet = fleet.Attached
	var dest: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p != home)
	var days: int = OrderManager.FleetTravelDays([fleet], home, dest)
	ui.ExecuteFleetMove([fleet], dest, true)
	await process_frame
	var w: Node = _confirm(ui)
	_check(w != null and fleet.Status != Enums.Status.Enroute and _text(w).contains("%s: %d" % [fleet.Name, days]),
		"a fleet's Confirmed Move: the window, '%s' - and it has not gone" % (_text(w).replace("\n", " / ") if w != null else "none"))
	if w != null:
		w.OnCancelPressed()
	await process_frame
	_check(fleet.Status != Enums.Status.Enroute and fleet.Attached == home, "the X: it stays at %s" % home.Name)
	ui.ExecuteFleetMove([fleet], dest, true)
	await process_frame
	w = _confirm(ui)
	if w != null:
		w.OnConfirmPressed()
	await process_frame
	_check(fleet.Status == Enums.Status.Enroute and fleet.Destination == dest, "the check: it goes, %d days" % fleet.DaysToDestination)

	# A ship.
	var other: Fleet = movers[1]
	var ship: Unit = other.Ships[0]
	var there: Planet = other.Attached
	var to: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p != there)
	ui.ExecuteShipMove([ship], to, true)
	await process_frame
	w = _confirm(ui)
	_check(w != null and _text(w).contains("%s: %d" % [ship.Name, there.TravelDaysTo(to, ship.Hyperdrive)]) and OrderManager.FleetOfShip(ship).Status != Enums.Status.Enroute,
		"a ship's Confirmed Move: the window with its days (%s), and it waits" % (_text(w).replace("\n", " / ") if w != null else "none"))
	if w != null:
		w.OnConfirmPressed()
	await process_frame
	_check(OrderManager.FleetOfShip(ship).Status == Enums.Status.Enroute, "the check: the ship goes")

	# A regiment.
	var from: Planet = troop.Attached
	var to2: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p != from)
	ui.ExecuteUnitMove([troop], to2, true)
	await process_frame
	w = _confirm(ui)
	_check(w != null and _text(w).contains("%s: %d" % [troop.Name, OrderManager.UnitTravelDays([troop], from, to2)]) and troop.Status != Enums.Status.Enroute,
		"a regiment's Confirmed Move: the window, and it waits")
	if w != null:
		w.OnCancelPressed()
	await process_frame

	# Onto a fleet at another system.
	ui.ExecuteLoadAboard([troop], far, true)
	await process_frame
	w = _confirm(ui)
	_check(w != null and _text(w).contains("%s: %d" % [troop.Name, OrderManager.UnitTravelDays([troop], from, far.Attached)]) and OrderManager.CarrierOf(troop) == null,
		"onto %s at another system: the days to it first" % far.Name)
	if w != null:
		w.OnConfirmPressed()
	await process_frame
	_check(OrderManager.CarrierOf(troop) == far, "the check: on its way to %s" % far.Name)

	# Plain Move: no window.
	var to3: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p != far.Attached)
	ui.ExecuteFleetMove([far], to3, false)
	await process_frame
	_check(_confirm(ui) == null and far.Status == Enums.Status.Enroute, "plain Move: no window, it goes")
	_finish(main)


func _confirm(ui: UIManager) -> Node:
	for k in ui._openWindows:
		var w: Variant = ui._openWindows[k]
		if str(k).begins_with("Confirm_") and is_instance_valid(w) and not (w as Node).is_queued_for_deletion():
			return w
	return null


func _text(w: Node) -> String:
	return (w.get_node("%MessageLabel") as Label).text if w != null else ""


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	print("[confirmed_move] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
