extends Control
## THE GALAXY DISPLAY MENU down the Command Center's left-hand column (TeeJ,
## 2026-09-25: "Next I would like to move the mostly empty left hand column
## ... This will completely eliminate the blue bar"). The left of the
## frame, top to bottom, in his order: each GID category under its heading -
## the category's icon and its name, no box - with its modes below it, one
## row each; Manufacturing's three pairs a little apart; then "Loyalty to
## <side>" (the map key, moved from the sector column: it opens and closes
## the key) and Display Off. The shorter lines are the pack's `menu_label`s
## ("Idle" under Fleets) and the side's `loyalty_label_short`, all approved
## by him. The mode on the map in the side's colour.
##
## The column wears the sector column's panel, and the rows its button
## style - the same greys, its hover, its 4px padding, its 14px type - so
## the two columns read as one interface; headings Arial Bold 16 over them;
## the row text 10px right of where it was, the icons at 16px, no rules, and
## 4px more before each heading (TeeJ's refinement, 2026-09-25). The sector column spaces its
## 28px rows 8 apart; 23 rows and 6 headings do not fit 850 that way, so
## these are 22 high and 4 apart - less where a pack's menu is longer, so it
## always fits.
##
## The headings' icons: the side's crest, the sector window's fleet, factory
## and tower (his "planet fleet icon", "planet factory icon", "planet defence
## icon" - the corner icons' glyphs), and for Personnel and Resources a
## person and a currency mark drawn here, in the side's colour (his
## references: a head-and-shoulders silhouette, and the ring with four
## spokes).
## Preloaded by path (a new class_name can lag the editor's class cache).

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

const HeadPx := 16
const RowPx := 14            # the sector column's size of type
const Margin := 6.0
const RowHeight := 22.0      # the most a row gets; less when a menu is longer
const RowGap := 4.0
const HeadHeight := 22.0
const IconSize := 16.0
const Indent := 6.0          # a row's box, in from the headings' icons
const Pad := 4.0             # its text, in from the box: the sector rows' padding
const SectionGap := 15.0     # before each heading (the old rule's 11, plus 4)
const PairGap := 8.0         # between Manufacturing's pairs
const TextColor := Color(0.86, 0.86, 0.86)
## A category's heading icon: the sector window's corner glyph it wears.
const CategoryGlyph := {"loyalty": "mission", "fleets": "fleet", "manufacturing": "manufacturing", "defense": "defenses"}
## Categories whose modes come in pairs, a little apart (TeeJ's list).
const Paired := ["manufacturing"]
const Person := [
	"....###....",
	"...#####...",
	"...#####...",
	"...#####...",
	"....###....",
	"...........",
	"..#######..",
	".#########.",
	".#########.",
	".#########.",
	".#########.",
]
const Currency := [
	"#.........#",
	".#..###..#.",
	"..#######..",
	"..##...##..",
	".##.....##.",
	".##.....##.",
	".##.....##.",
	"..##...##..",
	"..#######..",
	".#..###..#.",
	"#.........#",
]

var _map: GalaxyMap = null
var _side: String = ""
var _rows: Dictionary = {}       # GidMode -> Button
var _off: Button = null
var _key: Button = null
var _painted: Object = null      # the mode last painted as current
var _y: float = 0.0
var _w: float = 0.0
var _rowH: float = RowHeight


func Build(width: float, map: GalaxyMap, on_key: Callable) -> void:
	name = "GidMenu"
	_map = map
	_side = OUI.Side(GameSettings.PlayerFaction)
	_w = width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(width, get_viewport_rect().size.y)
	# The sector column's own panel behind it, so the column and its rows are
	# the same grey as that one (TeeJ: "the background should be the same grey
	# as the right column") - the row boxes are see-through, so it takes both.
	var back := Panel.new()
	back.name = "Back"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = size
	add_child(back)
	back.add_theme_stylebox_override("panel", back.get_theme_stylebox("panel", "PanelContainer"))
	Gid.ActiveMode()   # builds the catalogue if nothing has yet
	var cats: Array = Gid.Categories
	_rowH = _fit_rows(cats, size.y)
	_y = Margin
	for i in cats.size():
		var cat: Gid.GidCategory = cats[i]
		if i > 0:
			_y += SectionGap
		_heading(cat)
		var n := 0
		for mode in cat.Modes:
			_y += PairGap if Paired.has(cat.Id) and n > 0 and n % 2 == 0 else RowGap
			_row(mode)
			n += 1
	_y += SectionGap
	_key = _button("KeyRow", GameSettings.PlayerFaction.LoyaltyLabelShort if GameSettings.PlayerFaction != null else "Map Key")
	_key.tooltip_text = "Open or close the map key"
	_key.pressed.connect(on_key)
	_y += RowGap
	_off = _button("DisplayOff", "Display Off")
	_off.pressed.connect(func() -> void: _map.SetMode(Gid.DisplayOff))
	Repaint()


## The mode on the map in the side's colour, the rest plain.
func Repaint() -> void:
	var now: Object = Gid.ActiveMode()
	_painted = now
	var lit: Color = OUI.SideColor(GameSettings.PlayerFaction)
	for mode in _rows:
		_tint(_rows[mode], lit if mode == now else TextColor)
	if _off != null:
		_tint(_off, lit if now == Gid.DisplayOff else TextColor)


func _process(_delta: float) -> void:
	if Gid.ActiveMode() != _painted:
		Repaint()


## The row for a mode (for tests).
func Row(mode: Gid.GidMode) -> Button:
	return _rows.get(mode, null)


func KeyRow() -> Button:
	return _key


## A row's height: RowHeight, or what keeps the whole menu inside the
## column when a pack has more lines than the Rebellion's 23.
func _fit_rows(cats: Array, height: float) -> float:
	var rows := 2   # the key's line and Display Off
	var gaps := 0.0
	for cat in cats:
		var n: int = (cat as Gid.GidCategory).Modes.size()
		rows += n
		gaps += n * RowGap
		if Paired.has((cat as Gid.GidCategory).Id) and n > 2:
			gaps += int((n - 1) / 2) * (PairGap - RowGap)
	# Before every heading but the first and before the key's line; then
	# between the last two lines.
	gaps += cats.size() * SectionGap + RowGap
	var room: float = height - 2 * Margin - cats.size() * HeadHeight - gaps
	return clampf(floorf(room / rows), 1.0, RowHeight)


func _heading(cat: Gid.GidCategory) -> void:
	var icon: Texture2D = _icon_for(cat.Id)
	if icon != null:
		var t := TextureRect.new()
		t.texture = icon
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sz := Vector2(icon.get_size())
		t.position = Vector2(Margin + floorf((IconSize - sz.x) / 2.0), _y + floorf((HeadHeight - sz.y) / 2.0))
		t.size = sz
		add_child(t)
	var l := Label.new()
	l.name = "Head_" + cat.Id
	l.text = cat.Name
	l.add_theme_font_override("font", OUI.Face(true))
	l.add_theme_font_size_override("font_size", HeadPx)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(Margin + IconSize + 6.0, _y)
	l.size = Vector2(_w - l.position.x - Margin, HeadHeight)
	add_child(l)
	_y += HeadHeight


func _row(mode: Gid.GidMode) -> void:
	var b := _button("Mode_" + mode.Id, mode.MenuLabel)
	b.tooltip_text = mode.LabelText
	var m: Gid.GidMode = mode
	b.pressed.connect(func() -> void: _map.SetMode(m))
	_rows[mode] = b


## A row: the sector column's button - the same theme boxes, so the same grey
## and hover - its text left, 4px in, and no padding above or below.
func _button(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_override("font", OUI.Face(false))
	b.add_theme_font_size_override("font_size", RowPx)
	b.position = Vector2(Margin + Indent, _y)
	add_child(b)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = Pad
		sb.content_margin_right = Pad
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(st, sb)
	b.size = Vector2(_w - b.position.x - Margin, _rowH)
	_tint(b, TextColor)
	_y += b.size.y
	return b


static func _tint(b: Button, c: Color) -> void:
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c if k != "font_hover_color" else c.lightened(0.25))


## The heading icon for a category: the corner icon's glyph (the 27x18 cell
## cropped to what is drawn), or the person / currency drawn here - fitted
## to IconSize, its shape kept.
func _icon_for(cat_id: String) -> Texture2D:
	if cat_id == "personnel":
		return _fitted(_drawn(Person))
	if cat_id == "resources":
		return _fitted(_drawn(Currency))
	var glyph: String = CategoryGlyph.get(cat_id, "")
	if glyph.is_empty():
		return null
	var cell: Texture2D = Art.CornerIcon(glyph, _side)
	if cell == null:
		return null
	var img: Image = cell.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0:
		return null
	return _fitted(img.get_region(used))


func _drawn(rows: Array) -> Image:
	var h: int = rows.size()
	var w: int = str(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c: Color = OUI.SideColor(GameSettings.PlayerFaction)
	for y in h:
		var line: String = rows[y]
		for x in w:
			if line[x] == "#":
				img.set_pixel(x, y, c)
	return img


## The picture as large as fits IconSize square, its shape kept. A small one
## is blown up by whole pixels first, so the smoothing down stays crisp.
static func _fitted(img: Image) -> Texture2D:
	img.convert(Image.FORMAT_RGBA8)
	var whole: int = ceili(IconSize / maxi(img.get_width(), img.get_height()))
	if whole > 1:
		img.resize(img.get_width() * whole, img.get_height() * whole, Image.INTERPOLATE_NEAREST)
	var k: float = IconSize / maxi(img.get_width(), img.get_height())
	if k < 1.0:
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)
