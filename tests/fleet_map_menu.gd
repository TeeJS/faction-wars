extends SceneTree
## Right-clicking a fleet's icon on the Sector window opens the fleet command
## menu (TeeJ, 2026-09-24, with a screenshot of the original's: Move,
## Confirmed Move, Planetary Bombardment, Planetary Assault, Encyclopedia,
## Status, Scrap). The Fleet window's own menu is the same plus Rename (manual
## p121, Fig. 3.64). An opponent's fleet offers Encyclopedia and Status.
##
##   .\tools\run-gd.ps1 tests/fleet_map_menu.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_map_menu] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_map_menu] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # the engine's own look, whatever the developer imported
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

	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and Lq.any(p.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == us))
	_check(home != null, "a world of ours with a fleet of ours in orbit")
	if home == null:
		_finish()
		return
	var fleet: Fleet = Lq.first_or_null(home.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == us)

	var map_menu: PopupMenu = FleetWindow.FleetMenu([fleet], home, ui, false, func() -> void: pass)
	_check(_items(map_menu) == ["Move", "Confirmed Move", "Planetary Bombardment", "Planetary Assault", "Encyclopedia", "Status", "Scrap"],
		"the map's menu, as the original's: %s" % str(_items(map_menu)))
	var bombard: PopupMenu = map_menu.get_node_or_null("BombardSubmenu")
	_check(bombard != null and bombard.item_count >= 3 and bombard.get_item_text(0) == "Target Military Facilities",
		"Planetary Bombardment opens its targeting options")
	map_menu.free()
	var window_menu: PopupMenu = FleetWindow.FleetMenu([fleet], home, ui, true, func() -> void: pass)
	_check(_items(window_menu).has("Rename"), "the Fleet window's menu keeps Rename (p121)")
	window_menu.free()

	var enemy: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if enemy == null and f.Faction != null and f.Faction != us:
				enemy = f
	if enemy != null:
		var theirs: PopupMenu = FleetWindow.FleetMenu([enemy], enemy.Attached as Planet, ui, false, func() -> void: pass)
		_check(_items(theirs) == ["Encyclopedia", "Status"], "an opponent's fleet: Encyclopedia, Status (%s)" % str(_items(theirs)))
		theirs.free()

	# The icon itself: a right-click pops the menu.
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	var icon: Button = null
	for w in ui.get_children():
		if w is DraggableWindow and (w as DraggableWindow).WindowTitle == sector.Name:
			var map: Control = w.get_node("%SectorMap")
			var btn: Control = Lq.first_or_null(map.get_children(), func(c) -> bool: return c is SectorWindow.PlanetMapButton and c.AssociatedPlanet == home)
			var best := 1e9
			for c in map.get_children():
				if c is Button and c.get_meta("corner", "") == "fleet":
					var d: float = (c.position + c.size / 2.0).distance_to(btn.position + btn.size / 2.0)
					if d < best and d < 80:
						best = d
						icon = c
	_check(icon != null, "the fleet icon is drawn at %s" % home.Name)
	if icon != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = true
		click.global_position = icon.global_position + Vector2(4, 4)
		icon.gui_input.emit(click)
		await process_frame
		var popped: PopupMenu = icon.get_node_or_null("FleetMenu")
		_check(popped != null and popped.visible and _items(popped).has("Planetary Assault"), "right-clicking the icon pops the fleet menu")
	_finish()


static func _items(m: PopupMenu) -> Array:
	var out: Array = []
	for i in m.item_count:
		if not m.is_item_separator(i):
			out.append(m.get_item_text(i))
	return out


func _finish() -> void:
	print("[fleet_map_menu] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
