extends SceneTree
## Every pack under res://packs/ loads and validates, and its JSON is LF on
## disk (the pack hash is of the bytes) - the modularity proof
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
	_version_and_link()
	print("[pack_loads] %d ran, %d ok, %d failed" % [_ran, _ok, _failed])
	quit(0 if _failed == 0 and _ran == _ok else 1)


func _check(cond: bool, what: String) -> void:
	_ran += 1
	if cond:
		_ok += 1
		print("[pack_loads] ok   %s" % what)
	else:
		_failed += 1
		print("[pack_loads] FAIL %s" % what)


## pack.json `version` and `download_url` (SCHEMA.md section 2, strangers
## plan): plain optional text, never a load error; only a sound http(s) link
## is offered.
func _version_and_link() -> void:
	var m := PackDefs.PackManifest.from_dict({ "id": "x", "version": " 1.3 ", "download_url": " https://example.com/packs/x " })
	_check(m.Version == "1.3" and m.VersionLabel() == "v1.3" and m.OfferedUrl() == "https://example.com/packs/x", "version '1.3' shows as v1.3; an https link is offered, trimmed")
	var none := PackDefs.PackManifest.from_dict({ "id": "x" })
	_check(none.Version.is_empty() and none.VersionLabel().is_empty() and none.OfferedUrl().is_empty(), "no version, no link: nothing shown, nothing offered")
	var odd := PackDefs.PackManifest.from_dict({ "id": "x", "version": 2, "download_url": 7 })
	_check(odd.Version == "2" and odd.OfferedUrl().is_empty(), "a number for a version is taken as its text; a link that is not text is not offered")
	for bad in ["javascript:alert(1)", " JaVaScRiPt:alert(1)", "data:text/html,<b>x</b>", "ftp://example.com/x", "https://exa mple.com",
			"https://example.com/\nx", "https://example.com/" + "a".repeat(300), "//example.com/x", "http:/example.com"]:
		_check(PackDefs.PackManifest.SafeUrl(bad).is_empty(), "not offered: %s" % bad.c_escape().substr(0, 40))
	_check(PackDefs.PackManifest.SafeUrl("HTTP://Example.com/X") == "HTTP://Example.com/X", "the scheme is checked in any case; the link is kept as written")


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
	# The hash multiplayer compares is of the files' bytes: they must be the
	# same on every machine, so LF (.gitattributes), never CRLF.
	for f in FactionRegistry.PACK_FILES:
		if FileAccess.get_file_as_bytes("%s/%s" % [pack_dir, f]).has(13):
			_failed += 1
			print("[pack_loads] FAIL %s/%s has CRLF line endings; its hash would differ from an LF checkout's." % [pack_dir, f])
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
