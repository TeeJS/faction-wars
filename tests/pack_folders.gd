extends SceneTree
## A PACK FOLDER HOLDS ONLY THE PACK (TeeJ, 2026-10-04): the 1 GB of masters
## and backups the WWII redraws left in packs/ww2/art moved to art-archive/,
## because the pack editor reads every file of a pack folder and carries them
## all into a mod's zip. This fails if one comes back: a folder with a
## .gdignore inside a pack (the archives' mark - Godot skips it, so nothing
## else notices), or a pack over 100 MB. Every pack under res://packs. Reads
## the folders only; packs/ww2/PACK.md and art-archive/README.md say where
## archives go.
##
##   .\tools\run-gd.ps1 tests/pack_folders.gd

const PACKS := "res://packs"
const LIMIT_MB := 100

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[pack_folders] ok   %s" % what)
	else:
		_fails += 1
		print("[pack_folders] FAIL %s" % what)


func _init() -> void:
	var packs := DirAccess.get_directories_at(PACKS)
	_check(packs.size() >= 2, "found the packs (%s)" % ", ".join(packs))
	for id in packs:
		var ignored: Array = []
		var bytes := _walk("%s/%s" % [PACKS, id], ignored)
		_check(ignored.is_empty(), "%s holds no .gdignore'd folder (an archive belongs in art-archive/)%s"
			% [id, "" if ignored.is_empty() else ": " + ", ".join(ignored)])
		var mb := bytes / 1048576.0
		_check(mb <= LIMIT_MB, "%s is %.1f MB, within %d MB" % [id, mb, LIMIT_MB])
	print("[pack_folders] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Bytes under `path`; every folder in it holding a .gdignore goes on `ignored`.
func _walk(path: String, ignored: Array) -> int:
	var d := DirAccess.open(path)
	if d == null:
		return 0
	d.include_hidden = true
	var total := 0
	d.list_dir_begin()
	var name := d.get_next()
	while not name.is_empty():
		var full := "%s/%s" % [path, name]
		if d.current_is_dir():
			if name != "." and name != "..":
				total += _walk(full, ignored)
		elif name == ".gdignore":
			ignored.append(path.trim_prefix(PACKS + "/"))
		else:
			var f := FileAccess.open(full, FileAccess.READ)
			if f != null:
				total += f.get_length()
		name = d.get_next()
	d.list_dir_end()
	return total
