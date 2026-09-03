class_name GidKey
extends PanelContainer
## frontend/GidKey.cs - the GID key: what each marker size means for the active
## mode, plus the faction color legend. Sits on the map, draggable, and stows to
## the taskbar strip like every other panel.

var _title: Label
var _tierRows: VBoxContainer
var _body: VBoxContainer
var _collapseBtn: Button
var _collapsed: bool = false
var _stowed: bool = false     # hidden, with a button on the taskbar strip

var _dragging: bool = false
var _dragOffset: Vector2
var _userMoved: bool = false  # once dragged, stop re-snapping to the corner

const Margin := 24

# The taskbar strip down the right-hand edge (TaskbarPanel, 150 wide).
const SidebarWidth := 150

const SwatchWidth := 54   # keeps every row's text left-aligned
const SwatchCap := 34     # panel swatches shrink; map markers don't

# MINIMISES TO THE TASKBAR STRIP, like every other panel in the game.
var _taskbarBtn: Button = null


func Setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # so the panel can catch drags
	# Anchored top-LEFT deliberately even though it spawns on the right: plain
	# viewport coordinates keep the drag math and clamping simple.
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.94)
	sb.border_color = Color(0.40, 0.62, 0.92, 0.85)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # let drags fall through to the panel
	add_child(root)

	# TITLE ROW, with the collapse control on the right of it.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)

	_title = Label.new()
	_title.text = ""
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	_collapseBtn = Button.new()
	_collapseBtn.text = "_"
	_collapseBtn.custom_minimum_size = Vector2(24, 20)
	_collapseBtn.flat = true
	_collapseBtn.tooltip_text = "Collapse"
	_collapseBtn.focus_mode = Control.FOCUS_NONE
	_collapseBtn.add_theme_font_size_override("font_size", 14)
	_collapseBtn.pressed.connect(ToggleCollapsed)
	header.add_child(_collapseBtn)

	# Everything below the title collapses as one.
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 2)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_body)

	_tierRows = VBoxContainer.new()
	_tierRows.add_theme_constant_override("separation", 0)
	_tierRows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_tierRows)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(sep)

	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 18)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(legend)

	# Built from the pack - one row per playable faction, then the uncontrolled
	# and unknown states.
	for f in FactionRegistry.Playable:
		legend.add_child(LegendRow("•", f.FactionColor, f.DisplayName))
	legend.add_child(LegendRow("•", Gid.CNeutral(), FactionRegistry.Neutral.DisplayName))
	legend.add_child(LegendRow("+", Gid.CUnexplored(), FactionRegistry.Unknown.DisplayName))

	# STARTS STOWED, on the taskbar rather than on the map. The taskbar button
	# is created on the first Refresh, because UIManager is not reachable yet.
	_stowed = true

	# RE-PIN WHEN THE WINDOW RESIZES.
	get_viewport().size_changed.connect(func() -> void:
		if not _userMoved:
			call_deferred("SnapToCorner"))

	visible = false


## One "<swatch>  <text>" row. Swatch sits in a fixed-width box so the text
## column lines up no matter how big the swatch is.
static func Row(glyph: String, glyphSize: int, color: Color, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var swatch := Label.new()
	swatch.text = glyph
	swatch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swatch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swatch.custom_minimum_size = Vector2(SwatchWidth, 0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_theme_font_size_override("font_size", glyphSize)
	swatch.add_theme_color_override("font_color", color)
	row.add_child(swatch)

	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	row.add_child(lbl)

	return row


static func LegendRow(glyph: String, color: Color, text: String) -> HBoxContainer:
	return Row(glyph, 20, color, text)


## Rebuild the tier rows for a newly-selected mode.
func ShowMode(mode: Gid.GidMode) -> void:
	if mode == null or mode == Gid.DisplayOff:
		visible = false
		return

	_title.text = Gid.TitleFor(mode)

	for child in _tierRows.get_children():
		child.queue_free()

	for tier in mode.Tiers:
		# The zero tier is a bare dot on the map, so show a dot here too.
		var bare: bool = tier.FlareSize == 0
		var glyph: String = "•" if bare else "+"
		var size_: int = 14 if bare else mini(tier.FlareSize, SwatchCap)
		_tierRows.add_child(Row(glyph, size_, Color(0.95, 0.97, 1.0), tier.LabelText))

	visible = not _stowed

	# Deferred until now because Setup() runs before UIManager can be found.
	if _stowed and _taskbarBtn == null:
		var ui: UIManager = get_tree().root.find_child("UIManager", true, false) as UIManager
		if ui != null:
			_taskbarBtn = ui.AddToTaskbar(_title.text if _title.text.length() > 0 else "Map Key", Restore)
		else:
			_stowed = false   # no taskbar - do not vanish
			visible = true

	# The panel resizes to whatever the new mode's rows need, so re-snap after
	# layout settles - deferred, because Size is stale until then.
	if not _userMoved:
		call_deferred("SnapToCorner")


## PINNED JUST LEFT OF THE TASKBAR SIDEBAR, not jammed into the corner.
func SnapToCorner() -> void:
	var view: Vector2 = get_viewport_rect().size
	position = Vector2(view.x - SidebarWidth - Margin - size.x, Margin)


func ToggleCollapsed() -> void:
	var ui: UIManager = get_tree().root.find_child("UIManager", true, false) as UIManager
	if ui == null:
		# No taskbar to dock into - fall back to the old in-place collapse.
		_collapsed = not _collapsed
		_body.visible = not _collapsed
		reset_size()
		if not _userMoved:
			call_deferred("SnapToCorner")
		return

	_stowed = true
	visible = false
	_taskbarBtn = ui.AddToTaskbar(_title.text if _title.text.length() > 0 else "Map Key", Restore)


func Restore() -> void:
	var ui: UIManager = get_tree().root.find_child("UIManager", true, false) as UIManager
	if ui != null:
		ui.RemoveFromTaskbar(_taskbarBtn)
	_taskbarBtn = null

	# Comes back expanded - it was put away deliberately.
	_stowed = false
	_collapsed = false
	_body.visible = true
	visible = true

	reset_size()
	if not _userMoved:
		call_deferred("SnapToCorner")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_userMoved = true
			_dragOffset = get_global_mouse_position() - global_position
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var target: Vector2 = get_global_mouse_position() - _dragOffset
		# Keep at least a corner on screen so it can't be lost off an edge.
		var view: Vector2 = get_viewport_rect().size
		target.x = clampf(target.x, -size.x + 60, view.x - 60)
		target.y = clampf(target.y, 0, view.y - 40)
		global_position = target
		accept_event()
