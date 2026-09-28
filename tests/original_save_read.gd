extends SceneTree
## The Star Wars: Rebellion save reader (src/data/original_save.gd) on the
## player's own saved games, when the original is installed (the saves are not
## in the repo): every marker checked, read to the end of the game, the day,
## the three copies of the galaxy. Prints what tools/savegame/rebsave.py prints
## for the same file, to compare. Skips (exit 0) without the installed saves.
##
##   .\tools\run-gd.ps1 tests/original_save_read.gd
##   .\tools\run-gd.ps1 tests/original_save_read.gd -- --dir=C:/path/to/SaveGame

const OriginalSave := preload("res://src/data/original_save.gd")
const DEFAULT_DIR := "C:/Program Files (x86)/GOG Galaxy/Games/Star Wars - Rebellion/SaveGame"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_save_read] ok   %s" % what)
	else:
		_fails += 1
		print("[original_save_read] FAIL %s" % what)


func _init() -> void:
	var dir := DEFAULT_DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	var files: Array = []
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.to_upper().begins_with("SAVEGAME."):
				files.append("%s/%s" % [dir, f])
	if files.is_empty():
		print("[original_save_read] no saved games of the original at %s - skipped" % dir)
		quit(0)
		return
	# Not a saved game: refused with a reason, not read as nonsense.
	var junk: Dictionary = OriginalSave.Read("not a save".to_utf8_buffer())
	_check(not junk["ok"] and not str(junk["error"]).is_empty(), "a file that is not a saved game is refused (%s)" % junk["error"])
	for path: String in files:
		var bytes := FileAccess.get_file_as_bytes(path)
		var t0 := Time.get_ticks_msec()
		var g: Dictionary = OriginalSave.Read(bytes, true)
		var ms := Time.get_ticks_msec() - t0
		var f: String = path.get_file()
		_check(g["ok"], "%s reads (%s)" % [f, g["error"]])
		if not g["ok"]:
			continue
		var counts: Array = []
		for v: Dictionary in g["views"]:
			counts.append(OriginalSave.Walk(v).size())
		print("[original_save_read] %s: \"%s\" side %d day %d, read to 0x%x of 0x%x, markers %d, objects %s, %d ms" % [
			f, g["name"], g["header"]["side"], g["game"]["day"], g["read_to"], bytes.size(), g["markers"], str(counts), ms])
		_check(g["views"].size() == 3, "%s: three copies of the galaxy" % f)
		var master: Dictionary = g["views"][0]
		_check((int(master["control_kind"]) & 0x30) == 0 and master.has("state"), "%s: the first is the master copy" % f)
		var systems := 0
		for e: Dictionary in OriginalSave.Walk(master):
			if int(e["o"]["class"]) in [0x90, 0x92]:
				systems += 1
		_check(systems > 0, "%s: %d systems in the master copy" % [f, systems])
		# The players after the game: the human's block, proven by the file's closing words.
		var human: Dictionary = g.get("human", {})
		_check(not human.is_empty(), "%s: the human player's block reads to the file's end (%s)" % [f, g.get("tail_error", "")])
		for w: Dictionary in human.get("windows", []):
			print("[original_save_read]   message 0x%x \"%s\": %s" % [int(w["type"]), str(w.get("title", "")), str(w.get("text", "")).replace("
", " / ")])
	print("[original_save_read] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
