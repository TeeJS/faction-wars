extends SceneTree
## Checks a pack folder anywhere on disk with the game's own loader and
## validator (PackLoader.Load, SCHEMA.md section 11) - for a pack author, and
## for the pack editor's CI, which proves its port of the validator agrees
## (the editor handoff, 2026-09-23):
##
##   .\tools\run-gd.ps1 tests/validate_pack.gd -- --dir=D:\path\to\my-pack
##
## The folder's name must be the pack's id (rule 1). Prints each error on its
## own line as "[validate_pack] <error>". Exits 0 when the pack loads, 1 when it
## does not, 2 when no folder was given.


func _init() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	# A Windows path, or one ending in a separator, still names the folder.
	dir = dir.replace("\\", "/").trim_suffix("/")
	if dir.is_empty():
		print("[validate_pack] give the pack folder: -- --dir=<folder named after the pack's id>")
		quit(2)
		return
	var errors: Array[String] = []
	var pack := PackLoader.Load(dir, errors)
	for e in errors:
		print("[validate_pack] %s" % e)
	if pack != null and errors.is_empty():
		print("[validate_pack] PASS: %s loads (%s)" % [pack.Manifest.Id, dir])
		quit(0)
	else:
		print("[validate_pack] FAIL: %d error(s) in %s" % [errors.size(), dir])
		quit(1)
