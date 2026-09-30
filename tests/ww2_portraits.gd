extends SceneTree
## THE WWII PACK'S PERSONNEL PICTURES (tools/look/make_ww2_portraits.py,
## packs/ww2/art/PORTRAITS.md). Run with the WWII pack:
##
##   .\tools\run-gd.ps1 tests/ww2_portraits.gd -- --pack=ww2
##
## Every character has all three of its pictures, from the pack's own art/
## (never an art set or a stand-in), in the original's sizes: the Encyclopedia
## picture 400x200, the portrait 80x80, the list miniature 61x25. No picture
## in those folders is for a character the pack does not have. Every character
## has a record in tools/look/ww2_portraits.json: a Commons file with its
## page, address, SHA-1 and an accepted licence, or the reason it has the
## drawn stand-in.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const SOURCES := "res://tools/look/ww2_portraits.json"
const PACK_ART := "res://packs/ww2/art"
const SIZES := {"characters": Vector2i(400, 200), "portraits/characters": Vector2i(80, 80), "miniatures/characters": Vector2i(61, 25)}
## The licences the plan takes (Wikimedia Commons' own short names).
const LICENCES := ["Public domain", "No restrictions", "CC0", "CC BY 2.0", "CC BY 4.0", "CC BY-SA 3.0 de", "CC BY-SA 4.0"]

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("[ww2_portraits] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-ww2-portraits-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.LoadedId() != "ww2":
		print("[ww2_portraits] FAIL run with --pack=ww2 (loaded: %s)" % FactionRegistry.LoadedId())
		quit(1)
		return

	var ids: Array[String] = []
	for c in FactionRegistry.Pack.Characters:
		ids.append(c.Id)
	_check(ids.size() == 71, "the pack has 71 characters (%d)" % ids.size())

	# Every character, all three pictures, the pack's own, the original's sizes.
	for id in ids:
		for pair in [["characters", Art.Picture("characters", id)], ["portraits/characters", Art.Portrait("characters", id)],
				["miniatures/characters", Art.Miniature("characters", id)]]:
			var tex: Texture2D = pair[1]
			var want := "%s/%s/%s.png" % [PACK_ART, pair[0], id]
			_check(tex != null, "%s: %s picture found" % [id, pair[0]])
			if tex == null:
				continue
			_check(tex.resource_path == want, "%s: %s is the pack's own (%s)" % [id, pair[0], tex.resource_path])
			_check(Vector2i(tex.get_size()) == SIZES[pair[0]], "%s: %s is %s (%s)" % [id, pair[0], SIZES[pair[0]], Vector2i(tex.get_size())])

	# No stray picture: every file names one of the pack's characters.
	for folder in SIZES:
		for f in DirAccess.get_files_at("%s/%s" % [PACK_ART, folder]):
			if f.get_extension() == "png":
				_check(ids.has(f.get_basename()), "%s/%s names a character of the pack" % [folder, f])

	# Every character's record: a Commons file with an accepted licence, or the stand-in's reason.
	var doc: Variant = JsonUtil.parse(SOURCES)
	_check(doc is Dictionary and doc.get("people") is Dictionary, "%s reads" % SOURCES)
	var people: Dictionary = doc.get("people", {}) if doc is Dictionary else {}
	var generic := 0
	for id in ids:
		var p: Variant = people.get(id)
		_check(p is Dictionary, "%s: has a record" % id)
		if not p is Dictionary:
			continue
		if p.has("generic"):
			generic += 1
			_check(not str(p["generic"]).is_empty(), "%s: the stand-in's reason is given" % id)
			continue
		_check(str(p.get("page", "")).begins_with("https://commons.wikimedia.org/wiki/File:"), "%s: its Commons page" % id)
		_check(str(p.get("url", "")).begins_with("https://upload.wikimedia.org/"), "%s: its original's address" % id)
		_check(str(p.get("sha1", "")).length() == 40, "%s: the original's SHA-1" % id)
		_check(LICENCES.has(str(p.get("licence", ""))), "%s: an accepted licence (%s)" % [id, p.get("licence", "")])
		_check(not str(p.get("author", "")).is_empty(), "%s: an author" % id)
		var crop: Variant = p.get("crop")
		_check(crop is Array and crop.size() == 3, "%s: a crop" % id)
	_check(people.size() == ids.size(), "a record for each character and no more (%d)" % people.size())
	print("[ww2_portraits] %d characters, %d with the stand-in" % [ids.size(), generic])

	print("[ww2_portraits] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
