extends RefCounted
## Saved games in and out of the game as files (PROJECT.md, the Saved Games
## screen's Import Game and Export Game): the browser's own file picker and a
## download on the web, the system's open and save dialogs on the desktop.
## What a file holds is SaveManager's business (Detect, Import, ExportText).
##
## Preloaded by path (as SaveFiles): a new class_name can lag the editor's
## class cache.

static var _js_callback: JavaScriptObject = null
static var _picked: Callable = Callable()

## Where the desktop dialogs start.
static func StartDir() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Faction Wars")


## Let the player pick a saved game file - ours (.fwsave) or an original
## SAVEGAME.nnn. `done` gets (bytes: PackedByteArray, file_name: String), or
## nothing if the player cancels.
static func Pick(done: Callable) -> void:
	_picked = done
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_js_file)
		JavaScriptBridge.eval("""
			window.factionWarsPickSave = function (cb) {
				var input = document.createElement('input');
				input.type = 'file';
				input.onchange = function () {
					var f = input.files && input.files[0];
					if (!f) return;
					f.arrayBuffer().then(function (b) { cb(new Uint8Array(b), f.name); });
				};
				input.click();
			};""", true)
		JavaScriptBridge.get_interface("window").factionWarsPickSave(_js_callback)
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		return
	DisplayServer.file_dialog_show("Import Game", StartDir(), "", false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.fwsave ; Faction Wars saved game", "SAVEGAME.* ; Star Wars: Rebellion saved game", "* ; All files"]),
		func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			if ok and paths.size() > 0:
				_deliver(FileAccess.get_file_as_bytes(paths[0]), paths[0].get_file()))


static func _on_js_file(args: Array) -> void:
	_js_callback = null
	if args.size() < 2:
		return
	_deliver(JavaScriptBridge.js_buffer_to_packed_byte_array(args[0]), str(args[1]))


static func _deliver(bytes: PackedByteArray, file_name: String) -> void:
	if _picked.is_valid():
		var done := _picked
		_picked = Callable()
		done.call(bytes, file_name)


## Save `text` as a file named `suggested`: a download in the browser, the save
## dialog on the desktop. `done` gets (ok: bool, where: String) once it is
## written, or nothing if the player cancels.
static func Save(text: String, suggested: String, done: Callable) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), suggested, "application/json")
		done.call(true, suggested)
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		done.call(false, "")
		return
	DirAccess.make_dir_recursive_absolute(StartDir())
	DisplayServer.file_dialog_show("Export Game", StartDir(), suggested, false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.fwsave ; Faction Wars saved game"]),
		func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			if not ok or paths.is_empty():
				return
			var path: String = paths[0]
			if path.get_extension().to_lower() != "fwsave":
				path += ".fwsave"
			done.call(WriteText(path, text), path))


## Write `text` to `path` (the desktop export; a test calls it directly).
static func WriteText(path: String, text: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
