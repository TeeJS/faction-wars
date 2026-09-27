extends SceneTree
## The agent's advice messages (docs/advisor-plan.md; manual p022, p079), on a
## synthetic advice.json and picture - never the original's text:
##   - pack.json `advice`: the art set's list per side, group 7 at the start,
##     the side's picture; rule 29 refuses bad advice;
##   - a new game in Easy (Agent Advice on, manual p022) posts this side's
##     opening group, in the list's order (top to bottom in the Advice tab),
##     to the Advice category - not under All Messages nor its count, not to
##     the other side - each with the side's picture;
##   - with no briefing to play, the Message Index opens on Agent Advice;
##   - a long text keeps to the Message Summary's box, the wheel moving it;
##   - in Medium Agent Advice starts off and nothing is posted; switched on
##     from the agent's menu, the opening advice arrives, once;
##   - without the art set's file nothing is posted and nothing opens.
## Writes and removes its own files under user://.
##
##   .\tools\run-gd.ps1 tests/advice.gd

const Art := preload("res://src/ui/artwork.gd")
const AdviceLib := preload("res://src/ui/advice.gd")
const MessageWindow := preload("res://src/ui/message_window.gd")
const ArtRoot := "user://test-advice-art"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[advice] ok   %s" % what)
	else:
		_fails += 1
		print("[advice] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	FactionRegistry.EnsureLoaded()
	var m: PackDefs.PackManifest = FactionRegistry.Pack.Manifest

	# The pack's advice: the art set's lists, group 7 at the start.
	var al: Dictionary = m.Advice.get("alliance", {})
	var em: Dictionary = m.Advice.get("empire", {})
	_check(m.AdviceGiven and not m.Advice.has("_comment") and al.size() == 4
		and str(al.get("messages", "")) == "swr-original:advice.json" and str(al.get("list", "")) == "alliance"
		and int(al.get("opening", -1)) == 7 and str(al.get("picture", "")) == "swr-original:windows/advice.alliance.png"
		and str(em.get("messages", "")) == "swr-original:advice.json" and str(em.get("list", "")) == "empire" and int(em.get("opening", -1)) == 7 and str(em.get("picture", "")) == "swr-original:windows/advice.empire.png",
		"the Star Wars pack's advice: advice.json's list per side, group 7 at the start, the side's picture")
	_Rules()

	# A new game without the art set's file: nothing.
	var main: Node = await _start("alliance", Enums.Difficulty.Easy)
	var ui: UIManager = main.get_node("UIManager")
	_check(MessageWindow.MessagesFor("Advice").is_empty() and ui._openWindows.get("Communications") == null,
		"without the art set's advice.json: no advice, the Message Index stays shut")
	await _stop(main)

	# The stand-ins: three opening messages with a later one among them, and the
	# other side's list.
	var dir := "%s/swr-original" % ArtRoot
	DirAccess.make_dir_recursive_absolute("%s/windows" % dir)
	var file := {
		"alliance": [
			{"n": 1, "group": 7, "key": 10, "title": "First Tip", "text": "One.\n\n" + " ".join(PackedStringArray(range(120).map(func(i: int) -> String: return "word%d" % i)))},
			{"n": 2, "group": 7, "key": 20, "title": "Second Tip", "text": "Two."},
			{"n": 3, "group": 1, "key": 140, "title": "Later Tip", "text": "Not yet."},
			{"n": 4, "group": 7, "key": 30, "title": "Third Tip", "text": "Three."},
		],
		"empire": [{"n": 1, "group": 7, "key": 10, "title": "Imperial Tip", "text": "For the other side."}],
	}
	var f := FileAccess.open("%s/advice.json" % dir, FileAccess.WRITE)
	f.store_string(JSON.stringify(file))
	f.close()
	var pic := Image.create(400, 200, false, Image.FORMAT_RGBA8)
	pic.fill(Color(0.8, 0.6, 0.1))
	pic.save_png("%s/windows/advice.alliance.png" % dir)
	# The Message Index's own pictures, plain, so the original's window is built.
	for sub in ["buttons", "tabs"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for rel in ["windows/frame.alliance", "windows/frame.empire"]:
		_png("%s/%s.png" % [dir, rel], 470, 331)
	for rel in ["windows/msgindex_plate", "windows/ency_topic_plate"]:
		_png("%s/%s.png" % [dir, rel], 400, 306)
	for rel in ["windows/msgindex_selection.empire", "buttons/msgindex_select_all", "buttons/msgindex_summary.empire", "tabs/msg_all"]:
		_png("%s/%s.png" % [dir, rel], 20, 16)
	Art.Reset()
	var ours: Faction = FactionRegistry.ById("alliance")
	_check(AdviceLib.Messages(ours).size() == 4 and AdviceLib.Opening(ours).size() == 3, "the Alliance's list: 4, of them 3 in group 7")

	# A new game in Easy: the opening advice.
	main = await _start("alliance", Enums.Difficulty.Easy)
	ui = main.get_node("UIManager")
	var shown: Array = MessageWindow.MessagesFor("Advice")
	var titles: Array = shown.map(func(msg: GameMessage) -> String: return msg.Title)
	_check(titles == ["First Tip", "Second Tip", "Third Tip"], "a new game posts group 7 in the list's order, top to bottom: %s" % str(titles))
	var first: GameMessage = shown[0] if not shown.is_empty() else null
	_check(first != null and first.Body.begins_with("One.\n\nword0 ") and first.Category == Enums.MessageCategory.Advice and first.For == ours
		and first.Picture == "swr-original:windows/advice.alliance.png" and not first.IsRead,
		"... each its title and text, in Advice, for the Alliance, unread, with the side's picture")
	_check(MessageWindow.MessagesFor("All").all(func(msg: GameMessage) -> bool: return msg.Category != Enums.MessageCategory.Advice),
		"... and none under All Messages (manual p079)")
	var others: int = EventBus.MessageLog.filter(func(msg: GameMessage) -> bool:
		return EventBus.Visible(msg) and not msg.IsRead and msg.Category != Enums.MessageCategory.Advice).size()
	_check(EventBus.UnreadCount(Enums.MessageCategory.Advice) == 3 and EventBus.UnreadCount(Enums.MessageCategory.All) == others,
		"... nor in All Messages' unread count (%d, advice 3)" % EventBus.UnreadCount(Enums.MessageCategory.All))
	_check(AdviceLib.On, "Easy: Agent Advice on (manual p022)")
	_check(not EventBus.MessageLog.any(func(msg: GameMessage) -> bool: return msg.Title == "Imperial Tip" or msg.Title == "Later Tip"),
		"the other side's advice and the later tips are not posted")
	var tex: Texture2D = MessageWindow.MessagePicture(first)
	_check(tex != null and tex.get_width() == 400 and tex.get_height() == 200, "reading one shows the side's advice picture")
	var comms: Node = ui._openWindows.get("Communications")
	_check(comms != null and is_instance_valid(comms) and _category(comms) == "Advice",
		"with no briefing to play, the Message Index opens on Agent Advice (%s)" % (_category(comms) if comms != null else "none"))
	_Scroll(comms, first)
	await _stop(main)

	# Medium: Agent Advice starts off; switched on, the opening advice arrives.
	main = await _start("alliance", Enums.Difficulty.Medium)
	ui = main.get_node("UIManager")
	_check(not AdviceLib.On and MessageWindow.MessagesFor("Advice").is_empty() and ui._openWindows.get("Communications") == null,
		"Medium: Agent Advice off, no advice, the Message Index stays shut")
	var popup: PopupMenu = ui._AgentPopup()
	var at: int = popup.get_item_index(8)
	_check(popup.get_item_text(at) == "Agent Advice" and popup.is_item_checkable(at) and not popup.is_item_checked(at) and not popup.is_item_disabled(at),
		"the agent's menu: Agent Advice, a check item, unchecked")
	ui.OnAgentMenu(8)
	_check(AdviceLib.On and MessageWindow.MessagesFor("Advice").size() == 3 and ui._AgentPopup().is_item_checked(at),
		"switched on: checked, and the opening advice arrives (%d)" % MessageWindow.MessagesFor("Advice").size())
	ui.OnAgentMenu(8)
	ui.OnAgentMenu(8)
	_check(AdviceLib.On and MessageWindow.MessagesFor("Advice").size() == 3, "off and on again: the advice stays and does not come twice")
	var alt_a := InputEventKey.new()
	alt_a.keycode = KEY_A
	alt_a.alt_pressed = true
	alt_a.pressed = true
	ui._unhandled_input(alt_a)
	_check(not AdviceLib.On, "Alt+A switches it off")
	await _stop(main)
	_finish()


## A text longer than the Message Summary's box stays in it; the wheel moves it.
func _Scroll(comms: Node, long: GameMessage) -> void:
	if comms == null or not comms._original or long == null:
		_check(false, "the original's Message Index is built for the scroll check")
		return
	comms._o_show_summary(long)
	var text: Label = comms._oSumText
	var lines: int = text.get_line_count()
	_check(text.max_lines_visible == 4 and lines > 4 and text.lines_skipped == 0 and text.clip_text,
		"a long text in the Message Summary: four lines of its %d on show, from the top" % lines)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	comms._o_scroll_text(wheel)
	_check(text.lines_skipped == 1, "the wheel down moves it a line")
	for _i in lines + 3:
		comms._o_scroll_text(wheel)
	_check(text.lines_skipped == lines - 4, "... no further than its last line (%d)" % text.lines_skipped)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for _i in lines + 3:
		comms._o_scroll_text(wheel)
	_check(text.lines_skipped == 0, "the wheel up, back to the top")
	comms._o_show_summary(long)
	_check(text.lines_skipped == 0, "a message shown again starts at its top")


func _Rules() -> void:
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	var m := pack.Manifest
	var saved: Variant = m.AdviceRaw
	var good := {"messages": "swr-original:advice.json", "list": "alliance", "opening": 7, "picture": "swr-original:windows/advice.alliance.png"}
	var cases := [
		[{"alliance": good}, ""],
		[{"alliance": {"messages": "swr-original:advice.json", "list": "alliance"}}, ""],
		["no", "must be an object"],
		[{"rebels": good}, "is not a faction"],
		[{"alliance": []}, "must be an object (messages, list, opening, picture)"],
		[{"alliance": {"messages": "swr-original:advice.json", "list": "alliance", "voice": "x"}}, "is none of messages, list, opening, picture"],
		[{"alliance": {"list": "alliance"}}, "names no messages file"],
		[{"alliance": {"messages": "swr-original:advice.txt", "list": "alliance"}}, "is not a .json file"],
		[{"alliance": {"messages": "other-set:advice.json", "list": "alliance"}}, "which art_sets does not declare"],
		[{"alliance": {"messages": "swr-original:advice.json"}}, "list: must name the file's list"],
		[{"alliance": {"messages": "swr-original:advice.json", "list": "alliance", "opening": "start"}}, "opening: must be a group number"],
		[{"alliance": {"messages": "swr-original:advice.json", "list": "alliance", "picture": "swr-original:windows/advice.bmp"}}, "is not a .png file"],
	]
	for c in cases:
		var errors: Array[String] = []
		m.AdviceRaw = c[0]
		m.AdviceGiven = true
		PackLoader._validate_advice(pack, FactionRegistry.LoadedDir, errors)
		var want: String = c[1]
		var ok: bool = errors.is_empty() if want.is_empty() else (errors.size() >= 1 and errors[0].contains(want))
		_check(ok, "rule 29: %s -> %s" % [JSON.stringify(c[0]), str(errors) if not errors.is_empty() else "accepted"])
	m.AdviceRaw = saved


func _category(w: Node) -> String:
	if w == null or not is_instance_valid(w):
		return ""
	if w._original:
		return str(w._oCategory)
	var tc: TabContainer = w._tabContainer
	return str(tc.get_child(tc.current_tab).name)


func _start(side: String, difficulty: int) -> Node:
	Art.Reset()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = difficulty
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(side)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	return main


func _stop(main: Node) -> void:
	main.queue_free()
	for _i in 3:
		await process_frame


func _finish() -> void:
	_remove(ArtRoot)
	Art.Reset()
	print("[advice] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.35))
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
