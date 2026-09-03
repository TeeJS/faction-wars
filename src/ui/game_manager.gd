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

# HEAD-TO-HEAD (docs/multiplayer-ui-design.md section 0). When MpSetup holds a
# started room, the clock does not advance the day itself: the timer marks the
# day as due and _process advances it through the LockstepSession as soon as
# the opponent's orders for it are complete.
var _mpDayDue: bool = false
var _menuOpen: bool = false          # the Game Options screen is up: the opponent waits
var _appliedEffective: int = -1
var _stallSince: int = -1            # ms; the opponent's end-of-day is overdue
var _waitingSince: int = -1          # ms; the Waiting for Opponent box is up
var _waitBox: AcceptDialog
var _leaveBtn: Button
var _resyncing: bool = false
const WaitingAfterMs := 3000         # an overdue opponent becomes "waiting" after this
const LeaveAfterMs := 60000          # Leave Game appears after this (design question D)


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
	var mp: bool = MpSetup.active()
	var humans: Array = []
	if mp:
		# The host chose the seed at Start; it came with the room's settings.
		seed = GameSettings.Seed
		for f in GameSettings.HumanFactions:
			humans.append(f.Id)

	# The catalogs, the resets, the galaxy, the roster and day zero, in the
	# source's order - GameSession.new_game is GameManager._Ready's load path.
	_strategicEngine = GameSession.new_game(GameSettings.PlayerFaction.Id,
		GameSettings.SelectedDifficulty, GameSettings.SelectedSize, seed, humans,
		GameSettings.HostFaction.Id if mp and GameSettings.HostFaction != null else "")
	print("[Prng] seed=%d" % seed)
	if mp:
		_StartLockstep()   # may rebuild the world (Load Game) - the map comes after
	var authenticGalaxy: Array[Sector] = GameState.ActiveGalaxy

	_galaxyMap.InitializeMap(authenticGalaxy, _uiManager)

	# THE SESSION LOG (docs/m1-plan.md). Every order goes through the CommandBus
	# and into this file, with the day hash after every tick; --record=path
	# chooses the file, else user://last-session.jsonl. tests/replay.gd rebuilds
	# the game from it.
	var record: String = _ParseStringArg("--record=")
	if not mp:
		CommandLog.Open(record if not record.is_empty() else "user://last-session.jsonl", CommandLog.Header())

	_tickTimer = Timer.new()
	add_child(_tickTimer)
	if mp:
		_tickTimer.timeout.connect(func() -> void: _mpDayDue = true)
	else:
		_tickTimer.timeout.connect(_strategicEngine.AdvanceDay)
		_tickTimer.timeout.connect(CommandBus.day_done)

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


## The head-to-head session: the same transport the lobby used, the log under
## the room's code, and either a fresh start (hello) or a rebuild from the
## saved game's log (Load Game, docs/multiplayer-ui-design.md section 7).
func _StartLockstep() -> void:
	var lobby: RelayClient = MpSetup.lobby
	var us: Faction = GameSettings.PlayerFaction
	var them: Faction = MpSetup.other_faction(us)
	CommandLog.Open("user://mp-%s.jsonl" % lobby.code, CommandLog.Header())
	var session := LockstepSession.new(lobby.transport, us, them)
	session.engine = _strategicEngine
	CommandBus.Immediate = false
	CommandBus.Session = session
	if not MpSetup.load_lines.is_empty():
		var resumed: int = session.rebuild_from_log(MpSetup.load_lines, CommandLog.Header())
		MpSetup.load_lines = []
		if resumed < 0:
			push_error("[GameManager] the saved game's log could not be rebuilt")
		_strategicEngine = session.engine
	else:
		session.absorb(lobby.take_held())
		session.start()
	MpSetup.session = session
	_speed = session.my_speed if session.my_speed != 0 else DefaultSpeed
	print("[GameManager] head-to-head: %s vs %s, room %s, day %d" % [us.Id, them.Id, lobby.code, StrategicTickManager.Today])


func _process(_delta: float) -> void:
	var session: LockstepSession = MpSetup.session
	if session == null:
		return
	if _mpDayDue:
		if session.try_tick():
			_mpDayDue = false
	else:
		session.pump()
	_MpWatch(session)


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

	# Head-to-head: my setting goes to the opponent; the clock runs at the
	# slower of the two (manual p163).
	var session: LockstepSession = MpSetup.session
	if session != null:
		session.set_speed(0 if _menuOpen else level)
	_ApplyClock()


## The clock as it should run now: my setting alone in single player; in a
## head-to-head game the slowest of the two settings ("the game plays at the
## slowest speed set on either computer", manual p163), and stopped while my
## Game Options screen is up.
func _ApplyClock() -> void:
	var session: LockstepSession = MpSetup.session
	var effective: int = _speed if session == null else session.effective_speed()
	_appliedEffective = effective

	# THE CURRENT SETTING, ON THE FACE OF THE CONTROL (user-reported behaviour
	# of the original). Addition for head-to-head: when the opponent's setting
	# changes the speed the game actually runs at, the face says so.
	if session != null and effective != _speed and _speed != 0:
		if GameSettings.SpeedRule == "average":
			_speedReadout.text = "%s (averaged with opponent)" % SpeedNames[effective]
		else:
			_speedReadout.text = "%s (set by opponent)" % SpeedNames[effective]
	else:
		_speedReadout.text = SpeedNames[_speed]

	if _speed == 0:
		_tickTimer.stop()
		if not _pauseBox.visible:
			_pauseBox.popup_centered()
		return
	if _pauseBox.visible:
		_pauseBox.hide()
	if effective == 0 or _menuOpen:
		# The opponent paused, or I am in the Game Options screen: no clock.
		_tickTimer.stop()
		return
	# Idempotent: re-choosing the running setting must not restart the day.
	if _tickTimer.is_stopped() or _tickTimer.wait_time != SpeedSeconds[effective]:
		_tickTimer.wait_time = SpeedSeconds[effective]
		_tickTimer.start()


## The Game Options screen is up (open = true) or was closed. Manual p163:
## "Your opponent will receive a Waiting for Opponent message, until you
## return to the game."
func MenuOpened(open: bool) -> void:
	_menuOpen = open
	print("[GameManager] Game Options screen %s on day %d" % ["opened" if open else "closed", StrategicTickManager.Today])
	var session: LockstepSession = MpSetup.session
	if session != null:
		session.set_speed(0 if open else _speed)
	_ApplyClock()


## Waiting for Opponent (manual p163; docs/multiplayer-ui-design.md section 11):
## up while the opponent is in their Game Options screen, chose Pause, or
## dropped; after a minute a Leave Game button appears, behind a confirmation.
func _MpWatch(session: LockstepSession) -> void:
	# The opponent's speed changed: the slower of the two governs.
	if session.effective_speed() != _appliedEffective:
		_ApplyClock()

	# A desync: rebuild from the shared log (M2). Whoever drifted is repaired;
	# the faithful side keeps waiting for the other to repair.
	if session.state == LockstepSession.State.Desync and not _resyncing:
		_resyncing = true
		var ok: bool = session.resync()
		_resyncing = false
		if ok:
			_strategicEngine = session.engine
			_galaxyMap.InitializeMap(GameState.ActiveGalaxy, _uiManager)
			_uiManager.RefreshNow()
		print("[GameManager] desync on day %d: %s" % [StrategicTickManager.Today, "repaired from the log" if ok else "waiting for the opponent to repair"])

	var now := Time.get_ticks_msec()
	if _mpDayDue and session.state == LockstepSession.State.WaitingOpponent:
		if _stallSince < 0:
			_stallSince = now
	else:
		_stallSince = -1
	var waiting: bool = session.remote_speed == 0 or session.opponent_gone \
		or (_stallSince >= 0 and now - _stallSince > WaitingAfterMs)
	# My own pause box has the screen; the manual's message is for the other side.
	if _speed == 0 or _menuOpen:
		waiting = false

	if waiting:
		if _waitBox == null:
			_BuildWaitBox()
		# TeeJ (room #106): say WHY - a deliberate departure from the manual's
		# single "Waiting for Opponent" message.
		var text := "Opponent paused." if session.remote_speed == 0 else "Waiting for opponent..."
		if session.opponent_gone:
			text += "\nConnection to your opponent was lost; waiting for them to rejoin."
			if MpSetup.lobby != null and not MpSetup.lobby.code.is_empty():
				# TeeJ (room #110): the code is what a dropped player needs to come back.
				text += "\nGame code: %s - give it to your opponent to rejoin (same player name)." % MpSetup.lobby.code
		_waitBox.dialog_text = text
		if not _waitBox.visible:
			print("[GameManager] Waiting for Opponent (day %d)" % StrategicTickManager.Today)
			_waitingSince = now
			_leaveBtn.visible = false
			_waitBox.popup_centered()
		elif not _leaveBtn.visible and now - _waitingSince > LeaveAfterMs:
			_leaveBtn.visible = true
	elif _waitBox != null and _waitBox.visible:
		print("[GameManager] opponent is back (day %d)" % StrategicTickManager.Today)
		_waitBox.hide()
		_waitingSince = -1


func _BuildWaitBox() -> void:
	_waitBox = AcceptDialog.new()
	_waitBox.title = "Waiting for Opponent"
	_waitBox.exclusive = true
	_waitBox.unresizable = true
	_waitBox.get_ok_button().hide()
	_leaveBtn = _waitBox.add_button("Leave Game", true, "leave")
	_leaveBtn.visible = false
	_waitBox.custom_action.connect(func(action: StringName) -> void:
		if action != &"leave":
			return
		var confirm := ConfirmationDialog.new()
		confirm.title = "Leave Game"
		confirm.dialog_text = "Leave this game? It will be available to reload from either player."
		confirm.ok_button_text = "Leave"
		add_child(confirm)
		confirm.confirmed.connect(func() -> void:
			MpSetup.reset()
			get_tree().change_scene_to_file("res://Menu.tscn"))
		confirm.canceled.connect(func() -> void: confirm.queue_free())
		confirm.popup_centered())
	add_child(_waitBox)


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
