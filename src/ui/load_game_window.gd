class_name LoadGameWindow
extends PanelContainer
## The start-menu "Load Game" screen: pick one of the six save slots to restore.
## Loading sets GameSettings.PendingLoadPath and enters Main.tscn, where
## GameManager replays that slot's command log (issue #6, manual p073-077).
## Built in code (repo convention), shown as a centered modal overlay.

signal Cancelled

var _rows: Array = []   # per used slot: { "slot": int, "load": Button }


func _ready() -> void:
	name = "LoadGameWindow"
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
	title.text = "Load Game"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	box.add_child(HSeparator.new())

	var any_used := false
	for s: Dictionary in SaveManager.Slots():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12)
		if s["used"]:
			label.text = "Slot %d: %s (Day %d)" % [int(s["slot"]) + 1, s["name"], int(s["day"])]
			any_used = true
		else:
			label.text = "Slot %d: (empty)" % (int(s["slot"]) + 1)
		row.add_child(label)

		var loadBtn := Button.new()
		loadBtn.text = "Load"
		loadBtn.disabled = not s["used"]
		var slot := int(s["slot"])
		loadBtn.pressed.connect(func() -> void: _load(slot))
		row.add_child(loadBtn)

		box.add_child(row)
		_rows.append({ "slot": slot, "load": loadBtn })

	if not any_used:
		var none := Label.new()
		none.text = "No saved games yet."
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		box.add_child(none)

	box.add_child(HSeparator.new())
	var cancelBtn := Button.new()
	cancelBtn.text = "Cancel"
	cancelBtn.pressed.connect(func() -> void:
		Cancelled.emit()
		queue_free())
	box.add_child(cancelBtn)


## Public so a test can pick a slot without a real button press. Sets the pending
## load path, then enters the game scene; GameManager._ready does the replay.
func _load(slot: int) -> void:
	if not SaveManager.IsUsed(slot):
		return
	GameSettings.PendingLoadPath = SaveManager.SlotPath(slot)
	get_tree().change_scene_to_file("res://Main.tscn")
