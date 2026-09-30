extends SceneTree
## THE MESSAGE WINDOW AS DISPATCHES (src/ui/look_dispatch.gd; docs/ww2-look-plan.md
## phase 4). One pack per process:
##
##   .\tools\run-gd.ps1 tests/look_messages.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/look_messages.gd -- --pack=star-wars-rebellion --seed=12345
##
## With a look: the window in the look's frame, the list a ruled ledger (the
## subject bold until read, the theatre and day under it, the category's
## stamp; Conflict with a signal band), the message read as a dispatch (the
## header word, the stamp, the subject, "world, theatre · Day N", the text in
## ink) with its actions as command keys, and an empty category in the pack's
## words. The picture's fixed path still resolves. Without a look (Star Wars,
## no art set, the stand-ins off): the plain window as it was.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[look_messages] ok   %s" % what)
	else:
		_fails += 1
		print("[look_messages] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-look-messages-none"
	# The plain window, which is what a look dresses: without the art the Star
	# Wars pack would otherwise build the original's from our stand-ins
	# (art_standins.gd; a pack with a look never does).
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var id := FactionRegistry.LoadedId()
	_check(not GameState.ActiveGalaxy.is_empty() and main.get_script() != null and main.has_method("SetSpeed"),
		"%s: the game started (%d theatres)" % [id, GameState.ActiveGalaxy.size()])

	# Mail to read: a fleet signal about a world, a conflict report.
	var us: Faction = GameSettings.PlayerFaction
	var sector: Sector = GameState.ActiveGalaxy[0]
	var world: Planet = sector.Planets[0]
	var fleet := GameMessage.new("Look test: fleet in position", "The fleet stands ready.", Enums.MessageCategory.Fleets, StrategicTickManager.Today)
	fleet.AssociatedLocation = world
	EventBus.Tell(us, fleet)
	var clash := GameMessage.new("Look test: engagement", "Contact reported.", Enums.MessageCategory.Conflict, StrategicTickManager.Today)
	EventBus.Tell(us, clash)
	await process_frame

	ui.OnMessageIndexClicked("Fleets")
	for _i in 4:
		await process_frame
	var w: MessageWindow = ui._openWindows.get("Communications")
	_check(w != null, "%s: the Message Index opened" % id)
	if w == null:
		_done()
		return
	_check(w.get_node_or_null(MessageWindow.PortraitPath) != null, "the picture's fixed path still resolves")
	var list: VBoxContainer = w._lists["Fleets"]
	var row: Button = _row_for(list, fleet)

	if not Look.Active():
		_check(w.theme == null, "%s: no look - the window wears no theme" % id)
		_check(row != null and row.text.begins_with("[Day ") and row.text.ends_with(fleet.Title), "a row is the plain \"[Day N] subject\"")
		_check(w.get_node_or_null("%DetailView/LookHead") == null, "no dispatch header")
		w.OpenToCategory("Chat")
		await process_frame
		var empty: Label = _empty_label(w._lists["Chat"])
		_check(empty != null and empty.text == "No transmissions.", "an empty category: \"No transmissions.\" (%s)" % (empty.text if empty else "none"))
		_done()
		return

	# The frame.
	_check(w.theme == Look.GetTheme(), "the window wears the look")
	var bar: ColorRect = w.get_node("%TitleBar")
	_check(bar.color == Look.C("chassis_deep") and bar.get_node_or_null("LookRule") != null, "its bar is steel with a brass rule")
	_check((w.get_node("%TitleBarLabel") as Label).uppercase, "the title in capitals")

	# The ledger.
	_check(row != null and row.theme_type_variation == Look.ROW and row.text.is_empty(), "the fleet signal is a ledger row")
	if row != null:
		var subject: Label = row.get_node_or_null("LookRow/Lines/Subject")
		var meta: Label = row.get_node_or_null("LookRow/Lines/Meta")
		var stamp: PanelContainer = row.get_node_or_null("LookRow/Stamp")
		_check(subject != null and subject.text == fleet.Title, "its subject")
		_check(meta != null and meta.text.begins_with(sector.Name) and meta.text.contains("Day "), "its theatre and day (%s)" % (meta.text if meta else "none"))
		_check(stamp != null and (stamp.get_node("Word") as Label).text == Look.Stamp("Fleets").to_upper(), "its stamp (%s)" % Look.Stamp("Fleets"))
		_check(row.get_node_or_null("LookBand") == null, "no signal band on a fleet signal")
		_check(subject != null and subject.get_theme_font("font") == Look.F("body_bold"), "unread: the subject in the bold face")
		# A ruled line under every row (TeeJ, 2026-09-30: "there is no
		# separation between lines"), and a mission report stamped as one
		# ("none of these are 'orders'").
		var rule: ColorRect = row.get_node_or_null("LookRule")
		_check(rule != null and rule.anchor_top == 1.0 and rule.anchor_bottom == 1.0 and rule.color.a > 0.0, "a ruled line under the row")
		if id == "ww2":
			_check(Look.Stamp("Missions") == "Secret", "a mission report is stamped Secret, not Orders (%s)" % Look.Stamp("Missions"))

	# The dispatch.
	var detail: VBoxContainer = w.get_node("%DetailView")
	_check(detail.draw.get_connections().size() > 0, "the parchment is drawn under the detail column")
	var head: Label = detail.get_node_or_null("LookHead/Header")
	_check(head != null and head.text == Look.DispatchHeader().to_upper(), "the dispatch header (%s)" % (head.text if head else "none"))
	_check(detail.get_child(1) == w._detailSubject and detail.get_child(2).name == "LookMeta",
		"scan order: header, subject, then where and when")
	if row != null:
		row.button_pressed = true
		await process_frame
		# Reading it repaints the list: the row is a new one.
		row = _row_for(list, fleet)
	var meta_d: Label = detail.get_node("LookMeta")
	_check(w._detailSubject.text == fleet.Title, "the subject alone, the day moved to its own line")
	_check(meta_d.visible and meta_d.text == "%s, %s  ·  Day %d" % [world.Name, sector.Name, StrategicTickManager.Shown(fleet.DayReceived)],
		"world, theatre and day (%s)" % meta_d.text)
	_check((detail.get_node("LookHead/Stamp") as Control).visible, "the dispatch carries its stamp")
	_check(not bool(detail.get_meta("look_urgent", false)), "no signal band on the fleet dispatch")
	_check(w._detailBody.get_theme_color("default_color") == Look.C("ink"), "the text in ink")
	_check(fleet.IsRead, "reading it marks it read")
	var read_subject: Label = row.get_node_or_null("LookRow/Lines/Subject") if row != null else null
	_check(read_subject != null and read_subject.get_theme_font("font") == Look.F("body"), "read: the subject in the regular face")
	for b in [w._gotoButton, w._deleteBtn, w._selectAllBtn, w._deleteSelectedBtn]:
		_check(b != null and (b as Button).theme_type_variation == Look.COMMAND, "a command key: %s" % (b as Button).text)
	_check(w._gotoButton != null and not w._gotoButton.disabled, "Go To: on for a message about a world")
	var portrait: Control = w.get_node(MessageWindow.PortraitPath)
	_check(not portrait.visible or portrait.get_node_or_null("Picture") != null, "no empty picture box on the dispatch")

	# Urgent: the conflict report.
	w.OpenToCategory("Conflict")
	await process_frame
	var hot: Button = _row_for(w._lists["Conflict"], clash)
	_check(hot != null and hot.get_node_or_null("LookBand") != null, "a conflict report's row carries the signal band")
	var hot_stamp: PanelContainer = hot.get_node_or_null("LookRow/Stamp") if hot != null else null
	_check(hot_stamp != null and (hot_stamp.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Look.C("signal"), "and a red stamp")
	if hot != null:
		hot.button_pressed = true
		await process_frame
	_check(bool(detail.get_meta("look_urgent", false)), "its dispatch carries the signal band")

	# Empty.
	w.OpenToCategory("Chat")
	await process_frame
	var empty: Label = _empty_label(w._lists["Chat"])
	_check(empty != null and empty.text == Terms.label("no_messages") and empty.text != "No transmissions.",
		"an empty category in the pack's words (%s)" % (empty.text if empty else "none"))
	_check(not (detail.get_node("LookHead/Stamp") as Control).visible and not detail.get_node("LookMeta").visible,
		"nothing picked: a blank dispatch")
	_done()


func _row_for(list: VBoxContainer, m: GameMessage) -> Button:
	for c in list.get_children():
		if c is Button and not c.is_queued_for_deletion():
			var b: Button = c
			if b.text.ends_with(m.Title) or b.tooltip_text == m.Title:
				return b
	return null


## The list's empty-state line (opening a tab paints it twice, so the first
## one may still be on its way out).
func _empty_label(list: VBoxContainer) -> Label:
	for c in list.get_children():
		if c is Label and not c.is_queued_for_deletion():
			return c
	return null


func _done() -> void:
	print("[look_messages] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
