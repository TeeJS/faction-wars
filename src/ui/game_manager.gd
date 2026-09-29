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
var _oSpeedMenu: PopupPanel = null   # the original's, with its art
const OriginalMenu := preload("res://src/ui/original_menu.gd")
var _pauseBox: AcceptDialog

# THE ORIGINAL'S SPEED CONTROL AND ALERT BOX, with the art imported (TeeJ,
# 2026-09-23: "match the pull-down speed selector", "the paused screen does
# not match"). The Speed Control is the box cut from the side's Command
# Center frame (STRATEGY 900 / 901): the day in its window, and the side's
# bars - none lit at Pause and Very Slow, one at Slow, two at Medium, three at
# Fast (TeeJ's screenshot at Slow: one). Placed in the box's own pixels,
# measured on the frames; drawn HudScale times as large - one and a half, not
# the windows' two, so the strip across the top (the resource displays, 30
# pixels tall) stays inside the 45-pixel row above the docked sector window,
# and the Speed Control matches it as the original's does. The day's colour
# on the Alliance's is INFERRED (the Empire's is green): the side's.
const OUI := preload("res://src/ui/original_ui.gd")
const Art := preload("res://src/ui/artwork.gd")
const AdviceLib := preload("res://src/ui/advice.gd")
const OriginalMp := preload("res://src/ui/mp/original_mp.gd")
## The shell in a pack's look (docs/ww2-look-plan.md, phase 3).
const LookHud := preload("res://src/ui/look_hud.gd")
const HudScale := 1.5
## The scale the HUD is drawn at now: HudScale, or the Command Center frame's
## own (the screen's height over the frame's) when the frame is the screen, so
## the Speed Control and the resource displays sit on the frame's boxes.
static var HudScaleNow: float = HudScale
const SpeedLayout := {
	"empire": {"lcd": Rect2(11, 6, 62, 11), "bars": Vector2(73, 7)},
	"alliance": {"lcd": Rect2(12, 8, 62, 12), "bars": Vector2(74, 9)},
}
## WHERE THE ORIGINAL'S SPEED MENU OPENS, from the Speed Control's top-left:
## 5 pixels right of its bars and 2 under their top, over the box's lower half
## (TeeJ, 2026-09-25: "the alignment of the speed pull-down menu is different
## than the original, please make it match"). The Alliance's measured on his
## screenshot of the original - the menu's frame at (169,22) on the Command
## Center frame, the box at (90,11); the Empire's INFERRED, the same off its
## own bars. The menu's inside already matched (original_menu.gd).
const SpeedMenuAt := {"alliance": Vector2(79, 11), "empire": Vector2(78, 9)}
var _oSpeed: Control = null
var _oDay: Label = null
var _oBars: TextureRect = null
var _oSide: String = ""
var _oPause: Control = null

# THE ORIGINAL'S RESOURCE DISPLAYS (TeeJ, 2026-09-23: "match the resource
# display windows to the original"): the strip cut from the same frame - raw
# material, refined material, maintenance, each its icon and a number (manual
# p030 Fig. 2.15) - the numbers right-aligned 4 pixels inside each panel, 7
# pixels tall (measured on TeeJ's screenshot: 29, 125, 462). Maintenance is
# what is AVAILABLE, as the original's monitor shows (day-zero baseline in the
# research skill: "the maintenance monitor shows available"). What the plain
# row adds - the mine and refinery counts, the capacity - is on each panel's
# tooltip.
const ResourceLayout := {
	"empire": {"rights": [104, 202, 300], "cap": 11},
	"alliance": {"rights": [94, 188, 286], "cap": 10},   # TeeJ's Alliance screenshots, 2026-09-24
}
var _oResources: Control = null
var _oFigures: Array = []
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
var _mpDayDue: bool = false          # the host's day clock fired: the next phase end carries advance
var _phaseTimer: Timer               # ends the open phase every PhaseSeconds
const PhaseSeconds := 0.3            # room #99/#118: orders apply within a phase plus one round trip
var _menuOpen: bool = false          # the Game Options screen is up: the opponent waits
var _briefing: bool = false          # the opening briefing plays: no clock (single player)
var _dayGreyed: bool = false         # head-to-head: the opponent's briefing still plays (WaitingForBriefing)
var _appliedEffective: int = -1
var _stallSince: int = -1            # ms; the opponent's end-of-day is overdue
var _waitingSince: int = -1          # ms; the Waiting for Opponent box is up
var _wasWaiting: bool = false        # true while a wait is in progress; keeps _waitingSince from resetting when the box is closed and re-shown
var _waitBox: AcceptDialog
var _leaveBtn: Button
var _oWait: Control = null           # the original's alert box saying so (_OriginalAlert)
var _oWaitKey: String = ""           # what it shows: rebuilt when that changes
var _resyncing: bool = false
const WaitingAfterMs := 3000         # an overdue opponent becomes "waiting" after this
const LeaveAfterMs := 60000          # Leave Game appears after this (design question D)


func _ready() -> void:
	print("Booting up Rebellion Engine...")
	# The Cockpit's music ends as the game begins; the game's playlist starts
	# once there is a galaxy to judge the war by (below; docs/music-plan.md).
	preload("res://src/ui/music.gd").Stop()

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

	# SINGLE-PLAYER LOAD (issue #6): if the start menu picked a save slot, replay
	# its command log to restore that game instead of starting a new one. The
	# header carries the seed, factions and settings, so new_game runs inside the
	# replay - PlayerFaction etc. are set from the save, not the menu.
	var loaded: bool = false
	if not mp and not GameSettings.PendingLoadPath.is_empty():
		var loadPath: String = GameSettings.PendingLoadPath
		GameSettings.PendingLoadPath = ""
		var saved: Array = CommandLog.Read(loadPath)
		if not (saved[0] as Dictionary).is_empty():
			# The saved day comes from the log's day hashes, not the commands - a
			# game saved with few player orders must still restore to its real day.
			var upto: int = 1
			for d: Variant in (saved[2] as Dictionary).keys():
				upto = maxi(upto, int(d))
			# A game saved before its first tick (a new or an imported game) has
			# no day hash yet: its orders say what day it is.
			for c: Command in saved[1]:
				upto = maxi(upto, c.Day)
			# A HEAD-TO-HEAD SAVE played on alone (issue #301): the day the host
			# saved on, its orders up to the save, then the AI plays the opponent.
			var h2h: Dictionary = (saved[0] as Dictionary).get("h2h", {}) if (saved[0] as Dictionary).get("h2h") is Dictionary else {}
			var solo: bool = not h2h.is_empty() and int((saved[0] as Dictionary).get("ai_takeover_day", 0)) == 0
			if solo:
				upto = int(h2h.get("day", upto))
			_strategicEngine = Replayer.replay_entries(saved[0], saved[1], upto)
			if _strategicEngine != null and solo:
				CommandBus.apply_day(upto, (saved[1] as Array).filter(func(c: Command) -> bool: return c.Day == upto))
				var want := str(h2h.get("state_hash", ""))
				var got := GameSignature.ReplayHash(GameState.ActiveGalaxy)
				GameSettings.HandToAi(upto)
				if not want.is_empty() and want != got:
					push_warning("[GameManager] the head-to-head save's state does not match the saved one (saved %s, loaded %s)" % [want.substr(0, 12), got.substr(0, 12)])
				print("[GameManager] head-to-head save loaded alone on day %d as %s: state %s" % [upto, GameSettings.PlayerFaction.Id, "as saved" if want == got else "DIFFERS from the save"])
			elif _strategicEngine != null:
				# THE ORDERS GIVEN ON THE SAVED DAY. The replay stops at the tick
				# into that day, and the orders given after it - a message read,
				# a build queued, then Save - came after that tick. Applied now,
				# as they were then; without this they were lost on every load.
				CommandBus.apply_day(upto, (saved[1] as Array).filter(func(c: Command) -> bool: return c.Day == upto))
			# The replay queues by day (Immediate off) and leaves it off. Single
			# player applies an order on the frame it is issued - nothing here
			# ever drains CommandBus.Pending - so turn it back on.
			CommandBus.Immediate = true
			if _strategicEngine != null:
				# The loaded game's past goes on into the new session log (below), so
				# saving it again is a complete save: its day hashes (the replay does
				# not re-record them) and its order numbering.
				CommandLog.Hashes = (saved[2] as Dictionary).duplicate()
				CommandBus.resume_seq(saved[1])
				loaded = true
		if _strategicEngine == null:
			push_error("[GameManager] load failed for %s - starting a new game instead" % loadPath)

	# The catalogs, the resets, the galaxy, the roster and day zero, in the
	# source's order - GameSession.new_game is GameManager._Ready's load path.
	if _strategicEngine == null:
		_strategicEngine = GameSession.new_game(GameSettings.PlayerFaction.Id,
			GameSettings.SelectedDifficulty, GameSettings.SelectedSize, seed, humans,
			GameSettings.HostFaction.Id if mp and GameSettings.HostFaction != null else "")
	print("[Prng] seed=%d" % seed)
	if mp:
		# A rebuild from a log (a rejoin, or Load Game) is a game under way: no
		# opening briefing (below), as a single-player load has none.
		loaded = not MpSetup.load_lines.is_empty()
		_StartLockstep()   # may rebuild the world (Load Game) - the map comes after
	var authenticGalaxy: Array[Sector] = GameState.ActiveGalaxy

	_galaxyMap.InitializeMap(authenticGalaxy, _uiManager)
	preload("res://src/ui/music.gd").StartGame(get_tree())

	# THE SESSION LOG (docs/m1-plan.md). Every order goes through the CommandBus
	# and into this file, with the day hash after every tick; --record=path
	# chooses the file, else user://last-session.jsonl. tests/replay.gd rebuilds
	# the game from it.
	var record: String = _ParseStringArg("--record=")
	if not mp:
		CommandLog.Open(record if not record.is_empty() else "user://last-session.jsonl", CommandLog.Header(), loaded)

	_tickTimer = Timer.new()
	add_child(_tickTimer)
	if mp:
		_tickTimer.timeout.connect(func() -> void: _mpDayDue = true)
		_phaseTimer = Timer.new()
		_phaseTimer.wait_time = PhaseSeconds
		_phaseTimer.autostart = true
		add_child(_phaseTimer)
		_phaseTimer.timeout.connect(_EndPhase)
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
	# "Ship Info." was wired to nothing; it is the Fleet Finder (TeeJ, 2026-09-24).
	(get_node("UIManager/HBoxContainer/ShipInfo") as Button).pressed.connect(func() -> void: _uiManager.OpenFleetFinder())
	# "Troop Info." likewise: the Troop Finder.
	(get_node("UIManager/HBoxContainer/TroopInfo") as Button).pressed.connect(_uiManager.OpenTroopFinder)
	# The Encyclopedia control (manual p073): the Index view.
	var encyBtn: Button = get_node_or_null("UIManager/HBoxContainer/Encyclopedia")
	if encyBtn != null:
		encyBtn.pressed.connect(func() -> void: _uiManager.OpenEncyclopedia())

	# THE AGENT DROID. "C-3PO for the Alliance, IMP-22 for the Empire" (manual
	# p031). The manual's gesture is a RIGHT-CLICK on the droid itself; without
	# the Command Center frame's droids this is a button that opens the same
	# menu, and with them it goes (the droid stands in the frame).
	var chosenFaction: Faction = GameSettings.PlayerFaction
	var agentBtn := Button.new()
	agentBtn.name = "AgentButton"
	agentBtn.visible = not _uiManager.HasDroids()
	agentBtn.text = AgentDroid.NameFor(chosenFaction)
	agentBtn.tooltip_text = "Agent droid: overview, objectives, and the two management automations."
	agentBtn.pressed.connect(func() -> void: _uiManager.OpenAgentMenu(agentBtn))
	charInfoBtn.get_parent().add_child(agentBtn)
	charInfoBtn.get_parent().move_child(agentBtn, charInfoBtn.get_index() + 1)

	# The bar reads the engine's day from the first frame; it used to read
	# "Day: 0" until the first tick and then jump to 2 (TeeJ, 2026-09-22).
	_lastDay = StrategicTickManager.Today
	RefreshStatusBar()

	# A pack with a look (docs/ww2-look-plan.md): the shell as its command
	# table - not under the Command Center frame, which is the original's.
	if Look.Active() and _uiManager.CommandFrameRef == null:
		LookHud.Apply(self, _uiManager, _galaxyMap)
		LookHud.SpeedState(_timeControls, _appliedEffective == 0)

	# THE AGENT'S ADVICE (advice.gd): single player, Agent Advice on in Easy.
	# THE OPENING BRIEFING (manual p022): a new game, not a loaded one. In
	# head-to-head only when the host chose it (GameSettings.MpBriefing, the
	# Multiplayer Options' second page); each side hears its own, and the game
	# waits for both (HoldForBriefing). When it ends - at once, with none to
	# play (an art set without its recordings) - the opening advice and the
	# Message Index on it (UIManager.BriefingOver).
	if not mp:
		AdviceLib.Start(GameSettings.LocalFaction())
	else:
		AdviceLib.Start(null)
	if not loaded and (not mp or GameSettings.MpBriefing):
		if _uiManager.StartBriefing(HoldForBriefing) == null:
			_uiManager.BriefingOver()


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
	var session := LockstepSession.new(lobby.transport, us, them, MpSetup.hosting)
	session.engine = _strategicEngine
	CommandBus.Immediate = false
	CommandBus.Session = session
	if not MpSetup.load_lines.is_empty():
		var resumed: int = session.rebuild_from_log(MpSetup.load_lines, CommandLog.Header())
		MpSetup.load_lines = []
		if resumed < 0:
			push_error("[GameManager] the saved game's log could not be rebuilt")
		_strategicEngine = session.engine
		# A rejoin or a Load compares games too: the build may have changed
		# since the game was saved (a tab left open across a deploy).
		session.start()
	else:
		session.absorb(lobby.take_held())
		session.start()
	MpSetup.session = session
	_speed = session.my_speed if session.my_speed != 0 else DefaultSpeed
	print("[GameManager] head-to-head: %s vs %s, room %s, day %d" % [us.Id, them.Id, lobby.code, StrategicTickManager.Today])


## Every PhaseSeconds: close my open phase. The host's end carries advance when
## its day clock has fired since the last one, and only then does the day tick.
func _EndPhase() -> void:
	var session: LockstepSession = MpSetup.session
	if session == null or session.state == LockstepSession.State.Desync:
		return
	if session.end_phase(_mpDayDue and MpSetup.hosting):
		if MpSetup.hosting and _mpDayDue:
			_mpDayDue = false


func _process(delta: float) -> void:
	var session: LockstepSession = MpSetup.session
	if session == null:
		# The agent's advice keeps the original's clock: ticks as the day runs.
		if not _tickTimer.is_stopped():
			AdviceLib.Advance(AdviceLib.TicksIn(delta, _tickTimer.wait_time, _speed), StrategicTickManager.Today)
		return
	# The two games differ (the hello): nothing more is played.
	if not session.hello_mismatch.is_empty():
		_ShowMismatch(session.hello_mismatch)
		return
	var completed := 0
	while session.try_phase():
		completed += 1
		if completed > 50:
			break
	if completed == 0:
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
	# The original's: each speed's bars and name, the one in force in the
	# side's colour (original_menu.gd; TeeJ, 2026-09-24).
	_oSpeedMenu = OriginalMenu.SpeedMenu(OUI.Side(GameSettings.PlayerFaction), SpeedNames, SetSpeed)
	if _oSpeedMenu != null:
		add_child(_oSpeedMenu)

	# A CLICK ON THE TIME DISPLAY PULLS THE MENU DOWN under it. The manual
	# says right-click (p071); TeeJ asked for a pull-down (2026-09-23), so
	# either button drops it from the control's lower edge.
	_timeControls.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed 				and (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT):
			if WaitingForBriefing():
				_timeControls.accept_event()
				return
			var at: Vector2 = _timeControls.global_position + Vector2(0, _timeControls.size.y)
			var menu: Window = _speedMenu
			if _oSpeedMenu != null:
				OriginalMenu.MarkSpeed(_oSpeedMenu, _speed)
				menu = _oSpeedMenu
				# The original's opens off its bars, over the box's lower half.
				if _oSpeed != null and SpeedMenuAt.has(_oSide):
					at = _timeControls.global_position + SpeedMenuAt[_oSide] * HudScaleNow
			menu.position = Vector2i(int(at.x), int(at.y))
			menu.popup()
			_timeControls.accept_event())
	var hudSide: String = OUI.Side(GameSettings.PlayerFaction)
	HudScaleNow = CommandFrame.ScaleFor(get_viewport().get_visible_rect().size) \
		if CommandFrame.CanBuild(hudSide) else HudScale
	_BuildOriginalSpeed()
	_BuildOriginalResources()
	_PlaceHud()
	_BuildCommandFrame()

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
	_BuildOriginalPause()


## THE PLAIN FRAME'S READOUTS (the plain build parity plan, phase 1): without
## the original's pictures, the Speed Control and the resource displays are
## drawn by us at the pictures' own size and place in the frame (their sizes
## measured on the art set: the Alliance's 106 x 23 and 300 x 28, the
## Empire's 102 x 24 and 320 x 30) - our plate, black readouts, the same
## figures in the side's colour; the speed bars ours, lit as the original's
## five pictures light theirs (none at the first two speeds, then one, two,
## three).
const PlainHud := {
	"alliance": {"speed": Vector2(106, 23), "resources": Vector2(300, 28)},
	"empire": {"speed": Vector2(102, 24), "resources": Vector2(320, 30)},
}
const PlainIcons := preload("res://src/ui/plain_icons.gd")
const PlainResourceWords := ["Raw", "Refined", "Maint."]
var _oPlainBars: PlainBars = null


## The Speed Control as the original draws it, over the plain panel's place.
func _BuildOriginalSpeed() -> void:
	_oSide = OUI.Side(GameSettings.PlayerFaction)
	var bezel: Texture2D = Art.WindowPicture("hud_speed.%s" % _oSide)
	if bezel == null and _oSpeed == null and SpeedLayout.has(_oSide) and PlainHud.has(_oSide) and CommandFrame.CanBuild(_oSide):
		_BuildPlainSpeed()
		return
	if bezel == null or not SpeedLayout.has(_oSide) or _oSpeed != null:
		return
	var lay: Dictionary = SpeedLayout[_oSide]
	(_timeControls.get_node("Margin") as Control).visible = false
	_timeControls.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_oSpeed = Control.new()
	_oSpeed.name = "OriginalSpeed"
	_oSpeed.custom_minimum_size = bezel.get_size() * HudScaleNow
	_oSpeed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeControls.add_child(_oSpeed)
	HudPlace(_oSpeed, bezel, 0, 0, "Bezel")
	var lcd: Rect2 = lay["lcd"]
	# The day: 8-pixel figures centred in the window (Arial 11; its capitals
	# sit 2 pixels under the line's top).
	_oDay = HudText(_oSpeed, "", lcd.position.x, lcd.position.y + (lcd.size.y - 8) / 2.0 - 2, lcd.size.x, 12, 11,
		OUI.SideColor(GameSettings.PlayerFaction), HORIZONTAL_ALIGNMENT_CENTER, "Day")
	var bars: Vector2 = lay["bars"]
	_oBars = HudPlace(_oSpeed, null, bars.x, bars.y, "Bars")


## The plain frame's Speed Control: our plate, the day in the black window, our bars.
func _BuildPlainSpeed() -> void:
	var lay: Dictionary = SpeedLayout[_oSide]
	(_timeControls.get_node("Margin") as Control).visible = false
	_timeControls.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var box := PlainHudBox.new()
	box.name = "PlainSpeed"
	box.K = HudScaleNow
	var lcd: Rect2 = lay["lcd"]
	var bars: Vector2 = lay["bars"]
	box.Wells = [lcd, Rect2(bars - Vector2(1, 1), Vector2(18, 12))]
	box.custom_minimum_size = PlainHud[_oSide]["speed"] * HudScaleNow
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oSpeed = box
	_timeControls.add_child(_oSpeed)
	_oDay = HudText(_oSpeed, "", lcd.position.x, lcd.position.y + (lcd.size.y - 8) / 2.0 - 2, lcd.size.x, 12, 11,
		OUI.SideColor(GameSettings.PlayerFaction), HORIZONTAL_ALIGNMENT_CENTER, "Day")
	_oPlainBars = PlainBars.new()
	_oPlainBars.name = "Bars"
	_oPlainBars.On = OUI.SideColor(GameSettings.PlayerFaction)
	_oPlainBars.position = bars * HudScaleNow
	_oPlainBars.size = Vector2(16, 10) * HudScaleNow
	_oPlainBars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oSpeed.add_child(_oPlainBars)


## Our plate with black readout windows in it (`Wells`, in the frame's pixels).
class PlainHudBox extends Control:
	var Wells: Array = []
	var K: float = 1.0

	func _draw() -> void:
		PlainIcons.DrawPlate(self, Rect2(Vector2.ZERO, size))
		for w in Wells:
			var r: Rect2 = w
			PlainIcons.DrawWell(self, Rect2(r.position * K, r.size * K), Color.BLACK)


## Three bars, `Lit` of them in the side's colour, the rest dim.
class PlainBars extends Control:
	var Lit: int = 0
	var On: Color = Color.RED

	func SetLit(n: int) -> void:
		if n != Lit:
			Lit = n
			queue_redraw()

	func _draw() -> void:
		var unit: float = size.x / 16.0
		for i in 3:
			var c: Color = On if i < Lit else On.darkened(0.55)
			draw_rect(Rect2(Vector2(i * 6.0 * unit, 0), Vector2(4.0 * unit, size.y)), c)


## WHERE THE SPEED CONTROL AND THE RESOURCE DISPLAYS SIT: as the side's frame
## has them - "alliance and empire screen layouts are mirrored" (TeeJ,
## 2026-09-24): the Alliance's Speed Control left of its resources, the
## Empire's right of them - the pair centred at the top. Their places in the
## frames (STRATEGY 900 / 901), the same cuts the exporter makes.
const HudFrame := {
	"alliance": {"speed": Vector2(90, 11), "resources": Vector2(232, 10)},
	"empire": {"speed": Vector2(488, 13), "resources": Vector2(132, 12)},
}


func _PlaceHud() -> void:
	var side: String = OUI.Side(GameSettings.PlayerFaction)
	if not HudFrame.has(side) or (_oSpeed == null and _oResources == null):
		return
	var f: Dictionary = HudFrame[side]
	# With the Command Center frame as the screen, each sits on its own box in
	# the frame (the pieces are cut from it at these places).
	if CommandFrame.CanBuild(side):
		var origin: Vector2 = CommandFrame.OriginFor(get_viewport().get_visible_rect().size)
		if _oSpeed != null:
			_timeControls.position = (origin + f["speed"] * HudScaleNow).floor()
		if _oResources != null:
			_oResources.position = (origin + f["resources"] * HudScaleNow).floor()
		return
	var parts: Array = []   # [control, frame position, size in frame pixels]
	if _oSpeed != null:
		parts.append([_timeControls, f["speed"], _oSpeed.custom_minimum_size / HudScaleNow])
	if _oResources != null:
		parts.append([_oResources, f["resources"], _oResources.size / HudScaleNow])
	var left: float = INF
	var right: float = -INF
	var top: float = INF
	for part in parts:
		left = minf(left, part[1].x)
		right = maxf(right, part[1].x + part[2].x)
		top = minf(top, part[1].y)
	var x0: float = floorf((get_viewport().get_visible_rect().size.x - (right - left) * HudScaleNow) / 2.0)
	for part in parts:
		(part[0] as Control).position = Vector2(x0 + (part[1].x - left) * HudScaleNow, (part[1].y - top) * HudScaleNow).floor()


## The Command Center (CommandFrame): the side's frame as the screen.
func _BuildCommandFrame() -> void:
	_uiManager.BuildCommandFrame(OUI.Side(GameSettings.PlayerFaction))


## The resource displays as the original draws them, in place of the plain
## row (placed with the Speed Control by _PlaceHud).
func _BuildOriginalResources() -> void:
	var side: String = OUI.Side(GameSettings.PlayerFaction)
	var strip: Texture2D = Art.WindowPicture("hud_resources.%s" % side)
	if strip == null and _oResources == null and ResourceLayout.has(side) and PlainHud.has(side) and CommandFrame.CanBuild(side):
		_BuildPlainResources(side)
		return
	if strip == null or not ResourceLayout.has(side) or _oResources != null:
		return
	var row: Control = _availMines.get_parent().get_parent()   # the scene's Resources row
	row.visible = false
	var lay: Dictionary = ResourceLayout[side]
	_oResources = Control.new()
	_oResources.name = "OriginalResources"
	_oResources.size = strip.get_size() * HudScaleNow
	_oResources.position = Vector2(floorf((get_viewport().get_visible_rect().size.x - _oResources.size.x) / 2.0), 0)
	_oResources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.get_parent().add_child(_oResources)
	HudPlace(_oResources, strip, 0, 0, "Strip")
	_oFigures.clear()
	var left := 0.0
	for i in 3:
		var right: float = lay["rights"][i]
		# The figure (Arial 10: 7-pixel figures; the capitals 2 under the top).
		var fig := HudText(_oResources, "", right - 60, float(lay["cap"]) - 2, 60, 11, 10,
			OUI.SideColor(GameSettings.PlayerFaction), HORIZONTAL_ALIGNMENT_RIGHT, ["Raw", "Refined", "Maintenance"][i])
		_oFigures.append(fig)
		# The panel's hover area, for its tooltip.
		var hover := Control.new()
		hover.name = "Hover%d" % i
		hover.position = Vector2(left, 0) * HudScaleNow
		hover.size = Vector2(right + 4 - left, strip.get_height()) * HudScaleNow
		hover.mouse_filter = Control.MOUSE_FILTER_PASS
		_oResources.add_child(hover)
		left = right + 4


## The plain frame's resource displays: our plate with three black readouts,
## each its word (ours, for the original's icon) and the same figure.
func _BuildPlainResources(side: String) -> void:
	var row: Control = _availMines.get_parent().get_parent()   # the scene's Resources row
	row.visible = false
	var lay: Dictionary = ResourceLayout[side]
	var sz: Vector2 = PlainHud[side]["resources"]
	var box := PlainHudBox.new()
	box.name = "PlainResources"
	box.K = HudScaleNow
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oResources = box
	_oResources.size = sz * HudScaleNow
	_oResources.position = Vector2(floorf((get_viewport().get_visible_rect().size.x - _oResources.size.x) / 2.0), 0)
	row.get_parent().add_child(_oResources)
	_oFigures.clear()
	var left := 0.0
	for i in 3:
		var right: float = lay["rights"][i]
		box.Wells.append(Rect2(left + 3, 3, right + 4 - left - 6, sz.y - 6))
		HudText(_oResources, PlainResourceWords[i], left + 7, float(lay["cap"]) - 2, 50, 11, 9,
			PlainIcons.Dimmed, HORIZONTAL_ALIGNMENT_LEFT, "Word%d" % i)
		var fig := HudText(_oResources, "", right - 60, float(lay["cap"]) - 2, 60, 11, 10,
			OUI.SideColor(GameSettings.PlayerFaction), HORIZONTAL_ALIGNMENT_RIGHT, ["Raw", "Refined", "Maintenance"][i])
		_oFigures.append(fig)
		var hover := Control.new()
		hover.name = "Hover%d" % i
		hover.position = Vector2(left, 0) * HudScaleNow
		hover.size = Vector2(right + 4 - left, sz.y) * HudScaleNow
		hover.mouse_filter = Control.MOUSE_FILTER_PASS
		_oResources.add_child(hover)
		left = right + 4
	box.queue_redraw()


## A picture of the Command Center's frame at original position (x, y),
## HudScale times as large, each pixel kept square-edged.
static func HudPlace(parent: Control, tex: Texture2D, x: float, y: float, node_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = Vector2(x, y) * HudScaleNow
	r.size = tex.get_size() * HudScaleNow if tex != null else Vector2.ZERO
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Text in the frame's own pixels, HudScale times as large.
static func HudText(parent: Control, text: String, x: float, y: float, w: float, h: float, px: float,
		color: Color, align: HorizontalAlignment, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.position = Vector2(x, y) * HudScaleNow
	l.size = Vector2(w, h) * HudScaleNow
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", OUI.Face(false))
	l.add_theme_font_size_override("font_size", roundi(px * HudScaleNow))
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## "Resume Game Play?" in the original's alert box (REBDLOG.DLL: the plate with
## one button socket, the check), over a blocker that takes every other click:
## pause still locks you out of the game's controls (manual p071).
func _BuildOriginalPause() -> void:
	var plate: Texture2D = OUI.Pic("dialog_plate1")
	if plate == null or Art.ButtonIcon("dialog_ok") == null or _oPause != null:
		return
	_oPause = Control.new()
	_oPause.name = "OriginalPause"
	_oPause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_oPause.mouse_filter = Control.MOUSE_FILTER_STOP
	_oPause.visible = false
	_uiManager.add_child(_oPause)
	var box := Control.new()
	box.name = "Box"
	box.size = plate.get_size()
	box.position = ((_oPause.get_viewport_rect().size - box.size) / 2.0).floor()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oPause.add_child(box)
	OUI.Place(box, plate, 0, 0, "Plate")
	# The original's words (REBDLOG): white, Arial bold 13, centred (measured
	# on TeeJ's screenshot: capitals from y 63).
	OUI.Text(box, "Resume Game Play?", 0, 60.5, 412, 18, 13, Color(1, 251 / 255.0, 240 / 255.0), HORIZONTAL_ALIGNMENT_CENTER, true, "Text")
	OUI.PictureButton(box, "dialog_ok", 176, 134, "Resume").pressed.connect(ResumeFromPause)


func _PauseShowing() -> bool:
	return (_oPause.visible if _oPause != null else false) or _pauseBox.visible


func _ShowPause() -> void:
	if _oPause != null:
		_oPause.visible = true
		_uiManager.move_child(_oPause, _uiManager.get_child_count() - 1)
		var box: Control = _oPause.get_node("Box")
		box.position = ((_oPause.size - box.size) / 2.0).floor()
		return
	_pauseBox.popup_centered()


func _HidePause() -> void:
	if _oPause != null:
		_oPause.visible = false
	if _pauseBox.visible:
		_pauseBox.hide()


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
	if WaitingForBriefing() != _dayGreyed:
		_dayGreyed = WaitingForBriefing()
		RefreshStatusBar()

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
	if Look.Active() and _oSpeed == null:
		LookHud.SpeedState(_timeControls, effective == 0)

	if _oBars != null:
		# Blank while the opening briefing holds the clock (RefreshStatusBar).
		_oBars.texture = null if _briefing else Art.WindowPicture("speed_bars.%s.%d" % [_oSide, clampi(effective, 0, SpeedNames.size() - 1)])
		_oBars.size = _oBars.texture.get_size() * HudScaleNow if _oBars.texture != null else Vector2.ZERO
		_timeControls.tooltip_text = "Game Speed Control: %s" % _speedReadout.text
	elif _oPlainBars != null:
		_oPlainBars.SetLit(0 if _briefing else clampi(effective - 1, 0, 3))
		_timeControls.tooltip_text = "Game Speed Control: %s" % _speedReadout.text
	if _speed == 0:
		_tickTimer.stop()
		if not _PauseShowing():
			_ShowPause()
		return
	if _PauseShowing():
		_HidePause()
	if effective == 0 or _menuOpen or _briefing:
		# The opponent paused, I am in the Game Options screen, or the briefing
		# plays: no clock.
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


## HEAD-TO-HEAD, MY BRIEFING OVER AND THE OPPONENT'S STILL PLAYING: as the
## original (TeeJ, 2026-09-27, testing it), "the player who finishes 1st can
## look at the board/game, but can not make any changes - their day counter is
## greyed out and stays at 0 until opponent finishes", and "there is no
## indication what's going on, other than the time bar being greyed out". So:
## no Waiting box, the day at 0 in the original's grey, the bars unlit (the
## clock is stopped), the Speed Control and its keys do nothing, and an order is
## dropped as if taken (CommandBus.issue). Chat still goes.
func WaitingForBriefing() -> bool:
	var session: LockstepSession = MpSetup.session
	return session != null and session.opponent_briefing()


## THE OPENING BRIEFING plays (on = true) or has let the clock go: the clock
## waits for it - as the original's, until its release step (after "We await
## your orders", its last line; on Stop Briefing, before the skip's line
## plays; briefing.gd Released). In head-to-head my speed goes
## to the opponent as a pause while mine plays - a pause on either side stops
## both (LockstepSession) - with the reason, so the side that finishes first
## is told whose briefing it waits for.
func HoldForBriefing(on: bool) -> void:
	_briefing = on
	print("[GameManager] opening briefing %s on day %d" % ["started" if on else "released the clock", StrategicTickManager.Today])
	var session: LockstepSession = MpSetup.session
	if session != null:
		session.set_speed(0 if on or _menuOpen else _speed, "briefing" if on else "")
	_ApplyClock()
	RefreshStatusBar()


## Waiting for Opponent (manual p163; docs/multiplayer-ui-design.md section 11):
## up while the opponent is in their Game Options screen, chose Pause, or
## dropped; after a minute a Leave Game button appears, behind a confirmation.
func _MpWatch(session: LockstepSession) -> void:
	# The opponent's speed changed: the slower of the two governs. Their
	# briefing's end also lifts the greyed time bar.
	if session.effective_speed() != _appliedEffective or session.opponent_briefing() != _dayGreyed:
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
	# The opponent is overdue when my end for the open phase has been out for
	# longer than a phase plus a generous round trip.
	# The opponent's opening briefing puts up no box: as the original, the
	# side that finished first looks at the board, its time bar greyed out
	# (WaitingForBriefing).
	var paused: bool = session.remote_speed == 0 and not session.opponent_briefing()
	var waiting: bool = paused or session.opponent_gone \
		or session.overdue_ms() > WaitingAfterMs
	# My own pause box has the screen; the manual's message is for the other
	# side. My own briefing has the screen too, to its very end.
	if _speed == 0 or _menuOpen or _briefing or _uiManager.Briefing() != null:
		waiting = false

	if waiting:
		# THE ORIGINAL'S WORDS (REBDLOG.DLL's string table, 4614 / 4615; manual
		# p163: "Your opponent will receive a Waiting for Opponent message, until
		# you return to the game"), in the original's alert box (TeeJ,
		# 2026-09-27: "this is not the right UI"). An opponent gone: its 4612,
		# and ours after it - the game code, since ours can rejoin (TeeJ, room
		# #110). The To Cockpit cross (the original's X, tip 6414) comes at once
		# for a lost opponent and after LeaveAfterMs for a mere wait, so nobody
		# is trapped (TeeJ, room #197).
		var lines: Array = ["Waiting For Opponent To Resume", "See the Troubleshooting Guide for more help."]
		if session.opponent_gone:
			lines = ["Your Opponent Has Left The Game"]
			if MpSetup.lobby != null and not MpSetup.lobby.code.is_empty():
				lines.append("Game code: %s - give it to your opponent to rejoin." % MpSetup.lobby.code)
		# Timestamp the wait ONCE, on the false->true transition - not every time
		# the box is re-shown. Closing the box (X) and having it re-pop next tick
		# must not restart the Leave-Game clock (TeeJ, room, 2026-09-03).
		if not _wasWaiting:
			_wasWaiting = true
			_waitingSince = now
			print("[GameManager] Waiting for Opponent (day %d)" % StrategicTickManager.Today)
		var leave: bool = session.opponent_gone or (now - _waitingSince > LeaveAfterMs)
		_ShowWait(lines, leave)
	elif _WaitShowing():
		print("[GameManager] opponent is back (day %d)" % StrategicTickManager.Today)
		_HideWait()
		_waitingSince = -1
		_wasWaiting = false


## Waiting for Opponent on screen, the original's box or the plain one.
func _WaitShowing() -> bool:
	return (_oWait != null and is_instance_valid(_oWait)) or (_waitBox != null and _waitBox.visible)


func _ShowWait(lines: Array, leave: bool) -> void:
	var key: String = "%s|%s" % [str(lines), leave]
	if _oWait != null and is_instance_valid(_oWait) and key == _oWaitKey:
		return
	_Drop(_oWait)
	_oWait = _OriginalAlert("OriginalWait", lines, Callable(), _ConfirmLeave if leave else Callable(), "", "To Cockpit")
	_oWaitKey = key
	if _oWait != null:
		return
	# Without the art: the plain box, the same words.
	if _waitBox == null:
		_BuildWaitBox()
	_waitBox.dialog_text = "\n".join(lines)
	_leaveBtn.visible = leave
	if not _waitBox.visible:
		_waitBox.popup_centered()


func _HideWait() -> void:
	_Drop(_oWait)
	_oWait = null
	_oWaitKey = ""
	if _waitBox != null and _waitBox.visible:
		_waitBox.hide()


## THE ORIGINAL'S ALERT BOX - REBDLOG's plates (10621-10623: no, one, two
## button sockets) and its check and cross, as the pause box's: over the whole
## screen and taking every click; up to two lines of its words, white Arial
## bold 13 centred on the plate's screen; a check (`ok`) and / or a cross in
## the sockets - measured on the plates: one at x 176, two at 137 and 228;
## y 134 as the pause box's, measured on TeeJ's screenshot. Two lines sit
## either side of the pause box's one (INFERRED: no two-line box of the
## original has been seen). Null without the art.
func _OriginalAlert(node_name: String, lines: Array, ok: Callable, cross: Callable, ok_tip: String, cross_tip: String) -> Control:
	var buttons: int = int(ok.is_valid()) + int(cross.is_valid())
	var plate: Texture2D = OUI.Pic("dialog_plate%d" % buttons)
	if plate == null or Art.ButtonIcon("dialog_ok") == null or Art.ButtonIcon("dialog_cancel") == null:
		return null
	var layer := Control.new()
	layer.name = node_name
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_uiManager.add_child(layer)
	# Its size, not only its anchors: under a CanvasLayer anchors alone leave it
	# 0 x 0, and it would take no click at all.
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := Control.new()
	box.name = "Box"
	box.size = plate.get_size()
	box.position = ((layer.get_viewport_rect().size - box.size) / 2.0).floor()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	OUI.Place(box, plate, 0, 0, "Plate")
	var top: float = 60.5 - 9.0 * (lines.size() - 1)
	for i in lines.size():
		OUI.Text(box, str(lines[i]), 0, top + 18.0 * i, 412, 18, 13, Color(1, 251 / 255.0, 240 / 255.0), HORIZONTAL_ALIGNMENT_CENTER, true, "Text%d" % i)
	var xs: Array = [176] if buttons == 1 else [137, 228]
	var at := 0
	if ok.is_valid():
		OUI.PictureButton(box, "dialog_ok", xs[at], 134, ok_tip).pressed.connect(ok)
		at += 1
	if cross.is_valid():
		OUI.PictureButton(box, "dialog_cancel", xs[at], 134, cross_tip).pressed.connect(cross)
	return layer


## Out of the tree at once, so its name is free for the next box; freed after.
static func _Drop(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.queue_free()


## To Cockpit: asked first, in the original's box and words (REBDLOG 4618,
## "Quit and return to cockpit?"): the check leaves, the cross goes back.
func _ConfirmLeave() -> void:
	var go := func() -> void:
		MpSetup.reset()
		get_tree().change_scene_to_file("res://Menu.tscn")
	var ask: Control = _uiManager.get_node_or_null("OriginalLeave")
	if ask != null:
		return
	var back := func() -> void:
		_Drop(_uiManager.get_node_or_null("OriginalLeave"))
	ask = _OriginalAlert("OriginalLeave", ["Quit and return to cockpit?"], go, back, "To Cockpit", "Cancel")
	if ask != null:
		return
	var confirm := ConfirmationDialog.new()
	confirm.title = "Leave Game"
	confirm.dialog_text = "Leave this game? It will be available to reload from either player."
	confirm.ok_button_text = "Leave"
	add_child(confirm)
	confirm.confirmed.connect(go)
	confirm.canceled.connect(func() -> void: confirm.queue_free())
	confirm.popup_centered()


## The hello's backstop (the Multiplayer Options screen blocks Start first): two
## clients on different builds, packs or settings would desync, so the game
## stops, says why, and its only way on is Leave - on both sides, each having
## compared the other's hello.
var _mismatchBox: AcceptDialog


func _ShowMismatch(reasons: String) -> void:
	if _mismatchBox != null:
		return
	print("[GameManager] the two games differ: %s" % reasons)
	_mismatchBox = AcceptDialog.new()
	_mismatchBox.title = "Game can't continue"
	_mismatchBox.dialog_text = "This game can't continue: %s." % reasons
	_mismatchBox.dialog_autowrap = true
	_mismatchBox.exclusive = true
	_mismatchBox.ok_button_text = "Leave"
	var leave := func() -> void:
		MpSetup.reset()
		get_tree().change_scene_to_file("res://Menu.tscn")
	_mismatchBox.confirmed.connect(leave)
	_mismatchBox.canceled.connect(leave)
	add_child(_mismatchBox)
	_mismatchBox.popup_centered(Vector2i(480, 0))


func _BuildWaitBox() -> void:
	_waitBox = AcceptDialog.new()
	_waitBox.title = "Waiting"   # "Waiting for Opponent" was cut off (TeeJ, room #197)
	_waitBox.exclusive = true
	_waitBox.unresizable = true
	_waitBox.get_ok_button().hide()
	_leaveBtn = _waitBox.add_button("Leave Game", true, "leave")
	_leaveBtn.visible = false
	_waitBox.custom_action.connect(func(action: StringName) -> void:
		if action == &"leave":
			_ConfirmLeave())
	add_child(_waitBox)


## THE MANUAL'S KEYBOARD TABLE: Alt+P Pause; Alt++/Alt+- speed up / down
## (Very Slow · Slow · Medium · Fast - FOUR settings, so the step keys never
## reach Pause, which has its own key).
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.alt_pressed or _speedMenu == null:
		return
	if WaitingForBriefing() and event.keycode in [KEY_P, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
		get_viewport().set_input_as_handled()
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
	# (manual p068). WHICH types is the Message Alert bar's job (its icons light
	# per category); here a count, so the box never widens over the Raw readout
	# (TeeJ, 2026-09-22: "Missions 3, Defense 2, Conflict 1" ran into it).
	# The count is gone from here (TeeJ, 2026-09-23: "the unread message count
	# is not needed there"): the Message Alert column and the Message Index's
	# tabs carry it.
	# The opponent's briefing still plays: the day greyed out, at 0 (the
	# original's, WaitingForBriefing).
	var shown: int = 0 if _dayGreyed else StrategicTickManager.Shown(currentDay)
	# THE TIME BAR IS BLANK WHILE THE OPENING BRIEFING HOLDS THE CLOCK - no day,
	# no bars - as a recording of the original's shows it (SuperPaulGames,
	# https://www.youtube.com/watch?v=5h_55gx9Sgo, 5:30-7:47: the day window
	# and the bars black throughout; the day and the bars back at its end).
	# Single-source, BACKLOG #53.
	if _briefing:
		_dayLabel.text = ""
		if _oDay != null:
			_oDay.text = ""
	else:
		_dayLabel.text = "Day: %d" % shown
	_dayLabel.modulate = OriginalMp.Grey if _dayGreyed else Color.WHITE
	if _oDay != null and not _briefing:
		_oDay.text = str(shown)
		_oDay.add_theme_color_override("font_color", OriginalMp.Grey if _dayGreyed else OUI.SideColor(GameSettings.PlayerFaction))
	_availMines.text = "Raw: %d  (%d %s)" % [econ.RawMaterials, Economy.TotalMines(player), Terms.label("mines")]
	_availRefineries.text = "Refined: %d  (%d %s)" % [econ.RefinedMaterials, Economy.TotalRefineries(player), Terms.label("refineries")]
	# Maintenance is a pool, so it reads as remaining/total rather than a rate.
	_availMaintenence.text = "Maint: %d/%d" % [Economy.MaintenanceAvailable(player), Economy.MaintenanceCapacity(player)]
	if _oResources != null:
		var figures: Array = [econ.RawMaterials, econ.RefinedMaterials, Economy.MaintenanceAvailable(player)]
		var tips: Array = [
			"Raw material: %d (%d %s)" % [econ.RawMaterials, Economy.TotalMines(player), Terms.label("mines")],
			"Refined material: %d (%d %s)" % [econ.RefinedMaterials, Economy.TotalRefineries(player), Terms.label("refineries")],
			"Maintenance: %d available of %d" % [Economy.MaintenanceAvailable(player), Economy.MaintenanceCapacity(player)]]
		for i in 3:
			(_oFigures[i] as Label).text = str(figures[i])
			(_oResources.get_node("Hover%d" % i) as Control).tooltip_text = tips[i]
