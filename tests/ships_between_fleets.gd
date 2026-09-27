extends SceneTree
## Ships between fleets (BACKLOG #57). Manual p120: "Drag ships or troops
## between fleets in the open Fleet display"; "If you move all the ships out of
## a fleet, the fleet is automatically disbanded"; a ship's Create Fleet makes
## a new fleet ("Ctrl-select several first for a bigger one"). p122: "If you
## move a ship onto a fleet in a different sector, that ship will immediately
## be considered a member of the fleet but will still be in hyperspace for
## several days until it arrives." All of it as orders (the log replays them;
## Create Fleet and a ship's Move changed the world directly before):
##   - Create Fleet: the ship picked, a fleet of its own where it is;
##   - onto a fleet in the same orbit: it joins at once; the emptied fleet is
##     disbanded, the people aboard going with the ships;
##   - onto a fleet at another system: in hyperspace as a fleet named for it,
##     listed in it in the Fleet window, folded into it on arrival;
##   - the fleet gone before they arrive: they stay a fleet of their own;
##   - a ship's Move to a system: a fleet of its own that goes there.
##
##   .\tools\run-gd.ps1 tests/ships_between_fleets.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ships_between_fleets] ok   %s" % what)
	else:
		_fails += 1
		print("[ships_between_fleets] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var engine: StrategicTickManager = GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var big: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and big == null:
				big = f
	# Three ships or more: the fleet's first ship's class, built into it.
	if big != null:
		var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(x) -> bool: return x.Id == big.Ships[0].PackId)
		while def != null and big.Ships.size() < 3:
			big.AddShip(MilitaryCatalog.Create(def, us, big.Attached))
	_check(big != null and big.Ships.size() >= 3, "a fleet of ours of three ships")
	if big == null:
		_finish()
		return
	var home: Planet = big.Attached
	var a: Unit = big.Ships[0]
	var b: Unit = big.Ships[1]

	# Create Fleet, through the order.
	var before: int = home.OrbitingFleets.size()
	var r: Result = CommandBus.issue("create_fleet", { "ships": EntityIndex.ids_of_units([a]) })
	var solo: Fleet = OrderManager.FleetOfShip(a)
	_check(r.ok and solo != big and solo.Ships == [a] and home.OrbitingFleets.size() == before + 1 and not big.Ships.has(a),
		"Create Fleet: %s a fleet of its own, %s" % [a.Name, solo.Name if solo != null else "none"])

	# Onto a fleet in the same orbit: joins; the emptied fleet goes, its people with the ships.
	var rider: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached is Planet)
	if rider != null:
		rider.Attached = solo
	r = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units([a]), "fleet": big.ID })
	_check(r.ok and big.Ships.has(a) and not home.OrbitingFleets.has(solo) and home.OrbitingFleets.size() == before,
		"dragged back onto %s in the same orbit: it joins; the emptied fleet is disbanded" % big.Name)
	if rider != null:
		_check(rider.Attached == big, "... the people aboard go with the ships (%s)" % rider.Name)

	# Onto a fleet at another system.
	var far: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and f.Attached != home and far == null:
				far = f
	_check(far != null, "a fleet of ours at another system")
	if far != null:
		var there: Planet = far.Attached
		var count: int = far.Ships.size()
		r = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units([b]), "fleet": far.ID })
		var transit: Fleet = OrderManager.FleetOfShip(b)
		_check(r.ok and transit != null and transit.IsTransit() and transit.JoinFleet == far and transit.Name == far.Name
			and transit.Status == Enums.Status.Enroute and there.OrbitingFleets.has(transit) and not big.Ships.has(b) and far.Ships.size() == count,
			"%s sent onto %s at %s: in hyperspace, as a fleet named for it (%d days)" % [b.Name, far.Name, there.Name, transit.DaysToDestination if transit != null else -1])
		# The Fleet window lists it in the fleet it joins, and not as a fleet of its own.
		var w: FleetWindow = load("res://src/ui/FleetWindow.tscn").instantiate()
		root.add_child(w)
		await process_frame
		w.Populate(there, null)
		w.DisplayFleetContents(far)
		await process_frame
		var listed: bool = _lists(w, b)
		var columns: Array = _fleet_rows(w)
		_check(listed and not columns.has(transit), "the Fleet window lists it in %s, in hyperspace; no fleet of its own in the column" % far.Name)
		w.queue_free()
		for _d in transit.DaysToDestination:
			engine.AdvanceDay()
		_check(far.Ships.has(b) and not there.OrbitingFleets.has(transit) and b.Status == Enums.Status.AwaitingOrders,
			"it arrives and joins %s" % far.Name)

		# The fleet gone before they arrive: a fleet of their own.
		var c: Unit = big.Ships[1] if big.Ships.size() > 1 else null
		if c != null:
			r = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units([c]), "fleet": far.ID })
			var t2: Fleet = OrderManager.FleetOfShip(c)
			var elsewhere: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p != there and p != home and p.ControllingFaction == us)
			CommandBus.issue("move_fleets", { "fleets": [far.ID], "destination": elsewhere.Name })
			for _d in t2.DaysToDestination:
				engine.AdvanceDay()
			_check(t2 != null and there.OrbitingFleets.has(t2) and not t2.IsTransit() and t2.Name != far.Name and t2.Ships.has(c),
				"%s moved away first: the ship arrives as a fleet of its own (%s)" % [far.Name, t2.Name if t2 != null else "none"])

	# A ship's Move to a system.
	var d: Unit = big.Ships[0]
	var dest: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p != home and p.ControllingFaction == us)
	r = CommandBus.issue("move_ships", { "ships": EntityIndex.ids_of_units([d]), "destination": dest.Name })
	var own: Fleet = OrderManager.FleetOfShip(d)
	_check(r.ok and own != null and (own != big or big.Ships.size() == 1) and own.Status == Enums.Status.Enroute and own.Destination == dest,
		"a ship's Move to %s: a fleet of its own on its way" % dest.Name)
	_finish()


func _lists(n: Node, u: Unit) -> bool:
	if n is Button and n.get("UnitData") == u:
		return true
	for c in n.get_children():
		if _lists(c, u):
			return true
	return false


func _fleet_rows(n: Node) -> Array:
	var out: Array = []
	if n is Button and n.get("UnitData") is Fleet:
		out.append(n.get("UnitData"))
	for c in n.get_children():
		out.append_array(_fleet_rows(c))
	return out


func _finish() -> void:
	print("[ships_between_fleets] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
