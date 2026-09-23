extends SceneTree
## Renders the Create Mission window (manual p042 Fig 2.34) for the case in
## TeeJ's screenshot of the original - a character of ours recruiting on the
## world they stand on - and its Decoy tab with one of a team moved across, to
## PNGs cropped to the window. Needs a window (NOT --headless), like
## tests/capture_windows.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_create_mission.gd -- --out=C:/tmp/cm.png [--faction=alliance]
##   writes <out minus .png>_select.png and _decoy.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://cm.png").trim_suffix(".png")
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
	var recruit: int = Enums.MissionType.Recruitment
	var team: Array = []
	var world: Planet = null
	for c in GameState.ActiveRoster:
		if c.Faction != us or c.IsOffMap():
			continue
		var at: Planet = OrderManager.SystemOf(c.Attached)
		if at != null and MissionManager.TeamCanPerform([c], recruit) and MissionManager.CanTarget(recruit, us, at).ok:
			team = [c]
			world = at
			break
	if world == null:
		print("[capture_create_mission] no recruiter found")
		quit(1)
		return
	var ok := true
	ui.OnDefenseClicked(world)
	for _i in 3:
		await process_frame
	var host: DraggableWindow = ui._openWindows.get(world.Name + " Defenses")
	host.OpenCreateMission(team, world, world)
	for _i in 3:
		await process_frame
	var w: Control = ui._openWindows.get("Create Mission")
	if w == null:
		print("[capture_create_mission] the original window did not open (art imported?)")
		quit(1)
		return
	w._show_mission(maxi(0, w._legal.find(recruit)))
	for _i in 3:
		await process_frame
	ok = _shot(w, out + "_select.png") and ok
	# The Decoy tab: the whole of the recruiter's world's people, one moved.
	w.CloseWindow()
	for _i in 2:
		await process_frame
	var crowd: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and not c.IsOffMap() and OrderManager.SystemOf(c.Attached) == world)
	host.OpenCreateMission(crowd.slice(0, 4), world, world)
	for _i in 3:
		await process_frame
	w = ui._openWindows.get("Create Mission")
	if w != null:
		w._show_page(1)
		for _i in 2:
			await process_frame
		if crowd.size() > 1:
			w._picked = [crowd[1]]
			w._move(true)
			w._picked = [crowd[0]]
			w._fill_columns()
		for _i in 3:
			await process_frame
		ok = _shot(w, out + "_decoy.png") and ok
	print("[capture_create_mission] %s, team %s -> %s" % [world.Name, str(Lq.select(team, func(c: Unit) -> String: return c.Name)), "ok" if ok else "error"])
	quit(0 if ok else 1)


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position), Vector2i(w.size))
	print("[capture_create_mission] window at %s" % str(r))
	return img.get_region(r).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
