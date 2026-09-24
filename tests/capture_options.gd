extends SceneTree
## Renders the original's Game Options screen (manual p076 Fig. 3.16) in play,
## with two slots saved (one as each side), to a PNG cropped to the screen's
## picture. Needs a window (NOT --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_options.gd -- --out=C:/tmp/options.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://options.png")
	SaveManager.Dir = "user://capture-saves"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OnMenuButtonClicked()
	for _i in 3:
		await process_frame
	var screen: Control = ui.get_node_or_null("OptionsScreen")
	if screen == null:
		print("[capture_options] the original screen did not open (art imported?)")
		quit(1)
		return
	(screen._names[0] as LineEdit).text = "1"
	screen._save(0)
	var was: Faction = GameSettings.PlayerFaction
	GameSettings.PlayerFaction = FactionRegistry.ById("empire" if was.Id == "alliance" else "alliance")
	(screen._names[1] as LineEdit).text = "start"
	screen._save(1)
	GameSettings.PlayerFaction = was
	for _i in 3:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(screen._canvas.global_position), Vector2i(Vector2(640, 480) * screen._s))
	print("[capture_options] screen at %s, scale %.3f" % [str(r), screen._s])
	var err := img.get_region(r).save_png(out)
	for i in SaveManager.SLOT_COUNT:
		DirAccess.remove_absolute(SaveManager.SlotPath(i))
	DirAccess.remove_absolute("%s/slots.json" % SaveManager.Dir)
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
