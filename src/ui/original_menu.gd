extends RefCounted
## THE ORIGINAL'S POP-UP MENUS (TeeJ, 2026-09-24: the character menu "is
## missing the white background and color accent on the command expansion
## carrot, and it appears too opaque"; "the pull down speed menu does not
## match the original"). Measured on his screenshots of the original's
## character menu and Speed Control menu, in original pixels:
##   - a dark grey box, (59,59,59), the map faintly through it;
##   - a two-pixel frame, grey (192) outside and white inside, solid along the
##     top and bottom and dotted - every other pixel - down the sides;
##   - rows 20 pixels apart, Arial 14 in white, a greyed item (128,128,128);
##   - an item that opens a submenu marked at the left by a caret pointing
##     left, 8x11, in the side's colour at half strength (the Empire's
##     (0,128,0), measured; the Alliance's the same rule, INFERRED); the
##     items' text 27 pixels in, the caret 10;
##   - the Speed Control's menu: each speed's own bar icon (speed_bars.<side>.
##     <n>, the Speed Control's bitmaps, matched pixel for pixel) 6 pixels in,
##     its name 23 in, and the speed in force in the side's colour.
##   - the item under the mouse in the side's colour, nothing behind it (the
##     Alliance's agent menu, red: a capture of the original, open-rebellion's
##     0896; the Empire's green, INFERRED);
##   - a ticked item's mark, the original's own (STRATEGY 11902, 20x20, white
##     with a black shadow, windows/menu_check) 4 pixels in, the text still 27
##     in (the agent menu, manual p077 Fig 3.17; captures 0620 / 0896).
## The Speed Control's menu keeps a faint band under the mouse (ours): its
## speed in force is already the side's colour.
##
## Every PopupMenu in play is styled as it enters the tree (UIManager hooks
## SceneTree.node_added), so no window builds its menu differently. Preloaded
## by path: a new script can lag the editor's class cache.

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

const K := OUI.K
const Fill := Color(59 / 255.0, 59 / 255.0, 59 / 255.0, 0.85)
const Outer := Color(192 / 255.0, 192 / 255.0, 192 / 255.0)
const Inner := Color(1, 1, 1)
const Grey := Color(128 / 255.0, 128 / 255.0, 128 / 255.0)
const Hover := Color(1, 1, 1, 0.12)
const Pitch := 20        # a row
const FontPx := 14
const TextX := 27        # an item's text, from the frame's outside
const CaretX := 10       # the submenu caret
const CheckX := 4        # a ticked item's mark (its 20x20 bitmap's left)
const SpeedIconX := 6    # the speed menu's bar icon
const SpeedTextX := 23   # and its name
const CaretRows := [1, 2, 4, 5, 7, 8, 7, 5, 4, 2, 1]   # the caret, right-aligned

static var _caret: Dictionary = {}   # side -> texture
static var _tick: Texture2D = null
static var _tickInk := Rect2i()      # the drawn part of the tick's 20x20 bitmap
static var _blank: Texture2D = null


## The original's menus when its window art is in use.
static func Enabled() -> bool:
	return Art.ButtonIcon("title_close") != null


## THE BOX: the fill and the two-pixel frame, dotted down the sides.
class MenuBox extends StyleBox:
	func _init() -> void:
		content_margin_left = 2 * K
		content_margin_right = 2 * K
		content_margin_top = K
		content_margin_bottom = K

	func _draw(ci: RID, rect: Rect2) -> void:
		var rs := RenderingServer
		rs.canvas_item_add_rect(ci, rect, Fill)
		var p: Vector2 = rect.position
		var w: float = rect.size.x
		var h: float = rect.size.y
		for ring in 2:
			var c: Color = Outer if ring == 0 else Inner
			var o: float = ring * K
			rs.canvas_item_add_rect(ci, Rect2(p + Vector2(o, o), Vector2(w - 2 * o, K)), c)
			rs.canvas_item_add_rect(ci, Rect2(p + Vector2(o, h - o - K), Vector2(w - 2 * o, K)), c)
			var y: float = o + 2 * K
			while y < h - o - K:
				rs.canvas_item_add_rect(ci, Rect2(p + Vector2(o, y), Vector2(K, K)), c)
				rs.canvas_item_add_rect(ci, Rect2(p + Vector2(w - o - K, y), Vector2(K, K)), c)
				y += 2 * K


## Dress a menu in the original's style. Its submenu carets go on each time it
## opens, when its items are all there.
static func Style(menu: PopupMenu) -> void:
	if menu.has_meta("original_menu"):
		return
	menu.set_meta("original_menu", true)
	menu.transparent_bg = true
	menu.transparent = true
	menu.add_theme_stylebox_override("panel", MenuBox.new())
	menu.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	var face: Font = OUI.Face()
	var size: int = FontPx * K
	menu.add_theme_font_override("font", face)
	menu.add_theme_font_size_override("font_size", size)
	menu.add_theme_color_override("font_color", Color.WHITE)
	menu.add_theme_color_override("font_hover_color", OUI.SideColor(GameSettings.PlayerFaction))
	var tick: Texture2D = Tick()
	if tick != null:
		for icon in ["checked", "checked_disabled"]:
			menu.add_theme_icon_override(icon, tick)
		for icon in ["unchecked", "unchecked_disabled"]:
			menu.add_theme_icon_override(icon, _Blank())
	menu.add_theme_color_override("font_disabled_color", Grey)
	menu.add_theme_color_override("font_separator_color", Grey)
	menu.add_theme_constant_override("v_separation", maxi(0, Pitch * K - ceili(face.get_height(size))))
	menu.add_theme_constant_override("item_end_padding", 2 * K)
	# The original's caret is on the left; Godot's arrow on the right goes.
	menu.add_theme_icon_override("submenu", _Blank())
	menu.add_theme_icon_override("submenu_mirrored", _Blank())
	menu.about_to_popup.connect(_Carets.bind(menu))
	_Carets(menu)


## The caret on every item that opens a submenu, and the text column: 27
## pixels in whether a caret or a tick is there or not.
static func _Carets(menu: PopupMenu) -> void:
	var caret: Texture2D = Caret(GameSettings.PlayerFaction)
	var any := false
	var ticks := false
	for i in menu.item_count:
		if menu.get_item_submenu_node(i) != null:
			menu.set_item_icon(i, caret)
			any = true
		if menu.is_item_checkable(i):
			ticks = true
	var inner: int = 2   # the frame, which is the panel's margin
	if ticks and menu.has_theme_icon_override("checked"):
		# The tick's column: Godot puts it first and every item's text after it.
		var ink: int = CheckX + _tickInk.position.x
		menu.add_theme_constant_override("item_start_padding", (ink - inner) * K)
		menu.add_theme_constant_override("h_separation", (TextX - ink - _tickInk.size.x) * K)
	elif any:
		menu.add_theme_constant_override("item_start_padding", (CaretX - inner) * K)
		menu.add_theme_constant_override("h_separation", (TextX - CaretX - CaretRows.max()) * K)
	else:
		menu.add_theme_constant_override("item_start_padding", (TextX - inner) * K)


## The tick at the drawn scale, cut to what it draws (its 20x20 bitmap is
## taller than a row's text, and a taller icon would make its row taller).
## Null without it in the art set (before exporter 2.4.5).
static func Tick() -> Texture2D:
	if _tick != null:
		return _tick
	var pic: Texture2D = Art.WindowPicture("menu_check")
	var img: Image = pic.get_image() if pic != null else null
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	_tickInk = img.get_used_rect()
	if _tickInk.size.x <= 0:
		return null
	_tick = Art.Scaled(ImageTexture.create_from_image(img.get_region(_tickInk)), K)
	return _tick


## The submenu caret in a side's colour at half strength, at the drawn scale;
## `lit`, at full strength (the GID control's menu, its open category's).
static func Caret(side: Faction, lit: bool = false) -> Texture2D:
	var key: String = OUI.Side(side) + (".lit" if lit else "")
	if _caret.has(key):
		return _caret[key]
	var full: Color = OUI.SideColor(side)
	var c := full if lit else Color(full.r * 0.5, full.g * 0.5, full.b * 0.5, 1.0)
	var w: int = CaretRows.max()
	var img := Image.create(w, CaretRows.size(), false, Image.FORMAT_RGBA8)
	for y in CaretRows.size():
		for x in range(w - int(CaretRows[y]), w):
			img.set_pixel(x, y, c)
	img.resize(w * K, CaretRows.size() * K, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_caret[key] = tex
	return tex


static func _Blank() -> Texture2D:
	if _blank == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		_blank = ImageTexture.create_from_image(img)
	return _blank


# ---- the Speed Control's menu -------------------------------------------------

## The speed menu: one row per speed, its bar icon and its name; the speed in
## force in the side's colour. `pick` is called with the speed chosen. Null
## without the Speed Control's bars.
static func SpeedMenu(side: String, names: Array, pick: Callable) -> PopupPanel:
	if Art.WindowPicture("speed_bars.%s.0" % side) == null:
		return null
	var panel := PopupPanel.new()
	panel.name = "OriginalSpeedMenu"
	panel.transparent_bg = true
	panel.transparent = true
	panel.add_theme_stylebox_override("panel", MenuBox.new())
	var face: Font = OUI.Face()
	var size: int = FontPx * K
	var widest: float = 0.0
	for n in names:
		widest = maxf(widest, face.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var rowW: float = ceilf(widest / K) + SpeedTextX + 3 - 2   # inside the frame
	var rows := Control.new()
	rows.name = "Rows"
	rows.custom_minimum_size = Vector2(rowW, names.size() * Pitch) * K
	panel.add_child(rows)
	var band := StyleBoxFlat.new()
	band.bg_color = Hover
	for i in names.size():
		var row := Button.new()
		row.name = "Speed%d" % i
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.position = Vector2(0, i * Pitch) * K
		row.size = Vector2(rowW, Pitch) * K
		for st in ["normal", "pressed", "focus", "disabled"]:
			row.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		row.add_theme_stylebox_override("hover", band)
		row.add_theme_stylebox_override("hover_pressed", band)
		var icon := TextureRect.new()
		icon.name = "Bars"
		icon.texture = OUI.Pic("speed_bars.%s.%d" % [side, i])
		icon.position = Vector2(SpeedIconX - 2, 1) * K
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := OUI.Text(row, str(names[i]), SpeedTextX - 2, 3, rowW - SpeedTextX, Pitch - 3, FontPx, Color.WHITE,
			HORIZONTAL_ALIGNMENT_LEFT, false, "Name")
		label.clip_text = false
		var speed: int = i
		row.pressed.connect(func() -> void:
			panel.hide()
			pick.call(speed))
		rows.add_child(row)
	return panel


## The speed in force in the side's colour, the rest white.
static func MarkSpeed(panel: PopupPanel, current: int) -> void:
	var rows: Node = panel.get_node_or_null("Rows")
	if rows == null:
		return
	var sideColor: Color = OUI.SideColor(GameSettings.PlayerFaction)
	for row in rows.get_children():
		var i: int = int(str(row.name).trim_prefix("Speed"))
		var label: Label = row.get_node("Name")
		label.add_theme_color_override("font_color", sideColor if i == current else Color.WHITE)
