extends SceneTree
## Renders the original's Finders (manual p075 Fig. 3.12, p124-p126) on each
## of their tabs, to PNGs cropped to the window. Needs a window (NOT
## --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_finder.gd -- --out=C:/tmp/finder.png [--faction=alliance] [--which=system]
##   writes <out minus .png>_<which>_<tab>.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://finder.png").trim_suffix(".png")
	var which := _arg("--which=", "system")
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
	match which:
		"system":
			ui.OpenPlanetFinder()
		"fleet":
			ui.call("OpenFleetFinder", false)
		"ship":
			ui.call("OpenFleetFinder", true)
		"troop":
			ui.call("OpenTroopFinder")
		"personnel":
			ui.OpenPersonnelFinder()
	for _i in 4:
		await process_frame
	var w: DraggableWindow = null
	for c in ui.get_children():
		if c is DraggableWindow and c.has_method("ShowTab"):
			w = c
	var ok := w != null
	if w != null:
		var tabs: Array = w._o.get("tabs", [])
		for t in tabs.size():
			if (tabs[t] as TextureButton).disabled:
				continue
			w.ShowTab(t, true)
			for _i in 3:
				await process_frame
			ok = _shot(w, "%s_%s_%d.png" % [out, which, t]) and ok
		if w.has_method("SetSpecForces"):
			for t in tabs.size():
				w.SetSpecForces(true, t)
				for _i in 3:
					await process_frame
				ok = _shot(w, "%s_%s_sf_%d.png" % [out, which, t]) and ok
	print("[capture_finder] %s -> %s" % [which, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position), Vector2i(w.size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
