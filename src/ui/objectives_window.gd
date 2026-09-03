class_name ObjectivesWindow
extends PanelContainer
## frontend/ObjectivesWindow.cs - THE OBJECTIVES WINDOW, manual p136-p137, Fig. 3.84.
## "No matter which side you're playing, this window shows you the current
## status of ALL THREE victory conditions FOR EACH SIDE." Opened with ALT-H or
## from the agent's Objectives command (Fig. 3.83). Built in code: the label
## text and the met/unmet state both come from VictoryManager.

var _rows: VBoxContainer


func Setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(160, 120)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.97)
	sb.border_color = Color(0.40, 0.62, 0.92, 0.85)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "Objectives"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close window."
	close.pressed.connect(queue_free)
	header.add_child(close)

	root.add_child(HSeparator.new())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	root.add_child(_rows)

	Refresh()


func Refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()

	var galaxy: Array = GameState.ActiveGalaxy

	for f in FactionRegistry.Playable:
		var bracket := Label.new()
		bracket.text = "Status of victory conditions for %s" % f.DisplayName
		bracket.add_theme_font_size_override("font_size", 13)
		bracket.add_theme_color_override("font_color", Color(0.62, 0.72, 0.88))
		_rows.add_child(bracket)

		for entry in VictoryManager.StatusFor(f, galaxy):
			var label: String = entry[0]
			var met: bool = entry[1]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			# The figure carries an icon per row; no portrait art exists yet, so
			# this is a met/unmet marker in the same column.
			var mark := Label.new()
			mark.text = "●" if met else "○"
			mark.custom_minimum_size = Vector2(22, 0)
			mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45) if met else Color(0.55, 0.60, 0.70))
			row.add_child(mark)

			var text := Label.new()
			text.text = label
			text.add_theme_font_size_override("font_size", 15)
			text.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85) if met else Color(0.92, 0.94, 1.0))
			row.add_child(text)

			_rows.add_child(row)

		_rows.add_child(HSeparator.new())

	if VictoryManager.IsOver():
		var over := Label.new()
		over.text = "%s has won." % VictoryManager.Winner.DisplayName
		over.add_theme_font_size_override("font_size", 17)
		over.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		_rows.add_child(over)

	reset_size()
