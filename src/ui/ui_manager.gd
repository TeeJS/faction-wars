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


func _ready() -> void:
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
	var mapLayersBtn: MenuButton = get_node_or_null("%GalaxyMapLayers")
	if mapLayersBtn != null:
		var popup: PopupMenu = mapLayersBtn.get_popup()
		popup.id_pressed.connect(func(id: int) -> void: OnMapLayerSelected(popup, id))


func OnMapLayerSelected(popup: PopupMenu, selectedId: int) -> void:
	# Update checkmarks so only the selected item is checked.
	for i in popup.item_count:
		popup.set_item_checked(i, i == selectedId)
	# Command the active map to update its layer.
	if ActiveGalaxyMap != null:
		ActiveGalaxyMap.SetLayer(selectedId)


func _exit_tree() -> void:
	# Always unsubscribe from static events when the node is destroyed.
	EventBus.OnDayAdvanced.erase(RefreshActiveWindows)
	EventBus.OnStateChanged.erase(RefreshNow)
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
	img.resize(SocketSize.x, SocketSize.y, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(img)
	_sockets[key] = out
	return out


func RefreshCommsHighlights() -> void:
	var commsList: VBoxContainer = get_node_or_null("CommsPanel/Margin/CommsList")
	if commsList == null:
		return
	var side: String = GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else ""
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
	var panel: PanelContainer = get_node_or_null("CommsPanel")
	if panel != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.03, 0.05, 1)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.45, 0.47, 0.52, 1)
		sb.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", sb)


## The unread count on a socket's corner, yellow with a black edge; hidden at
## zero.
static func _Badge(btn: Button, count: int) -> void:
	var badge: Label = btn.get_node_or_null("Badge")
	if count <= 0:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = Label.new()
		badge.name = "Badge"
		badge.position = Vector2(SocketSize.x - 22, -2)
		badge.size = Vector2(22, 16)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", 13)
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
	OpenWindow("Communications", MessageWindowTemplate,
		func(window) -> void:
			window.Setup(self)   # without this the window's _uiManager is null and Go To is a no-op
			window.custom_minimum_size = CommsRect.size
			window.size = CommsRect.size
			window.position = CommsRect.position
			window._tabContainer.tabs_visible = false
			window.OpenToCategory(category)
			# Docked: after OpenWindow has placed it (it nudges new windows), so
			# the dock position is the one that stands.
			window.set_deferred("position", CommsRect.position)
			RefreshCommsHighlights(),
		CommsRect.position)


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
	var frame := Rect2(150, 99, 1070, get_viewport().get_visible_rect().size.y - 99)
	var size: Vector2 = window.get_combined_minimum_size()
	return (frame.get_center() - size / 2.0).floor().max(Vector2(150, 99))


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
	var targetPos := Vector2(100 + randf() * 50, 100 + randf() * 50)
	OpenWindow(sector.Name, SectorWindowTemplate,
		func(window) -> void:
			window.get_node("%Title").text = sector.Name
			window.Populate(sector, self)
			# Right-click on the title bar: "Pin to menu" / "Unpin from menu".
			# Setup runs again on every restore, so wire it once.
			if not window.has_meta("pin_menu_wired"):
				window.set_meta("pin_menu_wired", true)
				(window.get_node("%TitleBar") as Control).gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
						ShowPinMenu(sector)),
		targetPos)


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


func OnMissionClicked(planetData: Planet) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position() + Vector2(20, 20)
	OpenWindow(planetData.Name + " Missions", MissionWindowTemplate,
		func(window) -> void: window.Populate(planetData),
		targetPos)


func OnMenuButtonClicked() -> void:
	var viewportSize: Vector2 = get_viewport().get_visible_rect().size
	var centerPos: Vector2 = (viewportSize / 2.0) - Vector2(110, 80)
	OpenWindow("GameMenu", InGameMenuWindowTemplate, func(_window) -> void: pass, centerPos)


func OpenCharacterStatusWindow(character: Character) -> void:
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
	# At the top, in map order. The GID key docks itself later and takes index
	# 0 (AddToTaskbar), so the panel reads: key, the theatres, then whatever
	# windows are minimised.
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
## after the docked key and before any minimised window.
func PinSector(sector: Sector) -> void:
	if _pinnedSectors.has(sector.Name):
		return
	var base := 0
	if _taskbarList.get_child_count() > 0:
		var first: Node = _taskbarList.get_child(0)
		if not _pinnedSectors.values().has(first) and not _taskbarButtons.values().has(first):
			base = 1   # the docked GID key
	var before := 0
	for name in _pinOrder:
		if name == sector.Name:
			break
		if _pinnedSectors.has(name):
			before += 1
	var btn := _pin_button(sector)
	_taskbarList.move_child(btn, base + before)
	# If its window is minimised on a normal button, that button is now redundant.
	if _openWindows.has(sector.Name):
		var w: DraggableWindow = _openWindows[sector.Name]
		if _taskbarButtons.has(w):
			var old: Button = _taskbarButtons[w]
			if is_instance_valid(old):
				_taskbarList.remove_child(old)
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


func AddToTaskbar(title: String, onRestore: Callable) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.pressed.connect(func() -> void:
		if onRestore.is_valid():
			onRestore.call())
	_taskbarList.add_child(btn)
	# The docked GID key is the panel's first item, above the pinned theatres.
	_taskbarList.move_child(btn, 0)
	return btn


func RemoveFromTaskbar(btn: Button) -> void:
	if btn != null and is_instance_valid(btn):
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
	_taskbarList.add_child(taskbarBtn)
	_taskbarButtons[window] = taskbarBtn


func RestoreWindow(window: DraggableWindow) -> void:
	if is_instance_valid(window):
		window.Refresh()
		window.visible = true
		window.move_to_front()
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
	# says appears after EVERY battle including simulated ones.
	if not FleetBattleManager.Unreported().is_empty() and get_node_or_null("BattleResultsWindow") == null:
		var done: FleetBattleManager.BattleReport = FleetBattleManager.Unreported()[0]
		FleetBattleManager.MarkReported(done)
		ShowBattleResults(done)

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


## F1 Game Options - the six-slot save screen (single-player). Head-to-head uses
## its own relay Save, so this is offered only when there is no MP session. Guards
## against opening a second copy.
func OpenGameOptions() -> void:
	if MpSetup.session != null:
		return
	if get_node_or_null("GameOptionsWindow") != null:
		return
	add_child(GameOptionsWindow.new())


## Alt+W - close every open window at once. Windows opened through OpenWindow are
## tracked in _openWindows; freeing one triggers its own cleanup. A few screens
## (Galaxy Overview, Objectives, Game Options, Load Game) are added as direct
## children rather than through OpenWindow, so close those by name too.
func CloseAllWindows() -> void:
	for w: Variant in _openWindows.values().duplicate():
		if is_instance_valid(w):
			(w as Node).queue_free()
	for wname in ["GalaxyOverviewWindow", "ObjectivesWindow", "GameOptionsWindow", "LoadGameWindow"]:
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
## Advice." All nine appear, in the manual's order; four are disabled and say why.
func OpenAgentMenu(anchor: Button) -> void:
	var us: Faction = GameSettings.PlayerFaction
	if us == null:
		return

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
	popup.add_separator()
	popup.add_item("Galaxy Overview", 3)
	popup.add_item("Objectives", 4)
	popup.add_separator()
	popup.add_check_item("Manage Garrisons", 5)
	popup.add_check_item("Manage Production", 6)
	popup.add_separator()
	popup.add_item("Translate Counterpart", 7)
	popup.add_item("Agent Advice", 8)

	popup.set_item_checked(popup.get_item_index(5), AgentDroid.ManagingGarrisons(us))
	popup.set_item_checked(popup.get_item_index(6), AgentDroid.ManagingProduction(us))

	for id in [0, 1, 2, 7, 8]:
		popup.set_item_disabled(popup.get_item_index(id), true)

	popup.set_item_tooltip(popup.get_item_index(0), "Order ships from a shipyard's own menu.")
	popup.set_item_tooltip(popup.get_item_index(1), "Order troops from a training facility's own menu.")
	popup.set_item_tooltip(popup.get_item_index(2), "Order facilities from a construction yard's own menu.")
	popup.set_item_tooltip(popup.get_item_index(7), "Not built - there is no counterpart droid.")
	popup.set_item_tooltip(popup.get_item_index(8), "Not built.")

	var at: Vector2 = anchor.get_screen_position() + Vector2(0, -popup.size.y)
	popup.position = Vector2i(at)
	popup.popup()


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
	var win := BattleResultsWindow.new()
	win.name = "BattleResultsWindow"
	add_child(win)
	win.Setup(report)
	win.move_to_front()


## "ALT-O Galaxy Overview" and the agent's own command (manual p030-p031, Fig. 2.17).
func OpenGalaxyOverview() -> void:
	var existing: GalaxyOverviewWindow = get_node_or_null("GalaxyOverviewWindow")
	if existing != null:
		existing.Refresh()
		existing.move_to_front()
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
	if OrderManager.MustRunBlockade(currentPlanet, units):
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
	var r: Result = CommandBus.issue("move_fleets", { "fleets": EntityIndex.names_of(fleets), "destination": destination.Name })
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
	var targetPos := Vector2(350, 250)
	OpenWindow("Status_%s_%d" % [unit.Name.replace(" ", ""), unit.get_instance_id()],   # several X-Wings can open at once
		UnitStatusWindowTemplate,
		func(window) -> void: window.Populate(unit),
		targetPos)


func OpenDefenseFacilityStatusWindow(facility: Facility) -> void:
	var targetPos: Vector2 = get_viewport().get_mouse_position()
	OpenWindow("Status_%s_%d" % [facility.Name().replace(" ", ""), facility.get_instance_id()],
		DefenseFacilityStatusWindowTemplate,
		func(window) -> void: window.Populate(facility),
		targetPos)


func StartFleetDrag(dragGroup: Array) -> void:
	DraggedFleets = dragGroup


func EndFleetDrag() -> void:
	DraggedFleets = []


func OpenFleetStatusWindow(fleet: Fleet) -> void:
	if fleet == null:
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
