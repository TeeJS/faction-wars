extends SceneTree
## Issue #6 PR B: the start-menu Load screen lists the six slots (used ones
## loadable), and choosing one sets GameSettings.PendingLoadPath. Scratch save dir.
##
##   Godot_console.exe --headless --path . -s tests/load_game_window.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	SaveManager.Dir = "user://test-lgw-saves"
	_clean()

	# Create one saved game in slot 1.
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-lgw-gen.jsonl", CommandLog.Header())
	for _i in 3:
		engine.AdvanceDay()
		CommandBus.day_done()
	_check(SaveManager.Save(1, "My Save"), "a game is saved to slot 1")
	CommandLog.Close()

	GameSettings.PendingLoadPath = ""
	var w := LoadGameWindow.new()
	root.add_child(w)
	await process_frame

	_check(w._rows.size() == 6, "six slot rows are listed")
	_check(not (w._rows[1]["load"] as Button).disabled, "the used slot's Load button is enabled")
	_check((w._rows[0]["load"] as Button).disabled, "an empty slot's Load button is disabled")

	# Choosing the used slot sets the pending-load path (the scene change is
	# deferred; we quit before it processes).
	w._load(1)
	_check(GameSettings.PendingLoadPath == SaveManager.SlotPath(1), "Load sets PendingLoadPath to the chosen slot")

	GameSettings.PendingLoadPath = ""
	_clean()
	_finish()


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-lgw-saves/slots.json"):
		DirAccess.remove_absolute("user://test-lgw-saves/slots.json")


func _finish() -> void:
	print("[load_game_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
