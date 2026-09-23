extends SceneTree
## Renders the Mission window (with a Diplomacy mission running) and the
## Message window to a PNG, for a look at the pictures. Needs a window (NOT
## --headless), like tests/capture_map.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_mission.gd -- --out=C:/tmp/mission.png [--pack=ww2]

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://mission.png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached is Planet and c.IsMajor)
	var home: Planet = who.Attached
	CommandBus.Immediate = true
	MissionManager.Launch(Enums.MissionType.Diplomacy, [who], home, home)
	# A message about the character, selected in the Message window; the
	# Mission window opens after it, on top.
	EventBus.Tell(us, GameMessage.new("%s reports" % who.Name, "A picture check.", Enums.MessageCategory.Missions, StrategicTickManager.Today, home, who))
	ui.OnMessageIndexClicked("All")
	for _i in 4:
		await process_frame
	ui.OnMissionClicked(home)
	for _i in 3:
		await process_frame
	var mw: DraggableWindow = ui._openWindows.get(home.Name + " Missions")
	if mw != null:
		mw.position = Vector2(240, 300)
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("[capture_mission] %s at %s (%s) -> %s" % [who.Name, home.Name, out, "ok" if err == OK else ("error %d" % err)])
	quit(0 if err == OK else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
