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
## A faction pack is shareable, so it may carry none of the original's art: one
## with a file matching an installed art set, or anything under original/, is
## refused. Nothing is written until the whole file checks out; the old copy is
## replaced only then.
##
## Preloaded by path (as PackImport): a new class_name can lag the editor's
## class cache.

const Art := preload("res://src/ui/artwork.gd")

const FORMAT := 1
const KIND_ART_SET := "art_set"
const KIND_FACTION_PACK := "faction_pack"
## Where a picked file is staged for the zip reader (user://, so it is never an
## OS temp folder).
const STAGING := "user://import-staging.zip"
## The oldest Faction Wars Exporter whose art set this version of the game can
## use, per art set. 2.1.0: the galaxy map mirrored out to 640x480, which the
## Star Wars pack's map_image_rect needs. 2.3.0: the Mission window, the
## cockpit's monitors, Game Options, the Speed Control and pause box, the
## resource displays and the battle windows (2026-09-23). Raise it when the game
## needs pictures an older exporter did not write; the picker then asks for a
## new export.
const MIN_EXPORTER := {"swr-original": "2.3.0"}


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
	if not kind in [KIND_ART_SET, KIND_FACTION_PACK]:
		return _fail("It is a '%s', which is neither an art set nor a faction pack." % kind)
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
	else:
		var leaked := _leaks(contents)
		if not leaked.is_empty():
			return _fail("Not imported: a faction pack must not carry the original's art (refer to the art set instead). These files are the original's:\n  " + "\n  ".join(leaked))
		if not contents.has("pack.json"):
			return _fail("It is a faction pack with no pack.json.")
		if FileAccess.file_exists("%s/%s/pack.json" % [FactionRegistry.PACKS_ROOT, id]):
			return _fail("'%s' is a pack that comes with the game; an imported copy would never be used." % id)
		dest = "%s/%s" % [FactionRegistry.USER_PACKS_ROOT, id]

	# Write beside the old copy, then swap, so a failure leaves the old intact.
	var staging := dest + ".importing"
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
	_remove(dest)
	if DirAccess.rename_absolute(staging, dest) != OK:
		return _fail("Could not move the import into place at %s." % dest)
	Art.Reset()
	_sync()
	_ask_to_keep_storage()
	var what := "the art set" if kind == KIND_ART_SET else "the faction pack"
	var message := "Imported %s \"%s\" (%d files)." % [what, title, contents.size()]
	var made_by := str(manifest.get("exporter", ""))
	if kind == KIND_ART_SET and IsOutdated(id, made_by):
		message += " " + OutdatedNote(id, made_by)
	return {"ok": true, "kind": kind, "id": id, "files": contents.size(), "message": message}


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


## The art sets and faction packs the player imported: [{ kind, id, title,
## files, created_utc, exporter, outdated }], art sets first. `outdated`: an art
## set older than MIN_EXPORTER.
static func Installed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair in [[KIND_ART_SET, Art.UserArtRoot], [KIND_FACTION_PACK, FactionRegistry.USER_PACKS_ROOT]]:
		for id in DirAccess.get_directories_at(pair[1]):
			if id.ends_with(".importing"):
				continue
			var m: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/manifest.json" % [pair[1], id]))
			var entry := {"kind": pair[0], "id": id, "title": id, "files": 0, "created_utc": "", "exporter": "", "outdated": false}
			if m is Dictionary:
				entry["title"] = str(m.get("title", id))
				entry["files"] = (m.get("files", {}) as Dictionary).size() if m.get("files") is Dictionary else 0
				entry["created_utc"] = str(m.get("created_utc", ""))
				entry["exporter"] = str(m.get("exporter", ""))
			entry["outdated"] = pair[0] == KIND_ART_SET and IsOutdated(id, entry["exporter"])
			out.append(entry)
	return out


## Removes an imported art set or faction pack.
static func Remove(kind: String, id: String) -> void:
	if not _safe_id(id):
		return
	_remove("%s/%s" % [Art.UserArtRoot if kind == KIND_ART_SET else FactionRegistry.USER_PACKS_ROOT, id])
	Art.Reset()
	_sync()


## Files of a faction pack that are the original's: anything under original/,
## and any file identical to one in an installed art set.
static func _leaks(contents: Dictionary) -> Array[String]:
	var known := {}   # sha256 -> true, from every installed art set's manifest
	for id in DirAccess.get_directories_at(Art.UserArtRoot):
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/manifest.json" % [Art.UserArtRoot, id]))
		if m is Dictionary and m.get("files") is Dictionary:
			for h in (m["files"] as Dictionary).values():
				known[str(h)] = true
	var out: Array[String] = []
	for p in contents:
		if str(p).begins_with("original/"):
			out.append("%s  (the original's art lives in the art set, not in a pack)" % p)
		elif known.has(_sha256(contents[p])):
			out.append("%s  (the same picture as one in your art set)" % p)
	return out


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
