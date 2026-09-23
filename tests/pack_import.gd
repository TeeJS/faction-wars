extends SceneTree
## Importing pack files (docs/original-art-plan.md, phase 3; src/ui/pack_import.gd).
##   - an art set imports into the art root and the pictures appear at once;
##   - the same file again replaces it; Remove takes it away;
##   - a damaged file, an unsafe path, a missing manifest are refused, and
##     leave the installed copy alone;
##   - a faction pack imports into user://packs/ and is listed;
##   - a faction pack carrying one of the art set's pictures, or an original/
##     folder, is refused;
##   - with --real=<art.zip>, the Faction Wars Exporter's own output imports.
## Writes under a test art root and a test pack id; removes both.
##
##   Godot_console.exe --headless --path . -s tests/pack_import.gd [-- --real=C:\path\swr-original.art.zip]

const Art := preload("res://src/ui/artwork.gd")
const PackImport := preload("res://src/ui/pack_import.gd")
const SET_ROOT := "user://test-import-art"
const PACK_ID := "import-test-pack"
const TMP := "user://test-import"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[pack_import] ok   %s" % what)
	else:
		_fails += 1
		print("[pack_import] FAIL %s" % what)


func _init() -> void:
	await process_frame
	var pack_dir := "%s/%s" % [FactionRegistry.USER_PACKS_ROOT, PACK_ID]
	for d in [SET_ROOT, pack_dir, TMP]:
		PackImport._remove(d)
	DirAccess.make_dir_recursive_absolute(TMP)
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = SET_ROOT
	FactionRegistry.EnsureLoaded("star-wars-rebellion")

	# ---- an art set ----
	var red := _png(Color(1, 0, 0))
	var art := {"portraits/characters/luke_skywalker.png": red, "tabs/manufacturing.empire.png": _png(Color(0, 0, 1))}
	_zip(TMP + "/art.zip", "art_set", "swr-original", art)
	_check(Art.Portrait("characters", "luke_skywalker") == null, "before: no art set, no portrait")
	var r := PackImport.ImportFile(TMP + "/art.zip")
	_check(r.ok and r.kind == "art_set" and r.id == "swr-original" and r.files == 2, "an art set imports (%s)" % r.message)
	_check(FileAccess.file_exists(SET_ROOT + "/swr-original/manifest.json"), "... into the art root, with its manifest")
	_check(Art.Portrait("characters", "luke_skywalker") != null, "... and its portrait shows at once")
	var listed := PackImport.Installed()
	_check(listed.size() == 1 and listed[0].kind == "art_set" and listed[0].files == 2, "it is listed as installed")

	# A bad file leaves the installed one alone.
	_zip(TMP + "/damaged.zip", "art_set", "swr-original", art, {"portraits/characters/luke_skywalker.png": "00"})
	r = PackImport.ImportFile(TMP + "/damaged.zip")
	_check(not r.ok and r.message.contains("does not match its checksum"), "a damaged file is refused (%s)" % r.message)
	_check(Art.Portrait("characters", "luke_skywalker") != null, "... and the installed art set is untouched")
	_zip(TMP + "/slip.zip", "art_set", "swr-original", {"../escape.png": red})
	r = PackImport.ImportFile(TMP + "/slip.zip")
	_check(not r.ok and r.message.contains("unsafe path"), "a path leaving the folder is refused")
	var bare := ZIPPacker.new()
	bare.open(TMP + "/bare.zip")
	bare.start_file("x.png")
	bare.write_file(red)
	bare.close_file()
	bare.close()
	r = PackImport.ImportFile(TMP + "/bare.zip")
	_check(not r.ok and r.message.contains("no manifest.json"), "a zip with no manifest is refused")
	r = PackImport.ImportBytes(PackedByteArray([1, 2, 3]))
	_check(not r.ok, "bytes that are not a zip are refused")
	r = PackImport.ImportBytes(FileAccess.get_file_as_bytes(TMP + "/art.zip"))
	_check(r.ok, "the browser's path - the file's bytes - imports too")

	# ---- a faction pack ----
	var pack_files := {}
	for f in FactionRegistry.PACK_FILES:
		pack_files[f] = FileAccess.get_file_as_bytes("res://packs/star-wars-rebellion/%s" % f)
	var manifest: Dictionary = JSON.parse_string((pack_files["pack.json"] as PackedByteArray).get_string_from_utf8())
	manifest["id"] = PACK_ID
	# Its pictures come from the art set, not from files it does not carry.
	manifest["map_image"] = "swr-original:screens/galaxy.png"
	manifest.erase("menu")
	pack_files["pack.json"] = JSON.stringify(manifest, "  ").to_utf8_buffer()
	var leaky := pack_files.duplicate()
	leaky["art/portraits/characters/my_hero.png"] = red
	_zip(TMP + "/leaky.zip", "faction_pack", PACK_ID, leaky)
	r = PackImport.ImportFile(TMP + "/leaky.zip")
	_check(not r.ok and r.message.contains("the same picture as one in your art set"), "a faction pack carrying an art-set picture is refused")
	var old := pack_files.duplicate()
	old["original/portraits/x.png"] = _png(Color(0, 1, 0))
	_zip(TMP + "/old.zip", "faction_pack", PACK_ID, old)
	r = PackImport.ImportFile(TMP + "/old.zip")
	_check(not r.ok and r.message.contains("original/portraits/x.png"), "a faction pack with an original/ folder is refused")
	_check(not DirAccess.dir_exists_absolute(pack_dir), "... and nothing of either was written")
	var shipped := pack_files.duplicate()
	_zip(TMP + "/shipped.zip", "faction_pack", "star-wars-rebellion", shipped)
	r = PackImport.ImportFile(TMP + "/shipped.zip")
	_check(not r.ok and r.message.contains("comes with the game"), "a faction pack with a shipped pack's id is refused")
	var own := pack_files.duplicate()
	own["art/portraits/characters/my_hero.png"] = _png(Color(1, 0, 1))
	_zip(TMP + "/pack.zip", "faction_pack", PACK_ID, own)
	r = PackImport.ImportFile(TMP + "/pack.zip")
	_check(r.ok and r.kind == "faction_pack", "a faction pack with its own pictures imports (%s)" % r.message)
	_check(FactionRegistry.ListPackIds().has(PACK_ID) and FactionRegistry.PackDir(PACK_ID) == pack_dir,
		"... into user://packs, and the picker lists it")
	var errors: Array[String] = []
	_check(PackLoader.Load(pack_dir, errors) != null, "... and it validates (%s)" % ", ".join(errors))

	# ---- removing ----
	PackImport.Remove("faction_pack", PACK_ID)
	_check(not FactionRegistry.ListPackIds().has(PACK_ID), "Remove takes the faction pack away")
	PackImport.Remove("art_set", "swr-original")
	_check(Art.Portrait("characters", "luke_skywalker") == null and PackImport.Installed().is_empty(),
		"Remove takes the art set away; the pictures go at once")

	# ---- the exporter's own file ----
	var real := _arg("--real=")
	if not real.is_empty():
		r = PackImport.ImportFile(real)
		_check(r.ok and r.files > 1000, "the Faction Wars Exporter's file imports: %s" % r.message)
		_check(Art.Portrait("characters", "luke_skywalker") != null and Art.WindowPicture("status_plate.empire") != null
			and Art.PackImage("swr-original:screens/galaxy.png") != null, "... portraits, window plates and the galaxy map show")
		PackImport.Remove("art_set", "swr-original")

	for d in [SET_ROOT, pack_dir, TMP]:
		PackImport._remove(d)
	print("[pack_import] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A pack file as the exporter writes it: the files, and manifest.json listing
## each one's SHA-256 (`bad_hashes` overrides some, to damage it).
func _zip(path: String, kind: String, id: String, files: Dictionary, bad_hashes: Dictionary = {}) -> void:
	var hashes := {}
	for rel in files:
		hashes[rel] = bad_hashes.get(rel, PackImport._sha256(files[rel]))
	var zp := ZIPPacker.new()
	zp.open(path)
	for rel in files:
		zp.start_file(rel)
		zp.write_file(files[rel])
		zp.close_file()
	zp.start_file("manifest.json")
	zp.write_file(JSON.stringify({"format": 1, "kind": kind, "id": id, "title": id, "files": hashes}).to_utf8_buffer())
	zp.close_file()
	zp.close()


static func _png(colour: Color) -> PackedByteArray:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(colour)
	return img.save_png_to_buffer()


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""
