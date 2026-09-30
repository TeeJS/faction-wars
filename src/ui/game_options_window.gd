class_name GameOptionsWindow
extends PanelContainer
## The Game Options screen (manual p073-077) as a plain window, used when the
## original's art is not imported (original_options_screen.gd is the real one).
## The rows are the newest saved games (PROJECT.md): a name is a game - Save
## with the name unchanged overwrites it, a new name makes a new game. Each row
## is the manual's (p075-p076, Fig. 3.16): "a Save Game button, a name field,
## and a Load Game button", and between them what the original's icon shows,
## the side played (here in words, with the day). Loading over the running
## game asks first ("the computer asks you to confirm").
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

var _rows: Array = []   # per row: { "name": LineEdit, "state": Label, "load": Button, "id": String }
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
	title.text = "Game Options - Save Game / Load Game"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	box.add_child(HSeparator.new())

	for i in Rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var slot := i

		var saveBtn := Button.new()
		saveBtn.text = "Save"
		saveBtn.pressed.connect(func() -> void: _on_save(slot))
		# "Only the host player can save the game" (manual p163).
		if MpSetup.session != null and not MpSetup.hosting:
			saveBtn.disabled = true
			saveBtn.tooltip_text = "Only the host can save."
		row.add_child(saveBtn)

		var nameEdit := LineEdit.new()
		nameEdit.placeholder_text = "Save name"
		nameEdit.custom_minimum_size = Vector2(220, 0)
		nameEdit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nameEdit)

		var state := Label.new()
		state.custom_minimum_size = Vector2(130, 0)
		state.add_theme_font_size_override("font_size", 12)
		state.mouse_filter = Control.MOUSE_FILTER_PASS   # its hover shows the saved date
		row.add_child(state)

		var loadBtn := Button.new()
		loadBtn.text = "Load"
		loadBtn.pressed.connect(func() -> void: _on_load(slot))
		row.add_child(loadBtn)

		box.add_child(row)
		_rows.append({ "name": nameEdit, "state": state, "load": loadBtn, "id": "" })

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
	# In the middle of the screen: the centre anchors alone left it in the
	# top-left corner (its parent has no size).
	_center.call_deferred()


func _center() -> void:
	global_position = ((get_viewport_rect().size - size) / 2.0).floor()


## Fill the rows with the newest saved games, newest at the top.
func _refresh() -> void:
	var games: Array = SaveManager.Recent(_rows.size())
	for i in _rows.size():
		var used: bool = i < games.size()
		var g: Dictionary = games[i] if used else {}
		var state: Label = _rows[i]["state"]
		var nameEdit: LineEdit = _rows[i]["name"]
		var loadBtn: Button = _rows[i]["load"]
		_rows[i]["id"] = str(g["id"]) if used else ""
		state.text = ("%s, Day %d" % [SideWords(str(g["side"])), StrategicTickManager.Shown(int(g["day"]))]) if used else "(empty)"
		state.tooltip_text = SaveManager.SavedLabel(g) if used else ""
		nameEdit.text = str(g["name"]) if used else ""
		# Head-to-head, a game is loaded from the Multiplayer Options (manual
		# p163), as on the original's screen.
		loadBtn.disabled = not used or MpSetup.session != null


## The side a saved game was played as, in words: the faction's short name,
## "Head-to-head" for a two-player game (what the original's icon shows).
static func SideWords(side: String) -> String:
	if side == "h2h":
		return "Head-to-head"
	var f: Faction = FactionRegistry.ById(side) if not side.is_empty() else null
	if f == null or f == FactionRegistry.Unknown:
		return "Unknown side"
	return f.ShortName if not f.ShortName.is_empty() else f.DisplayName


func _import() -> void:
	SaveFiles.Pick(ImportBytes)


## Public so a test can hand it a file without the dialog.
func ImportBytes(bytes: PackedByteArray, file_name: String) -> Dictionary:
	var r: Dictionary = SaveManager.Import(bytes, file_name)
	_refresh()
	_tell(SaveManager.ImportNote(r))
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


## Load row `row`'s game over the running one, once the player confirms (the
## original's words, REBDLOG.DLL, as original_options_screen.gd). Public so a
## test can press it without a real click; returns the question asked, or null.
func _on_load(row: int) -> ConfirmationDialog:
	if row < 0 or row >= _rows.size() or not SaveManager.Exists(_rows[row]["id"]):
		return null
	var id: String = _rows[row]["id"]
	var box := ConfirmationDialog.new()
	box.name = "Confirm"
	box.title = "Load Game"
	box.dialog_text = "Loading the selected game will destroy unsaved changes.

Load without saving?"
	box.exclusive = true
	add_child(box)
	box.popup_centered()
	box.confirmed.connect(func() -> void:
		box.queue_free()
		MpSetup.reset()
		GameSettings.PendingLoadPath = SaveManager.GamePath(id)
		get_tree().change_scene_to_file("res://Main.tscn"))
	box.canceled.connect(box.queue_free)
	return box


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
