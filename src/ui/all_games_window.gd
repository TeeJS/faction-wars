class_name AllGamesWindow
extends PanelContainer
## See all games as a plain window, used when the original's art is not
## imported (original_all_games_screen.gd is the real one): every saved game,
## newest first - its name, Saved date and day, with Save, Load, Export and
## Delete (PROJECT.md). Save follows the Saved Games rule: the name is the game.
## Built in code (repo convention), shown as a centered modal overlay.

signal Closed

const SaveFiles := preload("res://src/ui/save_files.gd")

## Opened in a game (Save and Export have a game to work on; Load asks first).
var InGame: bool = false

var _list: VBoxContainer
var _rows: Array = []   # per game: { "id", "name": LineEdit }


func _ready() -> void:
	name = "AllGamesWindow"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(640, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "All Saved Games"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	box.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(HSeparator.new())
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		Closed.emit()
		queue_free())
	box.add_child(close)
	Refresh()


func Refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var head := HBoxContainer.new()
	for t in [["Name", 200], ["Saved", 90], ["Day", 70]]:
		var l := Label.new()
		l.text = t[0]
		l.custom_minimum_size = Vector2(t[1], 0)
		head.add_child(l)
	_list.add_child(head)
	var games: Array = SaveManager.Games()
	for g: Dictionary in games:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var id := str(g["id"])
		var nameEdit := LineEdit.new()
		nameEdit.text = str(g["name"])
		nameEdit.custom_minimum_size = Vector2(200, 0)
		nameEdit.tooltip_text = SaveManager.SavedLabel(g)
		row.add_child(nameEdit)
		for t in [[SaveManager.SavedDate(g), 90], ["Day %d" % StrategicTickManager.Shown(int(g["day"])), 70]]:
			var l := Label.new()
			l.text = t[0]
			l.custom_minimum_size = Vector2(t[1], 0)
			row.add_child(l)
		var save := _btn(row, "Save", func() -> void: _save(nameEdit, id))
		save.disabled = not InGame or MpSetup.session != null
		_btn(row, "Load", func() -> void: _load(id)).disabled = MpSetup.session != null
		_btn(row, "Export", func() -> void: SaveFiles.Save(SaveManager.ExportText(id), SaveManager.ExportFileName(id), func(_ok: bool, _w: String) -> void: pass))
		_btn(row, "Delete", func() -> void: _delete(id))
		_list.add_child(row)
		_rows.append({"id": id, "name": nameEdit})
	if games.is_empty():
		var none := Label.new()
		none.text = "No saved games yet."
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(none)


func _btn(row: HBoxContainer, text: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(act)
	row.add_child(b)
	return b


func _save(field: LineEdit, id: String) -> void:
	var nm: String = field.text.strip_edges()
	SaveManager.Save(nm if not nm.is_empty() else SaveManager.NameOf(id))
	Refresh()


func _load(id: String) -> void:
	if not SaveManager.Exists(id):
		return
	var go := func() -> void:
		GameSettings.PendingLoadPath = SaveManager.GamePath(id)
		get_tree().change_scene_to_file("res://Main.tscn")
	if not InGame:
		go.call()
		return
	_ask("Loading the selected game will destroy unsaved changes. Load without saving?", go)


func _delete(id: String) -> void:
	_ask("\"%s\" will be gone for good. Delete this saved game?" % SaveManager.NameOf(id), func() -> void:
		SaveManager.Delete(id)
		Refresh())


func _ask(text: String, yes: Callable) -> void:
	var box := ConfirmationDialog.new()
	box.dialog_text = text
	box.exclusive = true
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(func() -> void:
		box.queue_free()
		yes.call())
	box.canceled.connect(box.queue_free)
