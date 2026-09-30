extends SceneTree
## THE WWII PACK'S FACILITY PICTURES (tools/look/make_ww2_facilities.py). Run
## with the WWII pack:
##
##   .\tools\run-gd.ps1 tests/ww2_facility_pictures.gd -- --pack=ww2
##
## Every facility has all three of its pictures, from the pack's own art/
## (never an art set or a stand-in), in the original's sizes: the Encyclopedia
## picture 400x200, the portrait 122x50, the list miniature 61x25. No picture
## in those folders is for a facility the pack does not have.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")
const PACK_ART := "res://packs/ww2/art"
const SIZES := {"facilities": Vector2i(400, 200), "portraits/facilities": Vector2i(122, 50), "miniatures/facilities": Vector2i(61, 25)}

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("[ww2_facility_pictures] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-ww2-facility-pictures-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.LoadedId() != "ww2":
		print("[ww2_facility_pictures] FAIL run with --pack=ww2 (loaded: %s)" % FactionRegistry.LoadedId())
		quit(1)
		return

	var ids: Array[String] = []
	for f in FactionRegistry.Pack.Facilities:
		ids.append(f.Id)
	_check(ids.size() == 15, "the pack has 15 facilities (%d)" % ids.size())

	for id in ids:
		for pair in [["facilities", Art.Picture("facilities", id)], ["portraits/facilities", Art.Portrait("facilities", id)],
				["miniatures/facilities", Art.Miniature("facilities", id)]]:
			var tex: Texture2D = pair[1]
			var want := "%s/%s/%s.png" % [PACK_ART, pair[0], id]
			_check(tex != null, "%s: %s picture found" % [id, pair[0]])
			if tex == null:
				continue
			_check(tex.resource_path == want, "%s: %s is the pack's own (%s)" % [id, pair[0], tex.resource_path])
			_check(Vector2i(tex.get_size()) == SIZES[pair[0]], "%s: %s is %s (%s)" % [id, pair[0], SIZES[pair[0]], Vector2i(tex.get_size())])

	for folder in SIZES:
		for f in DirAccess.get_files_at("%s/%s" % [PACK_ART, folder]):
			if f.get_extension() == "png":
				_check(ids.has(f.get_basename()), "%s/%s names a facility of the pack" % [folder, f])

	print("[ww2_facility_pictures] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
