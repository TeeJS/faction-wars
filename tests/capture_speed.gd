extends SceneTree
## Renders the original's Speed Control (top left, at Slow) and the paused
## game's "Resume Game Play?" box to PNGs. Needs a window (NOT --headless) and
## the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_speed.gd -- --out=C:/tmp/speed.png [--faction=alliance]
##   writes <out minus .png>_speed.png and _pause.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://speed.png").trim_suffix(".png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", "empire"))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var gm: GameManager = main
	gm.SetSpeed(2)
	gm._lastDay = 69
	gm.RefreshStatusBar()
	for _i in 3:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var ok := img.get_region(Rect2i(0, 0, 300, 80)).save_png(out + "_speed.png") == OK
	gm.SetSpeed(0)
	for _i in 3:
		await process_frame
	img = root.get_viewport().get_texture().get_image()
	ok = img.save_png(out + "_pause.png") == OK and ok
	print("[capture_speed] %s" % ("ok" if ok else "error"))
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
