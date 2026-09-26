extends SceneTree
## Importing pack files (docs/original-art-plan.md, phase 3; src/ui/pack_import.gd).
##   - an art set imports into the art root and the pictures appear at once;
##   - the same file again replaces it; Remove takes it away;
##   - a damaged file, an unsafe path, a missing manifest are refused, and
##     leave the installed copy alone;
##   - a faction pack imports into user://packs/ and is listed;
##   - a faction pack carrying one of the art set's pictures, or an original/
##     folder (in any case), is refused;
##   - a faction pack whose pack.json names another id, or that the loader
##     would refuse, is refused with the reasons, and nothing is written;
##   - a player's FIRST faction pack imports, when user://packs does not exist
##     yet (a scratch packs root stands in for it);
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

	# The exporter's version: an art set older than the game needs imports, and
	# says so; one new enough says nothing.
	_check(PackImport.IsOlder("2.0.0", "2.1.0") and PackImport.IsOlder("2.0.9", "2.1") and not PackImport.IsOlder("2.1.0", "2.1.0")
		and not PackImport.IsOlder("2.10.0", "2.9.9") and PackImport.IsOlder("", "2.1.0"), "versions compare part by part")
	_zip(TMP + "/old-art.zip", "art_set", "swr-original", art, {}, "2.0.0")
	r = PackImport.ImportFile(TMP + "/old-art.zip")
	_check(r.ok and r.message.contains("made by exporter 2.0.0") and r.message.contains("needs %s or later" % PackImport.MIN_EXPORTER["swr-original"]),
		"an art set from exporter 2.0.0 imports, and says to export again (%s)" % r.message)
	var old_entry: Dictionary = PackImport.Installed()[0]
	_check(old_entry.exporter == "2.0.0" and old_entry.outdated, "... and is listed as outdated")
	_zip(TMP + "/new-art.zip", "art_set", "swr-original", art, {}, PackImport.MIN_EXPORTER["swr-original"])
	r = PackImport.ImportFile(TMP + "/new-art.zip")
	_check(r.ok and not r.message.contains("export again") and not PackImport.Installed()[0].outdated,
		"one from the exporter the game needs is current")

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
	# A MOD MAY CARRY THE ORIGINAL'S PICTURES (TeeJ, 2026-09-25: the original
	# came with its own editor, and people mod it): a pack holding a picture
	# from the art set, or an original/ folder, imports like any other.
	var withArt := pack_files.duplicate()
	withArt["art/portraits/characters/my_hero.png"] = red
	_zip(TMP + "/with-art.zip", "faction_pack", PACK_ID, withArt)
	r = PackImport.ImportFile(TMP + "/with-art.zip")
	_check(r.ok, "a faction pack carrying one of the art set's pictures imports (%s)" % r.message)
	PackImport.Remove("faction_pack", PACK_ID)
	var old := pack_files.duplicate()
	old["original/portraits/x.png"] = _png(Color(0, 1, 0))
	_zip(TMP + "/old.zip", "faction_pack", PACK_ID, old)
	r = PackImport.ImportFile(TMP + "/old.zip")
	_check(r.ok, "a faction pack with an original/ folder imports (%s)" % r.message)
	PackImport.Remove("faction_pack", PACK_ID)
	_check(not DirAccess.dir_exists_absolute(pack_dir), "... and Remove takes each away again")

	# One the game would not load is refused here, not shown as a broken card.
	var misnamed := pack_files.duplicate()
	var other: Dictionary = manifest.duplicate(true)
	other["id"] = "someone-else"
	misnamed["pack.json"] = JSON.stringify(other, "  ").to_utf8_buffer()
	_zip(TMP + "/misnamed.zip", "faction_pack", PACK_ID, misnamed)
	r = PackImport.ImportFile(TMP + "/misnamed.zip")
	_check(not r.ok and r.message.contains("names the pack 'someone-else' but its manifest '%s'" % PACK_ID), "a pack.json naming another id is refused (%s)" % r.message)
	var broken := pack_files.duplicate()
	var bad: Dictionary = manifest.duplicate(true)
	bad["schema_version"] = 99
	broken["pack.json"] = JSON.stringify(bad, "  ").to_utf8_buffer()
	_zip(TMP + "/broken.zip", "faction_pack", PACK_ID, broken)
	r = PackImport.ImportFile(TMP + "/broken.zip")
	_check(not r.ok and r.message.begins_with("Not imported: the game would refuse to load it.") and r.message.contains("schema_version"),
		"a pack the loader refuses is refused, with its reasons (%s)" % r.message.replace("\n", " | "))
	_check(not DirAccess.dir_exists_absolute(pack_dir) and not DirAccess.dir_exists_absolute("%s/%s" % [PackImport.PACK_STAGING, PACK_ID]),
		"... nothing is installed, and its staging folder is gone")
	_check(not FactionRegistry.ListPackIds().has(PACK_ID), "... and the picker lists nothing")
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

	# ---- a player's first faction pack: no packs folder yet ----
	var real_root: String = FactionRegistry.USER_PACKS_ROOT
	FactionRegistry.USER_PACKS_ROOT = "user://test-import-first-packs"
	PackImport._remove(FactionRegistry.USER_PACKS_ROOT)
	_check(not DirAccess.dir_exists_absolute(FactionRegistry.USER_PACKS_ROOT), "no packs folder before the first import")
	r = PackImport.ImportFile(TMP + "/pack.zip")
	_check(r.ok, "the first faction pack imports with no packs folder yet (%s)" % r.message)
	_check(FileAccess.file_exists("%s/%s/pack.json" % [FactionRegistry.USER_PACKS_ROOT, PACK_ID]), "... into a packs folder made for it")
	PackImport._remove(FactionRegistry.USER_PACKS_ROOT)
	FactionRegistry.USER_PACKS_ROOT = real_root

	# ---- versions (strangers plan PR 3): every version is kept ----
	_versions(pack_files, manifest, pack_dir)

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


## Importing a pack over another version of itself keeps both (strangers plan
## PR 3): the newer by `version` is current, the other archived under
## FactionRegistry.PACK_VERSIONS_ROOT; equal, missing or odd versions make the
## one just imported current; the same content replaces in place; the loaded
## copy, archived, is followed; FindByHash finds each; Remove takes them all.
func _versions(pack_files: Dictionary, manifest: Dictionary, pack_dir: String) -> void:
	var real_versions: String = FactionRegistry.PACK_VERSIONS_ROOT
	FactionRegistry.PACK_VERSIONS_ROOT = "user://test-import-versions"
	PackImport._remove(FactionRegistry.PACK_VERSIONS_ROOT)
	PackImport.Remove("faction_pack", PACK_ID)
	var current := func() -> String: return PackImport._version_in(pack_dir)
	var kept := func() -> Array:
		return PackImport.ArchivedVersions(PACK_ID).map(func(d: String) -> String: return PackImport._version_in(d))

	_check(PackImport.CompareVersions("1.10", "1.9") == 1 and PackImport.CompareVersions("1.9", "1.10") == -1
		and PackImport.CompareVersions("2", "2.0") == 0 and PackImport.CompareVersions("", "1.0") == 0
		and PackImport.CompareVersions("1.0-beta", "1.0") == 0, "versions order as dotted numbers (1.10 after 1.9); missing or odd ones cannot be ordered")

	var r := PackImport.ImportFile(_version_zip(pack_files, manifest, "1.0", "a"))
	var hash_v1 := FactionRegistry.ContentHash(pack_dir)
	r = PackImport.ImportFile(_version_zip(pack_files, manifest, "2.0", "b"))
	_check(r.ok and current.call() == "2.0" and kept.call() == ["1.0"] and r.message.contains("v1.0") and r.message.contains("is kept"),
		"v1.0 then v2.0: both kept, v2.0 current (%s)" % r.message)
	_check(FactionRegistry.ListPackIds().count(PACK_ID) == 1, "... and the picker still lists the pack once")
	var v1_dir := FactionRegistry.FindByHash(PACK_ID, hash_v1)
	var errors: Array[String] = []
	_check(v1_dir == PackImport.ArchiveDir(hash_v1, PACK_ID) and v1_dir.get_file() == PACK_ID and PackLoader.Load(v1_dir, errors) != null,
		"FindByHash finds v1.0 in the archive, in a folder named for the pack, and it loads (%s)" % ", ".join(errors))
	_check(FactionRegistry.FindByHash(PACK_ID, FactionRegistry.ContentHash(pack_dir)) == pack_dir and FactionRegistry.FindByHash(PACK_ID, "0".repeat(64)).is_empty(),
		"FindByHash finds the current one, and nothing for a hash not installed")

	r = PackImport.ImportFile(_version_zip(pack_files, manifest, "1.5", "c"))
	_check(r.ok and current.call() == "2.0" and kept.call().has("1.5") and r.message.contains("older"),
		"an older v1.5 after v2.0: kept beside it, v2.0 stays current (%s)" % r.message)
	var archived := PackImport.ArchivedVersions(PACK_ID).size()
	r = PackImport.ImportFile(_version_zip(pack_files, manifest, "2.0", "b"))
	_check(r.ok and current.call() == "2.0" and PackImport.ArchivedVersions(PACK_ID).size() == archived, "the same file again replaces it in place")

	# Numbers, not letters: 1.10 is after 1.9.
	PackImport.Remove("faction_pack", PACK_ID)
	_check(PackImport.ArchivedVersions(PACK_ID).is_empty() and not DirAccess.dir_exists_absolute(pack_dir), "Remove takes every version")
	PackImport.ImportFile(_version_zip(pack_files, manifest, "1.10", "d"))
	PackImport.ImportFile(_version_zip(pack_files, manifest, "1.9", "e"))
	_check(current.call() == "1.10" and kept.call() == ["1.9"], "1.10 then 1.9: 1.10 stays current")

	# No versions, or the same one: the one just imported is current.
	PackImport.Remove("faction_pack", PACK_ID)
	PackImport.ImportFile(_version_zip(pack_files, manifest, "", "f"))
	PackImport.ImportFile(_version_zip(pack_files, manifest, "", "g"))
	_check(PackImport._version_in(pack_dir).is_empty() and _summary(pack_dir) == "g" and PackImport.ArchivedVersions(PACK_ID).size() == 1
		and _summary(PackImport.ArchivedVersions(PACK_ID)[0]) == "f", "no version either time: the one just imported is current, the other kept")
	PackImport.Remove("faction_pack", PACK_ID)
	PackImport.ImportFile(_version_zip(pack_files, manifest, "3.0", "h"))
	PackImport.ImportFile(_version_zip(pack_files, manifest, "3.0", "i"))
	_check(_summary(pack_dir) == "i" and PackImport.ArchivedVersions(PACK_ID).size() == 1, "the same version with other content: the one just imported is current, the other kept")

	# The loaded copy, archived: the registry follows it.
	var was_dir := FactionRegistry.LoadedDir
	FactionRegistry.LoadedDir = pack_dir
	var loaded_hash := FactionRegistry.ContentHash(pack_dir)
	PackImport.ImportFile(_version_zip(pack_files, manifest, "4.0", "j"))
	_check(FactionRegistry.LoadedDir == PackImport.ArchiveDir(loaded_hash, PACK_ID) and FileAccess.file_exists(FactionRegistry.LoadedDir + "/pack.json"),
		"archiving the loaded version points the registry at its new folder")
	FactionRegistry.LoadedDir = was_dir

	PackImport.Remove("faction_pack", PACK_ID)
	_check(PackImport.ArchivedVersions(PACK_ID).is_empty() and DirAccess.get_directories_at(FactionRegistry.PACK_VERSIONS_ROOT).is_empty(),
		"Remove takes every version, and leaves no empty folders")
	PackImport._remove(FactionRegistry.PACK_VERSIONS_ROOT)
	FactionRegistry.PACK_VERSIONS_ROOT = real_versions
	FactionRegistry.ClearHashCache()


## The test pack at `version` (none when ""), its summary `mark` so each
## file's content - and hash - differs.
func _version_zip(pack_files: Dictionary, manifest: Dictionary, version: String, mark: String) -> String:
	var files := pack_files.duplicate()
	var m: Dictionary = manifest.duplicate(true)
	if not version.is_empty():
		m["version"] = version
	m["summary"] = mark
	files["pack.json"] = JSON.stringify(m, "  ").to_utf8_buffer()
	var path := "%s/v%s-%s.zip" % [TMP, version, mark]
	_zip(path, "faction_pack", PACK_ID, files)
	return path


static func _summary(pack_dir: String) -> String:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(pack_dir + "/pack.json"))
	return str(d.get("summary", "")) if d is Dictionary else ""


## A pack file as the exporter writes it: the files, and manifest.json listing
## each one's SHA-256 (`bad_hashes` overrides some, to damage it).
func _zip(path: String, kind: String, id: String, files: Dictionary, bad_hashes: Dictionary = {}, exporter: String = "2.4.7") -> void:
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
	zp.write_file(JSON.stringify({"format": 1, "kind": kind, "id": id, "title": id, "exporter": exporter, "files": hashes}).to_utf8_buffer())
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
