extends Control
## THE GALAXY DISPLAY MENU down the Command Center's left-hand column (TeeJ,
## 2026-09-25: "Next I would like to move the mostly empty left hand column
## ... This will completely eliminate the blue bar"). The black left of the
## frame, top to bottom, in his order: each GID category under its heading -
## the category's icon, its name, a short rule - with its modes below it, one
## line each; a rule between categories; Manufacturing's three pairs split by
## short rules; then "Loyalty to <side>" (the map key, moved from the sector
## column: it opens and closes the key) and Display Off. Arial 16, not
## indented (his option A); the shorter lines are the pack's `menu_label`s
## ("Idle" under Fleets) and the side's `loyalty_label_short`, all approved by
## him. The mode on the map in the side's colour.
##
## The headings' icons: the side's crest, the sector window's fleet, factory
## and tower (his "planet fleet icon", "planet factory icon", "planet defence
## icon" - the corner icons' glyphs, twice size), and for Personnel and
## Resources a person and a currency mark drawn here, in the side's colour
## (his references: a head-and-shoulders silhouette, and the ring with four
## spokes).
## Preloaded by path (a new class_name can lag the editor's class cache).

const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

const Px := 16
const Margin := 6.0
const RowHeight := 21.0
const HeadHeight := 28.0
const IconSize := 22.0
const Gap := 5.0
const TextColor := Color(0.86, 0.86, 0.86)
const RuleColor := Color(0.42, 0.42, 0.45)
## A category's heading icon: the sector window's corner glyph it wears.
const CategoryGlyph := {"loyalty": "mission", "fleets": "fleet", "manufacturing": "manufacturing", "defense": "defenses"}
## Categories whose modes come in pairs, split by short rules (TeeJ's list).
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


func Build(width: float, map: GalaxyMap, on_key: Callable) -> void:
	name = "GidMenu"
	_map = map
	_side = OUI.Side(GameSettings.PlayerFaction)
	_w = width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(width, get_viewport_rect().size.y)
	_y = Margin
	Gid.ActiveMode()   # builds the catalogue if nothing has yet
	var cats: Array = Gid.Categories
	for i in cats.size():
		var cat: Gid.GidCategory = cats[i]
		_heading(cat)
		var n := 0
		for mode in cat.Modes:
			if Paired.has(cat.Id) and n > 0 and n % 2 == 0:
				_rule(Margin + 12.0, 36.0)
			_row(mode)
			n += 1
		_rule(Margin, _w - 2 * Margin)
	_key = _button("KeyRow", GameSettings.PlayerFaction.LoyaltyLabelShort if GameSettings.PlayerFaction != null else "Map Key")
	_key.tooltip_text = "Open or close the map key"
	_key.pressed.connect(on_key)
	_rule(Margin, _w - 2 * Margin)
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


func _heading(cat: Gid.GidCategory) -> void:
	var icon: Texture2D = _icon_for(cat.Id)
	if icon != null:
		var t := TextureRect.new()
		t.texture = icon
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.position = Vector2(Margin, _y + (HeadHeight - IconSize) / 2.0)
		t.size = Vector2(IconSize, IconSize)
		add_child(t)
	var l := Label.new()
	l.name = "Head_" + cat.Id
	l.text = cat.Name
	l.add_theme_font_override("font", OUI.Face(true))
	l.add_theme_font_size_override("font_size", Px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(Margin + IconSize + 6.0, _y)
	l.size = Vector2(_w - l.position.x - Margin, HeadHeight)
	add_child(l)
	_y += HeadHeight
	# The heading's short rule, as long as the heading.
	var long: float = IconSize + 6.0 + OUI.Face(true).get_string_size(cat.Name, HORIZONTAL_ALIGNMENT_LEFT, -1, Px).x
	_rule(Margin, minf(long, _w - 2 * Margin), 1.0)


func _row(mode: Gid.GidMode) -> void:
	var b := _button("Mode_" + mode.Id, mode.MenuLabel)
	b.tooltip_text = mode.LabelText
	var m: Gid.GidMode = mode
	b.pressed.connect(func() -> void: _map.SetMode(m))
	_rows[mode] = b


func _button(node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_override("font", OUI.Face(false))
	b.add_theme_font_size_override("font_size", Px)
	# No padding above or below the words: a row is its line of text.
	var none := StyleBoxEmpty.new()
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(1, 1, 1, 0.1)
	for sb in [none, lit]:
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.content_margin_left = 0
		sb.content_margin_right = 0
	for st in ["normal", "focus", "disabled", "pressed"]:
		b.add_theme_stylebox_override(st, none)
	for st in ["hover", "hover_pressed"]:
		b.add_theme_stylebox_override(st, lit)
	b.position = Vector2(Margin, _y)
	add_child(b)
	var h: float = maxf(RowHeight, b.get_combined_minimum_size().y)
	b.size = Vector2(_w - 2 * Margin, h)
	_tint(b, TextColor)
	_y += h
	return b


static func _tint(b: Button, c: Color) -> void:
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c if k != "font_hover_color" else c.lightened(0.25))


func _rule(x: float, w: float, gap: float = Gap) -> void:
	_y += gap
	var r := ColorRect.new()
	r.color = RuleColor
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(x, _y)
	r.size = Vector2(w, 1.0)
	add_child(r)
	_y += 1.0 + gap


## The heading icon for a category: the corner icon's glyph (the 27x18 cell
## cropped to what is drawn), or the person / currency drawn here.
func _icon_for(cat_id: String) -> Texture2D:
	if cat_id == "personnel":
		return _drawn(Person)
	if cat_id == "resources":
		return _drawn(Currency)
	var glyph: String = CategoryGlyph.get(cat_id, "")
	if glyph.is_empty():
		return null
	var cell: Texture2D = Art.CornerIcon(glyph, _side)
	if cell == null:
		return null
	var img: Image = cell.get_image()
	if img == null:
		return cell
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0:
		return cell
	var only := AtlasTexture.new()
	only.atlas = cell
	only.region = Rect2(used)
	return only


func _drawn(rows: Array) -> Texture2D:
	var h: int = rows.size()
	var w: int = str(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c: Color = OUI.SideColor(GameSettings.PlayerFaction)
	for y in h:
		var line: String = rows[y]
		for x in w:
			if line[x] == "#":
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
