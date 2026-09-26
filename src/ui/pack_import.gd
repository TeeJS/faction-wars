extends RefCounted
## IMPORTING A PACK FILE (docs/original-art-plan.md, phase 3). The player's
## own art set (made by tools/FactionWarsExporter from their copy of the game)
## or a faction pack, as one .zip with manifest.json at its root:
##   { "format": 1, "kind": "art_set" | "faction_pack", "id": ..., "title": ...,
##     "files": { "<path>": "<sha256>", ... } }
## Every listed file is checked against its SHA-256 and written to the user
## folder - browser storage on the web, where it stays until the player clears
## the site's data:
##   an art set      -> Artwork.UserArtRoot/<id>/   (read by src/ui/artwork.gd)
##   a faction pack  -> user://packs/<id>/          (listed by the pack picker)
## A faction pack may carry any pictures, the original's included: Star Wars:
## Rebellion has a modding culture - the original came with its own editor -
## and a mod is the modder's to make (TeeJ, 2026-09-25; a refusal of packs
## holding the original's pictures stood here and is gone). A faction pack
## must be one the game will load: its pack.json
## names the same id as its manifest, and it passes the loader's checks
## (PackLoader.Load) from a staging folder named after it - so a pack that would
## only ever show as a broken card is refused here, with the reasons (the
## editor handoff, 2026-09-23). Nothing is written into place until the whole
## file checks out; the old copy is replaced only then.
##
## Preloaded by path (as PackImport): a new class_name can lag the editor's
## class cache.

const Art := preload("res://src/ui/artwork.gd")
const MoviesLib := preload("res://src/ui/movies.gd")

const FORMAT := 1
const KIND_ART_SET := "art_set"
const KIND_FACTION_PACK := "faction_pack"
## The original's movies, converted by the exporter from the player's own copy
## (docs/cutscenes-plan.md): a second, optional file beside the art set, to
## Movies.UserRoot/<id>/. Desktop only until the browser keeps them outside
## its in-memory user:// (the plan's phase 5).
const KIND_MOVIES := "movies"
## Where a picked file is staged for the zip reader (user://, so it is never an
## OS temp folder).
const STAGING := "user://import-staging.zip"
## Where a faction pack is unpacked to be checked: a folder named after the
## pack, since the loader's rule 1 compares the id with the folder name. Not
## under user://packs, where the picker would list it.
const PACK_STAGING := "user://import-staging"
## How many of the loader's reasons a refusal lists.
const REASONS_SHOWN := 8
## The oldest Faction Wars Exporter whose art set this version of the game can
## use, per art set. 2.1.0: the galaxy map mirrored out to 640x480, which the
## Star Wars pack's map_image_rect needs. 2.3.0: the Mission window, the
## cockpit's monitors, Game Options, the Speed Control and pause box, the
## resource displays and the battle windows (2026-09-23). 2.4.0: the Fleet
## window and the in-transit icon, the System, Fleet and Ship Finders, the
## battle results' forces pages, the character status icons and the blue
## hyperspace engine glow (released 2026-09-24). 2.4.1: planet pictures 24-26
## are the original's sprites (Umgul and Bpfassh were plain circles). 2.4.2:
## the Mines tab's mine and piles, and the Command Center frame (released
## 2026-09-25). 2.4.3: the Shuttle Cockpit's galaxy-size lever (released
## 2026-09-25). 2.4.4: the original's map key window and the ejector handle
## pulled (released 2026-09-25). 2.4.5: the Command Center's droids, the
## Control Panel's monitors held down and the menus' check mark (released
## 2026-09-25). 2.4.6: the GID control's menu icons (released 2026-09-25).
## 2.4.7: the head-to-head screens, their buttons and parts (released
## 2026-09-26).
## Raise it when the game needs pictures an older exporter did not write;
## the picker then asks for a new export.
const MIN_EXPORTER := {"swr-original": "2.4.7"}


## Called with each import's result (the pack picker refreshes its cards).
static var OnImported: Callable = Callable()
static var _listening: bool = false
static var _js_callback: JavaScriptObject = null
static var _picked: Callable = Callable()


## Lets the player pick a pack file: the browser's own file picker on the web
## (a tablet's too), the system's file dialog on the desktop. `done` gets the
## import's result.
static func PickFile(done: Callable) -> void:
	_picked = done
	if OS.has_feature("web"):
		# A file input clicked from the button's press; its bytes come back
		# through the callback (kept referenced until it fires).
		_js_callback = JavaScriptBridge.create_callback(_on_js_file)
		JavaScriptBridge.eval("""
			window.factionWarsPickFile = function (cb) {
				var input = document.createElement('input');
				input.type = 'file';
				input.accept = '.zip,application/zip';
				input.onchange = function () {
					var f = input.files && input.files[0];
					if (f) { f.arrayBuffer().then(function (b) { cb(new Uint8Array(b), f.name); }); }
				};
				input.click();
			};""", true)
		JavaScriptBridge.get_interface("window").factionWarsPickFile(_js_callback)
		return
	var start := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Faction Wars")
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Import a Faction Wars file", start, "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.zip ; Faction Wars file"]),
			func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
				if ok and paths.size() > 0:
					_report(ImportFile(paths[0])))
	else:
		_report(_fail("There is no file dialog here - drag the file onto the game instead."))


static func _on_js_file(args: Array) -> void:
	_js_callback = null
	if args.is_empty():
		return
	_report(ImportBytes(JavaScriptBridge.js_buffer_to_packed_byte_array(args[0])))


## A file dropped anywhere on the game imports too (the web build and the
## desktop both hand dropped files to the window). Connected once, by the
## pack picker, the first screen.
static func ListenForDrops(tree: SceneTree) -> void:
	if _listening:
		return
	_listening = true
	tree.root.files_dropped.connect(func(files: PackedStringArray) -> void:
		for f in files:
			if f.get_extension().to_lower() == "zip":
				_report(ImportFile(f)))


static func _report(result: Dictionary) -> void:
	if _picked.is_valid():
		var done := _picked
		_picked = Callable()
		done.call(result)
	elif OnImported.is_valid():
		OnImported.call(result)


## Imports the .zip at `path`. Returns { ok, message, kind, id, files }.
static func ImportFile(path: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return _fail("That is not a Faction Wars file (it could not be opened as a .zip).")
	var result := _import(zip)
	zip.close()
	return result


## The same, for a file's bytes (the browser's file picker hands over bytes).
static func ImportBytes(bytes: PackedByteArray) -> Dictionary:
	var f := FileAccess.open(STAGING, FileAccess.WRITE)
	if f == null:
		return _fail("Could not stage the file (%s)." % error_string(FileAccess.get_open_error()))
	f.store_buffer(bytes)
	f.close()
	var result := ImportFile(STAGING)
	DirAccess.remove_absolute(STAGING)
	_sync()
	return result


static func _import(zip: ZIPReader) -> Dictionary:
	if not zip.file_exists("manifest.json"):
		return _fail("That file has no manifest.json - export it with the Faction Wars Exporter, or build it with its Build faction pack.")
	var manifest: Variant = JSON.parse_string(zip.read_file("manifest.json").get_string_from_utf8())
	if not manifest is Dictionary:
		return _fail("Its manifest.json is not valid JSON.")
	var kind := str(manifest.get("kind", ""))
	var id := str(manifest.get("id", ""))
	var title := str(manifest.get("title", id))
	if int(manifest.get("format", 0)) != FORMAT:
		return _fail("It is format %s; this version of Faction Wars reads format %d." % [str(manifest.get("format", "?")), FORMAT])
	if not kind in [KIND_ART_SET, KIND_FACTION_PACK, KIND_MOVIES]:
		return _fail("It is a '%s', which is not an art set, a faction pack or a movies file." % kind)
	if kind == KIND_MOVIES and OS.has_feature("web"):
		return _fail("Movies play in the desktop game for now. The browser game gets them later.")
	if not _safe_id(id):
		return _fail("Its id '%s' is not a plain name (letters, digits, - and _)." % id)
	var files: Variant = manifest.get("files")
	if not files is Dictionary or files.is_empty():
		return _fail("Its manifest lists no files.")

	# Every file, checked before anything is written.
	var contents := {}   # path -> bytes
	for rel in files:
		var p := str(rel)
		if not _safe_path(p):
			return _fail("It lists an unsafe path: %s" % p)
		if not zip.file_exists(p):
			return _fail("It is incomplete: %s is listed but missing." % p)
		var bytes := zip.read_file(p)
		if _sha256(bytes) != str(files[rel]).to_lower():
			return _fail("It is damaged: %s does not match its checksum." % p)
		contents[p] = bytes

	var dest: String
	if kind == KIND_ART_SET:
		dest = "%s/%s" % [Art.UserArtRoot, id]
	elif kind == KIND_MOVIES:
		dest = "%s/%s" % [MoviesLib.UserRoot, id]
	else:
		if not contents.has("pack.json"):
			return _fail("It is a faction pack with no pack.json.")
		if FileAccess.file_exists("%s/%s/pack.json" % [FactionRegistry.PACKS_ROOT, id]):
			return _fail("'%s' is a pack that comes with the game; an imported copy would never be used." % id)
		var pj: Variant = JSON.parse_string((contents["pack.json"] as PackedByteArray).get_string_from_utf8())
		if not pj is Dictionary:
			return _fail("Its pack.json is not valid JSON.")
		if str(pj.get("id", "")) != id:
			return _fail("Its pack.json names the pack '%s' but its manifest '%s'; they must be the same." % [str(pj.get("id", "")), id])
		dest = "%s/%s" % [FactionRegistry.USER_PACKS_ROOT, id]

	# Write beside the old copy, then swap, so a failure leaves the old intact.
	# A faction pack is written where the loader can check it first.
	var staging := "%s/%s" % [PACK_STAGING, id] if kind == KIND_FACTION_PACK else dest + ".importing"
	_remove(staging)
	for p in contents:
		var path := "%s/%s" % [staging, p]
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			_remove(staging)
			return _fail("Could not write %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		out.store_buffer(contents[p])
		out.close()
	var keep := FileAccess.open("%s/manifest.json" % staging, FileAccess.WRITE)
	keep.store_string(JSON.stringify(manifest, "  "))
	keep.close()
	if kind == KIND_FACTION_PACK:
		var errors: Array[String] = []
		PackLoader.Load(staging, errors)
		if not errors.is_empty():
			_remove(staging)
			var shown: Array[String] = []
			for e in errors.slice(0, REASONS_SHOWN):
				shown.append(str(e))
			var more: String = "\n  ... and %d more" % (errors.size() - REASONS_SHOWN) if errors.size() > REASONS_SHOWN else ""
			return _fail("Not imported: the game would refuse to load it.\n  %s%s" % ["\n  ".join(shown), more])
	var note := ""
	# What was imported, for a caller that wanted one particular pack (the
	# Get-pack dialog compares it with the host's).
	var pack_facts := {}
	if kind == KIND_FACTION_PACK:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/pack.json" % staging))
		var m := PackDefs.PackManifest.from_dict(d if d is Dictionary else {})
		pack_facts = {"pack_title": m.DisplayName, "pack_version": m.Version, "pack_hash": FactionRegistry.ContentHash(staging)}
	if kind == KIND_FACTION_PACK and FileAccess.file_exists("%s/pack.json" % dest):
		# Another version of a pack already installed: both are kept.
		var placed := _place_version(staging, dest, id)
		if not placed.ok:
			_remove(staging)
			return _fail(placed.message)
		note = placed.note
	else:
		_remove(dest)
		# A faction pack is staged outside user://packs, so on a player's first
		# import that folder does not exist yet and the move would fail (the
		# editor's game check, 2026-09-24).
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		if DirAccess.rename_absolute(staging, dest) != OK:
			return _fail("Could not move the import into place at %s." % dest)
	FactionRegistry.ClearHashCache()
	Art.Reset()
	_sync()
	_ask_to_keep_storage()
	var what: String = {KIND_ART_SET: "the art set", KIND_MOVIES: "the movies"}.get(kind, "the faction pack")
	var message := "Imported %s \"%s\" (%d files).%s" % [what, title, contents.size(), note]
	var made_by := str(manifest.get("exporter", ""))
	if kind == KIND_ART_SET and IsOutdated(id, made_by):
		message += " " + OutdatedNote(id, made_by)
	var result := {"ok": true, "kind": kind, "id": id, "files": contents.size(), "message": message}
	result.merge(pack_facts)
	return result


## A faction pack imported over another version of itself (strangers plan,
## 2026-09-26): BOTH are kept, so a head-to-head game on either can be joined.
## The same content replaces in place. Otherwise the newer by pack.json
## `version` (dotted numbers, 1.10 after 1.9) is current at user://packs/<id>
## and the other goes to FactionRegistry.PACK_VERSIONS_ROOT; when the versions
## are equal, missing or not dotted numbers, the one just imported is current.
## Archiving the loaded pack points FactionRegistry.LoadedDir at its new place.
static func _place_version(staging: String, dest: String, id: String) -> Dictionary:
	var old_hash := FactionRegistry.ContentHash(dest)
	var new_hash := FactionRegistry.ContentHash(staging)
	if old_hash == new_hash:
		_remove(dest)
		if DirAccess.rename_absolute(staging, dest) != OK:
			return {"ok": false, "message": "Could not move the import into place at %s." % dest}
		return {"ok": true, "note": ""}
	var new_version := _version_in(staging)
	var old_version := _version_in(dest)
	if CompareVersions(new_version, old_version) < 0:
		# An older version than the current one: kept beside it.
		var kept := ArchiveDir(new_hash, id)
		_remove(kept)
		DirAccess.make_dir_recursive_absolute(kept.get_base_dir())
		if DirAccess.rename_absolute(staging, kept) != OK:
			return {"ok": false, "message": "Could not keep the older version at %s." % kept}
		return {"ok": true, "note": " It is older than the installed v%s, which stays current; v%s is kept beside it for games played on it." % [old_version, new_version]}
	# The new one becomes current; the one it replaces is kept.
	var archive := ArchiveDir(old_hash, id)
	_remove(archive)
	DirAccess.make_dir_recursive_absolute(archive.get_base_dir())
	if DirAccess.rename_absolute(dest, archive) != OK:
		return {"ok": false, "message": "Could not keep the installed version at %s." % archive}
	var was_loaded := FactionRegistry.LoadedDir == dest
	if was_loaded:
		FactionRegistry.LoadedDir = archive
	if DirAccess.rename_absolute(staging, dest) != OK:
		DirAccess.rename_absolute(archive, dest)   # put the installed one back
		if was_loaded:
			FactionRegistry.LoadedDir = dest
		return {"ok": false, "message": "Could not move the import into place at %s." % dest}
	var replaced := ("v" + old_version) if not old_version.is_empty() else "the one it replaces"
	return {"ok": true, "note": " The version installed before (%s) is kept, for games played on it." % replaced}


## Where an archived version of pack `id` lives: the first 16 characters of its
## content hash, then the id (the loader wants the folder named for the pack).
static func ArchiveDir(hash: String, id: String) -> String:
	return "%s/%s/%s" % [FactionRegistry.PACK_VERSIONS_ROOT, hash.substr(0, 16).to_lower(), id]


## The archived versions of pack `id` (not the current one).
static func ArchivedVersions(id: String) -> Array[String]:
	var out: Array[String] = []
	var root := FactionRegistry.PACK_VERSIONS_ROOT
	if DirAccess.dir_exists_absolute(root):
		for h in DirAccess.get_directories_at(root):
			if FileAccess.file_exists("%s/%s/%s/pack.json" % [root, h, id]):
				out.append("%s/%s/%s" % [root, h, id])
	return out


static func _version_in(pack_dir: String) -> String:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/pack.json" % pack_dir))
	return PackDefs.PackManifest.from_dict(d).Version if d is Dictionary else ""


## Pack versions as dotted numbers: 1 when `a` is newer, -1 when older, 0 when
## the same - or when either is missing or not dotted numbers, which no rule
## can order.
static func CompareVersions(a: String, b: String) -> int:
	var pa := _dotted(a)
	var pb := _dotted(b)
	if pa.is_empty() or pb.is_empty():
		return 0
	for i in maxi(pa.size(), pb.size()):
		var x: int = pa[i] if i < pa.size() else 0
		var y: int = pb[i] if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


static func _dotted(v: String) -> Array[int]:
	var out: Array[int] = []
	v = v.strip_edges()
	if v.is_empty():
		return out
	for part in v.split("."):
		if part.is_empty() or not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return [] as Array[int]
		out.append(int(part))
	return out


## Whether an art set made by exporter `made_by` is older than this game needs.
static func IsOutdated(set_id: String, made_by: String) -> bool:
	return IsOlder(made_by, str(MIN_EXPORTER.get(set_id, "0")))


static func OutdatedNote(set_id: String, made_by: String) -> String:
	return "It was made by exporter %s; this version of Faction Wars needs %s or later - download the new exporter and export again." \
		% [made_by if not made_by.is_empty() else "(unknown)", MIN_EXPORTER.get(set_id, "")]


## "2.0.9" is older than "2.1.0"; a missing version is older than any.
static func IsOlder(version: String, than: String) -> bool:
	var a := version.split(".")
	var b := than.split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x < y
	return false


## The art sets, faction packs and movies the player imported: [{ kind, id,
## title, files, created_utc, exporter, outdated }], art sets first. `outdated`:
## an art set older than MIN_EXPORTER.
static func Installed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair in [[KIND_ART_SET, Art.UserArtRoot], [KIND_FACTION_PACK, FactionRegistry.USER_PACKS_ROOT], [KIND_MOVIES, MoviesLib.UserRoot]]:
		if not DirAccess.dir_exists_absolute(pair[1]):
			continue
		for id in DirAccess.get_directories_at(pair[1]):
			if id.ends_with(".importing"):
				continue
			var manifest := "%s/%s/manifest.json" % [pair[1], id]
			var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest)) if FileAccess.file_exists(manifest) else null
			var entry := {"kind": pair[0], "id": id, "title": id, "files": 0, "created_utc": "", "exporter": "", "outdated": false}
			if m is Dictionary:
				entry["title"] = str(m.get("title", id))
				entry["files"] = (m.get("files", {}) as Dictionary).size() if m.get("files") is Dictionary else 0
				entry["created_utc"] = str(m.get("created_utc", ""))
				entry["exporter"] = str(m.get("exporter", ""))
			entry["outdated"] = pair[0] == KIND_ART_SET and IsOutdated(id, entry["exporter"])
			out.append(entry)
	return out


## Removes an imported art set, or a faction pack with EVERY version of it
## kept (ArchivedVersions) - the picker's Remove pack says so.
static func Remove(kind: String, id: String) -> void:
	if not _safe_id(id):
		return
	var root: String = {KIND_ART_SET: Art.UserArtRoot, KIND_MOVIES: MoviesLib.UserRoot}.get(kind, FactionRegistry.USER_PACKS_ROOT)
	_remove("%s/%s" % [root, id])
	if kind == KIND_FACTION_PACK:
		for dir in ArchivedVersions(id):
			_remove(dir)
			var holder := dir.get_base_dir()
			if DirAccess.get_directories_at(holder).is_empty() and DirAccess.get_files_at(holder).is_empty():
				DirAccess.remove_absolute(holder)
		FactionRegistry.ClearHashCache()
	Art.Reset()
	_sync()




static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "kind": "", "id": "", "files": 0}


static func _safe_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for ch in id:
		if not (ch in "abcdefghijklmnopqrstuvwxyz0123456789-_" or ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"):
			return false
	return true


## A relative path inside the pack: no drive, no leading slash, no "..".
static func _safe_path(p: String) -> bool:
	if p.is_empty() or p.begins_with("/") or p.begins_with("\\") or p.contains(":") or p.contains("\\"):
		return false
	for part in p.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


static func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)


## The web keeps user:// in browser storage and syncs it after writes; a rename
## alone may not trigger that, so sync on purpose.
static func _sync() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()


## Asks the browser to keep this site's storage (not clear it when the disk
## runs low). The browser may say no; clearing site data still removes it.
static func _ask_to_keep_storage() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.storage && navigator.storage.persist) { navigator.storage.persist(); }", true)
