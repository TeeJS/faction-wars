class_name GameOptionsWindow
extends PanelContainer
## The Game Options screen (manual p073-077) as a plain window, used when the
## original's art is not imported (original_options_screen.gd is the real one).
## The rows are the newest saved games (PROJECT.md): a name is a game - Save
## with the name unchanged overwrites it, a new name makes a new game.
## Head-to-head it is the same screen (manual p163: "follow the same procedure
## as you would to save a single player game"): the host's Save writes the game
## on both computers (H2hSave); the guest's Save buttons are off.
##
## Built in code (repo convention), shown as a centered modal overlay. Opened from
## the in-game menu's "Game Options" button.

const H2hSaveLib := preload("res://src/ui/h2h_save.gd")

signal Closed

## As many rows as the real screen.
const Rows := preload("res://src/ui/original_options_screen.gd").Rows
const SaveFiles := preload("res://src/ui/save_files.gd")
const AllGamesPlain := preload("res://src/ui/all_games_window.gd")

var _rows: Array = []   # per row: { "name": LineEdit, "state": Label, "id": String }
var _h2h: H2hSaveLib = H2hSaveLib.new()


func _ready() -> void:
	name = "GameOptionsWindow"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(440, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Head-to-head: "bring up the Game Options Screen. Your opponent will
	# receive a Waiting for Opponent message, until you return to the game"
	# (manual p163) - unless the Game Menu it was opened from already said so.
	if MpSetup.session != null:
		var gm: Node = get_parent()
		while gm != null and not gm.has_method("MenuOpened"):
			gm = gm.get_parent()
		if gm != null and not bool(gm.get("_menuOpen")):
			gm.MenuOpened(true)
			tree_exiting.connect(func() -> void:
				if is_instance_valid(gm):
					gm.MenuOpened(false))

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Game Options - Save Game"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	box.add_child(HSeparator.new())

	for i in Rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var state := Label.new()
		state.custom_minimum_size = Vector2(150, 0)
		state.add_theme_font_size_override("font_size", 12)
		state.mouse_filter = Control.MOUSE_FILTER_PASS   # its hover shows the saved date
		row.add_child(state)

		var nameEdit := LineEdit.new()
		nameEdit.placeholder_text = "Save name"
		nameEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nameEdit)

		var saveBtn := Button.new()
		saveBtn.text = "Save"
		var slot := i
		saveBtn.pressed.connect(func() -> void: _on_save(slot))
		# "Only the host player can save the game" (manual p163).
		if MpSetup.session != null and not MpSetup.hosting:
			saveBtn.disabled = true
			saveBtn.tooltip_text = "Only the host can save."
		row.add_child(saveBtn)

		box.add_child(row)
		_rows.append({ "name": nameEdit, "state": state, "id": "" })

	# Import Game and Manage Games, as on the real screen (TeeJ, 2026-09-28).
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	for t in [["Import Game", _import], ["Manage Games", _see_all]]:
		var b := Button.new()
		b.text = t[0]
		b.pressed.connect(t[1])
		tools.add_child(b)
	box.add_child(tools)

	box.add_child(HSeparator.new())
	var closeBtn := Button.new()
	closeBtn.text = "Close"
	closeBtn.pressed.connect(func() -> void:
		Closed.emit()
		queue_free())
	box.add_child(closeBtn)

	_refresh()


## Fill the rows with the newest saved games, newest at the top.
func _refresh() -> void:
	var games: Array = SaveManager.Recent(_rows.size())
	for i in _rows.size():
		var used: bool = i < games.size()
		var g: Dictionary = games[i] if used else {}
		var state: Label = _rows[i]["state"]
		var nameEdit: LineEdit = _rows[i]["name"]
		_rows[i]["id"] = str(g["id"]) if used else ""
		state.text = ("%s (Day %d)" % [g["name"], StrategicTickManager.Shown(int(g["day"]))]) if used else "(empty)"
		state.tooltip_text = SaveManager.SavedLabel(g) if used else ""
		nameEdit.text = str(g["name"]) if used else ""


func _import() -> void:
	SaveFiles.Pick(ImportBytes)


## Public so a test can hand it a file without the dialog.
func ImportBytes(bytes: PackedByteArray, file_name: String) -> Dictionary:
	var r: Dictionary = SaveManager.Import(bytes, file_name)
	_refresh()
	_tell(("\"%s\" is in your saved games." % r["name"]) if r["ok"] else str(r["message"]))
	return r


func _see_all() -> void:
	var all: Control = AllGamesPlain.new()
	all.InGame = true
	get_parent().add_child(all)
	all.Closed.connect(_refresh)


func _tell(text: String) -> void:
	var box := AcceptDialog.new()
	box.title = "Saved Games"
	box.dialog_text = text
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(box.queue_free)


## Public so a test can drive a save without a real button press. The name is
## the game: unchanged overwrites the row's game, a new name makes a new one.
func _on_save(row: int) -> void:
	if row < 0 or row >= _rows.size():
		return
	var nm: String = (_rows[row]["name"] as LineEdit).text.strip_edges()
	if nm.is_empty():
		nm = SaveManager.NameOf(_rows[row]["id"])
	if MpSetup.session != null:
		# Head-to-head (manual p163): the host's save, on both computers.
		if MpSetup.hosting:
			_h2h.begin(MpSetup.session, nm if not nm.is_empty() else SaveManager.FreeName())
		return
	SaveManager.Save(nm)   # an empty name takes the next free "Saved game"
	_refresh()


func _process(_delta: float) -> void:
	var said: String = _h2h.poll()
	if said.is_empty():
		return
	_refresh()
	var box := AcceptDialog.new()
	box.title = "Save Game"
	box.dialog_text = said
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(box.queue_free)
