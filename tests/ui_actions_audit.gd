extends SceneTree
## Behaviour re-audit (after the Go To bug): drive UI actions through their REAL
## trigger - press the actual button - and assert the visible outcome, not the
## handler in isolation. Covers: the All Messages HUD button, the in-game-menu
## Game Options entry, and the Game Options Save button. (Finders F2/F5/F6 are
## already driven end-to-end by keyboard_shortcuts.gd; the menu Load path by
## load_game_window.gd + below.)
##
##   Godot_console.exe --headless --path . -s tests/ui_actions_audit.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var found := _find_button(c, text)
		if found != null:
			return found
	return null


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	SaveManager.Dir = "user://test-audit-saves"
	_clean()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var ui: Node = main.get_node_or_null("UIManager")
	_check(ui != null, "UIManager present")
	if ui == null:
		_finish(); return

	# 1. Pressing "All Messages" in the left column opens the Comms window, set up.
	var allBtn: Node = ui.get_node_or_null("CommsPanel/Margin/CommsList/All")
	_check(allBtn is Button, "the All Messages button exists")
	if allBtn is Button:
		(allBtn as Button).pressed.emit()
		await process_frame
		_check(ui._openWindows.has("Communications"), "pressing All Messages opens the Comms window")
		if ui._openWindows.has("Communications"):
			_check(ui._openWindows["Communications"]._uiManager != null, "the opened Comms window has its UIManager (Go To works)")

	# 2. In-game menu -> pressing "Game Options" opens the save screen.
	ui.OnMenuButtonClicked()
	await process_frame
	var optBtn: Button = _find_button(ui, "Game Options")
	_check(optBtn != null, "the in-game menu has a Game Options button")
	if optBtn != null:
		optBtn.pressed.emit()
		await process_frame
		_check(ui.get_node_or_null("GameOptionsWindow") != null, "pressing Game Options opens the six-slot screen")

	# 3. Pressing a slot's Save button actually writes the slot.
	var gow: Node = ui.get_node_or_null("GameOptionsWindow")
	if gow != null:
		gow._rows[0]["name"].text = "Audit"
		var saveBtn: Button = _find_button(gow, "Save")
		_check(saveBtn != null, "the Game Options screen has a Save button")
		if saveBtn != null:
			saveBtn.pressed.emit()
			await process_frame
			_check(SaveManager.Slots()[0]["used"], "pressing Save writes slot 1")
			_check(SaveManager.Slots()[0]["name"] == "Audit", "the typed name is saved")

	_clean()
	_finish()


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-audit-saves/slots.json"):
		DirAccess.remove_absolute("user://test-audit-saves/slots.json")


func _finish() -> void:
	print("[ui_actions_audit] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
