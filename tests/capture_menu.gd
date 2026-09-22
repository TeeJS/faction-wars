extends SceneTree
## Renders the start menu to a PNG for a look at the pack's Cockpit picture and
## region placement. Needs a window (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x1080 -s tests/capture_menu.gd -- --out=C:/tmp/menu.png [--hover]
##
## --hover marks every region with a translucent box so the layout can be read
## off the capture; --hq toggles Headquarters Only Victory first.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://menu.png")
	var menu: Control = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--hq"):
		var hq: Button = menu.get_node_or_null("Regions/Region_hq_only_victory")
		if hq != null:
			hq.pressed.emit()
	if OS.get_cmdline_user_args().has("--hover"):
		var regions: Node = menu.get_node_or_null("Regions")
		if regions != null:
			for b in regions.get_children():
				if b is Button:
					var box := ColorRect.new()
					box.color = Color(0, 1, 0, 0.25)
					box.mouse_filter = Control.MOUSE_FILTER_IGNORE
					box.position = b.position
					box.size = b.size
					regions.add_child(box)
	for _i in 4:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_menu] %s -> %s (%d)" % [str(img.get_size()), out, err])
	quit(0)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
