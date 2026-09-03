class_name GameManager
extends Node
## GameManager.cs - the Main scene's root: boots the game the menu configured,
## draws the map, runs the clock (Game Speed and Pause Menu, manual p022, p033
## Fig 2.22, p071 Fig 3.8) and paints the status bar (p030 Fig 2.15, p087 Fig 3.32).
##
## The source's headless flags (--soak, --snapshot, --dto-dump, --prng-dump,
## --replay-log) live in tests/*.gd in this repo; --seed= is honoured here so a
## played game can be replayed.

var _uiManager: UIManager
var _galaxyMap: GalaxyMap
var _strategicEngine: StrategicTickManager

# Time Control Nodes
var _tickTimer: Timer
var _dayLabel: Label

# ---- GAME SPEED AND PAUSE MENU ----------------------------------------
# TEXTSTRA.DLL carries the five settings as one contiguous run - "Pause | Very
# Slow | Slow | Medium | Fast" - the tooltip name "Game Speed Control", and
# "Resume" among the button labels. The gesture, from the agent's advice text:
# "Right-click on the time display at the upper-right of the Command Center and
# click on the desired setting."
#
# ★ ONE DELIBERATE DEPARTURE, BY RULING: the control stays upper-LEFT; the
# upper right is held by the Window Reference Bar. Ruled by the coordinator.
const SpeedNames: Array[String] = ["Pause", "Very Slow", "Slow", "Medium", "Fast"]

# ⚠ OURS. No source gives the original's real-time rates; these are the old
# slider's values, carried over unchanged.
const SpeedSeconds: Array[float] = [0.0, 150.0, 15.0, 3.0, 1.3]

const DefaultSpeed := 2   # Slow - the slider's old default

var _timeControls: PanelContainer
var _speedReadout: Label
var _speedMenu: PopupMenu
var _pauseBox: AcceptDialog
var _speed: int = DefaultSpeed

# Never 0, so resuming always lands on a running speed.
var _speedBeforePause: int = DefaultSpeed
var _availMines: Label
var _availRefineries: Label
var _availMaintenence: Label

var _lastDay: int = 0


func _ready() -> void:
	print("Booting up Rebellion Engine...")

	_uiManager = get_node("UIManager")
	_galaxyMap = get_node("GalaxyMap")
	_dayLabel = get_node("%DayLabel")
	_timeControls = get_node("UIManager/TimeControls")
	_speedReadout = get_node("%SpeedReadout")
	_availMines = get_node("%AvailMines")
	_availRefineries = get_node("%AvailRefineries")
	_availMaintenence = get_node("%AvailMaintenence")
	var charInfoBtn: Button = get_node("%CharInfo")
	var planetInfoBtn: Button = get_node("UIManager/HBoxContainer/PlanetInfo")

	# Safety net when Main.tscn is run directly, bypassing the menu.
	FactionRegistry.EnsureLoaded()
	if GameSettings.PlayerFaction == null:
		GameSettings.PlayerFaction = FactionRegistry.Playable[0]

	# DETERMINISM - one seeded PRNG for the whole session (Prng). --seed=N
	# replays a game exactly; otherwise the clock seeds it, and the seed is
	# printed so any game can be replayed.
	var seedArg: String = _ParseStringArg("--seed=")
	var seed: int = int(seedArg) if seedArg.is_valid_int() else int(Time.get_unix_time_from_system() * 1000000.0)

	# The catalogs, the resets, the galaxy, the roster and day zero, in the
	# source's order - GameSession.new_game is GameManager._Ready's load path.
	_strategicEngine = GameSession.new_game(GameSettings.PlayerFaction.Id,
		GameSettings.SelectedDifficulty, GameSettings.SelectedSize, seed)
	print("[Prng] seed=%d" % seed)
	var authenticGalaxy: Array[Sector] = GameState.ActiveGalaxy

	_galaxyMap.InitializeMap(authenticGalaxy, _uiManager)

	_tickTimer = Timer.new()
	add_child(_tickTimer)
	_tickTimer.timeout.connect(_strategicEngine.AdvanceDay)

	EventBus.OnDayAdvanced.append(UpdateDayDisplay)
	# Everything on the bar changes mid-day - see RefreshStatusBar.
	EventBus.OnStateChanged.append(RefreshStatusBar)

	BuildSpeedMenu()
	SetSpeed(DefaultSpeed)

	# Developer shortcuts, Ctrl+Shift+H for the list.
	var debugKeys := DebugKeys.new()
	add_child(debugKeys)
	debugKeys.Setup(_strategicEngine, authenticGalaxy)

	charInfoBtn.pressed.connect(_uiManager.OpenPersonnelFinder)
	planetInfoBtn.pressed.connect(_uiManager.OpenPlanetFinder)

	# THE AGENT DROID. "C-3PO for the Alliance, IMP-22 for the Empire" (manual
	# p031). The manual's gesture is a RIGHT-CLICK on the droid itself; there is
	# no droid sprite on the bar, so this is a button that opens the same menu.
	var chosenFaction: Faction = GameSettings.PlayerFaction
	var agentBtn := Button.new()
	agentBtn.text = AgentDroid.NameFor(chosenFaction)
	agentBtn.tooltip_text = "Agent droid: overview, objectives, and the two management automations."
	agentBtn.pressed.connect(func() -> void: _uiManager.OpenAgentMenu(agentBtn))
	charInfoBtn.get_parent().add_child(agentBtn)
	charInfoBtn.get_parent().move_child(agentBtn, charInfoBtn.get_index() + 1)

	RefreshStatusBar()


func _exit_tree() -> void:
	EventBus.OnDayAdvanced.erase(UpdateDayDisplay)
	EventBus.OnStateChanged.erase(RefreshStatusBar)


static func _ParseStringArg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""


func BuildSpeedMenu() -> void:
	# "The game has tool tips - hover any control for a description" (manual
	# p022); TEXTSTRA names this one "Game Speed Control".
	_timeControls.tooltip_text = "Game Speed Control"
	_timeControls.mouse_filter = Control.MOUSE_FILTER_STOP

	_speedMenu = PopupMenu.new()
	for i in SpeedNames.size():
		_speedMenu.add_radio_check_item(SpeedNames[i], i)
	add_child(_speedMenu)
	_speedMenu.id_pressed.connect(func(id: int) -> void: SetSpeed(id))

	# RIGHT-CLICK ON THE TIME DISPLAY.
	_timeControls.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_speedMenu.position = Vector2i(int(event.global_position.x), int(event.global_position.y))
			_speedMenu.popup()
			_timeControls.accept_event())

	# PAUSE IS MODAL. "An alert box comes up, LOCKING YOU OUT OF GAME CONTROLS
	# UNTIL YOU RESUME PLAY" (manual p071). ✅ CONFIRMED AGAINST THE ORIGINAL:
	# the lockout also blocks quitting. DO NOT "fix" it by restoring a close path.
	_pauseBox = AcceptDialog.new()
	_pauseBox.title = "Pause"
	_pauseBox.ok_button_text = "Resume"   # the shipped label (TEXTSTRA)
	_pauseBox.exclusive = true
	_pauseBox.unresizable = true
	# ⚠ OURS. TEXTSTRA carries no body text for this box.
	_pauseBox.dialog_text = "The game is paused."
	add_child(_pauseBox)
	_pauseBox.confirmed.connect(ResumeFromPause)
	_pauseBox.canceled.connect(ResumeFromPause)


## Guarded rather than flagged: SetSpeed hides the box, hiding it can emit
## Canceled, and Canceled lands back here.
func ResumeFromPause() -> void:
	if _speed != 0:
		return
	SetSpeed(_speedBeforePause)


func SetSpeed(level: int) -> void:
	level = clampi(level, 0, SpeedNames.size() - 1)
	if level != 0:
		_speedBeforePause = level
	_speed = level

	# Radio marks follow the convention the manual sets for the GID menu (p071).
	for i in SpeedNames.size():
		_speedMenu.set_item_checked(_speedMenu.get_item_index(i), i == level)

	# THE CURRENT SETTING, ON THE FACE OF THE CONTROL (user-reported behaviour
	# of the original).
	_speedReadout.text = SpeedNames[level]

	if level == 0:
		_tickTimer.stop()
		if not _pauseBox.visible:
			_pauseBox.popup_centered()
		return

	_tickTimer.wait_time = SpeedSeconds[level]
	_tickTimer.start()
	if _pauseBox.visible:
		_pauseBox.hide()


## THE MANUAL'S KEYBOARD TABLE: Alt+P Pause; Alt++/Alt+- speed up / down
## (Very Slow · Slow · Medium · Fast - FOUR settings, so the step keys never
## reach Pause, which has its own key).
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.alt_pressed or _speedMenu == null:
		return

	match event.keycode:
		KEY_P:
			if _speed == 0:
				ResumeFromPause()
			else:
				SetSpeed(0)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			SetSpeed(clampi(_speed + 1, 1, SpeedNames.size() - 1))
		KEY_MINUS, KEY_KP_SUBTRACT:
			SetSpeed(clampi(_speed - 1, 1, SpeedNames.size() - 1))
		_:
			return

	get_viewport().set_input_as_handled()


## The day number keeps its own trigger; everything volatile also repaints on
## OnStateChanged (refined material is deducted the moment something is queued).
func UpdateDayDisplay(currentDay: int) -> void:
	_lastDay = currentDay
	RefreshStatusBar()


func RefreshStatusBar() -> void:
	var currentDay: int = _lastDay
	# The manual's three monitors, in order (manual p030 fig 2.15, p087 fig 3.32):
	# raw material, refined material, maintenance capacity.
	var player: Faction = GameSettings.PlayerFaction
	var econ: Economy.FactionEconomy = Economy.For(player)

	# "Message Notification: shows which types of unread messages are waiting"
	# (manual p068). Named categories rather than a bare count.
	var waiting: PackedStringArray = PackedStringArray()
	for c in Enums.MessageCategory.values():
		if c != Enums.MessageCategory.All and EventBus.UnreadCount(c) > 0:
			waiting.append("%s %d" % [JsonUtil.enum_name(Enums.MessageCategory, c), EventBus.UnreadCount(c)])

	_dayLabel.text = ("Day: %d" % currentDay) if waiting.is_empty() \
		else "Day: %d    ✉ %s" % [currentDay, ", ".join(waiting)]
	_availMines.text = "Raw: %d  (%d mines)" % [econ.RawMaterials, Economy.TotalMines(player)]
	_availRefineries.text = "Refined: %d  (%d refineries)" % [econ.RefinedMaterials, Economy.TotalRefineries(player)]
	# Maintenance is a pool, so it reads as remaining/total rather than a rate.
	_availMaintenence.text = "Maint: %d/%d" % [Economy.MaintenanceAvailable(player), Economy.MaintenanceCapacity(player)]
