extends SceneTree
## Renders the original's Scrap confirmation for a mine of ours - the case in
## TeeJ's screenshot of the original - cropped to the dialog. Needs a window
## (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_scrap.gd -- --out=C:/tmp/scrap.png [--faction=alliance]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://scrap.png")
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
	var world: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and not p.Facilities.is_empty())
	ui.OnEconomyClicked(world)
	for _i in 3:
		await process_frame
	var ew: Node = ui._openWindows.get(world.Name + " Economy")
	ew.ConfirmScrap(world, "Mine", 10, 0, func() -> void: pass)
	for _i in 4:
		await process_frame
	var w: Control = ui._openWindows.get("Confirm")
	var ok: bool = w != null
	if ok:
		var img: Image = root.get_viewport().get_texture().get_image()
		ok = img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size))).save_png(out) == OK
	print("[capture_scrap] %s -> %s" % [world.Name, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
