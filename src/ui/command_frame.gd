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
##   - the Game Options monitor ("Click here to go to Game Options screen");
##   - the two droids (AddDroids): the agent, C-3PO / IMP-22, and the message
##     droid, R2-D2 / SD-7, standing where the original stands them;
##   - the Control Panel (AddConsoles): the consoles' monitors, each opening
##     its finder or the Encyclopedia, shown held down while pressed.
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
## measured slat edge to slat edge; picture: where the original draws its
## galaxy picture (STRATEGY 903, the top-left of screens/galaxy.png), 1:1 -
## measured on TeeJ's screenshots of the original, 2026-09-25 (five of the
## Alliance's, standard, large and huge galaxies; one of the Empire's): the
## picture correlates 0.93 / 0.985 there, and every system's star sits within
## a pixel of where the Star Wars pack's map_image_rect puts it. agent /
## messenger: the droids' pictures (windows/droid_*.<side>, one frame's
## size), where the original draws them - matched on TeeJ's screenshots of
## the original (C-3PO and R2-D2 exactly, eight screenshots; IMP-22 98% and
## SD-7 89% of their pixels, caught mid-animation) and the same four places
## open-rebellion measured on its own (its 2026-09-10 advisor evidence).
## consoles: the Control Panel's monitors (manual p022 Fig 2.3), each at its
## pictures' place and size - STRATEGY's pressed / normal pairs, the normal
## one matched on this frame (the same place for both of each pair);
## options_picture: the Game Options monitor's pair likewise, a little larger
## than the monitor the frame's glass takes clicks on.
const Layout := {
	"alliance": {
		"window": Rect2(54, 35, 488, 358),
		"slot": Vector2(3, 109),
		"monitor": Rect2(3, 358, 27, 34),
		"shelf": Rect2(546, 58, 60, 262),
		"picture": Vector2(21, 25),
		"agent": Rect2(541, 337, 67, 116),
		"messenger": Rect2(316, 411, 47, 69),
		"consoles": {
			"system_finder": Rect2(105, 407, 29, 18), "fleet_finder": Rect2(156, 406, 29, 17),
			"troop_finder": Rect2(208, 405, 29, 17), "personnel_finder": Rect2(257, 404, 29, 17),
			"encyclopedia": Rect2(394, 405, 28, 18), "gid": Rect2(445, 406, 28, 17),
		},
		"options_picture": Rect2(3, 355, 27, 41),
	},
	"empire": {
		"window": Rect2(118, 41, 489, 358),
		"slot": Vector2(611, 110),
		"monitor": Rect2(78, 196, 32, 48),
		"shelf": Rect2(20, 46, 55, 291),
		"picture": Vector2(84, 27),
		"agent": Rect2(0, 347, 106, 133),
		"messenger": Rect2(302, 401, 101, 79),
		"consoles": {
			"system_finder": Rect2(143, 434, 37, 24), "fleet_finder": Rect2(199, 434, 34, 22),
			"troop_finder": Rect2(253, 433, 34, 22), "personnel_finder": Rect2(412, 433, 34, 22),
			"encyclopedia": Rect2(465, 434, 36, 22), "gid": Rect2(519, 435, 36, 22),
		},
		"options_picture": Rect2(79, 193, 35, 57),
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
var _droids: Array = []   # [Droid]


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
	options.tooltip_text = ConsoleTips["options"]
	options.pressed.connect(on_options)
	add_child(options)
	_hold(options, "options", lay.get("options_picture", Rect2()))
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


## THE DROIDS (manual p022 Fig 2.3; p077-p078): the agent - "Right-click on
## C-3PO or IMP-22 to bring up the Agent menu" - and the message droid - "right-
## click on the message droid and select Messages. A shortcut is to left-click
## on your message droid or press F6". Each stands still on the original's
## resting frame, the first of the art set's strip (the anchor bitmap; its
## type-302 frames follow it, exporter 2.4.5): C-3PO "only moves when he is
## talking, otherwise he is still" (TeeJ, 2026-09-25), and talking is not
## built; when the message droid moves is not known (BACKLOG #45). A droid
## takes the mouse only on its own pixels. Tooltips are the side's names for
## them (TEXTSTRA 5383/5384: "C-3PO", "R2-D2"). Nothing without the
## pictures: an art set before 2.4.5.


func AddDroids(agent_name: String, messenger_name: String, on_agent: Callable, on_messages: Callable, on_messenger: Callable) -> void:
	var lay: Dictionary = Layout.get(Side, {})
	for role in ["agent", "messenger"]:
		var strip: Texture2D = Art.WindowPicture("droid_%s.%s" % [role, Side])
		if strip == null or not lay.has(role):
			continue
		var r: Rect2 = lay[role]
		var d := Droid.new()
		d.name = "Droid_" + role
		d.Setup(strip, int(r.size.x))
		d.position = Origin + r.position * S
		d.size = r.size * S
		d.tooltip_text = agent_name if role == "agent" else messenger_name
		var agent: bool = role == "agent"
		d.gui_input.connect(func(e: InputEvent) -> void:
			var b := e as InputEventMouseButton
			if b == null or b.pressed:
				return
			if b.button_index == MOUSE_BUTTON_RIGHT:
				(on_agent if agent else on_messenger).call(b.global_position)
			elif b.button_index == MOUSE_BUTTON_LEFT and not agent:
				on_messages.call())
		add_child(d)
		_droids.append(d)


## The droids on screen (for tests): the agent first, where there is one.
func Droids() -> Array:
	return _droids


## One droid: its strip cut to the frame it shows (the first: at rest),
## taking the mouse only where that frame is drawn.
class Droid extends TextureRect:
	var Frame := 0
	var Frames := 1
	var _strip: Image
	var _w := 1

	func Setup(strip: Texture2D, frame_width: int) -> void:
		_w = frame_width
		Frames = maxi(1, strip.get_width() / frame_width)
		_strip = strip.get_image()
		if _strip != null and _strip.is_compressed():
			_strip.decompress()
		var cut := AtlasTexture.new()
		cut.atlas = strip
		cut.region = Rect2(0, 0, _w, strip.get_height())
		texture = cut
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _has_point(p: Vector2) -> bool:
		if _strip == null or size.x <= 0 or size.y <= 0:
			return Rect2(Vector2.ZERO, size).has_point(p)
		var q := Vector2(p.x / size.x * _w, p.y / size.y * _strip.get_height())
		if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _strip.get_height():
			return false
		return _strip.get_pixel(Frame * _w + int(q.x), int(q.y)).a > 0.5


## THE CONTROL PANEL (manual p022 Fig 2.3: "Most of the game's controls are
## here"; p024: "the Galactic Information Display button on the Control Panel
## at the bottom of the screen"): the consoles' monitors as buttons, each with
## the original's tooltip (TEXTSTRA 5376-5382) and, while held down, its
## pressed picture (windows/console_<name>.<side>.pressed, exporter 2.4.5).
## `actions` maps a monitor's name to what it opens; a monitor without one
## stays part of the picture (the GID's menu: not built yet).
const ConsoleTips := {
	"options": "Game Controls", "system_finder": "System Finder", "fleet_finder": "Fleet Finder",
	"personnel_finder": "Personnel Finder", "troop_finder": "Troop Finder",
	"encyclopedia": "Encyclopedia", "gid": "Galactic Information Display",
}


func AddConsoles(actions: Dictionary) -> void:
	var consoles: Dictionary = Layout.get(Side, {}).get("consoles", {})
	for key in consoles:
		if not actions.has(key):
			continue
		var r: Rect2 = consoles[key]
		var b := Button.new()
		b.name = "Console_" + key
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.position = Origin + r.position * S
		b.size = r.size * S
		b.tooltip_text = ConsoleTips.get(key, "")
		b.pressed.connect(actions[key])
		add_child(b)
		_hold(b, key, r)


## The Control Panel's monitors on screen, by name (for tests).
func Consoles() -> Dictionary:
	var out := {}
	for n in get_children():
		if str(n.name).begins_with("Console_"):
			out[str(n.name).trim_prefix("Console_")] = n
	return out


## A monitor's pressed picture over it while the mouse holds it down, at the
## picture's own place (`at`, frame pixels).
func _hold(b: Button, key: String, at: Rect2) -> void:
	var pic: Texture2D = Art.WindowPicture("console_%s.%s.pressed" % [key, Side])
	if pic == null or at.size == Vector2.ZERO:
		return
	var held := TextureRect.new()
	held.name = "Held"
	held.texture = pic
	held.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	held.stretch_mode = TextureRect.STRETCH_SCALE
	held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held.position = Origin + at.position * S - b.position
	held.size = at.size * S
	held.visible = false
	b.add_child(held)
	b.button_down.connect(func() -> void: held.visible = true)
	b.button_up.connect(func() -> void: held.visible = false)


## The Window Reference Bar's twelve slots on screen.
func Shelf() -> Rect2:
	var r: Rect2 = Layout[Side]["shelf"]
	return Rect2(Origin + r.position * S, r.size * S)


## The whole frame on screen.
func ScreenRect() -> Rect2:
	return Rect2(Origin, FrameSize * S)


## The map's window on screen.
func MapWindow() -> Rect2:
	return Rect2(Origin + (Layout[Side]["window"] as Rect2).position * S, (Layout[Side]["window"] as Rect2).size * S)


## Where the galaxy map goes so it lies behind the frame as the original's
## does: its picture (the pack's map_image, fitted into GalaxyMap.Frame from
## its top-left) drawn where the original draws its galaxy picture, 1:1 at
## the frame's scale, and cut off at the frame's edge - past it (the
## Empire's picture runs 50 px beyond) it would show over the black.
func Place(map: Node2D) -> void:
	var fitted: Vector2 = GalaxyMap.Frame
	var at: Vector2 = Layout[Side]["picture"]
	map.position = Origin + at * S
	var k: float = (FrameSize.x * S) / fitted.x
	map.scale = Vector2(k, k)
	var backdrop: Sprite2D = map.call("Backdrop") if map.has_method("Backdrop") else null
	if backdrop != null and backdrop.texture != null:
		# The picture's pixels per frame pixel: fitted into Frame, then scaled.
		var perFrame: float = backdrop.scale.x * k / S
		var room: Vector2 = (FrameSize - at) / perFrame
		backdrop.region_enabled = true
		backdrop.region_rect = Rect2(Vector2.ZERO, room.min(backdrop.texture.get_size()))
