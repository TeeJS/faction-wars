extends SceneTree
## EVERY PICTURE AND FONT WE SHIP HAS A RECORDED ORIGIN (SCHEMA.md section 16;
## docs/ww2-look-plan.md). Walks the project for images and fonts that an
## export would carry and fails on any that no credits.json names - a pack's
## own (paths relative to the pack) or assets/credits.json (relative to
## assets/). Also fails on a credits entry naming a file that is not there,
## and on an entry missing its title, author or licence.
##
##   .\tools\run-gd.ps1 tests/asset_credits.gd
##
## Not shipped, so not walked: tests/, tools/, docs/, the gitignored art/ and
## build/ folders, a pack's original/ (the player's own art, never shipped),
## and any folder holding a .gdignore - Godot neither imports nor exports it
## (assets/brand/source/, the brand's originals kept by #428).

const MEDIA := ["png", "jpg", "jpeg", "webp", "svg", "bmp", "gif", "tga", "ttf", "otf", "woff", "woff2", "ogg", "ogv", "wav", "mp3"]
const SKIP := ["res://.godot", "res://tests", "res://tools", "res://docs", "res://art", "res://build", "res://relay", "res://.github", "res://.claude"]

var _failed := 0
var _ok := 0


func _init() -> void:
	var credited := {}   # res:// path -> where it is credited
	_read_credits("res://assets/credits.json", "res://assets", credited)
	for id in DirAccess.get_directories_at("res://packs"):
		_read_credits("res://packs/%s/credits.json" % id, "res://packs/%s" % id, credited)

	var shipped: Array[String] = []
	_walk("res://", shipped)
	for path in shipped:
		if credited.has(path):
			_ok += 1
		else:
			_failed += 1
			print("[asset_credits] FAIL %s is shipped but no credits.json names it" % path)
	for path in credited:
		if not (FileAccess.file_exists(path) or ResourceLoader.exists(path)):
			_failed += 1
			print("[asset_credits] FAIL %s credits '%s', which is not there" % [credited[path], path])
	print("[asset_credits] %d shipped files credited, %d failed" % [_ok, _failed])
	quit(1 if _failed > 0 else 0)


func _read_credits(file: String, base: String, credited: Dictionary) -> void:
	if not FileAccess.file_exists(file):
		return
	var d: Variant = JsonUtil.parse(file)
	if not d is Dictionary or not d.get("assets") is Array:
		_failed += 1
		print("[asset_credits] FAIL %s: not an object with an `assets` list" % file)
		return
	for i in (d["assets"] as Array).size():
		var a: Variant = d["assets"][i]
		if not a is Dictionary:
			_failed += 1
			print("[asset_credits] FAIL %s assets[%d]: not an object" % [file, i])
			continue
		for key in ["title", "author", "licence"]:
			if str(a.get(key, "")).strip_edges().is_empty():
				_failed += 1
				print("[asset_credits] FAIL %s assets[%d]: no %s" % [file, i, key])
		for f in a.get("files", []):
			credited["%s/%s" % [base, str(f)]] = file


func _walk(dir: String, out: Array[String]) -> void:
	var clean := dir.trim_suffix("/")
	for s in SKIP:
		if clean == s:
			return
	if clean.begins_with("res://packs/") and clean.get_file() == "original":
		return
	if clean != "res:/" and FileAccess.file_exists("%s/.gdignore" % clean):
		return
	for f in DirAccess.get_files_at(dir):
		if MEDIA.has(f.get_extension().to_lower()):
			out.append("%s/%s" % [clean, f] if clean != "res:/" else "res://%s" % f)
	for sub in DirAccess.get_directories_at(dir):
		_walk("%s/%s" % [clean, sub] if clean != "res:/" else "res://%s" % sub, out)
