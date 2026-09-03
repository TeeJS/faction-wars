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
		menuButton.pressed.connect(OnMenuButtonClicked)
		# The build version, right of the Menu button (TeeJ, room #106).
		var ver := BuildInfo.label()
		menuButton.get_parent().add_child(ver)
		menuButton.get_parent().move_child(ver, menuButton.get_index() + 1)
	# Loop through the CommsList to wire the HUD buttons dynamically.
	var commsList: VBoxContainer = get_node_or_null("CommsPanel/Margin/CommsList")
	if commsList != null:
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
func RefreshCommsHighlights() -> void:
	var commsList: VBoxContainer = get_node_or_null("CommsPanel/Margin/CommsList")
	if commsList == null:
		return
	for btn in commsList.get_children():
		if not (btn is Button):
			continue
		var waiting: bool = Enums.MessageCategory.has(btn.name) \
			and EventBus.UnreadCount(Enums.MessageCategory[btn.name]) > 0
		if waiting:
			btn.add_theme_color_override("font_color", Color.YELLOW)
			btn.modulate = Color(1.5, 1.5, 0.5)
		else:
			btn.remove_theme_color_override("font_color")
			btn.modulate = Color.WHITE


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


func OnMessageIndexClicked(category: String = "All") -> void:
	OpenWindow("Communications", MessageWindowTemplate,
		func(window) -> void: window.OpenToCategory(category),
		Vector2(50, 50))


func OnSectorClicked(sector: Sector) -> void:
	var targetPos := Vector2(100 + randf() * 50, 100 + randf() * 50)
	OpenWindow(sector.Name, SectorWindowTemplate,
		func(window) -> void:
			window.get_node("%Title").text = sector.Name
			window.Populate(sector, self),
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
func AddToTaskbar(title: String, onRestore: Callable) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.pressed.connect(func() -> void:
		if onRestore.is_valid():
			onRestore.call())
	_taskbarList.add_child(btn)
	return btn


func RemoveFromTaskbar(btn: Button) -> void:
	if btn != null and is_instance_valid(btn):
		btn.queue_free()


func _AddWindowToTaskbar(window: DraggableWindow) -> void:
	# Don't add a button if one already exists.
	if _taskbarButtons.has(window):
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
	if event is InputEventKey and event.pressed and not event.echo and event.alt_pressed:
		# The original's own accelerators: "ALT-H Game Objectives", "ALT-O Galaxy Overview".
		if event.keycode == KEY_H:
			OpenObjectives()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_O:
			OpenGalaxyOverview()
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
