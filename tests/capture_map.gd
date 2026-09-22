extends SceneTree
## Renders the galaxy map of a fresh game to a PNG, for a look at the pack's
## map picture with its regions over it. Needs a window (NOT --headless), like
## tests/capture_menu.gd:
##
##   Godot_console.exe --path . --resolution 1280x850 -s tests/capture_map.gd -- --out=C:/tmp/map.png [--pack=ww2] [--titles]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://map.png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Huge
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 12:
		await process_frame
	# --titles: paint every theatre's hover name as if hovered, for a look.
	if OS.get_cmdline_user_args().has("--titles"):
		var map: GalaxyMap = main.get_node("GalaxyMap")
		for c in map.get_children():
			if c is Button and not (c as Button).text.is_empty():
				(c as Button).add_theme_color_override("font_color", GalaxyMap.TitleColor)
		for _i in 3:
			await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_map] %s -> %s" % [out, "ok" if err == OK else ("error %d" % err)])
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
