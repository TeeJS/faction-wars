extends SceneTree
## THE WWII PACK'S SYSTEM PICTURES: THE FLAGS (tools/look/make_ww2_flags.py,
## packs/ww2/art/FLAGS.md). Run with the WWII pack:
##
##   .\tools\run-gd.ps1 tests/ww2_flags.gd -- --pack=ww2
##
## Every system has its picture, from the pack's own art/ (never an art set),
## 37x37 as the original's; no picture there is for a system the pack does not
## have. Every system has a record in tools/look/ww2_flags.json naming a flag
## that is there, with a Commons page, SHA-1 and licence, and the reason. A
## country flies its own flag, never its conqueror's (TeeJ, 2026-09-30:
## Korea is not Japan, Burma not Britain). Germany's is the
## black-white-red tricolour - black over white over red, read off the picture
## itself - never the swastika flag (TeeJ, 2026-09-29).

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const SOURCES := "res://tools/look/ww2_flags.json"
const SPRITES := "res://packs/ww2/art/location_sprites"
const LICENCES := ["Public domain", "CC BY-SA 3.0", "CC BY-SA 4.0"]
## Flags that identify a country's conqueror, never the country (TeeJ,
## 2026-09-30): these systems must not fly them.
const NOT_THE_CONQUEROR := {"korea": "japan", "burma": "uk", "india": "uk", "indochina": "france",
	"dutch_east_indies": "netherlands", "ceylon": "uk", "baltic_states": "ussr", "east_africa": "italy",
	"libya": "italy", "algeria": "france", "malaya": "uk", "austria": "germany", "czechoslovakia": "germany", "poland": "germany"}

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("[ww2_flags] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-ww2-flags-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.LoadedId() != "ww2":
		print("[ww2_flags] FAIL run with --pack=ww2 (loaded: %s)" % FactionRegistry.LoadedId())
		quit(1)
		return

	var planets: Array = FactionRegistry.Pack.Map.Planets
	_check(planets.size() == 88, "the pack has 88 systems (%d)" % planets.size())
	var numbers := {}
	for p in planets:
		var tex: Texture2D = Art.LocationSprite(p.ArtworkId)
		numbers[p.ArtworkId] = p.Id
		_check(tex != null, "%s: its picture (%d) is found" % [p.Id, p.ArtworkId])
		if tex == null:
			continue
		_check(tex.resource_path == "%s/%d.png" % [SPRITES, p.ArtworkId], "%s: the pack's own (%s)" % [p.Id, tex.resource_path])
		_check(Vector2i(tex.get_size()) == Vector2i(37, 37), "%s: 37x37 (%s)" % [p.Id, Vector2i(tex.get_size())])
	_check(numbers.size() == planets.size(), "every system has its own artwork id")
	for f in DirAccess.get_files_at(SPRITES):
		if f.get_extension() == "png":
			_check(numbers.has(int(f.get_basename())), "location_sprites/%s is a system's" % f)

	var doc: Variant = JsonUtil.parse(SOURCES)
	_check(doc is Dictionary and doc.get("flags") is Dictionary and doc.get("systems") is Dictionary, "%s reads" % SOURCES)
	var flags: Dictionary = doc.get("flags", {}) if doc is Dictionary else {}
	var systems: Dictionary = doc.get("systems", {}) if doc is Dictionary else {}
	for p in planets:
		var s: Variant = systems.get(p.Id)
		_check(s is Dictionary and flags.has(str(s.get("flag", ""))) and not str(s.get("why", "")).is_empty(), "%s: flies a recorded flag, with the reason" % p.Id)
	for id in NOT_THE_CONQUEROR:
		var s: Variant = systems.get(id)
		_check(s is Dictionary and str(s.get("flag", "")) != NOT_THE_CONQUEROR[id], "%s: its own flag, not %s's" % [id, NOT_THE_CONQUEROR[id]])
	for key in flags:
		var f: Dictionary = flags[key]
		if f.has("parts"):
			# Several flags side by side (the Baltic States): each part is a flag here.
			var parts: Array = f["parts"]
			_check(parts.size() > 1 and parts.all(func(p) -> bool: return flags.has(p) and not flags[p].has("parts")), "%s: its parts are flags" % key)
			continue
		_check(str(f.get("page", "")).begins_with("https://commons.wikimedia.org/wiki/File:"), "%s: its Commons page" % key)
		_check(str(f.get("sha1", "")).length() == 40 and str(f.get("rendition_sha256", "")).length() == 64, "%s: its hashes" % key)
		_check(LICENCES.has(str(f.get("licence", ""))), "%s: an accepted licence (%s)" % [key, f.get("licence", "")])

	# Germany: black over white over red, read off its picture's middle column.
	var germany: Variant = null
	for p in planets:
		if p.Id == "germany":
			germany = p
	var tex: Texture2D = Art.LocationSprite(germany.ArtworkId) if germany != null else null
	if tex != null:
		var img: Image = tex.get_image()
		var top := img.get_pixel(18, 11)
		var mid := img.get_pixel(18, 18)
		var low := img.get_pixel(18, 25)
		_check(top.v < 0.3, "Germany's top band is black (%s)" % top)
		_check(mid.v > 0.8 and mid.s < 0.2, "Germany's middle band is white (%s)" % mid)
		_check(low.r > 0.6 and low.g < 0.35 and low.b < 0.35, "Germany's bottom band is red (%s)" % low)

	print("[ww2_flags] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
