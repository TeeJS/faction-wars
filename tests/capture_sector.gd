extends SceneTree
## Renders the Sector window of the player's home sector to a PNG, for a look
## at the three bars under each system. Needs a window (NOT --headless), like
## tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_sector.gd -- --out=C:/tmp/sector.png [--pack=ww2]
##
## --sector=Corellian opens that sector instead; --crop saves the window alone
## (to lay beside a screenshot of the original).

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://sector.png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and p.IsInhabited)
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	var named := _arg("--sector=", "")
	if not named.is_empty():
		sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Name == named)
	ui.OnSectorClicked(sector)
	for _i in 6:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var w: Control = ui._openWindows.get(sector.Name)
	if "--crop" in OS.get_cmdline_user_args() and w != null:
		img = img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size)))
	var err := img.save_png(out)
	print("[capture_sector] %s (%s) -> %s" % [sector.Name, out, "ok" if err == OK else ("error %d" % err)])
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
