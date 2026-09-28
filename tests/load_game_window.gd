extends SceneTree
## Issue #6 PR B: the start-menu Load screen lists every saved game, newest
## first, and choosing one sets GameSettings.PendingLoadPath. Scratch save dir.
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

	# Two saved games.
	var engine: StrategicTickManager = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-lgw-gen.jsonl", CommandLog.Header())
	for _i in 3:
		engine.AdvanceDay()
		CommandBus.day_done()
	var older: String = SaveManager.Save("Older Save")
	var mine: String = SaveManager.Save("My Save")
	_check(not older.is_empty() and not mine.is_empty(), "two games are saved")
	CommandLog.Close()

	GameSettings.PendingLoadPath = ""
	var w := LoadGameWindow.new()
	root.add_child(w)
	await process_frame

	_check(w._rows.size() == 2, "both games are listed")
	_check(w._rows[0]["id"] == mine and w._rows[1]["id"] == older, "newest first")

	# Choosing a game sets the pending-load path (the scene change is
	# deferred; we quit before it processes).
	w._load(mine)
	_check(GameSettings.PendingLoadPath == SaveManager.GamePath(mine), "Load sets PendingLoadPath to the chosen game")

	GameSettings.PendingLoadPath = ""
	_clean()
	_finish()


func _clean() -> void:
	_remove(SaveManager.Dir)


func _finish() -> void:
	print("[load_game_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
