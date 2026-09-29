extends RefCounted
## THE MAP SCREEN'S SHELL IN THE PACK'S LOOK (docs/ww2-look-plan.md, phase 3):
## the command table the map lies on. Every surface stays where it is and does
## what it did; only its dress changes:
##   - the desk under everything, the map's bezel (galaxy_map.gd draws it);
##   - the top strip as an operations strip: the day and speed as a chip, the
##     three monitors as labelled readouts between brass rules, the mode's
##     name in the display face;
##   - the message categories as the dispatch rail (the category on show is
##     the selected drawer; unread mail a brass count, not a yellow glow);
##   - the pinned theatres as the theatre directory (an open theatre reads as
##     selected - ui_manager.gd's poll);
##   - the mode bar and the command row as one console of grouped keys.
## Only for a pack with a look (Look.Active()) and without the Command Center
## frame (the original's art). The theme is put on these surfaces alone: the
## windows keep their own until their phase.
##
## Preloaded by path (as LookHud) from game_manager.gd.

## The strip behind the top readouts, in screen pixels: from just right of the
## day-and-speed chip (which ends at 212 in the look) to the directory's edge,
## the readouts' height (Main.tscn: Resources 0-40).
const StripRect := Rect2(216, 4, 1070, 36)
## The command row's backing (Main.tscn: HBoxContainer, offsets 2..-151, -34..-3).
const ConsoleInset := Vector2(2, 151)


static func Apply(main: Node, ui: Node, map: Node) -> void:
	var theme := Look.GetTheme()
	# Every menu, dialog and tooltip in the look (phase 5).
	Look.InstallPopups(main.get_tree())
	_desk(main)

	# THE OPERATIONS STRIP.
	var strip := Panel.new()
	strip.name = "OpsStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = StripRect.position
	strip.size = StripRect.size
	strip.add_theme_stylebox_override("panel", Look.Edged("chassis_deep", "brass_dim", SIDE_BOTTOM, 1, 0))
	ui.add_child(strip)
	ui.move_child(strip, 0)
	var resources: HBoxContainer = ui.get_node("Resources")
	resources.theme = theme
	var readouts: Array = resources.get_children()
	for i in readouts.size():
		var margin: MarginContainer = readouts[i]
		for l in margin.get_children():
			if l is Label:
				(l as Label).add_theme_font_override("font", Look.F("body"))
				(l as Label).add_theme_font_size_override("font_size", Look.Size("label") + 1)
				(l as Label).add_theme_color_override("font_color", Look.C("text"))
		if i > 0:
			var rule := VSeparator.new()
			rule.name = "Rule%d" % i
			resources.add_child(rule)
			resources.move_child(rule, margin.get_index())
	var clock: PanelContainer = ui.get_node("TimeControls")
	clock.theme = theme
	SpeedState(clock, false)
	var day: Label = main.get_node("%DayLabel")
	day.add_theme_font_override("font", Look.F("display"))
	day.add_theme_font_size_override("font_size", Look.Size("heading"))
	var speed: Label = main.get_node("%SpeedReadout")
	speed.add_theme_font_override("font", Look.F("display"))
	speed.add_theme_font_size_override("font_size", Look.Size("small"))
	speed.add_theme_color_override("font_color", Look.C("text_muted"))
	speed.uppercase = true
	var bar: Node = map.call("Bar")
	if bar != null:
		bar.call("ApplyLook")

	# THE DISPATCH RAIL.
	var comms: PanelContainer = ui.get_node("CommsPanel")
	comms.theme = theme
	comms.theme_type_variation = Look.PANEL
	for btn in comms.get_node("Margin/CommsList").get_children():
		if btn is Button:
			(btn as Button).theme_type_variation = Look.RAIL
			(btn as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT

	# THE THEATRE DIRECTORY.
	var directory: PanelContainer = ui.get_node("TaskbarPanel")
	directory.theme = theme
	directory.theme_type_variation = Look.PANEL
	for pin in (ui.call("PinnedSectors") as Dictionary).values():
		if is_instance_valid(pin):
			PinLook(pin)

	# THE CONSOLE: the command row on its own backing, its keys grouped.
	var row: HBoxContainer = ui.get_node("HBoxContainer")
	var backing := Panel.new()
	backing.name = "ConsoleBacking"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	backing.offset_left = ConsoleInset.x
	backing.offset_right = -ConsoleInset.y
	backing.offset_top = row.offset_top - 2
	backing.offset_bottom = 0
	backing.add_theme_stylebox_override("panel", Look.Edged("chassis_deep", "brass_dim", SIDE_TOP, 1, 0))
	ui.add_child(backing)
	ui.move_child(backing, row.get_index())
	row.theme = theme
	row.add_theme_constant_override("separation", 6)
	for b in row.get_children():
		if b is Button:
			(b as Button).theme_type_variation = Look.COMMAND
	for before in ["AgentButton", "Encyclopedia"]:
		var n: Node = row.get_node_or_null(before)
		if n != null:
			var sep := VSeparator.new()
			sep.name = "Group" + before
			row.add_child(sep)
			row.move_child(sep, n.get_index())

	# The left column's foot: the map key's button and the feedback box.
	for n in ["MapKeyButton", "FeedbackPanel"]:
		var c: Control = ui.get_node_or_null(n)
		if c != null:
			c.theme = theme


## The desk under the whole screen: its texture and the static grain, on a
## canvas layer beneath the map's.
static func _desk(main: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "LookDesk"
	layer.layer = -1
	main.add_child(layer)
	for name in ["desk", "grain"]:
		var tr := TextureRect.new()
		tr.name = name.capitalize()
		tr.texture = Look.Tex(name)
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(tr)


## The day-and-speed chip: steel while the clock runs, the signal band while
## it is paused (an alert state: the war is not moving).
static func SpeedState(clock: PanelContainer, paused: bool) -> void:
	if not Look.Active():
		return
	clock.add_theme_stylebox_override("panel", Look.Box("signal", "", 0, -1, 4) if paused else Look.Box("chassis_deep", "brass_dim", 1, -1, 4))


## A pinned theatre as a directory row.
static func PinLook(pin: Button) -> void:
	pin.theme_type_variation = Look.ROW
	pin.alignment = HORIZONTAL_ALIGNMENT_LEFT


## An open theatre reads as selected in the directory: its row wears the
## pressed style while its window is up.
static func MarkPin(pin: Button, open: bool) -> void:
	if open:
		pin.add_theme_stylebox_override("normal", pin.get_theme_stylebox("pressed"))
		pin.add_theme_stylebox_override("hover", pin.get_theme_stylebox("hover_pressed"))
	else:
		pin.remove_theme_stylebox_override("normal")
		pin.remove_theme_stylebox_override("hover")


## A rail drawer's unread mail: a brass count at its right, the name in the
## text colour - never a glow.
static func Unread(btn: Button, count: int) -> void:
	btn.remove_theme_color_override("font_color")
	btn.modulate = Color.WHITE
	var badge: Label = btn.get_node_or_null("LookUnread")
	if count <= 0:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = Label.new()
		badge.name = "LookUnread"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		badge.offset_left = -34
		badge.offset_right = -6
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", Look.F("display_bold"))
		badge.add_theme_font_size_override("font_size", Look.Size("label"))
		badge.add_theme_color_override("font_color", Look.C("brass"))
		btn.add_child(badge)
	badge.text = str(count)
	badge.visible = true
