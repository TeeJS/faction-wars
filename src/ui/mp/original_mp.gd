extends Control
## The head-to-head screens in the original's look (TeeJ, 2026-09-25: "the head
## to head menus need to be matched up"): the original's screen (COMMON.DLL
## 10100-10103, exporter 2.4.7) fills ours with its aspect kept, like the
## Cockpit, with its parts at the places measured on TeeJ's screenshots of the
## original, and its three buttons along the bottom - back, forward (the
## checkmark on Multiplayer Options), cancel. Those stand in for the plain
## screen's bottom bar: they emit its signals and mirror its state, so each
## screen's own code runs unchanged. Only with the art imported: the plain
## screens stay otherwise.
##
## Preloaded by path: a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

const W := 640
const H := 480
## The original's text colours (measured): green, the chosen red, the list's
## grey.
const Green := Color(0, 1, 0)
const Red := Color(1, 0, 0)
const Grey := Color(120 / 255.0, 120 / 255.0, 120 / 255.0)
## The bottom buttons (89 x 26), the same on every screen (matched to the
## pixel on TeeJ's screenshots): back, forward, cancel.
const ButtonY := 442
const BackX := 141
const NextX := 290
const CancelX := 437

var _s: float = 1.0
var _canvas: Control
## Every part: [its Control, its rect in the original's pixels, its font size
## in the original's pixels (0 for none)], re-placed when the window resizes.
var _items: Array = []
var _bar: MpBottomBar
var _back: TextureButton
var _next: TextureButton
var _cancel: TextureButton


## True when the player imported the art this screen is made of.
static func CanBuild(screen: String) -> bool:
	return Art.Screen(screen) != null and Art.ButtonIcon("mp_next") != null \
		and Art.ButtonIcon("mp_back") != null and Art.ButtonIcon("mp_cancel") != null


## Puts the original's screen over `mp`: its plain parts are hidden (the bottom
## bar too - its signals still run the screen) and the original's picture and
## buttons go in their place. The screen then adds its own parts. A screen
## whose plain form has no bottom bar (Locate Session, a dialog) gets one,
## hidden, to wire its buttons to: `Bar()`.
static func Dress(mp: MpScreen, screen: String) -> Control:
	for c in mp.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	var bar: MpBottomBar = mp.get_node_or_null("%BottomBar") as MpBottomBar
	if bar == null:
		bar = (load("res://src/ui/mp/MpBottomBar.tscn") as PackedScene).instantiate() as MpBottomBar
		bar.name = "OriginalBar"
		bar.visible = false
		mp.add_child(bar)
	var look: Control = (load("res://src/ui/mp/original_mp.gd") as GDScript).new()
	look.name = "Original"
	mp.add_child(look)
	look.call("_setup", bar, screen)
	return look


## The bottom bar the original's three buttons stand in for.
func Bar() -> MpBottomBar:
	return _bar


func _setup(bar: MpBottomBar, screen: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.name = "Black"
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	Place(Art.Screen(screen), 0, 0, "Plate")
	_bar = bar
	_back = PicButton("mp_back", BackX, ButtonY, "Back")
	_next = PicButton("mp_next", NextX, ButtonY, "Next")
	_cancel = PicButton("mp_cancel", CancelX, ButtonY, "Cancel")
	_cancel.tooltip_text = "Cancel: return to the Shuttle Cockpit."
	_back.pressed.connect(func() -> void: _bar.previous.emit())
	_next.pressed.connect(func() -> void: _bar.proceed.emit())
	_cancel.pressed.connect(func() -> void: _bar.cancel.emit())
	_bar.changed.connect(_mirror)
	_mirror()
	resized.connect(_layout)
	_layout()


## The bottom bar's state on the original's buttons: back greyed where the
## plain screen has no Previous (the original's first screen greys it), the
## forward arrow greyed while Proceed waits, and the checkmark where Proceed
## starts the game.
func _mirror() -> void:
	var prev: Button = _bar.get_node("%BtnPrevious")
	var proceed: Button = _bar.get_node("%BtnProceed")
	_back.disabled = not prev.visible or prev.disabled
	_back.tooltip_text = prev.text.trim_prefix("<").strip_edges() if prev.visible else ""
	var pic := "mp_start" if proceed.text == "Start Game" else "mp_next"
	if _next.texture_normal != Art.ButtonIcon(pic):
		_skin(_next, pic)
	_next.disabled = proceed.disabled or not proceed.visible
	_next.tooltip_text = proceed.tooltip_text if not proceed.tooltip_text.is_empty() \
		else ("Start the game." if pic == "mp_start" else "Proceed.")


func _layout() -> void:
	var view: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	_s = minf(view.x / W, view.y / H)
	_canvas.position = ((view - Vector2(W, H) * _s) / 2.0).floor()
	for it in _items:
		var c: Control = it[0]
		if not is_instance_valid(c):
			continue
		var r: Rect2 = it[1]
		c.position = r.position * _s
		c.size = r.size * _s
		if float(it[2]) > 0.0:
			c.add_theme_font_size_override("font_size", roundi(float(it[2]) * _s))


## Puts a part on the screen at its rect in the original's pixels.
func Add(c: Control, rect: Rect2, px: float = 0.0) -> void:
	_canvas.add_child(c)
	_track(c, rect, px)


func _track(c: Control, rect: Rect2, px: float) -> void:
	_items.append([c, rect, px])
	c.position = rect.position * _s
	c.size = rect.size * _s
	if px > 0.0:
		c.add_theme_font_size_override("font_size", roundi(px * _s))


# ---- the parts, in the original's pixels -------------------------------------

func Place(tex: Texture2D, x: float, y: float, node_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Add(r, Rect2(Vector2(x, y), tex.get_size() if tex != null else Vector2.ZERO))
	return r


## Swaps a placed picture, its size following.
func Repicture(r: TextureRect, tex: Texture2D) -> void:
	r.texture = tex
	for it in _items:
		if it[0] == r:
			it[1] = Rect2((it[1] as Rect2).position, tex.get_size() if tex != null else Vector2.ZERO)
	_layout()


## One of the original's picture buttons (buttons/<pic>, .pressed, .disabled).
func PicButton(pic: String, x: float, y: float, node_name: String) -> TextureButton:
	var b := TextureButton.new()
	b.name = node_name
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	_skin(b, pic)
	Add(b, Rect2(Vector2(x, y), b.texture_normal.get_size() if b.texture_normal != null else Vector2(89, 26)))
	return b


func _skin(b: TextureButton, pic: String) -> void:
	b.texture_normal = Art.ButtonIcon(pic)
	b.texture_pressed = Art.ButtonIcon(pic, "pressed")
	b.texture_disabled = Art.ButtonIcon(pic, "disabled")


## A line of text whose capital letters start at `cap_top` (Arial's capitals
## sit 0.19 of the size below the top of its line).
func Text(t: String, x: float, cap_top: float, w: float, px: float, color: Color,
		align: HorizontalAlignment, node_name: String, bold: bool = false) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = t
	l.horizontal_alignment = align
	l.clip_text = false
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_override("font", OUI.Face(bold))
	l.add_theme_color_override("font_color", color)
	Add(l, Rect2(x, cap_top - 0.19 * px, w, px * 1.4), px)
	return l


## The screen's own typing box moved onto the original's (its signals and
## unique name kept), with no box of its own - the original's is drawn on its
## screen: the text from x in `color`, capitals from cap_top, the caret white
## (measured). The text is centred on the box's height, so the box is the
## font's height (Arial: ascent 0.905, descent 0.212) with equal room round it.
func Field(f: LineEdit, x: float, cap_top: float, w: float, px: float, color: Color) -> LineEdit:
	f.reparent(_canvas, false)
	f.add_theme_font_override("font", OUI.Face(false))
	f.add_theme_color_override("font_color", color)
	f.add_theme_color_override("font_placeholder_color", Color(color, 0.35))
	f.add_theme_color_override("caret_color", Color.WHITE)
	f.add_theme_color_override("selection_color", Color(color, 0.3))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "focus", "read_only"]:
		f.add_theme_stylebox_override(st, empty)
	f.custom_minimum_size = Vector2.ZERO
	f.size_flags_horizontal = Control.SIZE_FILL
	_track(f, Rect2(x, cap_top - 0.19 * px - Pad, w, 1.117 * px + 2 * Pad), px)
	return f


## The room above and below a typing box's text.
const Pad := 3.0


## The screen's own label moved onto the original's, restyled like Text().
func Line(l: Label, x: float, cap_top: float, w: float, px: float, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	l.reparent(_canvas, false)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2.ZERO
	l.add_theme_font_override("font", OUI.Face(false))
	l.add_theme_color_override("font_color", color)
	_track(l, Rect2(x, cap_top - 0.19 * px, w, px * 1.4), px)
	return l
