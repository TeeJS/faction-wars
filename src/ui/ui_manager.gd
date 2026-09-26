class_name UIManager
extends CanvasLayer
## frontend/UIManager.cs - opens, tracks, minimises and repaints every window;
## owns targeting (the crosshair), the drag state, the agent droid's menu, the
## Battle Alert and Battle Results windows, and the order dialogs.

@export var SectorWindowTemplate: PackedScene
@export var PlanetWindowTemplate: PackedScene
@export var DefenseWindowTemplate: PackedScene
@export var FleetWindowTemplate: PackedScene
@export var EconomyWindowTemplate: PackedScene
@export var MissionWindowTemplate: PackedScene
@export var InGameMenuWindowTemplate: PackedScene
@export var MessageWindowTemplate: PackedScene
@export var CharacterStatusWindowTemplate: PackedScene
@export var PersonnelFinderTemplate: PackedScene
@export var PlanetFinderTemplate: PackedScene
@export var TransitConfirmWindowTemplate: PackedScene
@export var UnitStatusWindowTemplate: PackedScene
@export var DefenseFacilityStatusWindowTemplate: PackedScene
@export var FleetStatusWindowTemplate: PackedScene

var IsTargeting: bool = false
var _targetingCallback: Callable = Callable()

## OBJECT TARGETING (manual p040): "Missions are OBJECT-SPECIFIC... In this case
## the target is a system, so click on ANY AREA OF BLANK SPACE in the system's
## window." Typed as object; the mission decides what it will accept.
var _objectTargetingCallback: Callable = Callable()

var ActiveGalaxyMap: GalaxyMap

# Track open windows, and which windows currently have a taskbar button.
var _openWindows: Dictionary = {}        # String -> DraggableWindow
var _taskbarButtons: Dictionary = {}     # DraggableWindow -> Button
## THE THEATRES ARE PINNED (TeeJ, 2026-09-22): every sector has a permanent
## button on the side panel from the start of the game, and its window always
## comes back to that button - minimised or closed - instead of gaining a
## second entry or vanishing. Other windows minimise to the panel or close as
## before. Sector name -> Button.
var _pinnedSectors: Dictionary = {}
var _pinOrder: Array = []            # sector names in map order, for re-pinning in place
var _pinMenu: PopupMenu = null       # "Unpin from menu" / "Pin to menu"
var _pinMenuSector: Sector = null
const PIN_MENU_ID := 1

var _taskbarList: VBoxContainer

var DraggedCharacters: Array = []   # null in C# when no drag is running
var DraggedUnits: Array = []
var DraggedFleets: Array = []

# Fast enough to feel immediate, slow enough that the comparison cost is
# irrelevant next to a frame.
const StatePollSeconds := 0.25
var _statePoll: Timer


## Whether the current targeting run will accept a clicked object at all.
func IsTargetingObject() -> bool:
	return IsTargeting and _objectTargetingCallback.is_valid()


const OriginalMenu := preload("res://src/ui/original_menu.gd")


func _ready() -> void:
	MapFrame = DefaultMapFrame   # until the Command Center frame is built
	ApplyOriginalCursors()
	# Every menu in play in the original's style (original_menu.gd), as it
	# enters the tree - not a text field's or a drop-down's own.
	get_tree().node_added.connect(_StyleMenu)
	# A window opened is the window in focus (Esc closes it).
	child_entered_tree.connect(func(n: Node) -> void:
		if _IsEscWindow(n):
			_focusedWindow = n)
	_taskbarList = get_node("%TaskbarList")
	var menuButton: Button = get_node_or_null("../MenuButton")
	if menuButton == null:
		menuButton = get_node_or_null("%MenuButton")
	if menuButton == null:
		menuButton = get_node_or_null("HBoxContainer/MenuButton")
	if menuButton != null:
		# The Menu button's `pressed` signal is already wired in Main.tscn (a
		# [connection] node -> OnMenuButtonClicked). Connecting it again here
		# raised "Signal already connected" errors on every load (#8), so the
		# code connect is dropped and the scene connection is the single source.
		# The build version, right of the Menu button (TeeJ, room #106).
		var ver := BuildInfo.label()
		menuButton.get_parent().add_child(ver)
		menuButton.get_parent().move_child(ver, menuButton.get_index() + 1)
		_versionLabel = ver
	# Loop through the CommsList to wire the HUD buttons dynamically.
	var commsList: VBoxContainer = get_node_or_null("CommsPanel/Margin/CommsList")
	if commsList != null:
		# "All Messages" at the top of the category list - opens the Comms Center
		# on its existing All tab (OnMessageIndexClicked defaults to "All"; the
		# index's own All Messages view, manual p079). Built in code so the .tscn
		# needs no editing, and idempotent so a rebuild does not double-add it.
		# RefreshCommsHighlights lights it whenever ANY category has unread mail,
		# because UnreadCount(MessageCategory.All) aggregates (event_bus.gd).
		if commsList.get_node_or_null("All") == null:
			var allBtn := Button.new()
			allBtn.name = "All"
			allBtn.text = "All Messages"
			commsList.add_child(allBtn)
			commsList.move_child(allBtn, 0)
		for btn in commsList.get_children():
			if btn is Button:
				var categoryName: String = btn.name
				btn.pressed.connect(func() -> void: OnMessageIndexClicked(categoryName))
	EventBus.OnDayAdvanced.append(RefreshActiveWindows)
	# Redraw the moment state changes, not only on the day tick (see EventBus).
	EventBus.OnStateChanged.append(RefreshNow)
	# The original's movies at their moments (docs/cutscenes-plan.md, phase 4).
	EventBus.OnMovieCue.append(_OnMovieCue)

	# The general answer to stale windows: every open window is asked what it is
	# showing, and repainted only if that differs from what it last painted.
	_statePoll = Timer.new()
	_statePoll.wait_time = StatePollSeconds
	_statePoll.autostart = true
	_statePoll.timeout.connect(PollOpenWindows)
	add_child(_statePoll)
	EventBus.OnMessageReceived.append(ShowHudNotification)

	# THE HIGHLIGHT IS DERIVED, NOT TOGGLED: read off the unread count.
	EventBus.OnStateChanged.append(RefreshCommsHighlights)
	# Painted once at start too, so imported alert icons show before any mail moves.
	call_deferred("RefreshCommsHighlights")
	# The tester's feedback box, bottom of the left column (TeeJ, room #80).
	if GameSettings.ProvideFeedback:
		add_child(FeedbackPanel.new())
	# No Galaxy Map Layers button: the GID bar's categories do all it did
	# (TeeJ, 2026-09-25: "the functionality this provides has all been moved
	# elsewhere - please remove it").


## THE COMMAND CENTER, when the art set has the side's frame (CommandFrame):
## the frame is the screen, the galaxy map behind its window, the Message
## Alert bar and the Game Options monitor in their places; the socket column
## is put away and the black either side replaces the grey.
var CommandFrameRef: CommandFrame = null
## THE MAP'S AREA ON SCREEN, where windows are centred and docked: the scene's
## map rectangle, or the frame's window once the frame is built.
static var MapFrame: Rect2 = Rect2(150, 99, 1070, 751)
const DefaultMapFrame := Rect2(150, 99, 1070, 751)
## With the frame: its layer, the GID bar's (GidBar.FramedLayer), and this.
const FrameLayer := 1
const WindowsLayer := 3
## The black behind the frame: below everything on the map's canvas.
const BackgroundZ := -100


func BuildCommandFrame(side: String) -> void:
	if CommandFrameRef != null or not CommandFrame.CanBuild(side):
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	# THE LAYERS, bottom to top: the galaxy map (the base canvas), the frame,
	# the GID's mode name and selector (GidBar), then every window and panel
	# (this). Without the frame the GID bar stays on the base canvas and this
	# on layer 1.
	var frameLayer := CanvasLayer.new()
	frameLayer.name = "CommandFrameLayer"
	frameLayer.layer = FrameLayer
	get_parent().add_child(frameLayer)
	var frame := CommandFrame.new()
	frameLayer.add_child(frame)
	frame.Build(side, screen,
		func(category: String) -> void: OnMessageIndexClicked(category), OnMenuButtonClicked)
	var us: Faction = GameSettings.PlayerFaction
	frame.AddDroids(AgentDroid.NameFor(us), AgentDroid.MessengerFor(us),
		func(at: Vector2) -> void: OpenAgentMenuAt(at),
		func() -> void: OnMessageIndexClicked("All"),
		func(at: Vector2) -> void: OpenMessengerMenuAt(at))
	frame.AddConsoles({
		"system_finder": func() -> void: OpenPlanetFinder(),
		"fleet_finder": func() -> void: OpenFleetFinder(),
		"troop_finder": func() -> void: OpenTroopFinder(),
		"personnel_finder": func() -> void: OpenPersonnelFinder(),
		"encyclopedia": func() -> void: OpenEncyclopedia(),
		"gid": func() -> void: OpenGidControlMenu(),
	})
	CommandFrameRef = frame
	MapFrame = frame.MapWindow()
	layer = WindowsLayer
	var map: Node2D = get_node_or_null("../GalaxyMap")
	if map != null:
		frame.Place(map)
	if ActiveGalaxyMap != null and ActiveGalaxyMap.Bar() != null:
		ActiveGalaxyMap.Bar().FitToFrame(MapFrame)
		ActiveGalaxyMap.Bar().FitKeyToFrame(frame)
	_BuildGidMenu(frame)
	_FitBottomBars(frame)
	var background: ColorRect = get_node_or_null("../Background")
	if background != null:
		background.color = Color.BLACK
		background.visible = true   # hidden in Main.tscn: the grey was the clear colour
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Under the galaxy picture, which draws at z -10 (GalaxyMap's backdrop):
		# at z 0 the black covered it and the map's window showed empty space.
		background.z_as_relative = false
		background.z_index = BackgroundZ
	var comms: Control = get_node_or_null("CommsPanel")
	if comms != null:
		comms.visible = false
	_BuildReferenceBar()


## THE BOTTOM UNDER THE FRAME (TeeJ, 2026-09-25). Both bars are gone: the
## blue one (the GID selector) for the left-hand menu - "This will completely
## eliminate the blue bar" - and the grey one, the row of finders, for the
## Control Panel's monitors and the droid - "we have replicated everything
## the grey bar does, remove it completely". Feedback is at the foot of the
## sector column; the build label stays at the frame's bottom right, where
## the bars ended. Without the left-hand menu (a screen too narrow for it)
## the blue bar stays, Feedback at its left end, the label at its right.
var _versionLabel: Label = null
const BarTop := -80.0      # the blue bar, from the screen's bottom (GidBar)
const BarBottom := -36.0
const BarInset := 2.0      # what sits on it, in from its edges


func _FitBottomBars(frame: CommandFrame) -> void:
	var across: Rect2 = frame.ScreenRect()
	# The row of finders goes: the Control Panel's monitors, the droid and the
	# left-hand menu do all it did (TeeJ, 2026-09-25: "we have replicated
	# everything the grey bar does, remove it completely").
	var row: HBoxContainer = get_node_or_null("HBoxContainer")
	if row != null:
		row.visible = false
	var bar: GidBar = ActiveGalaxyMap.Bar() if ActiveGalaxyMap != null else null
	if bar != null:
		bar.FitAcross(across)
		# The left-hand menu does all the blue bar did: it goes (TeeJ: "This
		# will completely eliminate the blue bar").
		if _gidMenu != null and bar.Panel() != null:
			bar.Panel().visible = false
	# The build label at the frame's bottom right, where the grey bar ended -
	# at the blue bar's right end without the left-hand menu.
	var top: float = BarTop if _gidMenu == null else GreyTop
	var bottom: float = BarBottom if _gidMenu == null else GreyBottom
	if _versionLabel != null:
		_versionLabel.reparent(self)
		_versionLabel.anchor_left = 0.0
		_versionLabel.anchor_right = 0.0
		_versionLabel.anchor_top = 1.0
		_versionLabel.anchor_bottom = 1.0
		_versionLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_versionLabel.offset_right = across.end.x - BarInset * 3.0
		_versionLabel.offset_left = _versionLabel.offset_right - 200.0
		_versionLabel.offset_top = top
		_versionLabel.offset_bottom = bottom
	# Feedback at the foot of the sector column (TeeJ, 2026-09-25: "move the
	# feedback button to the bottom of the right hand panel"), where the map
	# key's button once was; the sectors stop above it. Without the left-hand
	# menu it stays at the blue bar's left end and the key's button takes the
	# foot.
	var feedback: FeedbackPanel = get_node_or_null("FeedbackPanel")
	var tb: Control = get_node_or_null("TaskbarPanel")
	var footUsed: bool = _gidMenu == null or feedback != null
	if tb != null:
		tb.offset_bottom = -(ColumnFoot + KeyButtonHeight + KeyButtonGap) if footUsed else 0.0
	if feedback != null:
		if _gidMenu != null:
			var right: float = get_viewport().get_visible_rect().size.x
			feedback.FitToBar(right - FeedbackPanel.Width - 3.0, -(ColumnFoot + KeyButtonHeight), -ColumnFoot)
			# Over the sectors when it opens upward.
			if tb != null and feedback.get_index() < tb.get_index():
				move_child(feedback, tb.get_index())
		else:
			feedback.FitToBar(across.position.x, top + BarInset, bottom - BarInset)
	var key: Button = get_node_or_null("MapKeyButton")
	if key != null:
		_PlaceKeyButton(key)


## THE GALAXY DISPLAY MENU down the left-hand column (gid_menu.gd), in the
## black left of the frame.
const GidMenuScript := preload("res://src/ui/gid_menu.gd")
const GreyTop := -34.0     # the grey bar, from the screen's bottom (Main.tscn)
const GreyBottom := -3.0
var _gidMenu: Control = null


func _BuildGidMenu(frame: CommandFrame) -> void:
	if _gidMenu != null or ActiveGalaxyMap == null or frame.Origin.x < 100.0:
		return
	_gidMenu = GidMenuScript.new()
	add_child(_gidMenu)
	move_child(_gidMenu, 0)   # under every window
	_gidMenu.call("Build", frame.Origin.x, ActiveGalaxyMap, func() -> void:
		if ActiveGalaxyMap != null and ActiveGalaxyMap.Bar() != null:
			ActiveGalaxyMap.Bar().ToggleKey())


func GidMenu() -> Control:
	return _gidMenu


## THE WINDOW REFERENCE BAR ("The Window Reference Bar has twelve slots for
## minimized System windows", manual p022): the frame's shelf - the
## Alliance's slats, the Empire's blue panel - takes every minimised window,
## one to a slat, the shelf's own slats showing through; past twelve they
## share its height. The sectors keep the grey bar on the right: the
## original's sector windows did not minimise (TeeJ, 2026-09-25: "sectors
## collapse to the grey bar on the right and everything else
## collapses/minimised to the panel used by the original"; "those 12 slats
## would be for everything but sectors").
var _referenceList: VBoxContainer = null
const ShelfSlots := 12


func _BuildReferenceBar() -> void:
	if CommandFrameRef == null or _referenceList != null:
		return
	var shelf: Rect2 = CommandFrameRef.Shelf()
	_referenceList = VBoxContainer.new()
	_referenceList.name = "ReferenceBar"
	_referenceList.position = shelf.position
	_referenceList.size = shelf.size
	_referenceList.add_theme_constant_override("separation", 0)
	add_child(_referenceList)
	move_child(_referenceList, 0)   # under every window
	# Anything already minimised moves across.
	for w in _taskbarButtons:
		var btn: Button = _taskbarButtons[w]
		if is_instance_valid(btn) and btn.get_parent() != null:
			btn.reparent(_referenceList)
	_referenceList.child_entered_tree.connect(func(_n: Node) -> void: call_deferred("RelayoutShelf"))
	_referenceList.child_exiting_tree.connect(func(_n: Node) -> void: call_deferred("RelayoutShelf"))
	RelayoutShelf()


## A minimised window's kind, as the sector window's corner icon for it:
## Manufacturing, Defenses, Fleet or Mission. Null for any other window. Only
## the glyph: the corner icon is a 27x18 cell with its glyph in one corner,
## and the original's shelf draws the glyph alone (11x7 before Commenor).
func _WindowKindIcon(window: DraggableWindow) -> Texture2D:
	var glyph := ""
	if window is EconomyWindow:
		glyph = "manufacturing"
	elif window is DefenseWindow:
		glyph = "defenses"
	elif window is FleetWindow:
		glyph = "fleet"
	elif window is MissionWindow or window.get_script() == OriginalMissionScript:
		glyph = "mission"
	if glyph.is_empty():
		return null
	var cell: Texture2D = Art.CornerIcon(glyph, OUI.Side(GameSettings.PlayerFaction))
	if cell == null:
		return null
	var img: Image = cell.get_image()
	if img == null:
		return cell
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return cell
	var only := AtlasTexture.new()
	only.atlas = cell
	only.region = Rect2(used)
	return only


## Where a minimised window's button goes: the Window Reference Bar with the
## frame, else the taskbar under the sectors.
func _MinimisedList() -> VBoxContainer:
	return _referenceList if _referenceList != null else _taskbarList


## A shelf entry as the original draws it (TeeJ's screenshot of Commenor,
## 2026-09-25: "too hard to read, esp compared to the original"), in the
## frame's pixels: the kind icon 2 px in from the slat's edge, the system name
## straight after it in pure yellow, regular weight, 8 px capitals (Arial 11),
## no outline and no fill - the bare slat behind - centred on the slat.
const ShelfText := Color(1, 1, 0)
const ShelfTextPx := 11.0
const ShelfInset := 2.0
const ShelfIconW := 11.0


## The shelf's entries: one slat high (or an even share of the shelf past
## twelve).
func RelayoutShelf() -> void:
	if CommandFrameRef == null or _referenceList == null:
		return
	var shelf: Rect2 = CommandFrameRef.Shelf()
	var s: float = CommandFrameRef.S
	var entries: Array = _referenceList.get_children().filter(func(n: Node) -> bool:
		return n is Button and not n.is_queued_for_deletion())
	var h: float = shelf.size.y / float(maxi(ShelfSlots, entries.size()))
	for b in entries:
		var btn: Button = b
		btn.custom_minimum_size = Vector2(shelf.size.x, h)
		btn.flat = true
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = btn.text
		# The icon at the original's size: fitted to the entry's height, then
		# held to its own width at the frame's scale.
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", roundi(ShelfIconW * s))
		btn.add_theme_constant_override("h_separation", 0)
		var bare := StyleBoxEmpty.new()
		bare.content_margin_left = ShelfInset * s
		bare.content_margin_right = ShelfInset * s
		for st in ["normal", "focus", "disabled", "hover", "pressed", "hover_pressed"]:
			btn.add_theme_stylebox_override(st, bare)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			btn.add_theme_color_override(c, ShelfText)
		btn.add_theme_constant_override("outline_size", 0)
		btn.add_theme_font_override("font", OUI.Face(false))
		btn.add_theme_font_size_override("font_size", roundi(ShelfTextPx * s))


const MoviesLib := preload("res://src/ui/movies.gd")


## A moment the pack may have a movie for: played for this client's side when
## it is one of `sides` (every side when empty), after the simulation's step.
## Whom each plays for is INFERRED where the original's is unknown: the
## destroyed system's owner and the destroyer, both sides of a sabotaged
## Death Star; victory and defeat are each side's own (their crawls say so);
## a headquarters lost is shown to everyone (Rebellion 2's remake does so).
func _OnMovieCue(event: String, sides: Array) -> void:
	if not sides.is_empty() and not sides.has(GameSettings.LocalFaction()):
		return
	(func() -> void: MoviesLib.Play(get_tree(), event)).call_deferred()


func _exit_tree() -> void:
	# Always unsubscribe from static events when the node is destroyed.
	EventBus.OnDayAdvanced.erase(RefreshActiveWindows)
	EventBus.OnStateChanged.erase(RefreshNow)
	EventBus.OnMovieCue.erase(_OnMovieCue)
	EventBus.OnStateChanged.erase(RefreshCommsHighlights)
	EventBus.OnMessageReceived.erase(ShowHudNotification)


## Paints each category button from what is actually unread in it.
## THE COLUMN IS THE MESSAGE INDEX'S STRIP (manual p079 Fig 3.19; TeeJ,
## 2026-09-23, against his screenshots of the original's Message Index):
## with the art imported, each category is the original's own 36x41 socket -
## the galaxy for All Messages, then Loyalty, Fleets, Missions, Resources,
## Manufacturing, Defense, Conflict, Chat and Advice in the side's versions -
## the blue socket on the category on show, and the unread count in yellow on
## the socket's corner. Each socket is its top 36 rows - under them the
## strip's own band and the list box's dotted edge, which belong to a
## horizontal strip - drawn 1.5x (all ten fit the column above the Feedback
## box), nearest-neighbour so the pixels stay crisp. Without the art, the text
## buttons, yellow when mail waits.
const Art := preload("res://src/ui/artwork.gd")
const SocketRows := 36
const SocketSize := Vector2i(54, 54)   # 36x36 at 1.5x
const SocketNames := {
	"All": "msg_all", "Loyalty": "msg_loyalty", "Fleets": "msg_fleets", "Missions": "msg_missions",
	"Resources": "msg_resources", "Manufacturing": "msg_manufacturing", "Defense": "msg_defense",
	"Conflict": "msg_conflict", "Chat": "msg_chat", "Advice": "msg_advice",
}
static var _sockets: Dictionary = {}


## A socket picture at the column's size, cached.
static func Socket(category: String, side: String, current: bool) -> Texture2D:
	var key := "%s.%s.%s" % [category, side, current]
	if _sockets.has(key):
		return _sockets[key]
	var tex: Texture2D = Art.TabIcon(SocketNames.get(category, ""), side, "pressed" if current else "")
	if tex == null:
		return null
	var img: Image = tex.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img = img.get_region(Rect2i(0, 0, img.get_width(), mini(SocketRows, img.get_height())))
	# A raised button's four corner pixels are the plate's grey in the bitmap:
	# clear them, so it stands on whatever is behind the column. The current
	# (blue) tile's bottom corners are its own fill - it fuses into the band.
	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var corners: Array = [Vector2i(0, 0), Vector2i(w - 1, 0)]
	if not current:
		corners.append_array([Vector2i(0, h - 1), Vector2i(w - 1, h - 1)])
	for c in corners:
		img.set_pixelv(c, Color(0, 0, 0, 0))
	img.resize(SocketSize.x, SocketSize.y, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(img)
	_sockets[key] = out
	return out


func RefreshCommsHighlights() -> void:
	if CommandFrameRef != null:
		CommandFrameRef.RefreshAlerts()
	var commsList: VBoxContainer = get_node_or_null("CommsPanel/Margin/CommsList")
	if commsList == null:
		return
	var side: String = GameSettings.PlayerFaction.ArtSkin if GameSettings.PlayerFaction != null else ""
	var showing: String = CommsCategory()
	var pictured: bool = Socket("All", side, false) != null
	if pictured:
		_StyleCommsColumn(commsList)
	for btn in commsList.get_children():
		if not (btn is Button):
			continue
		# The column is the docked Comms Center's tab bar: the category on show
		# reads as current.
		var active: bool = btn.name == showing
		if active:
			btn.set_meta("active_tab", true)
		elif btn.has_meta("active_tab"):
			btn.remove_meta("active_tab")
		var unread: int = EventBus.UnreadCount(Enums.MessageCategory[btn.name]) \
			if Enums.MessageCategory.has(btn.name) else 0
		var icon: Texture2D = Socket(btn.name, side, active) if pictured else null
		if icon != null:
			if not btn.has_meta("alert_icon"):
				btn.set_meta("alert_icon", true)
				btn.set_meta("label", btn.text)
				btn.tooltip_text = btn.text
				btn.text = ""
				btn.flat = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.expand_icon = false
				btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				btn.custom_minimum_size = Vector2(SocketSize)
				btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				var empty := StyleBoxEmpty.new()
				for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
					btn.add_theme_stylebox_override(st, empty)
			btn.icon = icon
			_Badge(btn, unread)
			btn.remove_theme_color_override("font_color")
			btn.modulate = Color.WHITE
			continue
		# Plain text buttons (no art imported, or no longer).
		if btn.has_meta("alert_icon"):
			btn.remove_meta("alert_icon")
			btn.icon = null
			btn.text = btn.get_meta("label")
			btn.flat = false
			btn.custom_minimum_size = Vector2.ZERO
			btn.size_flags_horizontal = Control.SIZE_FILL
			for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
				btn.remove_theme_stylebox_override(st)
		_Badge(btn, 0)
		if active:
			btn.add_theme_stylebox_override("normal", btn.get_theme_stylebox("pressed"))
			btn.add_theme_stylebox_override("hover", btn.get_theme_stylebox("pressed"))
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
		if unread > 0:
			btn.add_theme_color_override("font_color", Color.YELLOW)
			btn.modulate = Color(1.5, 1.5, 0.5)
		else:
			btn.remove_theme_color_override("font_color")
			btn.modulate = Color.WHITE


## The column behind the sockets: the Command Center's dark recess, the
## sockets packed as the original packs its strip.
func _StyleCommsColumn(commsList: VBoxContainer) -> void:
	if commsList.has_meta("styled"):
		return
	commsList.set_meta("styled", true)
	commsList.add_theme_constant_override("separation", 3)
	var margin: MarginContainer = commsList.get_parent() as MarginContainer
	if margin != null:
		for sideName in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + sideName, 3)
	# No panel behind the sockets: each is the original's own raised button,
	# standing on the screen (TeeJ, 2026-09-23: "get rid of the black
	# background - these should look like buttons").
	var panel: PanelContainer = get_node_or_null("CommsPanel")
	if panel != null:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


## The unread count on a socket's corner, yellow with a black edge; hidden at
## zero. `width` is the socket's, for a socket that is not the column's (the
## Message Index's tabs).
static func _Badge(btn: Control, count: int, width: float = SocketSize.x) -> void:
	var badge: Label = btn.get_node_or_null("Badge")
	if count <= 0:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		# Sized with the socket: the column's are 54 wide, the index's 72.
		var scale: float = width / float(SocketSize.x)
		badge = Label.new()
		badge.name = "Badge"
		badge.position = Vector2(width - 22 * scale, -2)
		badge.size = Vector2(22, 16) * scale
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", roundi(13 * scale))
		badge.add_theme_color_override("font_color", Color.YELLOW)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(badge)
	badge.text = str(count)
	badge.visible = true


func ShowHudNotification(msg: GameMessage) -> void:
	if not EventBus.Visible(msg):
		return   # the other side's message, in a head-to-head game
	var ticker: Label = get_node_or_null("%HudTicker")
	if ticker != null:
		ticker.text = "INCOMING TRANSMISSION: %s" % msg.Title
		ticker.modulate = Color.YELLOW

	# Highlight the category button in the CommsList; the category enum name
	# matches the node name (e.g., "Fleets").
	var commsList: VBoxContainer = get_node_or_null("CommsPanel/Margin/CommsList")
	if commsList != null:
		var categoryName: String = JsonUtil.enum_name(Enums.MessageCategory, msg.Category)
		var categoryBtn: Button = commsList.get_node_or_null(categoryName)
		if categoryBtn != null:
			categoryBtn.add_theme_color_override("font_color", Color.YELLOW)
			categoryBtn.modulate = Color(1.5, 1.5, 0.5)


## Compose Chat Message (manual p163, Fig 5.11). Loaded by path: the window
## did not exist when Main.tscn's template slots were assigned.
const ComposeChatMessageWindowScene := "res://src/ui/ComposeChatMessageWindow.tscn"


func OpenComposeChatMessage() -> void:
	OpenWindow("Compose Chat Message", load(ComposeChatMessageWindowScene),
		func(window) -> void: window.Setup(self),
		Vector2(120, 120))


## THE COMMS CENTER IS DOCKED (TeeJ, 2026-09-23): it opens on the left edge of
## the map frame at the frame's full height, with no tab strip of its own - the
## Message Alert column IS its tab bar (the column's buttons switch the
## category and the current one shows pressed), so the list gets the room the
## tabs took. Still a window: minimise and close work, and it re-docks on
## every open rather than drifting. Manual p079 Fig 3.20 has the Message
## Index over the whole display.
const CommsRect := Rect2(150, 99, 1000, 671)


func OnMessageIndexClicked(category: String = "All") -> void:
	# Docked at the map's top-left: the scene's, or the frame's window.
	var at: Vector2 = MapFrame.position if CommandFrameRef != null else CommsRect.position
	OpenWindow("Communications", MessageWindowTemplate,
		func(window) -> void:
			window.Setup(self)   # without this the window's _uiManager is null and Go To is a no-op
			# The original's Message Index is its 470x330 frame, drawn 2x.
			var dock: Vector2 = window.OriginalSize() if window._original else CommsRect.size
			window.custom_minimum_size = dock
			window.size = dock
			window.position = at
			window._tabContainer.tabs_visible = false
			window.OpenToCategory(category)
			# Docked: after OpenWindow has placed it (it nudges new windows), so
			# the dock position is the one that stands.
			window.set_deferred("position", at)
			RefreshCommsHighlights(),
		at)


## THE GALACTIC ENCYCLOPEDIA (manual p073-p074). One entry point: no
## arguments opens the Index view (the Encyclopedia control, F7); a kind and
## an id open that topic (right-click -> Encyclopedia, the i button). Kinds
## are the overlay's: planets, units, facilities, missions, characters.
## Preloaded by path: a new class_name can lag the editor's class cache.
const EncyclopediaScene := preload("res://src/ui/EncyclopediaWindow.tscn")
const EncyclopediaRect := Rect2(185, 99, 1000, 671)


func OpenEncyclopedia(kind: String = "", id: String = "") -> void:
	OpenWindow("Encyclopedia", EncyclopediaScene,
		func(window) -> void:
			window.Setup(self)
			if not kind.is_empty():
				window.ShowTopic(kind, id)
			window.set_deferred("position", EncyclopediaPosition(window)),
		EncyclopediaRect.position)


## The original's Encyclopedia sits in the middle of the Command Center's
## screen: centred over the map frame. The plain one keeps its rectangle.
func EncyclopediaPosition(window: Control) -> Vector2:
	if not window.get("_original"):
		return EncyclopediaRect.position
	var size: Vector2 = window.get_combined_minimum_size()
	return (MapFrame.get_center() - size / 2.0).floor().max(MapFrame.position)


## THE ORIGINAL'S MOUSE POINTERS (TeeJ, 2026-09-23: "we need the cursor to
## match"): its arrow everywhere, and its crosshair while a target is being
## picked (targeting switches the shape to CURSOR_CROSS), drawn 2x like the
## rest of the original's art, each at its own hotspot. Without the imported
## art (or on another pack) the system's pointers come back.
func ApplyOriginalCursors() -> void:
	var pointer: Texture2D = Art.CursorPicture("pointer")
	var cross: Texture2D = Art.CursorPicture("crosshair")
	var k: int = 2
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		if pointer != null:
			Input.set_custom_mouse_cursor(Art.Scaled(pointer, k), shape, Art.CursorHotspot("pointer") * k)
		else:
			Input.set_custom_mouse_cursor(null, shape)
	if cross != null:
		Input.set_custom_mouse_cursor(Art.Scaled(cross, k), Input.CURSOR_CROSS, Art.CursorHotspot("crosshair") * k)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)


## THE ORIGINAL'S CONFIRMATION DIALOG (confirm_window.gd), centred over the
## map frame and modal. Preloaded by path: a new script can lag the class cache.
const ConfirmScene := preload("res://src/ui/ConfirmWindow.tscn")
const ConfirmScript := preload("res://src/ui/confirm_window.gd")


func OpenConfirmation(f: Faction, picture: Texture2D, text: String, okTip: String, onConfirm: Callable) -> void:
	var size := Vector2(ConfirmScript.FrameW, ConfirmScript.FrameH) * ConfirmScript.K
	var at: Vector2 = (MapFrame.get_center() - size / 2.0).floor().max(MapFrame.position)
	OpenWindow("Confirm", ConfirmScene,
		func(window) -> void: window.Setup(self, f, picture, text, okTip, onConfirm),
		at)


## THE BUILD SELECTION WINDOW as the original draws it (manual p045, p112 Fig
## 3.58), centred and modal like the dialog it replaces. `items` are the
## catalogue rows EconomyWindow.OpenBuildChooser prepared.
## Preloaded by path: a new script can lag the editor's class cache.
const BuildSelectionScene := preload("res://src/ui/BuildSelectionWindow.tscn")
const BuildSelectionScript := preload("res://src/ui/build_selection_window.gd")


func OpenBuildSelection(f: Faction, items: Array, deployDays: int, destination: String, helpers: int, onDone: Callable) -> void:
	var size := Vector2(BuildSelectionScript.PlateW, BuildSelectionScript.PlateH) * BuildSelectionScript.K
	var at: Vector2 = ((get_viewport().get_visible_rect().size - size) / 2.0).floor()
	OpenWindow("Build Selection", BuildSelectionScene,
		func(window) -> void: window.Setup(self, f, items, deployDays, destination, helpers, onDone),
		at)


## THE CREATE MISSION WINDOW as the original draws it (manual p042 Fig 2.34,
## p103-p104 Figs 3.47 / 3.48), centred and modal like the dialog it replaces,
## when the player imported its art. False when not: the caller then shows
## the plain dialog. `launch` takes (mission type, decoys).
## Preloaded by path: a new script can lag the editor's class cache.
const CreateMissionScene := preload("res://src/ui/CreateMissionWindow.tscn")
const CreateMissionScript := preload("res://src/ui/create_mission_window.gd")


func OpenCreateMission(team: Array, origin: Planet, target: Planet, victim: Character, thing: Variant,
		legal: Array, launch: Callable) -> bool:
	if not CreateMissionScript.CanBuild():
		return false
	var size := Vector2(CreateMissionScript.PlateW, CreateMissionScript.PlateH) * CreateMissionScript.K
	var at: Vector2 = ((get_viewport().get_visible_rect().size - size) / 2.0).floor()
	OpenWindow("Create Mission", CreateMissionScene,
		func(window) -> void: window.Setup(self, team, origin, target, victim, thing, legal, launch),
		at)
	return true


## The category the docked Comms Center is showing, or "" when it is not open.
func CommsCategory() -> String:
	var w: DraggableWindow = _openWindows.get("Communications")
	if w == null or not is_instance_valid(w) or not w.visible:
		return ""
	var tabs: TabContainer = w._tabContainer
	if tabs == null or tabs.current_tab < 0:
		return ""
	return tabs.get_child(tabs.current_tab).name


func OnSectorClicked(sector: Sector) -> void:
	var original := SectorWindow.CanBuildOriginal()
	# A second sector opens on the other side from the one already open, not
	# over it (TeeJ, 2026-09-25: "it should default to the opposite side of
	# the screen"). The first opens where it always has: the original's
	# docked on the right, the plain one at the upper left.
	var fresh := not (_openWindows.has(sector.Name) and is_instance_valid(_openWindows[sector.Name]))
	var right := _NewSectorOnRight(sector.Name, original) if fresh else true
	var targetPos := Vector2(100 + randf() * 50, 100 + randf() * 50)
	if not original and right:
		targetPos.x = get_viewport().get_visible_rect().size.x   # kept on screen by GetSafeWindowPosition
	# The original's sector window docks against the map frame's right edge;
	# its box moves it to the left and back (SectorWindow._SwitchSide).
	if original:
		targetPos = SectorWindow.DockPosition(right)
	OpenWindow(sector.Name, SectorWindowTemplate,
		func(window) -> void:
			if fresh:
				window.set("_dockRight", right)
			window.get_node("%Title").text = sector.Name
			window.Populate(sector, self)
			_WireSectorPinMenu(window, sector),
		targetPos)


## Which side a new sector window opens on: its usual side (the right for the
## original's, the left for the plain one) unless another sector's window is
## on it and the other side is free. A window's side is where its middle is,
## so one dragged across counts where it now sits.
func _NewSectorOnRight(opening: String, original: bool) -> bool:
	var mid: float = MapFrame.get_center().x if original else get_viewport().get_visible_rect().size.x / 2.0
	var onLeft := false
	var onRight := false
	for n in _openWindows:
		var w: Variant = _openWindows[n]
		if n == opening or not is_instance_valid(w) or not (w is SectorWindow) or not (w as Control).visible:
			continue
		if (w as Control).get_global_rect().get_center().x >= mid:
			onRight = true
		else:
			onLeft = true
	var usual := original
	var taken := onRight if usual else onLeft
	var other := onLeft if usual else onRight
	return (not usual) if taken and not other else usual


## Right-click on the title bar: "Pin to menu" / "Unpin from menu". Setup
## runs again on every restore, so this wires it once. The original's window
## has no bar: its title takes the right-click.
func _WireSectorPinMenu(window: Control, sector: Sector) -> void:
	if window.has_meta("pin_menu_wired"):
		return
	window.set_meta("pin_menu_wired", true)
	for bar in [window.get_node("%TitleBar"), window.get("_originalTitle")]:
		if bar is Control:
			(bar as Control).gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
					ShowPinMenu(sector))


func OnPlanetClicked(planetData: Planet) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	if IsTargeting:
		ResolveTarget(planetData)
	else:
		OpenWindow(planetData.Name, PlanetWindowTemplate,
			func(window) -> void: window.Populate(planetData),
			targetPos)


func OnDefenseClicked(planetData: Planet) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	OpenWindow(planetData.Name + " Defenses", DefenseWindowTemplate,
		func(window) -> void: window.Populate(planetData, self),
		targetPos)


func OnFleetClicked(planetData: Planet) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	OpenWindow(planetData.Name + " Fleets", FleetWindowTemplate,
		func(window) -> void: window.Populate(planetData, self),
		targetPos)


func OnEconomyClicked(planetData: Planet) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	OpenWindow(planetData.Name + " Economy", EconomyWindowTemplate,
		func(window) -> void: window.Populate(planetData),
		targetPos)


## The original's Mission window (p109 Fig 3.51) when the player imported its
## art; the plain one otherwise. Preloaded by path, like Create Mission's.
const OriginalMissionScene := preload("res://src/ui/OriginalMissionWindow.tscn")
const OriginalMissionScript := preload("res://src/ui/original_mission_window.gd")


func OnMissionClicked(planetData: Planet) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	OpenWindow(planetData.Name + " Missions",
		OriginalMissionScene if OriginalMissionScript.CanBuild() else MissionWindowTemplate,
		func(window) -> void: window.Populate(planetData),
		targetPos)


## The original's Game Options screen (manual p075-p076, Fig. 3.16), which is
## the Game Menu and the save slots in one, when the player imported its art.
## Preloaded by path: a new script can lag the editor's class cache.
const OptionsScreenScript := preload("res://src/ui/original_options_screen.gd")


func OpenOptionsScreen() -> void:
	if get_node_or_null("OptionsScreen") != null:
		return
	var screen: Control = OptionsScreenScript.new()
	add_child(screen)
	# Nothing opens over it: whatever is added while it is up (a window a key
	# opened, a minimised button) goes under it.
	if not child_entered_tree.is_connected(_KeepOptionsOnTop):
		child_entered_tree.connect(_KeepOptionsOnTop)


func _KeepOptionsOnTop(n: Node) -> void:
	var screen: Node = get_node_or_null("OptionsScreen")
	if screen == null or n == screen:
		return
	(func() -> void:
		if is_instance_valid(screen) and screen.get_parent() == self and not screen.is_queued_for_deletion():
			move_child(screen, -1)).call_deferred()


func OnMenuButtonClicked() -> void:
	if OptionsScreenScript.CanBuild():
		OpenOptionsScreen()
		return
	var viewportSize: Vector2 = get_viewport().get_visible_rect().size
	var centerPos: Vector2 = (viewportSize / 2.0) - Vector2(110, 80)
	OpenWindow("GameMenu", InGameMenuWindowTemplate, func(_window) -> void: pass, centerPos)


func OpenCharacterStatusWindow(character: Character) -> void:
	# The original's Status window with the imported art (CharacterStatusWindow.StatusData).
	if OUI.HasStatus():
		OpenStatusPlate("Status_%s" % character.Name.replace(" ", ""),
			func() -> Dictionary: return CharacterStatusWindow.StatusData(character))
		return
	# Spawns slightly offset so it doesn't perfectly overlap the Defense Window.
	var targetPos := Vector2(300, 200)
	OpenWindow("Status_%s" % character.Name.replace(" ", ""),   # so several can open at once
		CharacterStatusWindowTemplate,
		func(window) -> void: window.Populate(character),
		targetPos)
	print("--- STATUS REPORT: %s ---" % character.Name)
	print("Commanding: %s" % str(character.Commanding))
	print("Attached: %s" % str(character.Attached))
	print("Status: %s" % JsonUtil.enum_name(Enums.Status, character.Status))
	print("Diplomacy: %d" % character.DiplomacyRating)
	print("Espionage: %d" % character.EspionageRating)
	print("Combat: %d" % character.CombatRating)
	print("Leadership: %d" % character.LeadershipRating)
	print("Ship Design: %d" % character.ShipDesign)
	print("Troop Training: %d" % character.TroopTraining)
	print("Facility Design: %d" % character.FacilityDesign)


# --- TASKBAR LOGIC ---
## THE TASKBAR, FOR THINGS THAT ARE NOT DraggableWindows (the GID key).
## Returns the button so the caller can hand it back to RemoveFromTaskbar.
## One permanent side-panel button per sector, at the top of the panel, in
## map order. Pressing it opens the sector window, or brings it back when
## minimised. Called by GalaxyMap.InitializeMap, so a loaded game pins too.
func PinSectors(galaxy: Array) -> void:
	for name in _pinnedSectors.keys():
		var old: Button = _pinnedSectors[name]
		if is_instance_valid(old):
			_taskbarList.remove_child(old)
			old.queue_free()
	_pinnedSectors.clear()
	_pinOrder.clear()
	for sector in galaxy:
		_pinOrder.append(sector.Name)
	# At the top, in map order, so the panel reads: the theatres, then whatever
	# windows are minimised. (The docked GID key is in the left column.)
	var index := 0
	for sector in galaxy:
		_taskbarList.move_child(_pin_button(sector), index)
		index += 1


## The permanent sector buttons, by sector name.
func PinnedSectors() -> Dictionary:
	return _pinnedSectors


func IsPinned(sector: Sector) -> bool:
	return _pinnedSectors.has(sector.Name)


## One pinned button: left-click opens/restores, right-click offers "Unpin".
func _pin_button(sector: Sector) -> Button:
	var local: Sector = sector
	var btn := Button.new()
	btn.text = local.Name
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", 14)
	btn.tooltip_text = "%s - right-click to unpin" % local.Name
	btn.pressed.connect(func() -> void: OnSectorClicked(local))
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			ShowPinMenu(local))
	_taskbarList.add_child(btn)
	_pinnedSectors[local.Name] = btn
	return btn


## "Unpin from menu" (TeeJ, 2026-09-22): the button goes, its window closes
## if open, and for the rest of the session that theatre minimises and closes
## like any other window. Pins are not remembered between games.
func UnpinSector(name: String) -> void:
	if not _pinnedSectors.has(name):
		return
	var btn: Button = _pinnedSectors[name]
	_pinnedSectors.erase(name)
	if is_instance_valid(btn):
		_taskbarList.remove_child(btn)
		btn.queue_free()
	if _openWindows.has(name):
		var w: DraggableWindow = _openWindows[name]
		if is_instance_valid(w):
			w.CloseWindow()


## "Pin to menu": the mirror. The button returns to its place in map order,
## before any minimised window.
func PinSector(sector: Sector) -> void:
	if _pinnedSectors.has(sector.Name):
		return
	var before := 0
	for name in _pinOrder:
		if name == sector.Name:
			break
		if _pinnedSectors.has(name):
			before += 1
	var btn := _pin_button(sector)
	_taskbarList.move_child(btn, before)
	# If its window is minimised on a normal button, that button is now redundant.
	if _openWindows.has(sector.Name):
		var w: DraggableWindow = _openWindows[sector.Name]
		if _taskbarButtons.has(w):
			var old: Button = _taskbarButtons[w]
			if is_instance_valid(old):
				if old.get_parent() != null:
					old.get_parent().remove_child(old)
				old.queue_free()
			_taskbarButtons.erase(w)


## The one-item menu, worded for the theatre's current state.
func ShowPinMenu(sector: Sector) -> void:
	if _pinMenu == null:
		_pinMenu = PopupMenu.new()
		add_child(_pinMenu)
		_pinMenu.id_pressed.connect(func(id: int) -> void:
			if id != PIN_MENU_ID or _pinMenuSector == null:
				return
			if IsPinned(_pinMenuSector):
				UnpinSector(_pinMenuSector.Name)
			else:
				PinSector(_pinMenuSector))
	_pinMenuSector = sector
	_pinMenu.clear()
	_pinMenu.add_item("Unpin from menu" if IsPinned(sector) else "Pin to menu", PIN_MENU_ID)
	_pinMenu.position = Vector2i(get_viewport().get_mouse_position())
	_pinMenu.popup()


func PinMenu() -> PopupMenu:
	return _pinMenu


## The docked GID key's button sits at the bottom of the LEFT column, just
## above the Feedback box - or in its place when there is none (TeeJ,
## 2026-09-24: moved from the top of the right-hand panel). As wide as the
## column, in the Feedback button's size of type so a long title fits. Under
## the Command Center frame it is the foot of the SECTOR column instead
## (TeeJ, 2026-09-25: "move loyalty to the alliance to the bottom of the
## sector column"), the sectors stopping above it.
const KeyButtonHeight := 30.0
const KeyButtonGap := 4.0
const ColumnFoot := 8.0      # the key under the frame, from the screen's bottom


func AddToTaskbar(title: String, onRestore: Callable) -> Button:
	var btn := Button.new()
	btn.name = "MapKeyButton"
	btn.text = title
	btn.tooltip_text = title
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void:
		if onRestore.is_valid():
			onRestore.call())
	add_child(btn)
	_PlaceKeyButton(btn)
	return btn


func _PlaceKeyButton(btn: Button) -> void:
	# With the left-hand menu, its "Loyalty to ..." line is the way to the key.
	btn.visible = _gidMenu == null
	if CommandFrameRef != null:
		# The sector column's foot: the column's width, inside its margins.
		btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		btn.offset_left = -146.0
		btn.offset_right = -3.0
		btn.offset_bottom = -ColumnFoot
		btn.offset_top = -ColumnFoot - KeyButtonHeight
		return
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var bottom: float = FeedbackPanel.ColumnBottom
	var feedback: FeedbackPanel = get_node_or_null("FeedbackPanel")
	if feedback != null and feedback.OnBar:
		feedback = null   # on the blue bar, not in the column
	if feedback != null:
		bottom -= FeedbackPanel.FoldedHeight + KeyButtonGap
	btn.offset_left = 4.0
	btn.offset_right = 147.0
	btn.offset_bottom = bottom
	btn.offset_top = bottom - KeyButtonHeight
	# Under the Feedback box, which grows up over it while open.
	if feedback != null:
		move_child(btn, feedback.get_index())


func RemoveFromTaskbar(btn: Button) -> void:
	if btn != null and is_instance_valid(btn):
		# Out of the tree at once, so a button added in the same frame (the
		# original's key taking over from the plain one) gets its name.
		if btn.get_parent() != null:
			btn.get_parent().remove_child(btn)
		btn.queue_free()


func _AddWindowToTaskbar(window: DraggableWindow) -> void:
	# Don't add a button if one already exists.
	if _taskbarButtons.has(window):
		return
	# A pinned theatre already has its permanent button; nothing to add.
	if _pinnedSectors.has(window.WindowTitle):
		return
	var taskbarBtn := Button.new()
	taskbarBtn.text = window.WindowTitle
	# When clicked, restore the window.
	taskbarBtn.pressed.connect(func() -> void: RestoreWindow(window))
	# On the Window Reference Bar, "the name of the system sits next to an icon
	# showing what kind of window it is" (manual p022): the kind's corner icon
	# from the sector window, where there is one.
	if _referenceList != null:
		var kind: Texture2D = _WindowKindIcon(window)
		if kind != null:
			taskbarBtn.icon = kind
			taskbarBtn.expand_icon = false
			# The icon says the kind; the slat says the system.
			var system: Variant = window.get("_associatedPlanet") if window.get("_associatedPlanet") != null else window.get("_planet")
			if system is Planet:
				taskbarBtn.text = (system as Planet).Name
	_MinimisedList().add_child(taskbarBtn)
	_taskbarButtons[window] = taskbarBtn


func RestoreWindow(window: DraggableWindow) -> void:
	if is_instance_valid(window):
		window.Refresh()
		window.visible = true
		window.move_to_front()
		_focusedWindow = window
	# Destroy the taskbar button.
	if _taskbarButtons.has(window):
		var btn: Button = _taskbarButtons[window]
		btn.queue_free()
		_taskbarButtons.erase(window)


## Checks if the window exists (visible or minimized) and pops it to the front.
## C#: `existingWindow is T` - the port checks the instance came from the same
## scene, which is what the generic type constraint amounted to.
func CheckAndRestoreExistingWindow(windowName: String, setupAction: Callable, template: PackedScene = null) -> bool:
	if _openWindows.has(windowName):
		var existingWindow: DraggableWindow = _openWindows[windowName]
		if is_instance_valid(existingWindow) and (template == null or existingWindow.scene_file_path == template.resource_path):
			RestoreWindow(existingWindow)
			if setupAction.is_valid():
				setupAction.call(existingWindow)
			return true
	return false


func CleanupClosedWindow(windowName: String, window: DraggableWindow) -> void:
	_openWindows.erase(windowName)
	# If the user closed the window while it somehow had a taskbar button, clean it up.
	if _taskbarButtons.has(window):
		var btn: Button = _taskbarButtons[window]
		if is_instance_valid(btn):
			btn.queue_free()
		_taskbarButtons.erase(window)


func GetSafeWindowPosition(window: DraggableWindow, targetPosition: Vector2) -> Vector2:
	var viewportSize: Vector2 = get_viewport().get_visible_rect().size
	var windowSize := Vector2(
		maxf(window.size.x, window.get_minimum_size().x),
		maxf(window.size.y, window.get_minimum_size().y))

	# --- HUD MARGINS --- TimeControls are 200px wide, CommsList ~143px; 210
	# guarantees a window never touches either. TaskbarPanel is 150; 160 pads it.
	var leftMargin := 210.0
	var rightMargin := 160.0
	var topMargin := 10.0
	var bottomMargin := 10.0

	var minX := leftMargin
	var maxX := maxf(minX, viewportSize.x - rightMargin - windowSize.x)
	var minY := topMargin
	var maxY := maxf(minY, viewportSize.y - bottomMargin - windowSize.y)

	return Vector2(clampf(targetPosition.x, minX, maxX), clampf(targetPosition.y, minY, maxY))


## C#: OpenWindow<T>(windowName, template, setupAction, targetPosition) where T : DraggableWindow.
func OpenWindow(windowName: String, template: PackedScene, setupAction: Callable, targetPosition: Vector2) -> void:
	if template == null:
		push_error("CRITICAL ERROR: Tried to open %s, but the PackedScene template is null! Did you assign it in the Godot Inspector?" % windowName)
		return
	if CheckAndRestoreExistingWindow(windowName, setupAction, template):
		return

	# Instantiate and Add
	var window: DraggableWindow = template.instantiate()
	add_child(window)

	# Track in Dictionaries
	_openWindows[windowName] = window
	window.WindowTitle = windowName

	# Hook up lifecycle events
	window.OnMinimized.connect(_AddWindowToTaskbar)
	window.tree_exited.connect(func() -> void: CleanupClosedWindow(windowName, window))

	# Execute the unique setup logic (Populate, UI tweaks) passed by the caller
	if setupAction.is_valid():
		setupAction.call(window)

	# Apply bounds checking
	window.position = GetSafeWindowPosition(window, targetPosition)


func RefreshWindowIfOpen(windowName: String, refreshAction: Callable) -> void:
	if _openWindows.has(windowName):
		var existingWindow: DraggableWindow = _openWindows[windowName]
		if is_instance_valid(existingWindow) and refreshAction.is_valid():
			refreshAction.call(existingWindow)


func RefreshNow() -> void:
	RefreshActiveWindows(0)


func PollOpenWindows() -> void:
	for windowName in _openWindows.keys():
		var window: DraggableWindow = _openWindows[windowName]
		if is_instance_valid(window) and window.visible:
			window.RefreshIfChanged()


func RefreshActiveWindows(_currentDay: int) -> void:
	# "Whenever your fleet meets another fleet in orbit about a system, the two
	# fleets engage in battle" (manual p124). If one was raised today it is
	# waiting for an answer, so put the alert in front of the player.
	ShowPendingBattle()

	# ...and any that finished get their Battle Results window, which the manual
	# says appears after EVERY battle including simulated ones - and an
	# assault its Assault Summary, for the side that ordered it (manual p123).
	while not FleetBattleManager.Unreported().is_empty() and get_node_or_null("BattleResultsWindow") == null:
		var done: RefCounted = FleetBattleManager.Unreported()[0]
		FleetBattleManager.MarkReported(done)
		if done is AssaultManager.AssaultReport and (done as AssaultManager.AssaultReport).Attacker != GameSettings.LocalFaction():
			continue   # the other side's: it reaches this one as a message
		ShowReport(done)
		break

	for windowName in _openWindows.keys():
		var window: DraggableWindow = _openWindows[windowName]
		# Only refresh if the window is valid AND currently visible (not minimized!)
		if is_instance_valid(window) and window.visible:
			window.Refresh()


func OpenPersonnelFinder() -> void:
	OpenWindow("PersonnelFinder", PersonnelFinderTemplate,
		func(window) -> void: window.Setup(self), Vector2(100, 100))


func OpenPlanetFinder() -> void:
	OpenWindow("PlanetFinder", PlanetFinderTemplate,
		func(window) -> void: window.Setup(self), Vector2(100, 150))


## The Fleet Finder (manual p125 Fig. 3.70), or the Ship Finder the same
## dialog switches to (p126 Fig. 3.72).
func OpenFleetFinder(ships: bool = false) -> void:
	OpenWindow("FleetFinder", load("res://src/ui/FleetFinder.tscn"),
		func(window) -> void: window.Setup(self, ships), Vector2(100, 150))


## The Troop Finder (manual p132 Fig. 3.80).
func OpenTroopFinder() -> void:
	OpenWindow("TroopFinder", load("res://src/ui/TroopFinder.tscn"),
		func(window) -> void: window.Setup(self), Vector2(100, 150))


## F1 Game Options - the six-slot save screen (single-player). Head-to-head uses
## its own relay Save, so this is offered only when there is no MP session. Guards
## against opening a second copy.
func OpenGameOptions() -> void:
	if OptionsScreenScript.CanBuild():
		OpenOptionsScreen()
		return
	if MpSetup.session != null:
		return
	if get_node_or_null("GameOptionsWindow") != null:
		return
	add_child(GameOptionsWindow.new())


func _StyleMenu(n: Node) -> void:
	if not (n is PopupMenu) or not OriginalMenu.Enabled():
		return
	var owner_: Node = n.get_parent()
	if owner_ is LineEdit or owner_ is TextEdit or owner_ is OptionButton or owner_ is SpinBox:
		return
	OriginalMenu.Style(n as PopupMenu)


## Alt+W - close every open window at once. Windows opened through OpenWindow are
## tracked in _openWindows; freeing one triggers its own cleanup. A few screens
## (Galaxy Overview, Objectives, Game Options, Load Game) are added as direct
## children rather than through OpenWindow, so close those by name too.
func CloseAllWindows() -> void:
	for w: Variant in _openWindows.values().duplicate():
		if is_instance_valid(w):
			(w as Node).queue_free()
	for wname in ["GalaxyOverviewWindow", "ObjectivesWindow", "GameOptionsWindow", "LoadGameWindow", "OptionsScreen"]:
		var extra: Node = get_node_or_null(wname)
		if extra != null:
			extra.queue_free()


## Alt+1..9 - switch the galaxy map to a Galaxy Display mode. SetMode sets the
## mode AND repaints the map (and mirroring sector windows).
func _set_galaxy_mode(index: int) -> void:
	var modes: Array = Gid.GalaxyDisplayModes()
	if ActiveGalaxyMap != null and index >= 0 and index < modes.size() and modes[index] != null:
		ActiveGalaxyMap.SetMode(modes[index])


func _process(_delta: float) -> void:
	# While targeting is active, override any Control that resets the cursor.
	if IsTargeting:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS)


## Picking a THING as well as a place. onObjectSelected fires when the player
## clicks a person, facility, ship, squadron or regiment in a window;
## onTargetSelected still fires for the system itself (p040's "blank space").
## C#: StartTargeting(Action<Planet>, Action<object>) overload.
func StartTargetingObject(onTargetSelected: Callable, onObjectSelected: Callable) -> void:
	StartTargeting(onTargetSelected)
	_objectTargetingCallback = onObjectSelected


## Called when any targetable row is clicked while the crosshair is up.
func ResolveObjectTarget(picked: Variant) -> void:
	if not IsTargeting or not _objectTargetingCallback.is_valid() or picked == null:
		return
	var callback: Callable = _objectTargetingCallback
	CancelTargeting()
	callback.call(picked)


func StartTargeting(onTargetSelected: Callable) -> void:
	IsTargeting = true
	_targetingCallback = onTargetSelected
	_objectTargetingCallback = Callable()

	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS)
	get_viewport().warp_mouse(get_viewport().get_mouse_position())


func CancelTargeting() -> void:
	IsTargeting = false
	_targetingCallback = Callable()
	_objectTargetingCallback = Callable()
	# Return to standard arrow cursor
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func ResolveTarget(targetPlanet: Planet) -> void:
	if IsTargeting and _targetingCallback.is_valid():
		var callback: Callable = _targetingCallback   # Copy reference
		CancelTargeting()                             # Immediately exit targeting mode
		callback.call(targetPlanet)                   # Execute the move logic!


## THE AGENT DROID'S MENU - manual p031, and p088/p128 for the two automations.
## "Right-clicking your agent droid (C-3PO for the Alliance, IMP-22 for the
## Empire) gives: Build Ships, Build Troops, Build Facilities, Galaxy Overview,
## Objectives, Manage Garrisons, Manage Production, Translate Counterpart, Agent
## Advice." All nine appear, in the manual's order and with no separators (Fig
## 3.17); five are disabled and say why. Under the Command Center frame the
## droid itself opens it, at the click (OpenAgentMenuAt); otherwise the bottom
## row's button does. Styled as the original's menus are (original_menu.gd).
func _AgentPopup() -> PopupMenu:
	var us: Faction = GameSettings.PlayerFaction
	var popup: PopupMenu = get_node_or_null("AgentPopup")
	if popup == null:
		popup = PopupMenu.new()
		popup.name = "AgentPopup"
		add_child(popup)
		popup.id_pressed.connect(OnAgentMenu)

	popup.clear()
	popup.add_item("Build Ships", 0)
	popup.add_item("Build Troops", 1)
	popup.add_item("Build Facilities", 2)
	popup.add_item("Galaxy Overview", 3)
	popup.add_item("Objectives", 4)
	popup.add_check_item("Manage Garrisons", 5)
	popup.add_check_item("Manage Production", 6)
	popup.add_item("Translate Counterpart", 7)
	popup.add_item("Agent Advice", 8)

	popup.set_item_checked(popup.get_item_index(5), AgentDroid.ManagingGarrisons(us))
	popup.set_item_checked(popup.get_item_index(6), AgentDroid.ManagingProduction(us))

	for id in [0, 1, 2, 7, 8]:
		popup.set_item_disabled(popup.get_item_index(id), true)

	popup.set_item_tooltip(popup.get_item_index(0), "Order ships from a shipyard's own menu.")
	popup.set_item_tooltip(popup.get_item_index(1), "Order troops from a training facility's own menu.")
	popup.set_item_tooltip(popup.get_item_index(2), "Order facilities from a construction yard's own menu.")
	popup.set_item_tooltip(popup.get_item_index(7), "Not built - the message droid's announcements are not voiced.")
	popup.set_item_tooltip(popup.get_item_index(8), "Not built.")
	return popup


func OpenAgentMenu(anchor: Button) -> void:
	if GameSettings.PlayerFaction == null:
		return
	var popup: PopupMenu = _AgentPopup()
	var at: Vector2 = anchor.get_screen_position() + Vector2(0, -popup.size.y)
	popup.position = Vector2i(at)
	popup.popup()


## The agent's menu at a right-click on the droid (the Command Center frame's).
func OpenAgentMenuAt(at: Vector2) -> void:
	if GameSettings.PlayerFaction == null:
		return
	_PopupAt(_AgentPopup(), at)


## THE MESSAGE DROID'S MENU (manual p078): "right-click on the message droid
## and select Messages" - the Display Message Index, as F6 opens it. Its other
## item, "Message Alerts" (TEXTSTRA 12573, beside "Messages" 12572), the manual
## never describes: grey until it is known.
func OpenMessengerMenuAt(at: Vector2) -> void:
	var popup: PopupMenu = get_node_or_null("MessengerPopup")
	if popup == null:
		popup = PopupMenu.new()
		popup.name = "MessengerPopup"
		add_child(popup)
		popup.add_item("Messages", 0)
		popup.add_item("Message Alerts", 1)
		popup.set_item_disabled(1, true)
		popup.set_item_tooltip(1, "Not built - the manual does not say what it does.")
		popup.id_pressed.connect(func(id: int) -> void:
			if id == 0:
				OnMessageIndexClicked("All"))
	_PopupAt(popup, at)


## A menu opened at a click, down and right of it, flipped to stay on the
## frame (the original's 640x480) as a Windows menu flips - the Alliance's
## agent menu opened up and left of C-3PO, the Empire's up and right of IMP-22
## (captures of the original, open-rebellion 0896 / 0620).
func _PopupAt(popup: PopupMenu, at: Vector2) -> void:
	popup.reset_size()
	var box := Vector2(popup.size)
	var screen: Rect2 = CommandFrameRef.ScreenRect() if CommandFrameRef != null else get_viewport().get_visible_rect()
	var p := at
	if p.x + box.x > screen.end.x:
		p.x = at.x - box.x
	if p.y + box.y > screen.end.y:
		p.y = at.y - box.y
	p.x = clampf(p.x, screen.position.x, maxf(screen.position.x, screen.end.x - box.x))
	p.y = clampf(p.y, screen.position.y, maxf(screen.position.y, screen.end.y - box.y))
	popup.position = Vector2i(p.floor())
	popup.popup()


## THE GID CONTROL'S MENU (manual p024 Fig 2.7), from the Control Panel's
## GID monitor, where the original opens it: its bottom-right corner on the
## original's (CommandFrame.Layout "gid_menu"). A mode chosen goes on the map.
const GidControlMenuScript := preload("res://src/ui/gid_control_menu.gd")


func OpenGidControlMenu() -> void:
	if CommandFrameRef == null or ActiveGalaxyMap == null:
		return
	var old: Node = get_node_or_null("GidControlMenu")
	if old != null:
		old.call("Close")
	var r: Rect2 = CommandFrame.Layout[CommandFrameRef.Side]["gid_menu"]
	var menu: Control = GidControlMenuScript.new()
	add_child(menu)
	menu.call("Open", CommandFrameRef.Origin + r.end * CommandFrameRef.S, CommandFrameRef.Side, Gid.Categories)
	var map: GalaxyMap = ActiveGalaxyMap
	menu.connect("chosen", func(mode: Object) -> void:
		if is_instance_valid(map):
			map.SetMode(mode))


## The droids stand in the Command Center frame (the bottom row's agent
## button then goes: the droid is the way to its menu).
func HasDroids() -> bool:
	return CommandFrameRef != null and not CommandFrameRef.Droids().is_empty()


func OnAgentMenu(id: int) -> void:
	var us: Faction = GameSettings.PlayerFaction
	if us == null:
		return
	match id:
		3: OpenGalaxyOverview()
		4: OpenObjectives()
		5: CommandBus.issue("droid", { "manage": "garrisons", "on": not AgentDroid.ManagingGarrisons(us) })
		6: CommandBus.issue("droid", { "manage": "production", "on": not AgentDroid.ManagingProduction(us) })


## THE BATTLE ALERT (manual p124, Fig 4.1). Raised from the repaint poll rather
## than pushed by the backend; the battle sits in FleetBattleManager.AwaitingOrders
## until answered - the original's state 6, WAIT_FOR_TYPE_CHOICE.
func ShowPendingBattle() -> void:
	if not FleetBattleManager.HasPendingBattle():
		return
	if get_node_or_null("BattleAlertWindow") != null:
		return
	var win := BattleAlertWindow.new()
	win.name = "BattleAlertWindow"
	add_child(win)
	win.Setup(FleetBattleManager.AwaitingOrders()[0])
	win.move_to_front()


## "NOTE: This window comes up at the end of EVERY battle, EVEN IF YOU
## INSTRUCTED THE GAME TO SIMULATE THE BATTLE" (manual p152).
func ShowBattleResults(report: FleetBattleManager.BattleReport) -> void:
	if report == null:
		return
	var win := _NewResultsWindow()
	win.Setup(report)
	win.move_to_front()


## The Assault Summary window (manual p123, Figs 3.66-3.67): the Battle
## Results window's own frame and column (TeeJ, 2026-09-26: "it's what already
## appears [after a] lost battle").
func ShowAssaultSummary(report: AssaultManager.AssaultReport) -> void:
	if report == null:
		return
	var win := _NewResultsWindow()
	win.SetupAssault(report)
	win.move_to_front()


## A battle's or an assault's window, from a Conflict message or at once.
func ShowReport(report: RefCounted) -> void:
	if report is AssaultManager.AssaultReport:
		ShowAssaultSummary(report)
	elif report is FleetBattleManager.BattleReport:
		ShowBattleResults(report)


## One results window at a time: another's replaces it.
func _NewResultsWindow() -> BattleResultsWindow:
	var old: Node = get_node_or_null("BattleResultsWindow")
	if old != null:
		remove_child(old)
		old.queue_free()
	var win := BattleResultsWindow.new()
	win.name = "BattleResultsWindow"
	add_child(win)
	return win


## "ALT-O Galaxy Overview" and the agent's own command (manual p030-p031, Fig. 2.17).
func OpenGalaxyOverview() -> void:
	var existing: GalaxyOverviewWindow = get_node_or_null("GalaxyOverviewWindow")
	if existing != null:
		existing.Refresh()
		existing.move_to_front()
		_focusedWindow = existing
		return
	var win := GalaxyOverviewWindow.new()
	win.name = "GalaxyOverviewWindow"
	add_child(win)
	win.Setup()


## THE OBJECTIVES WINDOW. "ALT-H Game Objectives" (manual p136-p137).
func OpenObjectives() -> void:
	var existing: ObjectivesWindow = get_node_or_null("ObjectivesWindow")
	if existing != null:
		existing.Refresh()
		existing.move_to_front()
		_focusedWindow = existing
		return
	var win := ObjectivesWindow.new()
	win.name = "ObjectivesWindow"
	add_child(win)
	win.Setup()


## Catch global right-clicks or Escape to cancel targeting.
func _unhandled_input(event: InputEvent) -> void:
	# The original's Command Center shortcuts (Steam guide + manual). Hardcoded key
	# checks in the style of the existing Alt+H/Alt+O binds; this node only exists
	# while a game is on screen, so no extra scene guard is needed. (Pause and
	# speed - Alt+P, Alt+/- - live in game_manager.gd's own handler.)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.alt_pressed:
			# ALT-1..9 select a Galaxy Display mode (Steam guide: loyalty,
			# insurrections, idle/moving fleets, idle/active characters, idle
			# shipyards/training/construction).
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				_set_galaxy_mode(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()
				return
			match event.keycode:
				KEY_H:                        # ALT-H Game Objectives
					OpenObjectives()
					get_viewport().set_input_as_handled()
					return
				KEY_O, KEY_0, KEY_KP_0:       # ALT-O / ALT-0 Galaxy Overview (synoptic chart)
					OpenGalaxyOverview()
					get_viewport().set_input_as_handled()
					return
				KEY_I:                        # ALT-I check the message index
					OnMessageIndexClicked("All")
					get_viewport().set_input_as_handled()
					return
				KEY_W:                        # ALT-W close all windows
					CloseAllWindows()
					get_viewport().set_input_as_handled()
					return
				KEY_G:                        # ALT-G toggle Manage Garrisons (agent)
					OnAgentMenu(5)
					get_viewport().set_input_as_handled()
					return
				KEY_U:                        # ALT-U toggle Manage Production (agent)
					OnAgentMenu(6)
					get_viewport().set_input_as_handled()
					return
		else:
			match event.keycode:
				KEY_F1:                       # F1 Game Options
					OpenGameOptions()
					get_viewport().set_input_as_handled()
					return
				KEY_F2:                       # F2 System (Planetary) Finder
					OpenPlanetFinder()
					get_viewport().set_input_as_handled()
					return
				KEY_F5:                       # F5 Character (Personnel) Finder
					OpenPersonnelFinder()
					get_viewport().set_input_as_handled()
					return
				KEY_F6:                       # F6 Message index (defaults to All - manual p079)
					OnMessageIndexClicked("All")
					get_viewport().set_input_as_handled()
					return
				KEY_F7:                       # F7 Encyclopedia (manual p081)
					OpenEncyclopedia()
					get_viewport().set_input_as_handled()
					return

	if IsTargeting:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			CancelTargeting()
			print("Move command cancelled.")
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			CancelTargeting()
			print("Move command cancelled.")
			get_viewport().set_input_as_handled()   # that Esc closes no window


# --- Esc closes the window in focus ---------------------------------------------
## "Cancel/Close Window - cancels the current command (same as clicking Close
## or Cancel)" (manual p064), and in the original Esc closes the window in
## focus (TeeJ, 2026-09-24): the one last clicked, opened or brought back.
## With that one gone, the front-most open window is next. Not the Battle
## Alert: it waits for an answer, and would only come straight back.
var _focusedWindow: Node = null


func _IsEscWindow(n: Node) -> bool:
	return n is DraggableWindow or n is GalaxyOverviewWindow or n is ObjectivesWindow \
		or n is GameOptionsWindow or n is LoadGameWindow or n is BattleResultsWindow


## A click anywhere in a window focuses it - seen here, not taken.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var w: Node = _WindowAt(get_final_transform().affine_inverse() * (event as InputEventMouseButton).position)
		if w != null:
			_focusedWindow = w


## The front-most open window under a point.
func _WindowAt(at: Vector2) -> Node:
	for i in range(get_child_count() - 1, -1, -1):
		var c: Node = get_child(i)
		if _IsEscWindow(c) and (c as Control).visible and (c as Control).get_global_rect().has_point(at):
			return c
	return null


## The window Esc would close now, or null.
func FocusedWindow() -> Node:
	if is_instance_valid(_focusedWindow) and _focusedWindow.get_parent() == self \
			and (_focusedWindow as Control).visible and not _focusedWindow.is_queued_for_deletion():
		return _focusedWindow
	for i in range(get_child_count() - 1, -1, -1):
		var c: Node = get_child(i)
		if _IsEscWindow(c) and (c as Control).visible and not c.is_queued_for_deletion():
			return c
	return null


## After everything in front has had its say: the Options screen, a Status
## window and the tactical view each take their own Esc first. While
## targeting, Esc is the targeting's to cancel (_unhandled_input, which Godot
## calls after this).
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if IsTargeting:
		return
	var w: Node = FocusedWindow()
	if w == null:
		return
	get_viewport().set_input_as_handled()
	if w is DraggableWindow and (w as DraggableWindow).StepBack():
		return
	_focusedWindow = null
	if w is DraggableWindow:
		(w as DraggableWindow).CloseWindow()
	elif w is GameOptionsWindow:
		(w as GameOptionsWindow).Closed.emit()   # as its Close button does
		w.queue_free()
	elif w is LoadGameWindow:
		(w as LoadGameWindow).Cancelled.emit()   # as its Cancel button does
		w.queue_free()
	else:
		w.queue_free()


func OpenTransitConfirm(characters: Array, daysRemaining: int, onConfirmCallback: Callable) -> void:
	# Spawns near the mouse cursor
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	var nameDisplay: String = characters[0].Name if characters.size() == 1 else "%d Personnel" % characters.size()
	OpenWindow("Confirm_%s" % nameDisplay, TransitConfirmWindowTemplate,
		func(window) -> void: window.Setup(characters, daysRemaining, onConfirmCallback),
		targetPos)


func StartCharacterDrag(characters: Array) -> void:
	DraggedCharacters = characters


func EndCharacterDrag() -> void:
	DraggedCharacters = []


## The move itself is OrderManager's; what remains here is the only part that
## was ever presentation: repainting the two windows the move affects.
func RefreshAfterMove(currentLocation: Location, destination: Location) -> void:
	var depPlanet: Planet = currentLocation as Planet
	var destPlanet: Planet = destination as Planet
	RefreshWindowIfOpen(currentLocation.Name + " Defenses", func(w) -> void: w.Populate(depPlanet, self))
	RefreshWindowIfOpen(destination.Name + " Defenses", func(w) -> void: w.Populate(destPlanet, self))
	RefreshWindowIfOpen(currentLocation.Name + " System Fleets", func(w) -> void: w.Populate(depPlanet, self))
	RefreshWindowIfOpen(destination.Name + " System Fleets", func(w) -> void: w.Populate(destPlanet, self))


func ExecuteCharacterMove(characters: Array, destination: Planet, requireConfirmation: bool) -> void:
	# A fleet is at the world it orbits - see OrderManager.SystemOf.
	var first: Character = Lq.first_or_null(characters, func(c: Character) -> bool: return c.Status != Enums.Status.Enroute)
	var currentPlanet: Planet = OrderManager.SystemOf(first.Attached if first != null else null)
	if currentPlanet == null:
		return

	# Confirmed Move "shows the transit time in days BEFORE you commit" (manual p110).
	var days: int = OrderManager.CharacterTravelDays(characters, currentPlanet, destination)

	var issue := func() -> void:
		var r: Result = CommandBus.issue("move_characters", { "characters": EntityIndex.names_of(characters), "destination": destination.Name })
		if r.ok:
			RefreshAfterMove(currentPlanet, destination)
		elif not r.error.is_empty():
			ShowRefusal(r.error)

	if requireConfirmation:
		OpenTransitConfirm(characters, days, issue)
	else:
		issue.call()


func ExecuteUnitMove(units: Array, destination: Planet, _requireConfirmation: bool) -> void:
	# The system, not the base: a unit aboard a fleet is Attached to the FLEET.
	var first: Unit = Lq.first_or_null(units, func(u: Unit) -> bool: return u.Status != Enums.Status.Enroute)
	var currentPlanet: Planet = OrderManager.SystemOf(first.Attached if first != null else null)
	if currentPlanet == null:
		return

	# RUNNING A BLOCKADE. "Troops attempting to move MAY BE KILLED" (manual p124),
	# and the original ASKS FIRST (TEXTSTRA.DLL 0xF168, REBEXE.EXE 0x49A6EA).
	# Troops landing from a fleet on the world it orbits are not leaving it.
	if destination != currentPlanet and OrderManager.MustRunBlockade(currentPlanet, units):
		var leaving: Planet = currentPlanet
		var odds: int = BlockadeManager.WithdrawPercent(leaving)
		ConfirmEvacuation(odds, func() -> void:
			var r: Result = CommandBus.issue("run_blockade", { "units": EntityIndex.ids_of_units(units), "from": leaving.Name, "destination": destination.Name })
			if r.ok:
				RefreshAfterMove(leaving, destination))
		return

	var r: Result = CommandBus.issue("move_units", { "units": EntityIndex.ids_of_units(units), "destination": destination.Name })
	if r.ok:
		RefreshAfterMove(currentPlanet, destination)
	elif not r.error.is_empty():
		ShowRefusal(r.error)


## The original's own dialog, word for word.
func ConfirmEvacuation(odds: int, onProceed: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Evacuation Losses"
	dialog.dialog_text = "Units evacuating from worlds under blockade risk being " \
		+ "destroyed by blockading vessels.  Are you sure you want to " \
		+ "proceed with the evacuation?\n\n(%d%% of each regiment " % odds \
		+ "getting clear.)"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		onProceed.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


## A REFUSED ORDER HAS TO SAY SO ON SCREEN.
## Units aboard a fleet: dropped on its row, or picked with the crosshair after
## Move - from the world below or from another fleet in the same orbit
## (OrderManager.LoadAboard; "Drag ships or troops between fleets", manual
## p120). A refusal says why, as a move's does.
func ExecuteLoadAboard(units: Array, fleet: Fleet) -> void:
	if fleet == null or units.is_empty():
		return
	var r: Result = CommandBus.issue("load_aboard", { "units": EntityIndex.ids_of_units(units), "fleet": fleet.ID })
	var orbit: Planet = OrderManager.SystemOf(fleet)
	if int(r.value) > 0 and orbit != null:
		RefreshAfterMove(orbit, orbit)
	if not r.error.is_empty():
		ShowRefusal(r.error)


func ShowRefusal(reason: String) -> void:
	print("[Move] %s" % reason)
	var dialog := AcceptDialog.new()
	dialog.title = "Order Refused"
	dialog.dialog_text = reason
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func ExecuteFleetMove(fleets: Array, destination: Planet, _requireConfirmation: bool) -> void:
	var first: Fleet = Lq.first_or_null(fleets, func(f: Fleet) -> bool: return f.Status != Enums.Status.Enroute)
	var currentPlanet: Planet = first.Attached if first != null else null
	if currentPlanet == null:
		return
	# requireConfirmation is accepted and ignored, exactly as in the source:
	# Confirmed Move for fleets is not built yet.
	var r: Result = CommandBus.issue("move_fleets", { "fleets": EntityIndex.ids_of_fleets(fleets), "destination": destination.Name })
	if r.ok:
		RefreshAfterMove(currentPlanet, destination)
	elif not r.error.is_empty():
		print("[Move] %s" % r.error)


## C#: ExecuteFleetMove(Fleet, Planet, bool) overload.
func ExecuteSingleFleetMove(fleet: Fleet, selectedPlanet: Planet, requireConfirmation: bool) -> void:
	ExecuteFleetMove([fleet], selectedPlanet, requireConfirmation)


func StartUnitDrag(units: Array) -> void:
	DraggedUnits = units


func EndUnitDrag() -> void:
	DraggedUnits = []


func OpenUnitStatusWindow(unit: Unit) -> void:
	var windowName := "Status_%s_%d" % [unit.Name.replace(" ", ""), unit.get_instance_id()]   # several X-Wings can open at once
	if OUI.HasStatus():
		OpenStatusPlate(windowName, func() -> Dictionary: return UnitStatusWindow.StatusData(unit))
		return
	var targetPos := Vector2(350, 250)
	OpenWindow(windowName,
		UnitStatusWindowTemplate,
		func(window) -> void: window.Populate(unit),
		targetPos)


func OpenDefenseFacilityStatusWindow(facility: Facility) -> void:
	var windowName := "Status_%s_%d" % [facility.Name().replace(" ", ""), facility.get_instance_id()]
	if OUI.HasStatus():
		OpenStatusPlate(windowName, func() -> Dictionary: return DefenseFacilityStatusWindow.StatusData(facility))
		return
	var targetPos: Vector2 = get_viewport().get_mouse_position()
	OpenWindow(windowName,
		DefenseFacilityStatusWindowTemplate,
		func(window) -> void: window.Populate(facility),
		targetPos)


## A manufacturing queue's Status window (manual p086, Fig 3.29): the queue's
## right-click menu -> Status. The original's look with the imported art, the
## same fields in a plain window without it.
func OpenQueueStatusWindow(planet: Planet, producer: String) -> void:
	OpenStatusPlate("Status_%s_%s" % [planet.Name.replace(" ", ""), producer],
		func() -> Dictionary: return EconomyWindow.QueueStatusData(planet, producer))


## A STATUS WINDOW (StatusPlateWindow): modal, as the manual has them (p064),
## centred over the map frame like the Encyclopedia. `source` returns its
## content and is asked again on every refresh.
## Preloaded by path: a new script can lag the editor's class cache.
const OUI := preload("res://src/ui/original_ui.gd")
const StatusPlateScene := preload("res://src/ui/StatusPlateWindow.tscn")


func OpenStatusPlate(windowName: String, source: Callable) -> void:
	var size: Vector2 = Vector2(OUI.StatusW, OUI.StatusH) * OUI.K if OUI.HasStatus() else Vector2(460, 260)
	var at: Vector2 = (MapFrame.get_center() - size / 2.0).floor().max(MapFrame.position)
	OpenWindow(windowName, StatusPlateScene,
		func(window) -> void: window.Setup(self, GameSettings.PlayerFaction, source),
		at)


func StartFleetDrag(dragGroup: Array) -> void:
	DraggedFleets = dragGroup


func EndFleetDrag() -> void:
	DraggedFleets = []


func OpenFleetStatusWindow(fleet: Fleet) -> void:
	if fleet == null:
		return
	# The original's Status window with the imported art (FleetStatusWindow.StatusData).
	if OUI.HasStatus() and OUI.Has(["status_fleet.alliance", "status_fleet.empire"]):
		OpenStatusPlate("FleetStatus_%s_%d" % [fleet.Name.replace(" ", ""), fleet.get_instance_id()],
			func() -> Dictionary: return FleetStatusWindow.StatusData(fleet))
		return
	# The export is honoured if wired in the inspector; falling back to the
	# resource path is what makes Status work without one.
	var template: PackedScene = FleetStatusWindowTemplate
	if template == null:
		template = load("res://src/ui/FleetStatusWindow.tscn")
	if template == null:
		push_error("[UI] FleetStatusWindow.tscn could not be loaded.")
		return
	OpenWindow("FleetStatus_%s_%d" % [fleet.Name.replace(" ", ""), fleet.get_instance_id()],
		template,
		func(window) -> void: window.Populate(fleet),
		Vector2(380, 280))
