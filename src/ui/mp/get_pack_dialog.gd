extends AcceptDialog
## GET THE PACK (strangers plan PR 5): a player joining a game on a pack they
## do not have is told which one it is, given the host's link to where it can
## be downloaded (the pack's download_url - its bytes never pass through the
## game's servers), and Upload pack... Once a file is in, the room is looked up
## again (it may have started or filled in the meantime) and a match switches
## to it and joins - back in the same room, never through the pack picker. The
## file stays installed whatever it turns out to be. An addition: nothing in
## the manual corresponds to it.
##
## Everything shown here that came from the host - the pack's title, version
## and link - is shown as plain text; the link is opened through the window's
## own open(), never a string built into JavaScript.
##
## Preloaded by path: a new script can lag the editor's class cache.

const PackImport := preload("res://src/ui/pack_import.gd")

## An import finished well: the caller looks the room up again.
signal uploaded(result: Dictionary)
## The player closed it without a match.
signal closed

var _settings: Dictionary = {}
var _status: Label
var _saved_on_imported: Callable = Callable()


func Setup(info: Dictionary) -> void:
	_settings = info.get("settings", {}) if info.get("settings") is Dictionary else {}
	title = "Get the pack"
	ok_button_text = "Cancel"
	exclusive = true
	dialog_autowrap = true
	var box := VBoxContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(_label("This game uses %s." % PackWords(_settings), "Uses"))
	var url := PackDefs.PackManifest.SafeUrl(str(_settings.get("pack_url", "")))
	if url.is_empty():
		box.add_child(_label("The host's pack has no download link - ask the host where to get it.", "NoLink"))
	elif OS.has_feature("web"):
		box.add_child(_label("1. Open the pack's page, and save the pack's .zip file.", "Step1"))
		var open := Button.new()
		open.name = "OpenLink"
		open.text = "Open the pack's page"
		open.tooltip_text = url
		open.pressed.connect(func() -> void: _open(url))
		box.add_child(open)
	else:
		# The game starts no other program (the pack picker's rule): the link
		# to copy into a browser.
		box.add_child(_label("1. Open this page in your browser, and save the pack's .zip file:", "Step1"))
		var row := HBoxContainer.new()
		var field := LineEdit.new()
		field.name = "Link"
		field.text = url
		field.editable = false
		field.custom_minimum_size = Vector2(340, 0)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		var copy := Button.new()
		copy.name = "CopyLink"
		copy.text = "Copy"
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(url)
			_say("Link copied."))
		row.add_child(copy)
		box.add_child(row)
	box.add_child(_label("2. Upload it here, and you go on into the same game.", "Step2"))
	var up := Button.new()
	up.name = "Upload"
	up.text = "Upload pack..."
	up.tooltip_text = "Pick the pack's .zip file. You can also drop it on the game."
	up.pressed.connect(func() -> void: PackImport.PickFile(_on_imported))
	box.add_child(up)
	_status = _label("", "Status")
	box.add_child(_status)
	# A file dropped on the game while this is open comes here.
	PackImport.ListenForDrops(get_tree())
	_saved_on_imported = PackImport.OnImported
	PackImport.OnImported = _on_imported
	tree_exiting.connect(_restore)
	confirmed.connect(_close)
	canceled.connect(_close)


## "<title> v1.3", or the title alone without a version.
static func PackWords(s: Dictionary) -> String:
	var t := str(s.get("pack_title", s.get("pack", "a pack")))
	var v := str(s.get("pack_version", ""))
	return "%s v%s" % [t, v] if not v.is_empty() else t


## The file just uploaded is not the host's pack: says what each is. The file
## stays installed.
func Wrong(result: Dictionary) -> void:
	var host_title := str(_settings.get("pack_title", _settings.get("pack", "")))
	var theirs: String = ("v%s" % str(_settings.get("pack_version", ""))) if str(result.get("pack_title", "")) == host_title and not str(_settings.get("pack_version", "")).is_empty() \
		else PackWords(_settings)
	_say("That file is %s; the host is on %s. It stays installed." % [PackWords(result), theirs])


func _on_imported(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_say(str(result.get("message", "Not imported.")))
		return
	if str(result.get("kind", "")) != PackImport.KIND_FACTION_PACK:
		_say("That was an artwork file, not the game's pack. It stays installed.")
		return
	_say("Uploaded. Checking the game...")
	uploaded.emit(result)


func _open(url: String) -> void:
	var window: Variant = JavaScriptBridge.get_interface("window")
	if window != null:
		window.open(url, "_blank", "noopener,noreferrer")


func _say(text: String) -> void:
	if _status != null:
		_status.text = text


func Status() -> String:
	return _status.text if _status != null else ""


func _close() -> void:
	closed.emit()
	queue_free()


## Imports go back to whoever listened before, and a file dialog left open
## reports to nobody.
func _restore() -> void:
	PackImport.OnImported = _saved_on_imported
	PackImport._picked = Callable()


static func _label(text: String, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l
