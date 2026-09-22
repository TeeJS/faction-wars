extends SceneTree
## Every pack under res://packs/ loads and validates - the modularity proof
## (BACKLOG #24). A second pack on the same binary is what SCHEMA.md section 1
## ("names are never behaviour") exists for; this is the test that says whether
## the engine can still read a pack it was not written against.
##
##   .\tools\run-gd.ps1 tests/pack_loads.gd

const PACKS_DIR := "res://packs"

var _failed := 0
var _ran := 0
var _ok := 0


func _init() -> void:
	var dir := DirAccess.open(PACKS_DIR)
	if dir == null:
		print("[pack_loads] FAIL: cannot open %s" % PACKS_DIR)
		quit(1)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var ids: Array[String] = []
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			ids.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	for id in ids:
		_load_one("%s/%s" % [PACKS_DIR, id])
	print("[pack_loads] %d ran, %d ok, %d failed" % [_ran, _ok, _failed])
	quit(0 if _failed == 0 and _ran == _ok else 1)


func _load_one(pack_dir: String) -> void:
	_ran += 1
	var errors: Array[String] = []
	var pack := PackLoader.Load(pack_dir, errors)
	if pack == null or not errors.is_empty():
		_failed += 1
		print("[pack_loads] FAIL %s:" % pack_dir)
		for e in errors:
			print("    %s" % e)
		return
	_ok += 1
	print("[pack_loads] ok   %s (%d sectors, %d planets, %d characters, %d facilities, %d units, %d weapons, %d missions, %d tables, %d rules, %d GID modes)"
		% [pack_dir, pack.Map.Sectors.size(), pack.Map.Planets.size(), pack.Characters.size(),
		   pack.Facilities.size(), pack.Units.size(), pack.Weapons.size(), pack.Missions.size(),
		   pack.MissionTables.size(), pack.Rules.size(), _mode_count(pack)])


func _mode_count(pack: PackLoader.LoadedPack) -> int:
	var n := 0
	for c in pack.Display.Categories:
		n += c.Modes.size()
	return n
