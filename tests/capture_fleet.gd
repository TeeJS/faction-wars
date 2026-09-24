extends SceneTree
## Renders the original's Fleet window (manual p112-p113) for the first world
## of the player's side with a fleet in orbit, on each of its tabs, then with
## its first fleet opened and a ship shown, to PNGs cropped to the window.
## Needs a window (NOT --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_fleet.gd -- --out=C:/tmp/fleet.png [--faction=alliance]
##   writes <out minus .png>_<tab>.png for tabs 0-3, then _ship.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://fleet.png").trim_suffix(".png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", "empire"))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var home: Planet = null
	var most := 0
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and f.Ships.size() > most:
				most = f.Ships.size()
				home = p
	if home == null:
		print("[capture_fleet] no fleet of ours")
		quit(1)
		return
	ui.OnFleetClicked(home)
	for _i in 4:
		await process_frame
	var w: FleetWindow = null
	for c in ui.get_children():
		if c is FleetWindow:
			w = c
	var ok := w != null and w._original
	var tabs: TabContainer = w.get_node("%FleetTabs")
	for t in 4:
		if tabs.is_tab_disabled(t):
			continue
		tabs.current_tab = t
		for _i in 3:
			await process_frame
		ok = _shot(w, out + "_%d.png" % t) and ok
	var fleet: Fleet = Lq.first_or_null(home.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == us)
	w._opened[fleet] = true
	w.Populate(home, ui)
	for _i in 3:
		await process_frame
	var ship: Unit = Lq.first_or_null(fleet.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
	if ship != null:
		w._ShowShip(ship)
		for _i in 3:
			await process_frame
		print("[capture_fleet] ship %s: tab %d, rows %s, disabled %s" % [ship.Name, tabs.current_tab,
			str(range(4).map(func(i): return FleetWindow._RowsOn(tabs.get_child(i)))),
			str(range(4).map(func(i): return tabs.is_tab_disabled(i)))])
		ok = _shot(w, out + "_ship.png") and ok
	print("[capture_fleet] %s at %s -> %s" % [fleet.Name, home.Name, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position), Vector2i(w.size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
