extends SceneTree
## Renders the left message column (the docked Comms Center's sockets) to a
## PNG, cropped round the column. Needs a window (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_column.gd -- --out=C:/tmp/column.png [--faction=alliance]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://column.png")
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
	ui.RefreshCommsHighlights()
	for _i in 3:
		await process_frame
	var panel: Control = ui.get_node("CommsPanel")
	var r := Rect2i(Vector2i(panel.global_position) - Vector2i(12, 12), Vector2i(panel.size) + Vector2i(24, 24))
	var img: Image = root.get_viewport().get_texture().get_image()
	var ok: bool = img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(out) == OK
	print("[capture_column] %s -> %s" % [str(r), "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
