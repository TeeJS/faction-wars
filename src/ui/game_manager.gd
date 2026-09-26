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
var _appliedEffective: int = -1
var _stallSince: int = -1            # ms; the opponent's end-of-day is overdue
var _waitingSince: int = -1          # ms; the Waiting for Opponent box is up
var _wasWaiting: bool = false        # true while a wait is in progress; keeps _waitingSince from resetting when the box is closed and re-shown
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
			_strategicEngine = Replayer.replay_entries(saved[0], saved[1], upto)
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
		_StartLockstep()   # may rebuild the world (Load Game) - the map comes after
	var authenticGalaxy: Array[Sector] = GameState.ActiveGalaxy

	_galaxyMap.InitializeMap(authenticGalaxy, _uiManager)

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


func _process(_delta: float) -> void:
	var session: LockstepSession = MpSetup.session
	if session == null:
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


## The Speed Control as the original draws it, over the plain panel's place.
func _BuildOriginalSpeed() -> void:
	_oSide = OUI.Side(GameSettings.PlayerFaction)
	var bezel: Texture2D = Art.WindowPicture("hud_speed.%s" % _oSide)
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

	if _oBars != null:
		_oBars.texture = Art.WindowPicture("speed_bars.%s.%d" % [_oSide, clampi(effective, 0, SpeedNames.size() - 1)])
		_oBars.size = _oBars.texture.get_size() * HudScaleNow if _oBars.texture != null else Vector2.ZERO
		_timeControls.tooltip_text = "Game Speed Control: %s" % _speedReadout.text
	if _speed == 0:
		_tickTimer.stop()
		if not _PauseShowing():
			_ShowPause()
		return
	if _PauseShowing():
		_HidePause()
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
	# The opponent is overdue when my end for the open phase has been out for
	# longer than a phase plus a generous round trip.
	var waiting: bool = session.remote_speed == 0 or session.opponent_gone \
		or session.overdue_ms() > WaitingAfterMs
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
		# Timestamp the wait ONCE, on the false->true transition - not every time
		# the box is re-shown. Closing the box (X) and having it re-pop next tick
		# must not restart the Leave-Game clock (TeeJ, room, 2026-09-03).
		if not _wasWaiting:
			_wasWaiting = true
			_waitingSince = now
		if not _waitBox.visible:
			print("[GameManager] Waiting for Opponent (day %d)" % StrategicTickManager.Today)
			_waitBox.popup_centered()
		# Leave Game appears IMMEDIATELY on a real disconnect (the seat is empty,
		# no reason to wait), and after LeaveAfterMs on a mere pause.
		_leaveBtn.visible = session.opponent_gone or (now - _waitingSince > LeaveAfterMs)
	elif _waitBox != null and _waitBox.visible:
		print("[GameManager] opponent is back (day %d)" % StrategicTickManager.Today)
		_waitBox.hide()
		_waitingSince = -1
		_wasWaiting = false


func _BuildWaitBox() -> void:
	_waitBox = AcceptDialog.new()
	_waitBox.title = "Waiting"   # "Waiting for Opponent" was cut off (TeeJ, room #197)
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
	# (manual p068). WHICH types is the Message Alert bar's job (its icons light
	# per category); here a count, so the box never widens over the Raw readout
	# (TeeJ, 2026-09-22: "Missions 3, Defense 2, Conflict 1" ran into it).
	# The count is gone from here (TeeJ, 2026-09-23: "the unread message count
	# is not needed there"): the Message Alert column and the Message Index's
	# tabs carry it.
	_dayLabel.text = "Day: %d" % currentDay
	if _oDay != null:
		_oDay.text = str(currentDay)
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
