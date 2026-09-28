extends SceneTree
## Issue #6 PR B: loading a saved game end to end. Play a few days recording to a
## log, Save it (SaveManager), then set GameSettings.PendingLoadPath to
## that game and bring up Main.tscn - GameManager._ready must replay it and
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
	var saved: String = SaveManager.Save("Mid-game")
	_check(not saved.is_empty(), "Save writes the current game")
	CommandLog.Close()

	# --- Load it through the GameManager load path. ---
	GameSettings.PendingLoadPath = SaveManager.GamePath(saved)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame

	_check(GameSettings.PendingLoadPath == "", "PendingLoadPath is consumed by the load")
	_check(StrategicTickManager.Today == saved_day, "restored to the saved day %d (got %d)" % [saved_day, StrategicTickManager.Today])

	_clean()
	_finish()


func _clean() -> void:
	_remove(SaveManager.Dir)


func _finish() -> void:
	print("[load_game] %d checks, %d failed (restored day %d)" % [_checks, _fails, StrategicTickManager.Today])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
