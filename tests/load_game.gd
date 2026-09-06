extends SceneTree
## Issue #6 PR B: loading a saved game end to end. Play a few days recording to a
## log, Save it to a slot (SaveManager), then set GameSettings.PendingLoadPath to
## that slot and bring up Main.tscn - GameManager._ready must replay the slot and
## restore the saved day instead of starting fresh.
##
##   Godot_console.exe --headless --path . -s tests/load_game.gd

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
	SaveManager.Dir = "user://test-load-saves"
	_clean()

	# --- Generate a real save: play a few days, recording to the command log. ---
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-load-gen.jsonl", CommandLog.Header())
	for _i in 5:
		engine.AdvanceDay()
		CommandBus.day_done()   # record the day hash to the log
	var saved_day: int = StrategicTickManager.Today
	_check(saved_day > 1, "generated a multi-day game to save (day %d)" % saved_day)
	_check(SaveManager.Save(0, "Mid-game"), "Save(0) writes the current game to a slot")
	CommandLog.Close()

	# --- Load slot 0 through the GameManager load path. ---
	GameSettings.PendingLoadPath = SaveManager.SlotPath(0)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame

	_check(GameSettings.PendingLoadPath == "", "PendingLoadPath is consumed by the load")
	_check(StrategicTickManager.Today == saved_day, "restored to the saved day %d (got %d)" % [saved_day, StrategicTickManager.Today])

	_clean()
	_finish()


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-load-saves/slots.json"):
		DirAccess.remove_absolute("user://test-load-saves/slots.json")


func _finish() -> void:
	print("[load_game] %d checks, %d failed (restored day %d)" % [_checks, _fails, StrategicTickManager.Today])
	quit(1 if _fails > 0 else 0)
