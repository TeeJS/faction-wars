extends SceneTree
## Renders the Galactic Encyclopedia to PNGs, for a look: the Index view of
## the Personnel database and the Topic view of a major character. Needs a
## window (NOT --headless), like tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_encyclopedia.gd -- --out=C:/tmp/ency.png [--pack=ww2]
##   writes <out> (Index) and <out minus .png>_topic.png (Topic).
##
## --faction=alliance plays that side; --db=N shows database N (0 = All,
## 6 = Personnel, the default); --crop saves the window alone.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://ency.png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	if not _arg("--faction=", "").is_empty():
		GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", ""))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OpenEncyclopedia()
	for _i in 3:
		await process_frame
	var w: EncyclopediaWindow = ui._openWindows.get("Encyclopedia")
	w.ShowIndex(int(_arg("--db=", "6")))
	for _i in 3:
		await process_frame
	var crop: bool = "--crop" in OS.get_cmdline_user_args()
	var img: Image = root.get_viewport().get_texture().get_image()
	if crop:
		img = img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size)))
	var err := img.save_png(out)
	var us: Faction = GameSettings.PlayerFaction
	var major: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.IsMajor)
	w.ShowTopic("characters", major.PackId)
	for _i in 3:
		await process_frame
	var out2 := out.trim_suffix(".png") + "_topic.png"
	var err2 := root.get_viewport().get_texture().get_image().save_png(out2)
	print("[capture_encyclopedia] %s, %s -> %s" % [out, out2, "ok" if err == OK and err2 == OK else "error"])
	quit(0 if err == OK and err2 == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
