extends SceneTree
## Renders the pack picker to a PNG for a look at the cards. Needs a window
## (NOT --headless), like tests/capture_menu.gd:
##
##   Godot_console.exe --path . --resolution 1440x1080 -s tests/capture_picker.gd -- --out=C:/tmp/picker.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://picker.png")
	var picker: Control = load("res://PackPicker.tscn").instantiate()
	root.add_child(picker)
	for _i in 6:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_picker] %s -> %s" % [out, "ok" if err == OK else ("error %d" % err)])
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
