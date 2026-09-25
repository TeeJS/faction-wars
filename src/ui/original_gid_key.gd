extends Control
## THE GID KEY AS THE ORIGINAL DRAWS IT (TeeJ, 2026-09-25: "the default opening
## location for this should be somewhere it's visible, and we should ALSO
## re-add the weird button for it from the original, and match the UI, and it
## should re-open to its last location if moved"). Under the Command Center
## frame, with the original's pieces in the art set; measured on TeeJ's
## screenshots of the original, both sides, every picture matched to the pixel:
##   - CLOSED, the key is its small button on the map's top-left corner
##     (STRATEGY 10168, the key in miniature; the original shows its top-left
##     29x23) at frame (56,51) for the Alliance, (114,51) for the Empire.
##     While the key is open the button is not shown.
##   - OPEN, a 180-wide box - the original's pop-up box: grey (59,59,59) over
##     the map, a two-pixel rim, grey outside and white inside, solid along
##     the top and bottom and dotted down the sides - first opened at frame
##     (85,58) for the Alliance, (150,120) for the Empire, then wherever it was
##     last dragged to. The mode's title across the top, Arial 14, the close
##     box (title_close) at (163,3); one row per tier, 20 apart from y 20, the
##     grey GID star (gid/unexplored.<tier>) at x 7 and the tier's name at
##     x 26, Arial 14; two white rows under them; then the legend, Arial 11:
##     the sides' marks (9x9) at x 7 with their short names at x 25, neutral
##     and unexplored at x 85 / 82 with theirs at x 105.
## Preloaded by path (a new class_name can lag the editor's class cache).

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

## In the frame's pixels.
const Layout := {
	"alliance": {"key": Vector2(85, 58), "closed": Vector2(56, 51)},
	"empire": {"key": Vector2(150, 120), "closed": Vector2(114, 51)},
}
const Width := 180
const FirstRow := 20
const Pitch := 20
const LegendHeight := 35
const ClosedPart := Rect2(1, 1, 29, 23)   # the part of 10168 the original shows
const Fill := Color(59 / 255.0, 59 / 255.0, 59 / 255.0, 0.85)
const Outer := Color(192 / 255.0, 192 / 255.0, 192 / 255.0)
const Inner := Color(1, 1, 1)
const RowPx := 14.0
const LegendPx := 11.0

## Where each side's key was last left, in frame pixels, for the session.
static var LastAt: Dictionary = {}

var Side: String = ""
var S: float = 1.0
var Origin: Vector2 = Vector2.ZERO
var IsOpen: bool = false
var _box: Control
var _rows: Control
var _title: Label
var _legend: Control
var _closed: TextureButton
var _dock: Button = null
var _mode: Gid.GidMode = null
var _dragging := false
var _grab := Vector2.ZERO


## The pieces the original's key is made of, all in the art set.
static func CanBuild(side: String) -> bool:
	return Layout.has(side) and Art.WindowPicture("gid_key_closed") != null \
		and Art.ButtonIcon("title_close") != null and Art.GidStar("unexplored", "big") != null


func Build(side: String, s: float, origin: Vector2) -> void:
	Side = side
	S = s
	Origin = origin
	name = "OriginalGidKey"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The closed key: its small button.
	_closed = TextureButton.new()
	_closed.name = "KeyButton"
	var part := AtlasTexture.new()
	part.atlas = Art.WindowPicture("gid_key_closed")
	part.region = ClosedPart
	_closed.texture_normal = part
	_closed.ignore_texture_size = true
	_closed.stretch_mode = TextureButton.STRETCH_SCALE
	_closed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_closed.position = Origin + (Layout[side]["closed"] as Vector2) * S
	_closed.size = ClosedPart.size * S
	_closed.tooltip_text = "Open the key"
	_closed.pressed.connect(Open)
	add_child(_closed)

	# The open key.
	_box = Control.new()
	_box.name = "Key"
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_box.draw.connect(_draw_box)
	_box.gui_input.connect(_box_input)
	add_child(_box)
	_title = _text(_box, "", 0, 4.25, Width, RowPx, HORIZONTAL_ALIGNMENT_CENTER)
	var close := TextureButton.new()
	close.name = "Close"
	close.texture_normal = Art.ButtonIcon("title_close")
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_SCALE
	close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close.position = Vector2(163, 3) * S
	close.size = Vector2(14, 14) * S
	close.pressed.connect(Close)
	_box.add_child(close)
	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_rows)
	_legend = Control.new()
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_legend)
	# Starts closed (its button on the map), as the plain key starts stowed.
	IsOpen = false
	_show_state()


## A tier count's key: its title, a row per tier, and the legend under them.
func ShowMode(mode: Gid.GidMode) -> void:
	_mode = mode
	var off: bool = mode == null or mode == Gid.DisplayOff
	if off:
		_box.visible = false
		_closed.visible = false
		return
	_title.text = Gid.TitleFor(mode)
	for c in _rows.get_children():
		c.queue_free()
	var n := 0
	for tier in mode.Tiers:
		var y: float = FirstRow + n * Pitch
		_picture(_rows, Art.GidStar("unexplored", Gid.FlareName(tier.FlareSize)), 7, y)
		_text(_rows, tier.LabelText, 26, y + 3, Width - 30, RowPx)
		n += 1
	_build_legend(FirstRow + n * Pitch)
	_box.size = Vector2(Width, FirstRow + n * Pitch + LegendHeight) * S
	_box.queue_redraw()
	_show_state()
	if not IsOpen:
		_redock()


func _build_legend(rule: float) -> void:
	_rule = rule
	for c in _legend.get_children():
		c.queue_free()
	var row := 0
	for f in FactionRegistry.Playable:
		_picture(_legend, Art.WindowPicture("gid_key_%s" % f.ArtSkin), 7, rule + 5 + row * 15)
		_text(_legend, f.ShortName, 25, rule + 8 + row * 16, 58, LegendPx)
		row += 1
	_picture(_legend, Art.WindowPicture("gid_key_neutral"), 85, rule + 5)
	_text(_legend, FactionRegistry.Neutral.DisplayName, 105, rule + 8, 72, LegendPx)
	_picture(_legend, Art.WindowPicture("gid_key_unexplored"), 82, rule + 20)
	_text(_legend, FactionRegistry.Unknown.DisplayName, 105, rule + 24, 72, LegendPx)


var _rule: float = 100.0


func Open() -> void:
	IsOpen = true
	var at: Vector2 = LastAt.get(Side, Layout[Side]["key"])
	_box.position = Origin + at * S
	_show_state()
	_undock()


func Close() -> void:
	IsOpen = false
	_show_state()
	_redock()


func _show_state() -> void:
	var off: bool = _mode == null or _mode == Gid.DisplayOff
	_box.visible = IsOpen and not off
	_closed.visible = not IsOpen and not off


## The sector column's "Loyalty to ..." button stays a way back to the key
## while it is closed (UIManager places it).
func _redock() -> void:
	if _dock != null:
		return
	var ui: UIManager = get_tree().root.find_child("UIManager", true, false) as UIManager if is_inside_tree() else null
	if ui != null:
		_dock = ui.AddToTaskbar(_title.text if not _title.text.is_empty() else "Map Key", Open)


func _undock() -> void:
	var ui: UIManager = get_tree().root.find_child("UIManager", true, false) as UIManager
	if ui != null and _dock != null:
		ui.RemoveFromTaskbar(_dock)
	_dock = null


func _box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_grab = _box.get_global_mouse_position() - _box.global_position
		if not event.pressed:
			LastAt[Side] = (_box.position - Origin) / S
		_box.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var view: Vector2 = get_viewport_rect().size
		var to: Vector2 = _box.get_global_mouse_position() - _grab
		to.x = clampf(to.x, 0.0, view.x - _box.size.x)
		to.y = clampf(to.y, 0.0, view.y - _box.size.y)
		_box.global_position = to
		LastAt[Side] = (_box.position - Origin) / S
		_box.accept_event()


## The original's pop-up box at the frame's scale: the fill, the two-pixel rim
## (dotted down the sides), and the two white rows over the legend.
func _draw_box() -> void:
	var r := Rect2(Vector2.ZERO, _box.size)
	var p: float = S
	_box.draw_rect(r, Fill)
	for ring in 2:
		var c: Color = Outer if ring == 0 else Inner
		var o: float = ring * p
		_box.draw_rect(Rect2(o, o, r.size.x - 2 * o, p), c)
		_box.draw_rect(Rect2(o, r.size.y - o - p, r.size.x - 2 * o, p), c)
		var y: float = o + 2 * p
		while y < r.size.y - o - p:
			_box.draw_rect(Rect2(o, y, p, p), c)
			_box.draw_rect(Rect2(r.size.x - o - p, y, p, p), c)
			y += 2 * p
	_box.draw_rect(Rect2(p, _rule * p, r.size.x - 2 * p, 2 * p), Inner)


func _picture(parent: Control, tex: Texture2D, x: float, y: float) -> void:
	if tex == null:
		return
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = Vector2(x, y) * S
	t.size = tex.get_size() * S
	parent.add_child(t)


## White Arial text whose capitals start at `cap_top` (the original's Arial
## puts them 0.19 of the size below the line's top).
func _text(parent: Control, text: String, x: float, cap_top: float, w: float, px: float,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", OUI.Face(false))
	l.add_theme_font_size_override("font_size", roundi(px * S))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.position = Vector2(x, cap_top - 0.19 * px) * S
	l.size = Vector2(w, px * 1.4) * S
	parent.add_child(l)
	return l
