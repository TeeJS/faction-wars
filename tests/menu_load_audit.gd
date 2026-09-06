extends SceneTree
## Behaviour re-audit for the start-menu Load path: press the real "Load Game"
## button on the menu, then the real "Load" button in the slot picker, and assert
## the outcome (PendingLoadPath set) - not the handler in isolation.
##
##   Godot_console.exe --headless --path . -s tests/menu_load_audit.gd

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
	SaveManager.Dir = "user://test-menuload-saves"
	_clean()

	# A saved game in slot 0.
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-menuload-gen.jsonl", CommandLog.Header())
	for _i in 3:
		engine.AdvanceDay()
		CommandBus.day_done()
	SaveManager.Save(0, "Menu Save")
	CommandLog.Close()
	GameSettings.PendingLoadPath = ""

	# The start menu.
	var menu: Node = load("res://Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame

	var loadGameBtn: Button = _find_button(menu, "Load Game")
	_check(loadGameBtn != null, "the menu has a Load Game button")
	if loadGameBtn != null:
		loadGameBtn.pressed.emit()
		await process_frame
		var lgw: Node = menu.get_node_or_null("LoadGameWindow")
		_check(lgw != null, "pressing Load Game opens the slot picker")
		if lgw != null:
			# The first "Load" button belongs to slot 0 (used), so it is enabled.
			var loadBtn: Button = _find_button(lgw, "Load")
			_check(loadBtn != null and not loadBtn.disabled, "the used slot has an enabled Load button")
			if loadBtn != null and not loadBtn.disabled:
				loadBtn.pressed.emit()   # sets PendingLoadPath, then defers a scene change
				_check(GameSettings.PendingLoadPath == SaveManager.SlotPath(0), "pressing Load sets PendingLoadPath to the slot")

	GameSettings.PendingLoadPath = ""
	_clean()
	_finish()


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-menuload-saves/slots.json"):
		DirAccess.remove_absolute("user://test-menuload-saves/slots.json")


func _finish() -> void:
	print("[menu_load_audit] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
