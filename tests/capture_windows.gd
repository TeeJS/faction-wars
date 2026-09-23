extends SceneTree
## Renders the Manufacturing, System Defenses and System windows of the
## player's home world to PNGs, for a look. Needs a window (NOT --headless),
## like tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_windows.gd -- --out=C:/tmp/win.png [--pack=ww2]
##   writes <out minus .png>_economy.png, _defense.png and _planet.png.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://win.png").trim_suffix(".png")
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
	# A held world with somebody standing on it, so the Personnel cards show.
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and not p.Facilities.is_empty() \
			and Lq.any(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached == p))
	if home == null:
		home = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
			return p.ControllingFaction == us and not p.Facilities.is_empty())
	var ok := true
	for shot in [["economy", func() -> void: ui.OnEconomyClicked(home)],
			["defense", func() -> void: ui.OnDefenseClicked(home)],
			["planet", func() -> void: ui.OnPlanetClicked(home)]]:
		(shot[1] as Callable).call()
		for _i in 4:
			await process_frame
		var path: String = "%s_%s.png" % [out, shot[0]]
		if root.get_viewport().get_texture().get_image().save_png(path) != OK:
			ok = false
		for w in ui._openWindows.values():
			if w is DraggableWindow:
				w.CloseWindow()
		for _i in 2:
			await process_frame
	print("[capture_windows] %s -> %s" % [home.Name, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
