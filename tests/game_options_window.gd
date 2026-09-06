extends SceneTree
## Issue #6 PR A: the Game Options screen builds six save-slot rows and its Save
## action writes the current game to that slot via SaveManager. Runs against a
## scratch save directory.
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

	_check(w._rows.size() == 6, "six slot rows are built")

	# Save into slot 2 via the window's own Save action, with a typed name.
	(w._rows[2]["name"] as LineEdit).text = "From The Screen"
	w._on_save(2)

	var slots: Array = SaveManager.Slots()
	_check(slots[2]["used"], "slot 2 is saved via the window")
	_check(slots[2]["name"] == "From The Screen", "the typed name is used")
	_check((w._rows[2]["state"] as Label).text.contains("From The Screen"), "row 2 state shows the saved name")
	_check(not slots[0]["used"], "an untouched slot stays empty")

	w.free()
	_clean()
	_finish()


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-saves-win/slots.json"):
		DirAccess.remove_absolute("user://test-saves-win/slots.json")


func _finish() -> void:
	print("[game_options_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
