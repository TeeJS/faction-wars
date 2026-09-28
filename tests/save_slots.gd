extends SceneTree
## Saved games as a list, newest first (PROJECT.md, TeeJ 2026-09-27): a name is
## a game - saving under a name that is taken overwrites it and moves it to the
## top, a new name makes a new game on top and pushes the rest down. Also the
## hover text, Delete, the .fwsave export and import (import never overwrites),
## telling our files from the original's, and the one-time copy of the six old
## slots into the list with the old files left untouched. Runs against scratch
## directories so it never touches a player's real saves.
##
##   .\tools\run-gd.ps1 tests/save_slots.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[save_slots] ok   %s" % what)
	else:
		_fails += 1
		print("[save_slots] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	SaveManager.Dir = "user://test-saves"
	_remove(SaveManager.Dir)

	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	# GameManager opens the command log in the real game; here we open it directly
	# so Snapshot() has a live log (with a header) to copy.
	CommandLog.Open("user://test-save-session.jsonl", CommandLog.Header())

	_check(SaveManager.Games().is_empty(), "no saved games to start")

	# The charter's example: save "game 1", then "game 1 - death star".
	var first: String = SaveManager.Save("game 1")
	_check(not first.is_empty() and FileAccess.file_exists(SaveManager.GamePath(first)), "Save writes a game file")
	var read: Array = SaveManager.Read(first)
	_check(read.size() == 3 and not (read[0] as Dictionary).is_empty(), "the file is a Read-able log with a header")
	var second: String = SaveManager.Save("game 1 - death star")
	var names: Array = SaveManager.Games().map(func(g: Dictionary) -> String: return g["name"])
	_check(names == ["game 1 - death star", "game 1"], "a new name makes a new game on top, the old one underneath (%s)" % str(names))
	_check(second != first, "the new name is a new game")

	# Saving under a name that is taken overwrites that game and moves it up.
	_check(SaveManager.Save("game 1") == first, "Save with the name unchanged overwrites that game")
	names = SaveManager.Games().map(func(g: Dictionary) -> String: return g["name"])
	_check(names == ["game 1", "game 1 - death star"], "and it becomes the newest (%s)" % str(names))
	_check(SaveManager.Games().size() == 2, "overwriting adds no game")

	var g: Dictionary = SaveManager.Games()[0]
	_check(g["day"] == StrategicTickManager.Today and g["side"] == "alliance", "the day and the side are recorded")
	var today: Dictionary = Time.get_datetime_dict_from_system()
	var want: String = "Saved %02d/%02d/%04d - Day %d" % [today["month"], today["day"], today["year"], StrategicTickManager.Shown(StrategicTickManager.Today)]
	_check(SaveManager.SavedLabel(g) == want, "the hover text is \"%s\" (%s)" % [want, SaveManager.SavedLabel(g)])
	_check(SaveManager.Recent(1).size() == 1 and SaveManager.Recent(1)[0]["name"] == "game 1", "Recent gives the newest")

	# An empty name takes the next free "Saved game".
	var a: String = SaveManager.Save("")
	var b: String = SaveManager.Save("")
	_check(SaveManager.NameOf(a) == "Saved game" and SaveManager.NameOf(b) == "Saved game (2)", "empty names become \"Saved game\", then \"Saved game (2)\"")

	# Export, then import: never overwrites, the name gets " (2)", the Saved date is now.
	var text: String = SaveManager.ExportText(first)
	_check(text.begins_with("{") and text.contains("\"fwsave\""), "an export's first line names the format")
	_check(SaveManager.ExportFileName(first) == "game 1.fwsave", "the export file is named after the game")
	_check(SaveManager.Detect(text.to_utf8_buffer()) == "fwsave", "an export is recognised as ours")
	var imp: Dictionary = SaveManager.Import(text.to_utf8_buffer(), "game 1.fwsave")
	_check(imp["ok"] and imp["name"] == "game 1 (2)", "importing a taken name adds \" (2)\" and overwrites nothing (%s)" % str(imp))
	_check(SaveManager.Games()[0]["id"] == imp["id"], "the imported game is the newest")
	var back: Array = SaveManager.Read(imp["id"])
	_check(JSON.stringify(back[0]) == JSON.stringify(read[0]) and (back[2] as Dictionary).size() == (read[2] as Dictionary).size(), "the imported save is the exported one")
	_check(SaveManager.Games().filter(func(x: Dictionary) -> bool: return x["name"] == "game 1").size() == 1, "the original \"game 1\" is still there")

	# A bare command log is ours too.
	var log: String = FileAccess.get_file_as_string(SaveManager.GamePath(first))
	_check(SaveManager.Detect(log.to_utf8_buffer()) == "log", "a bare command log is recognised as ours")
	var imp2: Dictionary = SaveManager.Import(log.to_utf8_buffer(), "last-session.jsonl")
	_check(imp2["ok"] and imp2["name"] == "last-session", "a bare log imports, named after its file")

	# The original's file: name, six u32, then a u32 holding its own offset.
	var orig := PackedByteArray([1, 0, 0x31])
	for v in [1, 0, 1, 1, 1, 0, 27]:
		var w := PackedByteArray([0, 0, 0, 0])
		w.encode_u32(0, v)
		orig.append_array(w)
	_check(SaveManager.Detect(orig) == "original", "an original SAVEGAME.nnn is recognised")
	_check(not SaveManager.Import(orig)["ok"], "and not imported yet (phase 4)")
	_check(SaveManager.Detect("hello".to_utf8_buffer()) == "", "anything else is not a saved game")

	# Delete.
	var before: int = SaveManager.Games().size()
	_check(SaveManager.Delete(b) and SaveManager.Games().size() == before - 1 and not FileAccess.file_exists(SaveManager.GamePath(b)), "Delete removes the game and its file")
	_check(not SaveManager.Delete(b), "deleting it again does nothing")

	_remove(SaveManager.Dir)
	_migration()
	_finish()


## The six old slots are copied in once, oldest first; a repeated name gets
## " (2)"; the old files are not changed.
func _migration() -> void:
	SaveManager.Dir = "user://test-saves-migrate"
	_remove(SaveManager.Dir)
	DirAccess.make_dir_recursive_absolute(SaveManager.Dir)
	var log: String = CommandLog.Snapshot()
	var old := {
		"0": {"name": "Saved game", "day": 12, "saved_at": "2026-09-20T10:00:00", "side": "empire"},
		"3": {"name": "Saved game", "day": 40, "saved_at": "2026-09-25T10:00:00", "side": "alliance"},
		"5": {"name": "actual game", "day": 90, "saved_at": "2026-09-22T10:00:00", "side": "empire"},
	}
	for k: String in old:
		var f := FileAccess.open("%s/slot%s.jsonl" % [SaveManager.Dir, k], FileAccess.WRITE)
		f.store_string(log)
		f.close()
	var idx := FileAccess.open("%s/slots.json" % SaveManager.Dir, FileAccess.WRITE)
	idx.store_string(JSON.stringify(old))
	idx.close()
	var slot0_before: String = FileAccess.get_file_as_string("%s/slot0.jsonl" % SaveManager.Dir)

	var games: Array = SaveManager.Games()
	var names: Array = games.map(func(g: Dictionary) -> String: return g["name"])
	_check(names == ["Saved game (2)", "actual game", "Saved game"], "the old slots come in newest first, a repeated name gets \" (2)\" (%s)" % str(names))
	_check(games[1]["day"] == 90 and games[1]["side"] == "empire" and games[1]["saved_at"] == "2026-09-22T10:00:00", "their day, side and saved date come too")
	_check(FileAccess.get_file_as_string("%s/slot0.jsonl" % SaveManager.Dir) == slot0_before and FileAccess.file_exists("%s/slots.json" % SaveManager.Dir), "the old slot files are left as they were")
	_check(SaveManager.Games().size() == 3, "the copy happens once")
	_remove(SaveManager.Dir)


func _finish() -> void:
	CommandLog.Close()
	DirAccess.remove_absolute("user://test-save-session.jsonl")
	print("[save_slots] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
