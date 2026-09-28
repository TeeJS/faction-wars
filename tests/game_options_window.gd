extends SceneTree
## Issue #6 PR A: the plain Game Options window builds its rows (as many as
## the real screen) and its Save action writes the current game under the typed
## name; the rows then show the newest games. Runs against a scratch save directory.
##
##   Godot_console.exe --headless --path . -s tests/game_options_window.gd

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
	SaveManager.Dir = "user://test-saves-win"
	_clean()

	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-gow-session.jsonl", CommandLog.Header())

	var w := GameOptionsWindow.new()
	root.add_child(w)
	await process_frame   # let _ready build the rows

	_check(w._rows.size() == GameOptionsWindow.Rows, "as many rows as the real screen")

	# Save from row 2 via the window's own Save action, with a typed name.
	(w._rows[2]["name"] as LineEdit).text = "From The Screen"
	w._on_save(2)

	var games: Array = SaveManager.Games()
	_check(games.size() == 1 and games[0]["name"] == "From The Screen", "the game is saved under the typed name")
	_check((w._rows[0]["state"] as Label).text.contains("From The Screen"), "it shows on the top row, the newest")
	_check((w._rows[0]["state"] as Label).tooltip_text == SaveManager.SavedLabel(games[0]), "hovering it shows Saved and the day")
	_check((w._rows[1]["state"] as Label).text == "(empty)", "the next row is empty")

	w.free()
	_clean()
	_finish()


func _clean() -> void:
	_remove(SaveManager.Dir)


func _finish() -> void:
	print("[game_options_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
