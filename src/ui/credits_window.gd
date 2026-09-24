class_name CreditsWindow
extends PanelContainer
## "View credits" on the Shuttle Cockpit (manual p021, Fig. 2.2). The lines are
## the pack's (`menu.credits`, else `credits`, in pack.json) - who made the setting is content,
## not engine. Built in code (repo convention), shown as a centered modal overlay.

func _init(title: String = "", lines: Array[String] = []) -> void:
	name = "CreditsWindow"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(420, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var head := Label.new()
	head.name = "Title"
	head.text = "Credits" if title.is_empty() else "%s - Credits" % title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 22)
	box.add_child(head)

	var body := VBoxContainer.new()
	body.name = "Lines"
	body.add_theme_constant_override("separation", 4)
	for line in lines:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
	if lines.is_empty():
		var l := Label.new()
		l.text = "(this pack declares no credits)"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
	box.add_child(body)

	var close := Button.new()
	close.name = "BtnClose"
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	box.add_child(close)


func _ready() -> void:
	# Centre once the contents have a size.
	await get_tree().process_frame
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
