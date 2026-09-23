extends SceneTree
## Renders the Character Status and Unit Status windows of a fresh game to a
## PNG, for a look at the portraits. Needs a window (NOT --headless), like
## tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_status.gd -- --out=C:/tmp/status.png [--pack=ww2]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://status.png")
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
	var major: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.IsMajor and c.Attached != null)
	ui.OpenCharacterStatusWindow(major)
	var owned: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and not p.FleetsInOrbit().is_empty())
	if owned != null:
		ui.OpenUnitStatusWindow(owned.FleetsInOrbit()[0].Ships[0])
		for _i in 2:
			await process_frame
		for w in ui._openWindows.values():
			if is_instance_valid(w) and str(w.WindowTitle).begins_with('Status_') and not str(w.WindowTitle).contains(major.Name.replace(' ', '')):
				w.position = Vector2(760, 200)   # beside the character's, not over it
	for _i in 6:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_status] %s (%s) -> %s" % [major.Name, out, "ok" if err == OK else ("error %d" % err)])
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
