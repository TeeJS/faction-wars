class_name CommandFrame
extends Control
## THE COMMAND CENTER (manual p022 Fig 2.3), as the original draws it: the
## side's whole frame (STRATEGY 900 / 901, windows/command.<side>) is the
## screen, scaled to the screen's height and centred - black either side, the
## screen being wider than the original's 640x480 - with the galaxy showing
## through its window (GalaxyMap is placed behind it, see Place). TeeJ,
## 2026-09-25, of a strip and a pillar laid over our own grey layout: "how the
## holly hell does this even look remotely like the original?" - so the whole
## frame, with our pieces moved into its places:
##   - the Speed Control and the resource displays sit on the frame's own boxes
##     (GameManager places them at the frame's scale);
##   - the Message Alert bar: the nine category icons in the frame's nine
##     slots (the Alliance's on the left, the Empire's on the right - the two
##     sides' layouts are mirrored), dim, lit while that category holds unread
##     mail (icons and order matched on TeeJ's screenshot), each opening the
##     Message Index on its category;
##   - the Game Options monitor ("Click here to go to Game Options screen").
## The metal takes the mouse (only the window lets clicks through to the map),
## so a click on the frame never opens a system under it. Without the frame in
## the art set, nothing: the plain screen stays.

const Art := preload("res://src/ui/artwork.gd")
const FrameSize := Vector2(640, 481)

## In the frame's own pixels. window: the map's window (the see-through blue);
## slot: the first Message Alert icon (pitch 25, down; each 1 px up and left of
## its 25x20 slot); monitor: the Game Options monitor; shelf: the Window
## Reference Bar's twelve slots ("twelve slots for minimized System windows",
## manual p022) - the Alliance's slatted shelf, the Empire's blue panel -
## measured slat edge to slat edge.
const Layout := {
	"alliance": {
		"window": Rect2(54, 35, 488, 358),
		"slot": Vector2(3, 109),
		"monitor": Rect2(3, 358, 27, 34),
		"shelf": Rect2(546, 58, 60, 262),
	},
	"empire": {
		"window": Rect2(118, 41, 489, 358),
		"slot": Vector2(611, 110),
		"monitor": Rect2(78, 196, 32, 48),
		"shelf": Rect2(20, 46, 55, 291),
	},
}
const SlotPitch := 25
## The Message Alert bar, top to bottom, as the original orders it.
const Categories := ["Loyalty", "Fleets", "Missions", "Resources", "Manufacturing", "Defense", "Conflict", "Advice", "Chat"]

var Side: String = ""
## The frame's scale and its top-left on screen.
var S: float = 1.0
var Origin: Vector2 = Vector2.ZERO
var _frame: Texture2D
var _image: Image
var _alerts: Array = []   # [TextureButton, category]


## True when this side's frame and its alert icons are in the art set.
static func CanBuild(side: String) -> bool:
	if not Layout.has(side) or Art.WindowPicture("command.%s" % side) == null:
		return false
	for c in Categories:
		if Art.AlertIcon(side, c, false) == null:
			return false
	return true


## The frame's scale on a screen this size: the frame fills the height.
static func ScaleFor(screen: Vector2) -> float:
	return screen.y / FrameSize.y


## Where the frame's top-left lands on a screen this size (centred).
static func OriginFor(screen: Vector2) -> Vector2:
	return Vector2(floorf((screen.x - FrameSize.x * ScaleFor(screen)) / 2.0), 0)


## The map's window on screen, for a side, on a screen this size.
static func WindowRect(side: String, screen: Vector2) -> Rect2:
	var s: float = ScaleFor(screen)
	var w: Rect2 = Layout[side]["window"]
	return Rect2(OriginFor(screen) + w.position * s, w.size * s)


func Build(side: String, screen: Vector2, on_category: Callable, on_options: Callable) -> void:
	Side = side
	name = "CommandFrame"
	S = ScaleFor(screen)
	Origin = OriginFor(screen)
	position = Vector2.ZERO
	size = screen
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame = Art.WindowPicture("command.%s" % side)
	_image = _frame.get_image()
	if _image != null and _image.is_compressed():
		_image.decompress()
	var lay: Dictionary = Layout[side]

	var pic := TextureRect.new()
	pic.name = "Frame"
	pic.texture = _frame
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.position = Origin
	pic.size = FrameSize * S
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)

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
		b.position = Origin + (slot + Vector2(0, n * SlotPitch)) * S
		b.tooltip_text = cat
		b.pressed.connect(on_category.bind(cat))
		add_child(b)
		_alerts.append([b, cat])

	var mon: Rect2 = lay["monitor"]
	var options := Button.new()
	options.name = "GameOptions"
	options.flat = true
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		options.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	options.position = Origin + mon.position * S
	options.size = mon.size * S
	options.tooltip_text = "Game Options"
	options.pressed.connect(on_options)
	add_child(options)
	RefreshAlerts()


## The metal takes the mouse; the window (and the black either side, where the
## plain panels sit) does not.
func _has_point(point: Vector2) -> bool:
	if _image == null:
		return false
	var p: Vector2 = (point - Origin) / S
	if p.x < 0 or p.y < 0 or p.x >= _image.get_width() or p.y >= _image.get_height():
		return false
	return _image.get_pixel(int(p.x), int(p.y)).a > 0.5


## Lit while its category holds unread mail, with the unread count on its
## corner as the message column's sockets had it (TeeJ, 2026-09-25: "I'm not
## getting numbers for messages anymore, which was a nice feature").
func RefreshAlerts() -> void:
	for pair in _alerts:
		var b: TextureButton = pair[0]
		var cat: String = pair[1]
		var unread: int = EventBus.UnreadCount(Enums.MessageCategory[cat]) if Enums.MessageCategory.has(cat) else 0
		b.texture_normal = Art.AlertIcon(Side, cat, unread > 0)
		b.tooltip_text = cat if unread == 0 else "%s (%d unread)" % [cat, unread]
		UIManager._Badge(b, unread, b.size.x)


## The Window Reference Bar's twelve slots on screen.
func Shelf() -> Rect2:
	var r: Rect2 = Layout[Side]["shelf"]
	return Rect2(Origin + r.position * S, r.size * S)


## The map's window on screen.
func MapWindow() -> Rect2:
	return Rect2(Origin + (Layout[Side]["window"] as Rect2).position * S, (Layout[Side]["window"] as Rect2).size * S)


## Where the galaxy map goes so it lies behind the frame as the original's
## does: its picture (the pack's map_image, fitted into GalaxyMap.Frame from
## its top-left) drawn at the frame's origin, the frame's scale - the
## original's 640x480 galaxy picture fills its screen behind the frame.
func Place(map: Node2D) -> void:
	var fitted: Vector2 = GalaxyMap.Frame
	map.position = Origin
	var k: float = (FrameSize.x * S) / fitted.x
	map.scale = Vector2(k, k)
