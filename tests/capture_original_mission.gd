extends SceneTree
## Renders the original's Mission window (manual p109 Fig 3.51) for the case
## in TeeJ's screenshot of the original - the Emperor recruiting on Coruscant
## - on both tabs, and a Diplomacy mission still in hyperspace, to PNGs
## cropped to the window. Needs a window (NOT --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_original_mission.gd -- --out=C:/tmp/mw.png
##   writes <out minus .png>_agents.png, _decoys.png and _transit.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://mw.png").trim_suffix(".png")
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
	CommandBus.Immediate = true
	var recruit: int = Enums.MissionType.Recruitment
	var who: Character = null
	for c in GameState.ActiveRoster:
		if c.Faction == us and not c.IsOffMap() and c.Attached is Planet and MissionManager.TeamCanPerform([c], recruit) \
				and MissionManager.CanTarget(recruit, us, c.Attached).ok:
			who = c
			break
	if who == null:
		print("[capture_original_mission] no recruiter found")
		quit(1)
		return
	var home: Planet = who.Attached
	MissionManager.Launch(recruit, [who], home, home)
	ui.OnMissionClicked(home)
	for _i in 3:
		await process_frame
	var w: Control = ui._openWindows.get(home.Name + " Missions")
	if w == null or not w.has_method("_show_picked"):
		print("[capture_original_mission] the original window did not open (art imported?)")
		quit(1)
		return
	w.position = Vector2(200, 100)
	for _i in 2:
		await process_frame
	var ok := _shot(w, out + "_agents.png")
	w._page = 1
	w._show_picked()
	for _i in 2:
		await process_frame
	ok = _shot(w, out + "_decoys.png") and ok
	w.CloseWindow()
	# A Diplomacy team sent to another world: in hyperspace, a decoy along.
	var team: Array = Lq.where(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and not c.IsOffMap() and c.Attached is Planet and c != who).slice(0, 2)
	var dip: int = Enums.MissionType.Diplomacy
	var far: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p != (team[0] as Character).Attached and p.IsExplored and MissionManager.CanTarget(dip, us, p).ok \
			and (team[0].Attached as Planet).DeploymentDaysTo(p) > 0)
	if far != null and team.size() == 2:
		MissionManager.Launch(dip, team, team[0].Attached, far, [team[1]])
		ui.OnMissionClicked(far)
		for _i in 3:
			await process_frame
		w = ui._openWindows.get(far.Name + " Missions")
		if w != null:
			w.position = Vector2(200, 100)
			for _i in 2:
				await process_frame
			ok = _shot(w, out + "_transit.png") and ok
	print("[capture_original_mission] %s at %s -> %s" % [who.Name, home.Name, "ok" if ok else "error"])
	quit(0 if ok else 1)


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	var r := Rect2i(Vector2i(w.global_position), Vector2i(w.size))
	print("[capture_original_mission] window at %s" % str(r))
	return img.get_region(r).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
