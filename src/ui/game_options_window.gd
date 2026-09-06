class_name GameOptionsWindow
extends PanelContainer
## The Game Options screen (manual p073-077): six named save slots. This is where
## the original saves and loads a single-player game. PR A wires SAVE (write the
## current command log to a slot); LOAD from here / the start menu is PR B.
##
## Built in code (repo convention), shown as a centered modal overlay. Opened from
## the in-game menu's "Game Options" button.

signal Closed

var _rows: Array = []   # per slot: { "name": LineEdit, "state": Label }


func _ready() -> void:
	name = "GameOptionsWindow"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(440, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

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
			state.text = "Slot %d: %s (Day %d)" % [i + 1, s["name"], s["day"]]
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
	SaveManager.Save(slot, nm)
	_refresh()
