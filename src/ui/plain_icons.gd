extends RefCounted
## OUR OWN GLYPHS, for the build without the original's art (TeeJ, 2026-09-28:
## "why is the artwork-free version missing the sidebars, none of that is the
## original's IP, we built it"; docs: the plain build parity plan). Where the
## original-look build shows one of the original's pictures - a Message Alert
## icon, a Control Panel monitor, the left menu's heading glyphs, the shelf's
## window kinds - the plain build shows one of these: an 11 x 11 mask drawn
## here, in one colour, blown up by whole pixels so it stays crisp. Two of
## them (Person, Currency) were the left menu's own drawings (gid_menu.gd).
##
## The approved palette (TeeJ, 2026-09-28) for what these sit on: the plate
## #3b3b3b, its lit bevel #5c5c5c, its shadow and wells #141414, caption bands
## #2d2d2d, labels #dfdfdf (dimmed at 50%), counts #ffff00; the side's colour
## (OUI.SideColor) for anything lit.
## Preloaded by path (a new class_name can lag the editor's class cache).

const Plate := Color("#3b3b3b")
const BevelLight := Color("#5c5c5c")
const Well := Color("#141414")
const Band := Color("#2d2d2d")
const LabelColor := Color("#dfdfdf")
const Dimmed := Color(0.875, 0.875, 0.875, 0.5)
const Count := Color("#ffff00")

const Masks := {
	"personnel": [
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
	],
	"resources": [
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
	],
	"loyalty": [
		"##.........",
		"##########.",
		"##########.",
		"##########.",
		"##########.",
		"##.........",
		"##.........",
		"##.........",
		"##.........",
		"##.........",
		"####.......",
	],
	"fleets": [
		"...........",
		"...........",
		"#..........",
		"####.......",
		".########..",
		"###########",
		".########..",
		"####.......",
		"#..........",
		"...........",
		"...........",
	],
	"missions": [
		".....#.....",
		"...#####...",
		"..#..#..#..",
		".#.......#.",
		".#.......#.",
		"###..#..###",
		".#.......#.",
		".#.......#.",
		"..#..#..#..",
		"...#####...",
		".....#.....",
	],
	"manufacturing": [
		"#..........",
		"#..........",
		"#..#..#..#.",
		"#.##.##.##.",
		"###########",
		"###########",
		"##.##.##.##",
		"##.##.##.##",
		"###########",
		"###########",
		"...........",
	],
	"defense": [
		"###########",
		"#.........#",
		"#....#....#",
		"#...###...#",
		"#..#####..#",
		".#...#...#.",
		".#...#...#.",
		"..#.....#..",
		"...#...#...",
		"....#.#....",
		".....#.....",
	],
	"conflict": [
		"#.........#",
		".#.......#.",
		"..#.....#..",
		"...#...#...",
		"....#.#....",
		".....#.....",
		"....#.#....",
		"...#...#...",
		".##.....##.",
		"##.......##",
		"#.........#",
	],
	"advice": [
		".#########.",
		"#.........#",
		"#....#....#",
		"#....#....#",
		"#....#....#",
		"#.........#",
		"#....#....#",
		".#########.",
		"...##......",
		"..#........",
		"...........",
	],
	"chat": [
		".#########.",
		"#.........#",
		"#.#######.#",
		"#.........#",
		"#.#####...#",
		"#.........#",
		".#########.",
		"......##...",
		".......#...",
		"...........",
		"...........",
	],
	"options": [
		"..###......",
		"###########",
		"..###......",
		"...........",
		"......###..",
		"###########",
		"......###..",
		"...........",
		"....###....",
		"###########",
		"....###....",
	],
	"system_finder": [
		"....###....",
		"..#######..",
		".#########.",
		"...........",
		"###########",
		"...........",
		".#########.",
		"..#######..",
		"....###....",
		"...........",
		"...........",
	],
	"troop_finder": [
		"...#####...",
		"..#######..",
		".#########.",
		".#########.",
		".##.....##.",
		".#..#.#..#.",
		".#.......#.",
		".##.....##.",
		"..#######..",
		"...#...#...",
		"...........",
	],
	"encyclopedia": [
		"...........",
		"##.......##",
		"####...####",
		"#..##.##..#",
		"#...###...#",
		"#....#....#",
		"#....#....#",
		"#....#....#",
		"####.#.####",
		"...#####...",
		"...........",
	],
	"all": [
		"###.###.###",
		"###.###.###",
		"###.###.###",
		"...........",
		"###.###.###",
		"###.###.###",
		"###.###.###",
		"...........",
		"###.###.###",
		"###.###.###",
		"###.###.###",
	],
	"select_all": [
		"##.########",
		"##.########",
		"...........",
		"##.########",
		"##.########",
		"...........",
		"##.########",
		"##.########",
		"...........",
		"##.########",
		"##.########",
	],
	"delete": [
		"...#####...",
		"###########",
		"...........",
		".#########.",
		".#.#.#.#.#.",
		".#.#.#.#.#.",
		".#.#.#.#.#.",
		".#.#.#.#.#.",
		".#.#.#.#.#.",
		".#########.",
		"...........",
	],
	"summary": [
		".########..",
		".#......##.",
		".#.####..#.",
		".#.......#.",
		".#.#####.#.",
		".#.......#.",
		".#.#####.#.",
		".#.......#.",
		".#.####..#.",
		".#.......#.",
		".#########.",
	],
	"post": [
		".....#.....",
		"....###....",
		"...#####...",
		"..#######..",
		"..#######..",
		"..#######..",
		".#########.",
		"###########",
		"...........",
		"....###....",
		".....#.....",
	],
	"open": [
		"###########",
		"#.........#",
		"###########",
		"#.........#",
		"#....#....#",
		"#...###...#",
		"#..#####..#",
		"#....#....#",
		"#....#....#",
		"#.........#",
		"###########",
	],
	"compose": [
		".........##",
		"........###",
		".......###.",
		"......###..",
		".....###...",
		"....###....",
		"...###.....",
		"..###......",
		".##........",
		"##.........",
		"#..........",
	],
	"close": [
		"##.......##",
		"###.....###",
		".###...###.",
		"..###.###..",
		"...#####...",
		"....###....",
		"...#####...",
		"..###.###..",
		".###...###.",
		"###.....###",
		"##.......##",
	],
	"ok": [
		"...........",
		"..........#",
		".........##",
		"........##.",
		".......##..",
		"#.....##...",
		"##...##....",
		".##.##.....",
		"..###......",
		"...#.......",
		"...........",
	],
	"up": [
		"...........",
		"...........",
		".....#.....",
		"....###....",
		"...#####...",
		"..#######..",
		".#########.",
		"###########",
		"...........",
		"...........",
		"...........",
	],
	"down": [
		"...........",
		"...........",
		"...........",
		"###########",
		".#########.",
		"..#######..",
		"...#####...",
		"....###....",
		".....#.....",
		"...........",
		"...........",
	],
	"minimize": [
		"...........",
		"...........",
		"...........",
		"...........",
		"...........",
		"...........",
		"...........",
		"###########",
		"###########",
		"...........",
		"...........",
	],
	"switch": [
		"...........",
		"...........",
		"..#.....#..",
		".##.....##.",
		"###########",
		"###########",
		".##.....##.",
		"..#.....#..",
		"...........",
		"...........",
		"...........",
	],
	"system": [
		"...#####...",
		"..#######..",
		".#########.",
		"###########",
		"###########",
		"###########",
		"###########",
		"###########",
		".#########.",
		"..#######..",
		"...#####...",
	],
	"enroute": [
		"...........",
		"...........",
		"...........",
		".......#...",
		".......###.",
		"#.#.#######",
		".......###.",
		".......#...",
		"...........",
		"...........",
		"...........",
	],
	"uprising": [
		".....#.....",
		"....##.....",
		"....###....",
		"...####.#..",
		"...#####...",
		"..#######..",
		"..###.###..",
		".###...###.",
		".##.....##.",
		".##.....##.",
		"..#######..",
	],
	"fighter": [
		".....#.....",
		".....#.....",
		"....###....",
		"#...###...#",
		"###########",
		"###########",
		"#...###...#",
		"....###....",
		"...#####...",
		"..#######..",
		"...........",
	],
	"battery": [
		"...........",
		"........##.",
		".......###.",
		"......###..",
		".....###...",
		"....###....",
		"...####....",
		"..#####....",
		".#######...",
		"#########..",
		"#########..",
	],
	"construction": [
		"###########",
		"#.#.#.#.#.#",
		"###########",
		".#.........",
		".#......#..",
		".#......#..",
		".#.....###.",
		".#.....###.",
		".#.........",
		"###........",
		"###........",
	],
	"refinery": [
		"...........",
		"..#####....",
		".#######...",
		".#.....#...",
		".#######.##",
		".#.....#.#.",
		".#######.#.",
		".#.....###.",
		".#######...",
		"###########",
		"###########",
	],
	"mine": [
		"........#..",
		".......###.",
		"......#.#.#",
		".....#..#..",
		"....#...#..",
		"...###.....",
		"..#####....",
		".#######...",
		"#########..",
		"###########",
		"###########",
	],
	"decoy": [
		"....###....",
		"...#...#...",
		"...#...#...",
		"...#...#...",
		"....###....",
		"...........",
		"..#######..",
		".#.......#.",
		".#.......#.",
		".#.......#.",
		".#########.",
	],
	"left": [
		"...........",
		"...........",
		"....#......",
		"...##......",
		"..#########",
		".##########",
		"..#########",
		"...##......",
		"....#......",
		"...........",
		"...........",
	],
	"right": [
		"...........",
		"...........",
		"......#....",
		"......##...",
		"#########..",
		"##########.",
		"#########..",
		"......##...",
		"......#....",
		"...........",
		"...........",
	],
	"gid": [
		"###########",
		"#.........#",
		"#.#.....#.#",
		"#....#....#",
		"#..#....#.#",
		"#.........#",
		"#.#...#...#",
		"###########",
		"....###....",
		"..#######..",
		"...........",
	],
}
## The same glyph under another name: the finders for fleets and people, the
## Message Alert categories as the Command Center names them, the sector
## window's corner icons.
const Aliases := {
	"fleet_finder": "fleets", "personnel_finder": "personnel", "mission": "missions",
	"fleet": "fleets", "defenses": "defense", "cancel": "close", "ship": "fleets", "troop": "troop_finder", "troops": "troop_finder", "fighters": "fighter", "shipyards": "fleets", "training_facilities": "troop_finder", "construction_yards": "construction", "refineries": "refinery", "mines": "mine", "planetary_shield": "defense", "planetary_battery": "battery", "agents": "personnel", "decoys": "decoy", "prev": "left", "next": "right", "view_topic": "summary", "view_index": "select_all", "display": "open", "btn_fleets": "fleets", "btn_ships": "select_all", "btn_characters": "personnel", "btn_specforces": "troop_finder", "facilities": "manufacturing", "rebel": "system", "imperial": "system", "neutral": "system", "unexplored": "system",
}

static var _cache: Dictionary = {}


static func Has(kind: String) -> bool:
	return Masks.has(Aliases.get(kind.to_lower(), kind.to_lower()))


## The glyph as an image, 11 x 11, in `color` on clear.
static func Picture(kind: String, color: Color) -> Image:
	var rows: Array = Masks.get(Aliases.get(kind.to_lower(), kind.to_lower()), [])
	if rows.is_empty():
		return null
	var h: int = rows.size()
	var w: int = str(rows[0]).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var line: String = rows[y]
		for x in w:
			if line[x] == "#":
				img.set_pixel(x, y, color)
	return img


## The glyph blown up by whole pixels to at most `size` square (at least 1x),
## in `color`. Cached.
static func Icon(kind: String, color: Color, size: float) -> Texture2D:
	var key := "%s|%s|%d" % [kind, color.to_html(), int(size)]
	if _cache.has(key):
		return _cache[key]
	var img: Image = Picture(kind, color)
	if img == null:
		return null
	var k: int = maxi(1, int(size / img.get_width()))
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A recessed box as ours are drawn - a well, its shadow edge top and left and
## its lit edge bottom and right - for `ci` to draw at `r`.
static func DrawWell(ci: CanvasItem, r: Rect2, fill: Color = Well, edge: float = 2.0) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, edge)), Color.BLACK)
	ci.draw_rect(Rect2(r.position, Vector2(edge, r.size.y)), Color.BLACK)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - edge), Vector2(r.size.x, edge)), BevelLight)
	ci.draw_rect(Rect2(Vector2(r.end.x - edge, r.position.y), Vector2(edge, r.size.y)), BevelLight)


## A raised plate: lit edge top and left, shadow bottom and right.
static func DrawPlate(ci: CanvasItem, r: Rect2, edge: float = 2.0) -> void:
	ci.draw_rect(r, Plate)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, edge)), BevelLight)
	ci.draw_rect(Rect2(r.position, Vector2(edge, r.size.y)), BevelLight)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - edge), Vector2(r.size.x, edge)), Well)
	ci.draw_rect(Rect2(Vector2(r.end.x - edge, r.position.y), Vector2(edge, r.size.y)), Well)


## A button of ours on the plain Command Center at `rect` (screen pixels): a
## well with `kind`'s glyph in it - or `word` where there is no glyph - lit in
## `lit_color` or dimmed, held down while pressed.
static func MakeSlot(kind: String, word: String, lit_color: Color, rect: Rect2, glyph: float) -> Slot:
	var s := Slot.new()
	s.name = "Plain_" + (kind if not kind.is_empty() else word).replace(" ", "")
	s.position = rect.position
	s.size = rect.size
	s.Word = word
	var room: float = minf(glyph, minf(rect.size.x, rect.size.y) - 6.0)
	if Has(kind):
		s.TexLit = Icon(kind, lit_color, room)
		s.TexDim = Icon(kind, Dimmed, room)
	s.LitColor = lit_color
	return s


class Slot extends Button:
	var Word: String = ""
	var Lit: bool = true
	var LitColor: Color = Color.WHITE
	var TexLit: Texture2D = null
	var TexDim: Texture2D = null

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func SetLit(on: bool) -> void:
		if on != Lit:
			Lit = on
			queue_redraw()

	func _draw() -> void:
		var down := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
		var fill: Color = Color("#222222") if is_hovered() and not down else Well
		var e := 2.0
		draw_rect(Rect2(Vector2.ZERO, size), fill)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, e)), Color.BLACK)
		draw_rect(Rect2(Vector2.ZERO, Vector2(e, size.y)), Color.BLACK)
		draw_rect(Rect2(Vector2(0, size.y - e), Vector2(size.x, e)), BevelLight)
		draw_rect(Rect2(Vector2(size.x - e, 0), Vector2(e, size.y)), BevelLight)
		var nudge := Vector2(1, 1) if down else Vector2.ZERO
		var tex: Texture2D = TexLit if Lit else TexDim
		if tex != null:
			draw_texture(tex, ((size - tex.get_size()) / 2.0).floor() + nudge)
		elif not Word.is_empty():
			var f: Font = get_theme_font("font")
			var px: int = get_theme_font_size("font_size")
			var w: float = f.get_string_size(Word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var at := Vector2((size.x - w) / 2.0, (size.y + f.get_ascent(px) - f.get_descent(px)) / 2.0).floor() + nudge
			draw_string(f, at, Word, HORIZONTAL_ALIGNMENT_LEFT, -1, px, LitColor if Lit else Dimmed)
