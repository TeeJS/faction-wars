extends SceneTree
## Renders the Command Center with the single-player briefing playing - the
## Stop Briefing button and the sector column's foot - to a PNG, cropped to the
## right-hand column (or --full=1 for the whole screen). Needs a window (NOT
## --headless) and an art set with the briefing's sounds:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_briefing.gd -- --out=C:/tmp/briefing.png [--faction=alliance] [--full=1]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://briefing.png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", "alliance"))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var b: Control = ui.StartBriefing()
	print("[capture_briefing] briefing %s" % ("playing" if b != null else "NOT playing (no art set with its sounds?)"))
	for _i in 6:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var size := img.get_size()
	var r := Rect2i(Vector2i.ZERO, size) if _arg("--full=", "") == "1" else Rect2i(size.x - 170, size.y - 260, 170, 260)
	var ok: bool = img.get_region(r).save_png(out) == OK
	print("[capture_briefing] %s -> %s" % [str(r), "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
