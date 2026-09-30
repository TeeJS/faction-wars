extends SceneTree
## A TEST NEVER WRITES THE PLAYER'S NAMES AND OPTIONS (MpSetup.NamesPath). Under
## a script's own SceneTree - every test and capture - they go to
## MpSetup.TestNamesFile; the player's user://mp.cfg is left exactly as it was.
## (TeeJ, 2026-09-29: the Host Game screen offered "Luke" and "The End of the
## Empire", which mp_flow and mp_screens had saved there.)
##
##   .\tools\run-gd.ps1 tests/mp_names_file.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[mp_names_file] %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		_fails += 1


func _init() -> void:
	var before: String = FileAccess.get_file_as_string(MpSetup.NamesFile) if FileAccess.file_exists(MpSetup.NamesFile) else "<none>"
	_check(MpSetup.NamesPath() == MpSetup.TestNamesFile, "a script-run keeps its own file (%s)" % MpSetup.NamesPath())
	MpSetup.player_name = "Test Player"
	MpSetup.game_name = "Test Game"
	MpSetup.remember_names()
	var after: String = FileAccess.get_file_as_string(MpSetup.NamesFile) if FileAccess.file_exists(MpSetup.NamesFile) else "<none>"
	_check(after == before, "the player's own file is untouched")
	var ours := ConfigFile.new()
	_check(ours.load(MpSetup.TestNamesFile) == OK and ours.get_value("names", "player", "") == "Test Player",
		"the names went to the test file")
	MpSetup.player_name = ""
	MpSetup.game_name = ""
	MpSetup.load_names()
	_check(MpSetup.player_name == "Test Player", "and are read back from it")
	DirAccess.remove_absolute(MpSetup.TestNamesFile)
	print("[mp_names_file] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
