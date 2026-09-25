class_name CommandFrame
extends Control
## THE COMMAND CENTER'S FRAME (manual p022 Fig 2.3; TeeJ, 2026-09-25: "build
## the frame across the top (from the day counter) across the top and down the
## left hand column", then "implementing the left hand column"), cut from the
## side's frame (STRATEGY 900 / 901, windows/command.<side>) and drawn at the
## HUD's one and a half times:
##   - the top bar, placed so its own boxes sit under the Speed Control and the
##     resource displays (GameManager places those), its plain metal repeated
##     out to the screen's edges;
##   - the Message Alert bar's column ("Message Alert bar", Fig 2.3), flush
##     against the map's left edge: the side's nine category icons in its nine
##     slots, dim, lit while that category holds unread mail (the icons and
##     their order matched on TeeJ's screenshot of the original's), each
##     opening the Message Index on its category;
##   - the Game Options monitor under them ("Click here to go to Game Options
##     screen", Fig 2.3).
## The Empire's column is on its frame's right (the two sides' layouts are
## mirrored); ours stays on the left for both, so the Empire's is drawn turned
## round, and its monitor, on the far side of its frame, is set under it.
## Without the frame in the art set, nothing: the plain column stays.

const Art := preload("res://src/ui/artwork.gd")
const S := 1.5

## In the frame's own pixels. band: the top bar; fill: a plain stretch of it,
## repeated outward; top: the frame row drawn at the screen's top (the HUD's
## highest piece); column: the Message Alert bar's column (the Alliance's
## from the top, its glass corner with it); slot: where the first category
## icon sits, in the frame (pitch 25, down; in the turned-round column for the
## Empire); monitor: the Game Options monitor in the frame, and monitor_at
## where it sits from the column's corner.
const Layout := {
	"alliance": {
		"top": 10,
		"band": Rect2i(72, 10, 528, 30),
		"fill": Rect2i(72, 10, 16, 30),
		"column": Rect2i(0, 10, 52, 420),
		"flip": false,
		"slot": Vector2(3, 109),
		"monitor": Rect2i(3, 358, 27, 34),
		"monitor_at": Vector2(3, 348),
	},
	"empire": {
		"top": 12,
		"band": Rect2i(100, 12, 505, 30),
		"fill": Rect2i(458, 12, 16, 30),
		"column": Rect2i(596, 40, 44, 380),
		"flip": true,
		"slot": Vector2(2, 110),
		"monitor": Rect2i(78, 196, 32, 48),
		"monitor_at": Vector2(6, 322),
	},
}
const SlotPitch := 25
## The Message Alert bar, top to bottom, as the original orders it (matched on
## TeeJ's screenshot): the CommsList buttons by name, and the icons' names.
const Categories := ["Loyalty", "Fleets", "Missions", "Resources", "Manufacturing", "Defense", "Conflict", "Advice", "Chat"]

var Side: String = ""
var _frame: Texture2D
var _alerts: Array = []   # [TextureButton, category]


## True when this side's frame and its alert icons are in the art set.
static func CanBuild(side: String) -> bool:
	if not Layout.has(side) or Art.WindowPicture("command.%s" % side) == null:
		return false
	for c in Categories:
		if Art.AlertIcon(side, c, false) == null:
			return false
	return true


## Lays the frame out: `hud_origin` is where the frame's (0, top) lands on
## screen for the top bar (GameManager's placing of the HUD); `map_left` the
## map's left edge; `width` the screen's.
func Build(side: String, hud_origin: Vector2, map_left: float, width: float, on_category: Callable, on_options: Callable) -> void:
	Side = side
	name = "CommandFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame = Art.WindowPicture("command.%s" % side)
	var lay: Dictionary = Layout[side]
	var top: int = lay["top"]

	# The top bar, its boxes under the HUD's, and its plain metal both ways.
	var band: Rect2i = lay["band"]
	var bandAt := Vector2(hud_origin.x + band.position.x * S, hud_origin.y)
	_piece(band, bandAt, "Band")
	var fill: Rect2i = lay["fill"]
	var step: float = fill.size.x * S
	var x: float = bandAt.x - step
	var i := 0
	while x > -step:
		_piece(fill, Vector2(x, hud_origin.y), "FillLeft%d" % i)
		x -= step
		i += 1
	x = bandAt.x + band.size.x * S
	i = 0
	while x < width:
		_piece(fill, Vector2(x, hud_origin.y), "FillRight%d" % i)
		x += step
		i += 1

	# The Message Alert bar's column, against the map.
	var col: Rect2i = lay["column"]
	var colAt := Vector2(map_left - col.size.x * S, hud_origin.y + (col.position.y - top) * S)
	var column := _piece(col, colAt, "Column")
	column.flip_h = lay["flip"]
	var slot: Vector2 = lay["slot"]
	for n in Categories.size():
		var cat: String = Categories[n]
		var b := TextureButton.new()
		b.name = "Alert" + cat
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		var icon: Texture2D = Art.AlertIcon(side, cat, false)
		b.size = icon.get_size() * S
		b.position = colAt + Vector2(slot.x, slot.y - col.position.y + n * SlotPitch) * S
		b.tooltip_text = cat
		b.pressed.connect(on_category.bind(cat))
		add_child(b)
		_alerts.append([b, cat])
	var mon: Rect2i = lay["monitor"]
	var monAt: Vector2 = colAt + lay["monitor_at"] * S
	if side == "empire":
		# The Empire's monitor, from the far side of its frame.
		_piece(mon, monAt, "Monitor")
	var options := Button.new()
	options.name = "GameOptions"
	options.flat = true
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		options.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	options.position = monAt
	options.size = Vector2(mon.size) * S
	options.tooltip_text = "Game Options"
	options.pressed.connect(on_options)
	add_child(options)
	RefreshAlerts()


## Lit while its category holds unread mail.
func RefreshAlerts() -> void:
	for pair in _alerts:
		var b: TextureButton = pair[0]
		var cat: String = pair[1]
		var unread: int = EventBus.UnreadCount(Enums.MessageCategory[cat]) if Enums.MessageCategory.has(cat) else 0
		b.texture_normal = Art.AlertIcon(Side, cat, unread > 0)
		b.tooltip_text = cat if unread == 0 else "%s (%d unread)" % [cat, unread]


## The column's rectangle on screen (for the parts that make room for it).
func ColumnRect() -> Rect2:
	var c: Control = get_node_or_null("Column")
	return Rect2(c.position, c.size) if c != null else Rect2()


func _piece(src: Rect2i, at: Vector2, piece_name: String) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = _frame
	atlas.region = Rect2(src)
	var r := TextureRect.new()
	r.name = piece_name
	r.texture = atlas
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = at
	r.size = Vector2(src.size) * S
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(r)
	return r
