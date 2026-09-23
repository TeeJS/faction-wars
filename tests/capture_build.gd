extends SceneTree
## Renders the original's Build Selection window (manual p045, Fig 3.58) for a
## construction yard of ours with the Construction Yard picked - the case in
## TeeJ's screenshot of the original - cropped to the window. Needs a window
## (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_build.gd -- --out=C:/tmp/build.png [--faction=alliance]
##
## --role=produces_troop builds at a training facility instead; --list drops
## the item list, as in TeeJ's screenshot of the original's.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://build.png")
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
	var role := _arg("--role=", "produces_facility")
	var world: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and Lq.any(p.Facilities, func(f: Facility) -> bool: return f.HasRole(role)))
	ui.OnEconomyClicked(world)
	for _i in 3:
		await process_frame
	var ew: Node = ui._openWindows.get(world.Name + " Economy")
	ew.OpenBuildChooser(world, role)
	for _i in 3:
		await process_frame
	var w: Control = ui._openWindows.get("Build Selection")
	var ok: bool = w != null
	if ok:
		for i in w._items.size():
			if str(w._items[i].name) == "Construction Yard":
				w._show(i)
		if "--list" in OS.get_cmdline_user_args():
			w._open_list(true)
		for _i in 3:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		ok = img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size))).save_png(out) == OK
	print("[capture_build] %s -> %s" % [world.Name, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
