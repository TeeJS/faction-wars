extends SceneTree
## Renders the original's Status window (manual p064) for a trooper regiment,
## the Facilities Under Construction queue and a manufacturing facility, each
## cropped to the window. Needs a window (NOT --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_status_plate.gd -- --out=C:/tmp/st.png [--faction=alliance]
##   writes <out minus .png>_unit.png, _queue.png and _facility.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://st.png").trim_suffix(".png")
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
	var us: Faction = GameSettings.PlayerFaction
	var regiment: Unit = null
	var yard: Facility = null
	var home: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		for u in p.Garrison:
			if regiment == null and u.Type == Enums.UnitType.Troop:
				regiment = u
		for f in p.Facilities:
			if yard == null and f.HasRole("produces_unit"):
				yard = f
				home = p
	var ok := true
	var shots := [["unit", func() -> void: ui.OpenUnitStatusWindow(regiment)],
		["queue", func() -> void: ui.OpenQueueStatusWindow(home, "produces_facility")],
		["facility", func() -> void: ui.OpenDefenseFacilityStatusWindow(yard)]]
	for shot in shots:
		(shot[1] as Callable).call()
		for _i in 4:
			await process_frame
		var w: Control = null
		for k in ui._openWindows:
			if str(k).begins_with("Status_") and is_instance_valid(ui._openWindows[k]):
				w = ui._openWindows[k]
		if w == null:
			ok = false
			continue
		var img: Image = root.get_viewport().get_texture().get_image()
		ok = img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size))).save_png("%s_%s.png" % [out, shot[0]]) == OK and ok
		(w as DraggableWindow).CloseWindow()
		for _i in 2:
			await process_frame
	print("[capture_status_plate] %s, %s, %s -> %s" % [regiment.Name if regiment else "-", home.Name if home else "-", yard.Name() if yard else "-", "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
