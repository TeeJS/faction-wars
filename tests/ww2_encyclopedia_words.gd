extends SceneTree
## EVERY WWII ENCYCLOPEDIA ENTRY HAS ITS WORDS (TeeJ, 2026-09-30: "most
## encyclopedia entries are blank, and none have any text at all (that's what
## an encyclopedia is, right, words?"). The pack's own art/descriptions.json
## (Art.Description) carries a text for every territory, unit, facility,
## mission and person the Encyclopedia lists, none of them in the Star Wars
## words tests/ww2_words.gd keeps out; every territory has its plate
## (art/locations/<id>.png, tools/look/make_ww2_flags.py). Headless:
##
##   .\tools\run-gd.ps1 tests/ww2_encyclopedia_words.gd -- --pack=ww2

const Art := preload("res://src/ui/artwork.gd")
const Guard := preload("res://tests/ww2_words.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ww2_encyclopedia_words] ok   %s" % what)
	else:
		_fails += 1
		print("[ww2_encyclopedia_words] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # the pack's own art only, never an imported set
	Art.UserArtRoot = "user://test-ww2-encyclopedia-words-none"
	FactionRegistry.EnsureLoaded()
	var pack: PackLoader.LoadedPack = FactionRegistry.Pack
	if pack.Manifest.Id != "ww2":
		print("[ww2_encyclopedia_words] (run with --pack=ww2)")
		print("[ww2_encyclopedia_words] 0 checks, 0 failed")
		quit(0)
		return

	var rows: Array = []   # [kind, id, name]
	for p in pack.Map.Planets:
		rows.append([EncyclopediaWindow.KindSystem, p.Id, p.DisplayName])
	for u in pack.Units:
		rows.append([EncyclopediaWindow.KindUnit, u.Id, u.DisplayName])
	for f in pack.Facilities:
		rows.append([EncyclopediaWindow.KindFacility, f.Id, f.DisplayName])
	for m in pack.Missions:
		if not m.Id.begins_with("unnamed"):
			rows.append([EncyclopediaWindow.KindMission, m.Id, m.DisplayName])
	for c in pack.Characters:
		rows.append([EncyclopediaWindow.KindCharacter, c.Id, c.DisplayName])

	var rx := RegEx.new()
	var alts: PackedStringArray = []
	for w: String in Guard.Words:
		alts.append(w.replace("-", "\\-"))
	rx.compile("(?i)(?<![\\w-])(%s)(?![\\w-])" % "|".join(alts))

	var blank: Array = []
	var leaks: Array = []
	var short: Array = []
	for r: Array in rows:
		var text: String = Art.Description(r[0], r[1]).strip_edges()
		if text.is_empty():
			blank.append("%s/%s" % [r[0], r[1]])
			continue
		if text.split(" ", false).size() < 40:
			short.append("%s/%s" % [r[0], r[1]])
		var t: String = text
		for a: String in Guard.Allowed:
			t = t.replace(a, "")
		var m: RegExMatch = rx.search(t)
		if m != null or t.contains("the Force"):
			leaks.append("%s/%s: \"%s\"" % [r[0], r[1], m.get_string() if m != null else "the Force"])
	_check(rows.size() > 200, "the Encyclopedia's entries (%d)" % rows.size())
	_check(blank.is_empty(), "every entry has its words (%d without: %s)" % [blank.size(), str(blank.slice(0, 12))])
	_check(short.is_empty(), "each is a paragraph, 40 words or more (%s)" % str(short.slice(0, 12)))
	_check(leaks.is_empty(), "none in the Star Wars words (%s)" % str(leaks.slice(0, 12)))

	var plateless: Array = []
	for p in pack.Map.Planets:
		var pic: Texture2D = Art.Picture(EncyclopediaWindow.KindSystem, p.Id)
		if pic == null or pic.get_size() != Vector2(400, 200):
			plateless.append(p.Id)
	_check(plateless.is_empty(), "every territory has its 400x200 plate (%s)" % str(plateless.slice(0, 12)))

	print("[ww2_encyclopedia_words] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
