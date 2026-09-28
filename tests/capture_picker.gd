extends SceneTree
## Renders the pack picker to a PNG for a look at the cards. Needs a window
## (NOT --headless), like tests/capture_menu.gd:
##
##   Godot_console.exe --path . --resolution 1440x1080 -s tests/capture_picker.gd -- --out=C:/tmp/picker.png
##
## --box=confirm | art | tell opens that box over the cards first: the ask to
## remove, the artwork window (as for a pack without its art), an import's
## result.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://picker.png")
	var picker: Control = load("res://PackPicker.tscn").instantiate()
	root.add_child(picker)
	for _i in 6:
		await process_frame
	match _arg("--box=", ""):
		"confirm":
			picker.call("_confirm", "Clear artwork pack", "Remove the imported artwork and movies? Galactic Civil War plays without them until you import your files again.", "Remove", func() -> void: pass)
		"art":
			picker.call("_open_art_window", "star-wars-rebellion")
		"tell":
			picker.call("_tell", {"ok": false, "message": "That is not a Faction Wars file (it could not be opened as a .zip)."})
	for _i in 4:
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
