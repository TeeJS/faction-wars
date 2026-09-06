extends SceneTree
## Issue #6 PR A: SaveManager writes the current game's command log to a named
## slot, reports the six-slot state for the Game Options screen, and the slot file
## is a complete, Read-able command log. Runs against a scratch directory so it
## never touches a player's real saves.
##
##   Godot_console.exe --headless --path . -s tests/save_slots.gd

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
	SaveManager.Dir = "user://test-saves"
	_clean()

	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	# GameManager opens the command log in the real game; here we open it directly
	# so Snapshot() has a live log (with a header) to copy.
	CommandLog.Open("user://test-save-session.jsonl", CommandLog.Header())

	# Empty to start: six slots, none used.
	var slots: Array = SaveManager.Slots()
	_check(slots.size() == 6, "six slots are reported")
	_check(not slots[0]["used"], "slot 0 starts empty")

	# Save into slot 0.
	_check(SaveManager.Save(0, "My First Game"), "Save(0) returns true")
	_check(FileAccess.file_exists(SaveManager.SlotPath(0)), "the slot 0 file is written")

	# The slot is a complete, Read-able command log (has a header).
	var read: Array = SaveManager.ReadSlot(0)
	_check(read.size() == 3 and not (read[0] as Dictionary).is_empty(), "slot 0 is a Read-able log with a header")

	# Slots() now reports slot 0 used, with the name and current day; slot 1 empty.
	slots = SaveManager.Slots()
	_check(slots[0]["used"], "slot 0 is now used")
	_check(slots[0]["name"] == "My First Game", "slot 0 name is recorded")
	_check(slots[0]["day"] == StrategicTickManager.Today, "slot 0 day is recorded")
	_check(not slots[1]["used"], "slot 1 is still empty")

	# Overwriting a used slot is allowed and updates the name.
	_check(SaveManager.Save(0, "Renamed"), "overwriting Save(0) returns true")
	_check(SaveManager.Slots()[0]["name"] == "Renamed", "slot 0 name updates on overwrite")

	# Out-of-range slots are rejected.
	_check(not SaveManager.Save(6, "Bad"), "Save(6) is rejected (out of range)")
	_check(not SaveManager.Save(-1, "Bad"), "Save(-1) is rejected (out of range)")

	_clean()
	_finish()


func _clean() -> void:
	for i in SaveManager.SLOT_COUNT:
		if FileAccess.file_exists(SaveManager.SlotPath(i)):
			DirAccess.remove_absolute(SaveManager.SlotPath(i))
	if FileAccess.file_exists("user://test-saves/slots.json"):
		DirAccess.remove_absolute("user://test-saves/slots.json")


func _finish() -> void:
	print("[save_slots] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
