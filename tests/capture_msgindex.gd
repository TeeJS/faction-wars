extends SceneTree
## Renders the Comms Center as the original's Message Index (manual p078 Fig
## 3.18) after a few days of play, on the Advice tab with its first message
## picked, then that message read (Figs 2.38 / 3.19). Needs a window (NOT
## --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_msgindex.gd -- --out=C:/tmp/mi.png [--faction=alliance] [--tab=Advice]
##   writes <out minus .png>_index.png and _summary.png, each the window
##
## --extra=N posts N read Conflict messages first (a tab long enough for the
## scroll bar); --pick=K picks the K-th row instead of the first.

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://mi.png").trim_suffix(".png")
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
	var engine: StrategicTickManager = main._strategicEngine
	AiManager.DriveAllFactions = true
	for _d in 12:
		engine.AdvanceDay()
		await process_frame
	var tab := _arg("--tab=", "Advice")
	for i in int(_arg("--extra=", "0")):
		var filler := GameMessage.new("Filler message %d" % (i + 1), "A message to fill the tab.", Enums.MessageCategory.Conflict)
		EventBus.BroadcastMessage(filler)
	for m in MessageWindow.MessagesFor("All"):
		if (m as GameMessage).Title.begins_with("Filler"):
			(m as GameMessage).IsRead = true
	ui.OnMessageIndexClicked(tab)
	for _i in 4:
		await process_frame
	var w: Node = ui._openWindows.get("Communications")
	var ok: bool = w != null and w._original
	if ok:
		var messages: Array = MessageWindow.MessagesFor(tab)
		var pick: int = clampi(int(_arg("--pick=", "0")), 0, maxi(0, messages.size() - 1))
		if not messages.is_empty():
			w._o_pick(messages[pick], false, false)
		for _i in 3:
			await process_frame
		ok = _shot(w, out + "_index.png") and ok
		if not messages.is_empty():
			w._o_show_summary(messages[0])
			for _i in 3:
				await process_frame
			ok = _shot(w, out + "_summary.png") and ok
		print("[capture_msgindex] %s: %d messages on %s" % [GameSettings.PlayerFaction.Id, messages.size(), tab])
	quit(0 if ok else 1)


func _shot(w: Control, path: String) -> bool:
	var img: Image = root.get_viewport().get_texture().get_image()
	return img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size))).save_png(path) == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
