extends SceneTree
## A fleet of ours on its way to a system shows on the map while in transit
## (TeeJ, 2026-09-24: "I moved a fleet from Coruscant to Yaga Minor - it did
## not show up until it arrived"): the destination's fleet corner carries the
## "Units Enroute to System" icon (the original's sector legend) with the
## arrival day, and opens its Fleet window; an opponent's inbound fleet does
## not show (fog).
##
##   .\tools\run-gd.ps1 tests/fleet_enroute_icon.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_enroute_icon] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_enroute_icon] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
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

	var fleet: Fleet = null
	var from: Planet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and not f.Ships.is_empty():
				fleet = f
				from = p
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(from))
	var to: Planet = Lq.first_or_null(sector.Planets, func(p: Planet) -> bool:
		return p != from and not Lq.any(p.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == us))
	_check(fleet != null and to != null, "a fleet of ours and a world in its sector with none of ours")
	if fleet == null or to == null:
		_finish()
		return
	ui.ExecuteSingleFleetMove(fleet, to, false)
	await process_frame
	_check(fleet.Status == Enums.Status.Enroute and fleet.Destination == to, "the fleet is on its way to %s" % to.Name)

	var icon: Button = await _fleet_corner(ui, sector, to)
	_check(icon != null and icon.get_meta("corner", "") == "enroute", "the destination's fleet corner shows it en route")
	_check(icon != null and icon.tooltip_text.contains(fleet.Name) and icon.tooltip_text.contains("arrives day"),
		"its tooltip names the fleet and the arrival day ('%s')" % (icon.tooltip_text if icon != null else ""))
	if icon != null:
		icon.pressed.emit()
		for _i in 3:
			await process_frame
		var w: FleetWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is FleetWindow)
		_check(w != null, "clicking it opens the destination's Fleet window")

	# An opponent's inbound fleet does not show.
	var enemy: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if enemy == null and f.Faction != null and f.Faction != us and not f.Ships.is_empty():
				enemy = f
	if enemy != null:
		(enemy.Attached as Planet).OrbitingFleets.erase(enemy)
		to.OrbitingFleets.append(enemy)
		enemy.Attached = to
		enemy.Destination = to
		enemy.Status = Enums.Status.Enroute
		enemy.DaysToDestination = 5
		icon = await _fleet_corner(ui, sector, to)
		_check(icon == null or not icon.tooltip_text.contains(enemy.Name), "an opponent's inbound fleet is not shown")
	_finish()


## The fleet corner by the system's planet, the sector window reopened.
func _fleet_corner(ui: UIManager, sector: Sector, planet: Planet) -> Button:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == sector.Name:
			(c as DraggableWindow).CloseWindow()
	for _i in 2:
		await process_frame
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == sector.Name:
			var map: Control = c.get_node("%SectorMap")
			var btn: Control = Lq.first_or_null(map.get_children(), func(n) -> bool: return n is SectorWindow.PlanetMapButton and n.AssociatedPlanet == planet)
			var best: Button = null
			var near := 80.0
			for n in map.get_children():
				if n is Button and str(n.get_meta("corner", "")) in ["fleet", "enroute"]:
					var d: float = (n.position + n.size / 2.0).distance_to(btn.position + btn.size / 2.0)
					if d < near:
						near = d
						best = n
			return best
	return null


func _finish() -> void:
	print("[fleet_enroute_icon] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
