extends SceneTree
## Renders the Manufacturing, System Defenses, System and Encyclopedia windows
## of the player's home world to PNGs, for a look. Needs a window (NOT
## --headless), like tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_windows.gd -- --out=C:/tmp/win.png [--pack=ww2] [--faction=empire]
##   writes <out minus .png>_economy.png, _economy_mines.png, _defense.png,
##   _defense_troops.png, _planet.png, _ency_index.png and _ency_topic.png,
##   each the whole screen.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://win.png").trim_suffix(".png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
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
	var topicOf: String = FactionRegistry.Pack.Units[0].Id
	for u in FactionRegistry.Pack.Units:
		if u.Id.contains("commando"):
			topicOf = u.Id
	var turn := func(title: String, tabsPath: String, index: int) -> void:
		var w: Node = ui._openWindows.get(title)
		if w != null:
			var t: TabContainer = w.get_node_or_null(tabsPath)
			if t != null:
				t.set_tab_disabled(index, false)
				t.current_tab = index
	for shot in [["economy", func() -> void: ui.OnEconomyClicked(home)],
			["economy_mines", func() -> void:
				ui.OnEconomyClicked(home)
				turn.call(home.Name + " Economy", "%EconomyTabs", 5)],
			["defense", func() -> void: ui.OnDefenseClicked(home)],
			["defense_troops", func() -> void:
				# A world of ours with regiments on it, so the trooper cards show.
				var garrisoned: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
					return p.ControllingFaction == us and p.TrooperRegiments() > 1)
				var world: Planet = garrisoned if garrisoned != null else home
				ui.OnDefenseClicked(world)
				turn.call(world.Name + " Defenses", "%DefenseTabs", 1)],
			["planet", func() -> void: ui.OnPlanetClicked(home)],
			["ency_index", func() -> void: ui.OpenEncyclopedia()],
			["ency_topic", func() -> void: ui.OpenEncyclopedia("units", topicOf)]]:
		(shot[1] as Callable).call()
		for _i in 5:
			await process_frame
		var path: String = "%s_%s.png" % [out, shot[0]]
		if root.get_viewport().get_texture().get_image().save_png(path) != OK:
			ok = false
		var rects: Dictionary = {}
		for w in ui._openWindows.values():
			if w is DraggableWindow and w.visible:
				rects[w.WindowTitle] = Rect2(w.global_position, w.size)
		print("[capture_windows] %s: %s" % [shot[0], str(rects)])
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
