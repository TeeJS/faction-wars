extends SceneTree
## Troops and fighters aboard a fleet, moved off it and onto it (TeeJ,
## 2026-09-25: "I should be able to drag troops or fighters from a fleet to a
## planet", "if I right click troops on a ship and click move, I'm unable to
## move them to another planet", "in the original you can drag and drop or
## move from and to fleets"). Manual p120: "drag them onto the system, or
## right-click -> Move"; "Drag ships or troops between fleets".
##
## A day-zero payload's Attached names the SYSTEM, not the fleet, so the
## orders find the carrier by its hangars:
##   - moved onto the world below, it lands (it was "Already at <world>.")
##   - moved to another world, it leaves from the orbit and the hangar
##   - loaded aboard from the world, and from one fleet to another
##   - its row in the Fleet window has the unit's own menu (manual p045),
##     whose Move puts up the crosshair; a fleet's row takes a drop
##
##   .\tools\run-gd.ps1 tests/hangar_units.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[hangar_units] ok   %s" % what)
	else:
		_fails += 1
		print("[hangar_units] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-hangar-units-none"   # the plain windows
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction

	# A seeded payload: a regiment in a ship's hangar, its fleet in orbit.
	var found := _payload(us, Enums.UnitType.Troop)
	_check(not found.is_empty(), "%s has a regiment aboard a fleet at day zero" % us.Id)
	if found.is_empty():
		_finish()
		return
	var world: Planet = found[0]
	var fleet: Fleet = found[1]
	var troop: Unit = found[3]
	print("[hangar_units] %s aboard %s at %s (Attached: %s)" % [troop.Name, fleet.Name, world.Name, troop.Attached.Name if troop.Attached != null else "-"])
	_check(OrderManager.CarrierOf(troop) == fleet, "its carrier is found by the hangar it is in")

	# 1 Onto the world below: it lands.
	var r: Result = CommandBus.issue("move_units", { "units": EntityIndex.ids_of_units([troop]), "destination": world.Name })
	_check(r.ok and int(r.value) == 0, "moved onto %s, below it: done at once (was 'Already at %s.') - %s" % [world.Name, world.Name, r.error])
	_check(world.Garrison.has(troop) and OrderManager.CarrierOf(troop) == null and troop.Attached == world, "... it is in the garrison, out of the hangar")

	# 2 Back aboard from the world.
	r = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units([troop]), "fleet": fleet.ID })
	_check(int(r.value) == 1 and OrderManager.CarrierOf(troop) == fleet and not world.Garrison.has(troop), "loaded aboard from the world")
	r = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units([troop]), "fleet": fleet.ID })
	_check(int(r.value) == 0 and _hangar_count(fleet, troop) == 1, "loading one already aboard does nothing (not twice in a hangar)")

	# 3 From one fleet to another in the same orbit - wherever two of our
	# fleets with room can be had (a fleet of two such ships is split).
	_fleet_to_fleet(us, troop)

	# 4 The Fleet window: the troop's row has the unit's menu; Move puts up the
	# crosshair, and the world below lands it.
	ui.OnFleetClicked(world)
	for _i in 3:
		await process_frame
	var fw: FleetWindow = ui._openWindows.get(world.Name + " Fleets")
	_check(fw != null, "the Fleet window opens")
	if fw != null:
		fw.DisplayFleetContents(fleet)
		for _i in 2:
			await process_frame
		var row: Button = null
		for b in fw.find_children("*", "Button", true, false):
			if b.get("UnitData") == troop:
				row = b
		_check(row != null, "the regiment has a row in the fleet's Troops tab")
		var menu: PopupMenu = null
		if row != null:
			for c in row.get_children():
				if c is PopupMenu:
					menu = c
		var items: Array = []
		if menu != null:
			for i in menu.item_count:
				items.append(menu.get_item_text(i))
		_check(items.has("Move") and items.has("Confirmed Move") and items.has("Encyclopedia") and items.has("Status") and items.has("Retire")
			and not items.has("Create Fleet") and not items.has("Rename"), "its menu is the unit's (manual p045), not a ship's: %s" % str(items))
		if menu != null:
			menu.id_pressed.emit(0)
			for _i in 2:
				await process_frame
			_check(ui.IsTargeting, "Move puts up the crosshair")
			ui.ResolveTarget(world)
			for _i in 2:
				await process_frame
			_check(world.Garrison.has(troop) and OrderManager.CarrierOf(troop) == null, "the crosshair on the world below lands it")

		# 5 A drop on the fleet's row takes it aboard.
		var fleetRow: Button = null
		for b in fw.find_children("*", "Button", true, false):
			if b.get("UnitData") == fleet:
				fleetRow = b
		_check(fleetRow != null, "the fleet has a row")
		if fleetRow != null:
			ui.StartUnitDrag([troop])
			_check(fleetRow._can_drop_data(Vector2.ZERO, "unit_move"), "the fleet's row takes a dragged regiment")
			fleetRow._drop_data(Vector2.ZERO, "unit_move")
			for _i in 2:
				await process_frame
			_check(OrderManager.CarrierOf(troop) == fleet and not world.Garrison.has(troop), "dropped on the fleet's row, it is aboard")

	# 6 To another world: it leaves from the orbit, out of the hangar.
	var dest: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p != world and p.ControllingFaction == us and not BlockadeManager.IsBlockaded(p))
	if dest != null and not BlockadeManager.IsBlockaded(world):
		r = CommandBus.issue("move_units", { "units": EntityIndex.ids_of_units([troop]), "destination": dest.Name })
		_check(r.ok and int(r.value) > 0 and troop.Status == Enums.Status.Enroute and troop.Destination == dest,
			"moved to %s: under way (%d days) - %s" % [dest.Name, int(r.value), r.error])
		_check(OrderManager.CarrierOf(troop) == null and _hangar_count(fleet, troop) == 0 and not world.Garrison.has(troop),
			"... off the ship, not left in the hangar")
	_finish()


## [world, fleet, ship, unit]: a unit of `kind` in a hangar of one of our
## fleets in orbit.
func _payload(us: Faction, kind: int) -> Array:
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction != us or f.Status == Enums.Status.Enroute:
				continue
			for ship in f.Ships:
				for u in ship.Hangar:
					if u.Type == kind:
						return [p, f, ship, u]
	return []


func _hangar_count(fleet: Fleet, u: Unit) -> int:
	var n := 0
	for ship in fleet.Ships:
		n += ship.Hangar.count(u)
	return n


## A regiment aboard one of our fleets, dropped on a second fleet in the same
## orbit. Day zero never has two fleets with troop room in one orbit, so the
## test makes one: a ship split off a fleet of two or more (DetachIntoOwnFleet),
## given room for a regiment if it has none.
func _fleet_to_fleet(us: Faction, keep: Unit) -> void:
	var troop := Enums.UnitType.Troop
	for p in GameState.AllPlanets():
		for a in p.OrbitingFleets:
			if a.Faction != us or a.Status == Enums.Status.Enroute or a.Ships.size() < 2:
				continue
			var regiment: Unit = null
			for s in a.Ships:
				for u in s.Hangar:
					if u.Type == troop and u != keep and regiment == null:
						regiment = u
			if regiment == null:
				continue
			var other: Unit = Lq.first_or_null(a.Ships, func(s: Unit) -> bool: return not s.Hangar.has(regiment))
			if other.TroopCapacity < 1 + Lq.count(other.Hangar, func(h: Unit) -> bool: return h.Type == troop):
				other.TroopCapacity = 1 + Lq.count(other.Hangar, func(h: Unit) -> bool: return h.Type == troop)
			var b: Fleet = p.DetachIntoOwnFleet(other)
			_check(b != null and b != a and b.Attached == p, "fleet to fleet at %s: a second fleet split off %s" % [p.Name, a.Name])
			if b == null:
				return
			var r: Result = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units([regiment]), "fleet": b.ID })
			_check(int(r.value) == 1 and OrderManager.CarrierOf(regiment) == b and _hangar_count(a, regiment) == 0 and not p.Garrison.has(regiment),
				"... %s moved from %s to %s in the same orbit, out of the first one's hangar" % [regiment.Name, a.Name, b.Name])
			return
	print("[hangar_units] (no fleet of two ships carrying a regiment - fleet-to-fleet not exercised)")


func _finish() -> void:
	print("[hangar_units] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
