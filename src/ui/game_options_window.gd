class_name GameOptionsWindow
extends PanelContainer
## The Game Options screen (manual p073-077): six named save slots. This is where
## the original saves and loads a single-player game. PR A wires SAVE (write the
## current command log to a slot); LOAD from here / the start menu is PR B.
## Head-to-head it is the same screen (manual p163: "follow the same procedure
## as you would to save a single player game"): the host's Save writes the slot
## on both computers (H2hSave); the guest's Save buttons are off.
##
## Built in code (repo convention), shown as a centered modal overlay. Opened from
## the in-game menu's "Game Options" button.

const H2hSaveLib := preload("res://src/ui/h2h_save.gd")

signal Closed

var _rows: Array = []   # per slot: { "name": LineEdit, "state": Label }
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

	for i in SaveManager.SLOT_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var state := Label.new()
		state.custom_minimum_size = Vector2(150, 0)
		state.add_theme_font_size_override("font_size", 12)
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
		_rows.append({ "name": nameEdit, "state": state })

	box.add_child(HSeparator.new())
	var closeBtn := Button.new()
	closeBtn.text = "Close"
	closeBtn.pressed.connect(func() -> void:
		Closed.emit()
		queue_free())
	box.add_child(closeBtn)

	_refresh()


func _refresh() -> void:
	var slots: Array = SaveManager.Slots()
	for i in slots.size():
		if i >= _rows.size():
			break
		var s: Dictionary = slots[i]
		var state: Label = _rows[i]["state"]
		var nameEdit: LineEdit = _rows[i]["name"]
		if s["used"]:
			state.text = "Slot %d: %s (Day %d)" % [i + 1, s["name"], StrategicTickManager.Shown(int(s["day"]))]
			if nameEdit.text.is_empty():
				nameEdit.text = str(s["name"])
		else:
			state.text = "Slot %d: (empty)" % (i + 1)


## Public so a test can drive a save without a real button press.
func _on_save(slot: int) -> void:
	if slot < 0 or slot >= _rows.size():
		return
	var nm: String = (_rows[slot]["name"] as LineEdit).text.strip_edges()
	if nm.is_empty():
		nm = "Saved game"
	if MpSetup.session != null:
		if MpSetup.hosting:
			_h2h.begin(MpSetup.session, slot, nm)
		return
	SaveManager.Save(slot, nm)
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
