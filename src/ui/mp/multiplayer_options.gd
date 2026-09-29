extends MpScreen
## Multiplayer Options screen (manual p161-p162, Fig 5.9). "This screen allows
## the host to select the game parameters and load a previously saved game. This
## screen also lets both players chat with each other before the game is
## started." The host edits; the guest sees the same screen with the choices
## disabled; every host choice is echoed into the chat view as a line from the
## host (the figure's "Darth Vader: Standard game victory selected."), which is
## how the guest learns the settings. The checkmark starts the game (host only).
##
## TWO PAGES (TeeJ, 2026-09-27: restore the original's screen, "then add a
## SEPARATE screen next that is similar, except it has two options: briefing
## skip (yes / no), speed rule (slowest / average) - that way the chat window
## can still function"). Page 1 is the manual's: the side, the galaxy size,
## Standard Game / HQ Victory, Load Game, and the chat; the host's checkmark
## goes on to page 2. Page 2 is ours: whether the opening briefing plays, and
## the speed rule; the chat goes with it. There the checkmark starts the game
## and the back arrow returns to page 1. The guest follows the host's page
## (the settings' "page") and sees the choices, greyed.
##
## In the original's look when its screen is imported (original_mp.gd): page 1
## is the original's Multiplayer Options screen (COMMON.DLL 10103) as it is.
## Page 2 is the same screen with two choices on its second row, a third row -
## the first row's band - in the Standard Game / HQ Victory row's place for the
## game code and Copy, and the chat where page 1 has it, the same size
## (Page2Plate; TeeJ, 2026-09-28: Copy "should be more of a button", off page
## 1, the code and Copy "on their own separate row so the chat boxes are the
## same size on both").

const OriginalMp := preload("res://src/ui/mp/original_mp.gd")
const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

## The parts (px of the original's 640 x 480, measured on TeeJ's screenshot):
## the questions green Arial 15.5 centred on x 258, capitals at y 82 and 145;
## the side symbols (36 x 36) at (389, 71) and (440, 71), the galaxy sizes at
## x 389 / 440 / 491, y 133; the lamps (29 x 27) at (142, 205) and (318, 205),
## their words Arial 13 centred on x 231 and 407.5, capitals at 213; Load Game
## (48 x 43) at (502, 199); "Chat>" at x 181, capitals at 266; the message
## list from 297, four lines 16 apart.
const QuestionCentre := 258.0
const QuestionTops := [82, 145]
const QuestionPx := 15.5
const Questions := ["Which side do you want to play?", "What size galaxy would you like?"]
const SideAt := [Vector2(389, 71), Vector2(440, 71)]
const SizeAt := [Vector2(389, 133), Vector2(440, 133), Vector2(491, 133)]
const SizePictures := ["standard", "large", "huge"]
const Slot := Vector2(36, 36)
const LampAt := [Vector2(142, 205), Vector2(318, 205)]
## The lamp and the bar of words beside it take the click.
const LampHit := [Rect2(137, 200, 155, 36), Rect2(313, 200, 157, 36)]
const LampWords := [[231.0, "Standard Game"], [407.5, "HQ Victory"]]
const LampTop := 213
const LoadAt := Vector2(502, 199)
const ChatTop := 266
const ChatX := 181
const EntryX := 222
## The space to the right of Chat>, to the bar's end (the log's right edge).
const EntryW := 308
const LogX := 150
const LogTop := 297
const LogW := 386
const LogLines := 4

## Page 2: its questions on the two rows, its choices in the rows' two slots
## (their words Arial 9 - "Slowest" / "wins" - or 12, their capitals this far
## down the slot; the chosen one marked with a galaxy size's red brackets,
## their corners out at the slot's edges so they frame the words rather than
## cross them; the words green, chosen or not - TeeJ, 2026-09-28: "the red is
## hard to read on the black background").
const Page2Questions := ["Skip the opening briefing?", "What speed rule would you like?"]
const BriefingAt := [Vector2(389, 71), Vector2(440, 71)]
const BriefingWords := [[["Yes", 13]], [["No", 13]]]
const BriefingPx := 12.0
const SpeedAt := [Vector2(389, 133), Vector2(440, 133)]
const SpeedWords := [[["Slowest", 11], ["wins", 22]], [["Average", 16]]]
const SpeedPx := 9.0
## Page 2's plate, from the original's. The second row keeps its own red and
## green wires and grid (TeeJ, 2026-09-28: "make the wires match the colors on
## the previous page"); only its third slot goes, under the first row's plain
## panel beside it. The third row is the second row's band, its red and green
## wires with it (TeeJ, 2026-09-28: "make the wires red and green") (Page2Plate:
## rows [first, after last, where to], across x 133-575) in the lamp row's
## place, its third slot under that plain panel too, and the foot of the Load
## Game frame left below it under the panel's plain rows beside (Page2Covers:
## [from, to]). Its first two slots are made one for Copy Code (Page2Stretch):
## their frames run x 383-431 and 434-482, so the first's left edge and the
## second's right edge stay and x 397-468 between is filled, row by row, with
## a column of the first slot's recess (x 405).
const PlateX := Vector2i(133, 575)
const Page2Plate := [[124, 186, 186]]
const Page2Covers := [
	[Rect2i(483, 62, 55, 55), Vector2i(483, 124)],
	[Rect2i(483, 62, 55, 55), Vector2i(483, 186)],
	[Rect2i(400, 248, 76, 3), Vector2i(490, 248)],
]
## [from x, to x, the column, first row, after last row].
const Page2Stretch := [397, 468, 405, 186, 248]
## The third row's parts, 62 below the second row's: the code in its field
## (capitals at 206), and Copy Code across both slots' places - as wide as the
## two choices above together (TeeJ, 2026-09-28: "as wide as both the buttons
## above combined for balance"): Yes 389-425 and No 440-476, so 389-476, 87 -
## its words as page 2's are.
const CodeTop := 206
const CopyAt := Vector2(389, 195)
const CopySize := Vector2(87, 36)
const CopyWordTop := 13

const SizeNames: Array[String] = ["Standard", "Large", "Huge"]
## The win-condition tooltips are the PACK's words (pack.json victory_tips,
## manual p162 for the Star Wars pack) - the last setting text engine code
## carried. A pack without them shows no tooltip.
static func _victory_tip(hq_only: bool) -> String:
	var tips: PackDefs.VictoryTipsDef = FactionRegistry.Pack.Manifest.VictoryTips if FactionRegistry.Pack != null else null
	if tips == null:
		return ""
	return tips.HqOnly if hq_only else tips.Standard

var _lobby: RelayClient
var _host: bool = false
var _settings: Dictionary = {}
var _seen_settings: Dictionary = {}
var _chat_seen: int = 0
var _guest_seen: String = ""
var _log: RichTextLabel
var _side_group: ButtonGroup
var _size_group: ButtonGroup
var _victory_group: ButtonGroup
var _side_buttons: Array = []
var _size_buttons: Array = []
var _victory_buttons: Array = []
var _speed_group: ButtonGroup
var _speed_buttons: Array = []
var _saves: Array = []
var _load_for: String = ""      # the opponent the shared-saves check was made for
## A game saved on this computer goes to the relay, line by line,
## before Start (issue #301): both clients then rebuild it from the room's log.
var _upload: Array = []
var _upload_at: int = 0
var _uploading: bool = false
var _load_failed: bool = false
var _loading: bool = false
var _load_client: RelayClient = null
var _left: bool = false
## Joined a game that had already started (a rejoin by code, TeeJ room #110):
## the relay's whole log is pulled and the game rebuilt, as Load does.
var _rejoining: bool = false
## The guest's game as last seen (RelayClient.seat_info), host side.
var _seat_seen: Dictionary = {}
## The original's look: its screen, and its parts per choice.
var _look: OriginalMp
var _oSides: Array = []
var _oSizes: Array = []
var _oSpeeds: Array = []
var _oLamps: Array = []
var _oLoad: TextureButton
## Page 1 or 2 (TWO PAGES above), as the host's settings say.
var _page: int = 1
## Page 2's briefing choice: the plain look's buttons, the original's slots.
var _briefing_group: ButtonGroup
var _briefing_buttons: Array = []
var _oBriefs: Array = []
## The original's parts of each page; the two pages' pictures.
var _oPage1: Array = []
var _oPage2: Array = []
var _plates: Array = []


func _ready() -> void:
	_lobby = MpSetup.lobby
	_host = MpSetup.hosting
	_log = get_node("%ChatLog")
	_log.bbcode_enabled = false
	_log.scroll_following = true
	FactionRegistry.EnsureLoaded()

	# 1 "Which side do you want to play?" - the red symbol / the green symbol.
	_side_group = ButtonGroup.new()
	var side_box: HBoxContainer = get_node("%SideHBox")
	var tints := [Color(1.0, 0.3, 0.3), Color(0.3, 0.85, 0.3)]
	for i in mini(2, FactionRegistry.Playable.size()):
		var f: Faction = FactionRegistry.Playable[i]
		var b := Button.new()
		b.text = f.DisplayName
		b.custom_minimum_size = Vector2(200, 44)
		b.toggle_mode = true
		b.button_group = _side_group
		b.add_theme_color_override("font_color", tints[i])
		b.add_theme_color_override("font_pressed_color", tints[i])
		b.add_theme_color_override("font_hover_color", tints[i])
		b.tooltip_text = "Play as the %s." % f.DisplayName
		b.set_meta("id", f.Id)
		b.pressed.connect(func() -> void: _host_change("side", f.Id))
		side_box.add_child(b)
		_side_buttons.append(b)

	# 2 "What size galaxy would you like?" - standard, large, huge.
	_size_group = ButtonGroup.new()
	var size_box: HBoxContainer = get_node("%SizeHBox")
	var systems := [100, 150, 200]
	for i in SizeNames.size():
		var b := Button.new()
		b.text = SizeNames[i]
		b.custom_minimum_size = Vector2(130, 44)
		b.toggle_mode = true
		b.button_group = _size_group
		b.tooltip_text = "%s galaxy: %d systems." % [SizeNames[i], systems[i]]
		b.set_meta("id", i)
		var idx := i
		b.pressed.connect(func() -> void: _host_change("size", idx))
		size_box.add_child(b)
		_size_buttons.append(b)

	# TeeJ's addition (room #75): how the two speed settings combine in play.
	# "Slowest wins" is the manual's rule (p163); "Average" is floor of the mean.
	_speed_group = ButtonGroup.new()
	var speed_box: HBoxContainer = get_node("%SpeedRuleHBox")
	for pair in [["slowest", "Slowest wins", "The game runs at the slower of the two players' speed settings (the original's rule)."], ["average", "Average", "The game runs at the average of the two settings, rounded down: Slow and Fast give Medium; adjacent settings give the slower one."]]:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(160, 44)
		b.toggle_mode = true
		b.button_group = _speed_group
		b.tooltip_text = pair[2]
		b.set_meta("id", pair[0])
		var rule: String = pair[0]
		b.pressed.connect(func() -> void: _host_change("speed_rule", rule))
		speed_box.add_child(b)
		_speed_buttons.append(b)

	# Page 2 (TeeJ, 2026-09-27): whether the opening briefing plays, in the
	# plain look a row like the speed rule's, above it.
	_briefing_group = ButtonGroup.new()
	var speed_row: Control = speed_box.get_parent()
	var briefing_row := HBoxContainer.new()
	briefing_row.name = "BriefingRow"
	var caption: Label = (speed_row.get_node("SpeedCaption") as Label).duplicate()
	caption.name = "BriefingCaption"
	caption.text = "Skip the opening briefing?"
	briefing_row.add_child(caption)
	var briefing_box := HBoxContainer.new()
	briefing_box.name = "BriefingHBox"
	briefing_row.add_child(briefing_box)
	for pair in [["skip", "Yes", "No briefing: the game begins at once."], ["play", "No", "Each side hears its opening briefing; the game waits for both."]]:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(160, 44)
		b.toggle_mode = true
		b.button_group = _briefing_group
		b.tooltip_text = pair[2]
		b.set_meta("id", pair[0])
		var choice: String = pair[0]
		b.pressed.connect(func() -> void: _host_change("briefing", choice))
		briefing_box.add_child(b)
		_briefing_buttons.append(b)
	speed_row.get_parent().add_child(briefing_row)
	speed_row.get_parent().move_child(briefing_row, speed_row.get_index())

	# 3 Standard Game / HQ Only Victory.
	_victory_group = ButtonGroup.new()
	var std: Button = get_node("%BtnStandardGame")
	var hq: Button = get_node("%BtnHQOnlyVictory")
	std.tooltip_text = _victory_tip(false)
	hq.tooltip_text = _victory_tip(true)
	for b in [std, hq]:
		b.toggle_mode = true
		b.button_group = _victory_group
	std.pressed.connect(func() -> void: _host_change("hq_only", false))
	hq.pressed.connect(func() -> void: _host_change("hq_only", true))
	_victory_buttons = [std, hq]

	# Load Game: "only be available if you have saved a game from a previous
	# session with your current opponent" (p162).
	var load_btn: Button = get_node("%BtnLoadGame")
	load_btn.disabled = true
	load_btn.tooltip_text = "Load a game saved with your current opponent."
	load_btn.pressed.connect(_open_load_list)

	# 4 Chat> - "click your mouse in the space to the right of Chat>, then type
	# your message. Press Enter to send it."
	var entry: LineEdit = get_node("%ChatEntry")
	entry.text_submitted.connect(func(t: String) -> void:
		var text := t.strip_edges()
		entry.text = ""
		if text.is_empty():
			return
		_lobby.chat(text)
		_say(MpSetup.player_name, text))

	# The game code, with a Copy button (TeeJ, room #103): a browser player
	# cannot select text on the canvas, so the code goes to the clipboard.
	(get_node("%CodeValue") as Label).text = _lobby.code if not _lobby.code.is_empty() else "------"
	(get_node("%BtnCopyCode") as Button).pressed.connect(_copy_code)

	if _can_dress():
		_dress()

	# 5 The checkmark goes on to page 2, where it starts the game - host only.
	bar().set_previous(true, "Previous")
	bar().proceed.connect(_on_proceed)
	bar().previous.connect(_on_previous)
	bar().cancel.connect(cancel_to_cockpit)

	if _host:
		# The pack and build first (MpSetup.pack_settings, as the room was
		# created with), then the game's own choices.
		_settings = MpSetup.pack_settings()
		_settings.merge({ "side": FactionRegistry.Playable[0].Id, "size": int(Enums.GalaxySize.Large), "hq_only": false, "speed_rule": "slowest",
			"briefing": "play", "page": 1 }, true)
		_lobby.set_settings(_settings)
		_reflect()
		_say(MpSetup.player_name, "Game \"%s\" created. Code %s." % [MpSetup.game_name, _lobby.code])
		_echo_all()
		_lobby.list_saves()
	else:
		_settings = _lobby.settings.duplicate()
		_seen_settings = _settings.duplicate()
		_reflect()
		_check_pack()
		_say(MpSetup.player_name, "Joined \"%s\" hosted by %s." % [_lobby.name, _lobby.host_name])
		_echo_all()
		# The guest sees the host's choices but cannot change them. Not
		# `disabled`: Godot's disabled style hides the pressed look, so the
		# selection was invisible (TeeJ, room #93). Ignore the mouse instead.
		for b in _side_buttons + _size_buttons + _victory_buttons + _speed_buttons + _briefing_buttons:
			_lock(b)
		load_btn.disabled = true
		load_btn.tooltip_text = "Only the host loads a saved game."
		# The guest's game - build and pack - for the host's check before Start.
		_lobby.send_seat_info()
	_sync_load()
	_refresh_look()
	_refresh_start()
	entry.grab_focus()

	if _lobby.started and _lobby.lines_on_relay > 0:
		_rejoining = true
		_say(MpSetup.player_name, "This game is under way - rejoining as %s..." % _lobby.side)
		_lobby.fetch_log(0)


func _process(_delta: float) -> void:
	if _lobby == null:
		return
	_lobby.poll()
	if _rejoining:
		if not _lobby.last_error.is_empty():
			show_error(_lobby.last_error.capitalize() + ".")
			_lobby.last_error = ""
			_rejoining = false
		elif _lobby.caught_up:
			MpSetup.load_lines = _lobby.replayed_lines + _lobby.take_held()
			# A saved game whose lines never reached the room would start a new
			# game in its place: stop and say so instead.
			if not str(_lobby.settings.get("load_game", "")).is_empty() and _lobby.replayed_lines.is_empty():
				MpSetup.load_lines = []
				_rejoining = false
				_load_failed = true
				show_error("Could not load the saved game: the relay has none of it.")
				return
			MpSetup.hosting = _lobby.side == "host"
			MpSetup.apply_settings(_lobby.settings, _lobby.side)
			_rejoining = false
			go(MainScene)
		return
	# Chat lines from the other side.
	while _chat_seen < _lobby.lobby_chat.size():
		var pair: Array = _lobby.lobby_chat[_chat_seen]
		_chat_seen += 1
		if str(pair[0]) != MpSetup.player_name:
			_say(str(pair[0]), str(pair[1]))
	# The host came (back): the guest's game goes to it again.
	if not _host and _lobby.host_arrived:
		_lobby.host_arrived = false
		_lobby.send_seat_info()
	# The guest's game arrived, or went with the guest: Start follows it.
	if _host and _lobby.seat_info != _seat_seen:
		_seat_seen = _lobby.seat_info.duplicate()
		var why := _seat_mismatch()
		if not _seat_seen.is_empty() and not why.is_empty():
			_say(MpSetup.player_name, why)
		_refresh_start()
	# Who is here.
	if _host and _lobby.guest_name != _guest_seen:
		_guest_seen = _lobby.guest_name
		if not _guest_seen.is_empty():
			_say(MpSetup.player_name, "%s has joined." % _guest_seen)
			_lobby.list_saves()
		_refresh_start()
	if _lobby.opponent_left and not _left:
		_left = true
		_say(MpSetup.player_name, "Your opponent has left.")
		if _host:
			_lobby.guest_name = ""
			_guest_seen = ""
			_lobby.opponent_left = false
			_left = false
			_refresh_start()
	# The guest learns the host's choices from the settings lines.
	if not _host and _lobby.settings != _seen_settings:
		_settings = _lobby.settings.duplicate()
		_echo_diff()
		_seen_settings = _settings.duplicate()
		_reflect()
		_check_pack()
	# Saves shared with the current opponent (host): depends on the list AND
	# on who the opponent is, so it is recomputed whenever either changes.
	if _host and (_lobby.saves != _saves or _lobby.guest_name != _load_for):
		_saves = _lobby.saves.duplicate()
		_load_for = _lobby.guest_name
		var any := not _shared_saves().is_empty() or not _own_saves().is_empty()
		var load_btn: Button = get_node("%BtnLoadGame")
		load_btn.disabled = not any
		load_btn.tooltip_text = "Load a game saved with your current opponent." if any else "Available once you have saved a game from a previous session with your current opponent."
		_sync_load()
	# Errors.
	if not _lobby.last_error.is_empty():
		show_error(_lobby.last_error.capitalize() + ".")
		_lobby.last_error = ""
	# A saved game going to the relay: a few lines a frame, then Start.
	if _uploading:
		_upload_some()
	# Started - both go to the game.
	if _lobby.started and not _loading and not _load_failed:
		_settings = _lobby.settings.duplicate()
		if not str(_settings.get("load_game", "")).is_empty():
			# A saved game (issue #301): the host sent its lines to this room
			# before Start. Both rebuild from the room's log, as a rejoin does -
			# the guest's copies of those lines, forwarded as they went up, are
			# the same lines and are dropped.
			_lobby.take_held()
			_lobby.fetch_log(0)
			_rejoining = true
			return
		if str(_settings.get("load", "")).is_empty():
			MpSetup.apply_settings(_settings, _lobby.side)
			go(MainScene)
		else:
			_begin_load(str(_settings.get("load", "")))
	if _loading:
		_poll_load()


# --- the original's look ---

## True when the player imported the pictures this screen is made of.
func _can_dress() -> bool:
	if not OriginalMp.CanBuild("mp_options") or Art.ButtonIcon("mp_load") == null or Art.ButtonIcon("mp_start") == null:
		return false
	if FactionRegistry.Playable.size() < 2:
		return false
	for i in 2:
		if Art.WindowPicture("mp_side.%s" % (FactionRegistry.Playable[i] as Faction).ArtSkin) == null:
			return false
	for s in SizePictures:
		if Art.WindowPicture("mp_size.%s" % s) == null:
			return false
	return Art.WindowPicture("mp_lamp.on") != null and Art.WindowPicture("mp_lamp.off") != null


## The two pages' pictures: the original's screen as it is, and page 2's
## made from it (Page2Plate).
static func _page_plates() -> Array:
	var tex: Texture2D = Art.Screen("mp_options")
	var src: Image = tex.get_image() if tex != null else null
	if src == null:
		return [tex, tex]
	return [tex, ImageTexture.create_from_image(Page2Picture(src))]


## Page 2's picture made from the original's screen `src` (Page2Plate,
## Page2Covers, Page2Stretch).
static func Page2Picture(src: Image) -> Image:
	var out: Image = src.duplicate()
	for p in Page2Plate:
		out.blit_rect(src, Rect2i(PlateX.x, p[0], PlateX.y - PlateX.x, p[1] - p[0]), Vector2i(PlateX.x, p[2]))
	for c in Page2Covers:
		out.blit_rect(src, c[0], c[1])
	var st: Array = Page2Stretch
	var column: Image = out.get_region(Rect2i(st[2], st[3], 1, st[4] - st[3]))
	for x in range(st[0], st[1]):
		out.blit_rect(column, Rect2i(0, 0, 1, st[4] - st[3]), Vector2i(x, st[3]))
	return out


## Corner marks `marks` (a slot's) spread to `width`: the left half at the left,
## the right half at the right.
static func WideMarks(marks: Texture2D, width: int) -> Texture2D:
	if marks == null:
		return null
	var m: Image = marks.get_image()
	var half := m.get_width() / 2
	var out := Image.create(width, m.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect(m, Rect2i(0, 0, half, m.get_height()), Vector2i.ZERO)
	out.blit_rect(m, Rect2i(half, 0, m.get_width() - half, m.get_height()), Vector2i(width - (m.get_width() - half), 0))
	return ImageTexture.create_from_image(out)


## The red corner brackets of a chosen galaxy size - the pixels that set its
## chosen picture apart from the plain one - to mark page 2's chosen choices
## the same way, each corner moved out to the slot's edges (TeeJ, 2026-09-28:
## "make the red brackets large enough to not cover the text"): the original's
## sit 5-7 px in, across "Slowest".
static func _brackets() -> Texture2D:
	var on: Texture2D = Art.WindowPicture("mp_size.huge.chosen")
	var off: Texture2D = Art.WindowPicture("mp_size.huge")
	if on == null or off == null or on.get_size() != off.get_size():
		return null
	var a: Image = on.get_image()
	var b: Image = off.get_image()
	var mask := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8)
	for y in a.get_height():
		for x in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if ca.r > 0.6 and ca.g < 0.35 and absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.25:
				mask.set_pixel(x, y, ca)
	return ImageTexture.create_from_image(Outward(mask))


## Corner marks `mask` with each quarter moved out until the marks reach the
## picture's edges.
static func Outward(mask: Image) -> Image:
	var used: Rect2i = mask.get_used_rect()
	var w := mask.get_width()
	var h := mask.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	if used.size == Vector2i.ZERO:
		return out
	var mid := used.get_center()
	for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var from := Rect2i(used.position.x if q.x == 0 else mid.x, used.position.y if q.y == 0 else mid.y, 0, 0)
		from.end = Vector2i(mid.x if q.x == 0 else used.end.x, mid.y if q.y == 0 else used.end.y)
		var shift := Vector2i(-used.position.x if q.x == 0 else w - used.end.x, -used.position.y if q.y == 0 else h - used.end.y)
		out.blend_rect(mask, from, from.position + shift)
	return out


func _dress() -> void:
	_plates = _page_plates()
	_look = OriginalMp.Dress(self, "mp_options", _plates[0]) as OriginalMp
	# Page 1: the manual's - side, galaxy size, Standard Game / HQ Victory, Load Game.
	for i in Questions.size():
		_oPage1.append(_look.Text(Questions[i], QuestionCentre - 150, QuestionTops[i], 300, QuestionPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "Question%d" % i))
	for i in 2:
		var f: Faction = FactionRegistry.Playable[i]
		_oSides.append(_slot("Side%d" % i, SideAt[i], (_side_buttons[i] as Button).tooltip_text, "side", f.Id))
	for i in SizeAt.size():
		_oSizes.append(_slot("Size%d" % i, SizeAt[i], (_size_buttons[i] as Button).tooltip_text, "size", i))
	_oPage1.append_array(_oSides + _oSizes)
	for i in 2:
		var lamp := _look.Place(Art.WindowPicture("mp_lamp.off"), LampAt[i].x, LampAt[i].y, "Lamp%d" % i)
		var words: Label = _look.Text(LampWords[i][1], LampWords[i][0] - 75, LampTop, 150, 13.0, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "LampWords%d" % i)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hit := Control.new()
		hit.name = "LampHit%d" % i
		hit.tooltip_text = _victory_tip(i == 1)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		var hq: bool = i == 1
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_pick("hq_only", hq))
		_look.Add(hit, LampHit[i])
		_oLamps.append(lamp)
		_oPage1.append_array([lamp, words, hit])
	_oLoad = _look.PicButton("mp_load", LoadAt.x, LoadAt.y, "Load")
	_oLoad.pressed.connect(_open_load_list)
	_oPage1.append(_oLoad)
	# Page 2: ours - the opening briefing, the speed rule.
	for i in Page2Questions.size():
		_oPage2.append(_look.Text(Page2Questions[i], QuestionCentre - 150, QuestionTops[i], 300, QuestionPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "Page2Question%d" % i))
	var marks: Texture2D = _brackets()
	for i in 2:
		_oBriefs.append(_choice("Briefing", i, BriefingAt[i], _briefing_buttons[i], "briefing", BriefingWords[i], BriefingPx, marks))
		_oSpeeds.append(_choice("Speed", i, SpeedAt[i], _speed_buttons[i], "speed_rule", SpeedWords[i], SpeedPx, marks))
	# Page 2's third row: the game code in the row's field, Copy Code in the
	# slot across both places - a button like the page's others, its brackets
	# shown while it is held.
	var code_text := "Code: %s" % (_lobby.code if not _lobby.code.is_empty() else "------")
	_oPage2.append(_look.Text(code_text, QuestionCentre - 150, CodeTop, 300, QuestionPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "Code"))
	var copy := TextureButton.new()
	copy.name = "Copy"
	copy.ignore_texture_size = true
	copy.stretch_mode = TextureButton.STRETCH_SCALE
	copy.tooltip_text = "Copy the game code, to give to your opponent."
	copy.pressed.connect(_copy_code)
	_look.Add(copy, Rect2(CopyAt, CopySize))
	var word: Label = _look.Text("Copy Code", CopyAt.x, CopyAt.y + CopyWordTop, CopySize.x, BriefingPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "CopyWord")
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var held := _look.Place(WideMarks(marks, int(CopySize.x)), CopyAt.x, CopyAt.y, "CopyMark")
	held.visible = false
	copy.button_down.connect(func() -> void: held.visible = true)
	copy.button_up.connect(func() -> void: held.visible = false)
	_oPage2.append_array([copy, word])
	# The chat, on both pages where page 1 has it: Chat> and the space to its
	# right, the message list.
	_look.Text("Chat>", ChatX, ChatTop, 40, 13.0, OriginalMp.Green, HORIZONTAL_ALIGNMENT_LEFT, "ChatLabel")
	var entry: LineEdit = get_node("%ChatEntry")
	entry.placeholder_text = ""
	_look.Field(entry, EntryX, ChatTop, EntryW, 13.0, OriginalMp.Green)
	_look.Log(_log, LogX, LogTop, LogW, LogLines, 12.0, 16.0, OriginalMp.Green)


## One of page 2's choices: a slot, its words, and the red brackets shown when
## it is the one chosen (`prefix` "Speed" or "Briefing", `i` its place).
func _choice(prefix: String, i: int, at: Vector2, plain: Button, key: String, lines: Array, px: float, marks: Texture2D) -> TextureButton:
	var b := _slot("%s%d" % [prefix, i], at, plain.tooltip_text, key, str(plain.get_meta("id")))
	var words: Array = []
	for line in lines:
		var l: Label = _look.Text(line[0], at.x, at.y + line[1], Slot.x, px, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "%sWords%d_%d" % [prefix, i, words.size()])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.append(l)
	var mark := _look.Place(marks, at.x, at.y, "%sMark%d" % [prefix, i])
	b.set_meta("words", words)
	b.set_meta("mark", mark)
	_oPage2.append(b)
	_oPage2.append_array(words)
	return b


## Page 1 or 2: the plain look's rows, or the original's parts, its picture
## and the chat's place; the checkmark goes on (page 1) or starts (page 2).
func _show_page(page: int) -> void:
	_page = clampi(page, 1, 2)
	var one := _page == 1
	for n in ["SideRow", "SizeRow", "VictoryRow"]:
		(get_node("CenterContainer/Console/" + n) as Control).visible = one
	# The game code and Copy Code on page 2 alone, as the original's look has
	# them (_oPage2; TeeJ, 2026-09-28: Copy off page 1).
	for n in ["BriefingRow", "SpeedRow", "CodeRow"]:
		(get_node("CenterContainer/Console/" + n) as Control).visible = not one
	if _look != null:
		for c in _oPage1:
			(c as CanvasItem).visible = one
		for c in _oPage2:
			(c as CanvasItem).visible = not one
		var plate: TextureRect = _look.Plate()
		if plate != null and _plates.size() == 2 and plate.texture != _plates[0 if one else 1]:
			_look.Repicture(plate, _plates[0 if one else 1])
	bar().set_proceed("Next" if one else "Start Game")
	_refresh_start()


## One of the square choices: a picture button that makes the host's choice.
func _slot(node_name: String, at: Vector2, tip: String, key: String, value: Variant) -> TextureButton:
	var b := TextureButton.new()
	b.name = node_name
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.tooltip_text = tip
	b.pressed.connect(func() -> void: _pick(key, value))
	_look.Add(b, Rect2(at, Slot))
	return b


## A choice made on the original's screen: the host's alone, and not once a
## saved game has fixed them.
func _pick(key: String, value: Variant) -> void:
	if _locked():
		return
	_host_change(key, value)
	_reflect()


func _locked() -> bool:
	return not _host or _loading or (_side_buttons.size() > 0 and (_side_buttons[0] as Button).disabled)


## The pictures for the choices as they stand: the chosen one lit; for a
## player who cannot change them (the guest, or a loaded game), the others
## greyed - the original's disabled pictures (INFERRED: which state the
## original's guest sees is not on any screenshot).
func _refresh_look() -> void:
	if _look == null:
		return
	var locked := _locked()
	var state := func(chosen: bool) -> String: return ".chosen" if chosen else (".grey" if locked else "")
	for i in _oSides.size():
		var skin: String = (FactionRegistry.Playable[i] as Faction).ArtSkin
		var chosen: bool = str(FactionRegistry.Playable[i].Id) == str(_settings.get("side", ""))
		_picture(_oSides[i], "mp_side.%s%s" % [skin, state.call(chosen)], "mp_side.%s" % skin)
	for i in _oSizes.size():
		var chosen: bool = i == int(_settings.get("size", 1))
		_picture(_oSizes[i], "mp_size.%s%s" % [SizePictures[i], state.call(chosen)], "mp_size.%s" % SizePictures[i])
	for pair in [[_oSpeeds, _speed_buttons, "speed_rule", "slowest"], [_oBriefs, _briefing_buttons, "briefing", "play"]]:
		for i in (pair[0] as Array).size():
			var b: TextureButton = pair[0][i]
			var chosen: bool = str((pair[1][i] as Button).get_meta("id")) == str(_settings.get(pair[2], pair[3]))
			for l in b.get_meta("words"):
				(l as Label).add_theme_color_override("font_color", OriginalMp.Green if chosen or not locked else OriginalMp.Grey)
			(b.get_meta("mark") as Control).visible = chosen and _page == 2
	var hq := bool(_settings.get("hq_only", false))
	for i in _oLamps.size():
		var on: bool = (i == 1) == hq
		var pic: Texture2D = Art.WindowPicture("mp_lamp.on" if on else ("mp_lamp.grey" if locked else "mp_lamp.off"))
		(_oLamps[i] as TextureRect).texture = pic if pic != null else Art.WindowPicture("mp_lamp.off")


static func _picture(b: TextureButton, pic: String, fallback: String) -> void:
	var tex: Texture2D = Art.WindowPicture(pic)
	b.texture_normal = tex if tex != null else Art.WindowPicture(fallback)


## Load Game on the original's screen follows the plain button.
func _sync_load() -> void:
	if _oLoad == null:
		return
	var load_btn: Button = get_node("%BtnLoadGame")
	_oLoad.disabled = load_btn.disabled
	_oLoad.tooltip_text = load_btn.tooltip_text


## A choice the guest may see but not touch: drawn as on the host's screen.
static func _lock(b: Button) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_mode = Control.FOCUS_NONE
	# The tooltip stays: the win conditions on the victory buttons are the
	# manual's words (p162) and the guest is entitled to read them.


func _copy_code() -> void:
	var code := _lobby.code
	if code.is_empty():
		return
	DisplayServer.clipboard_set(code)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(code), true)
	_say(MpSetup.player_name, "Copied the game code %s." % code)


# --- the host's choices ---

func _host_change(key: String, value: Variant) -> void:
	if not _host or _loading:
		return
	if _settings.get(key) == value:
		return
	_settings[key] = value
	_lobby.set_settings(_settings)
	_echo(key)


func _reflect() -> void:
	for b in _side_buttons:
		b.button_pressed = str(b.get_meta("id")) == str(_settings.get("side", ""))
	for b in _size_buttons:
		b.button_pressed = int(b.get_meta("id")) == int(_settings.get("size", 1))
	_victory_buttons[0].button_pressed = not bool(_settings.get("hq_only", false))
	_victory_buttons[1].button_pressed = bool(_settings.get("hq_only", false))
	for b in _speed_buttons:
		b.button_pressed = str(b.get_meta("id")) == str(_settings.get("speed_rule", "slowest"))
	for b in _briefing_buttons:
		b.button_pressed = str(b.get_meta("id")) == str(_settings.get("briefing", "play"))
	_show_page(int(_settings.get("page", 1)))
	_refresh_look()


## The figure's wording: "Standard game victory selected." "Small galaxy size
## selected." "Host has chosen the Alliance side."
func _echo(key: String) -> void:
	var host_name := MpSetup.player_name if _host else _lobby.host_name
	match key:
		"side":
			_say(host_name, "Host has chosen the %s side." % MpSetup.host_faction(_settings).DisplayName)
		"size":
			_say(host_name, "%s galaxy size selected." % SizeNames[clampi(int(_settings.get("size", 1)), 0, 2)])
		"hq_only":
			_say(host_name, "%s selected." % ("HQ Only victory" if bool(_settings.get("hq_only", false)) else "Standard game victory"))
		"speed_rule":
			_say(host_name, "%s speed rule selected." % ("Average" if str(_settings.get("speed_rule", "slowest")) == "average" else "Slowest"))
		"briefing":
			_say(host_name, "The opening briefing will be skipped." if str(_settings.get("briefing", "play")) == "skip" else "The opening briefing will play.")
		"load":
			_say(host_name, "Loaded \"%s\", Day %d." % [str(_settings.get("load_name", "")), StrategicTickManager.Shown(int(_settings.get("load_day", 0)))])


func _echo_all() -> void:
	for k in ["side", "size", "hq_only", "speed_rule", "briefing"]:
		_echo(k)
	if not str(_settings.get("load_name", "")).is_empty():
		_echo("load")


func _echo_diff() -> void:
	for k in ["side", "size", "hq_only", "speed_rule", "briefing"]:
		if _settings.get(k) != _seen_settings.get(k):
			_echo(k)
	# A save picked (a slot's or the relay's): its name and day, once.
	for k in ["load", "load_game", "load_name", "load_day"]:
		if _settings.get(k) != _seen_settings.get(k):
			_echo("load")
			break


## A line in the chat view. Names and messages come from strangers: added as
## plain text, never parsed as BBCode.
func _say(who: String, text: String) -> void:
	_log.add_text("%s: %s\n" % [who, text])


## A guest on the wrong pack is told so here. What stops the game is the
## host's side: Start stays disabled until the guest's seat_info matches
## (_seat_mismatch), and in play the hello stops a game that differs anyway
## (GameManager._ShowMismatch).
func _check_pack() -> void:
	var why := MpSetup.pack_mismatch(_settings)
	if not why.is_empty():
		show_error(why)
		_say(MpSetup.player_name, why)


# --- start / previous ---

func _refresh_start() -> void:
	if _page == 1:
		if _host:
			bar().set_proceed_enabled(not _loading, "Next: the opening briefing and the speed rule.")
		else:
			bar().set_proceed_enabled(false, "The host chooses the game's options.")
		return
	if not _host:
		bar().set_proceed_enabled(false, "The host starts the game.")
	elif _lobby.guest_name.is_empty():
		bar().set_proceed_enabled(false, "Waiting for an opponent to join. Game code: %s" % _lobby.code)
	else:
		var why := _seat_mismatch()
		bar().set_proceed_enabled(why.is_empty(), why)


## Why the guest's game cannot play this one, or "" when it can: a HARD block
## on Start, not a warning - two builds or two packs would desync. Until the
## guest's seat_info arrives its game is taken to be out of date: a client
## too old to send one.
func _seat_mismatch() -> String:
	var s: Dictionary = _lobby.seat_info
	if s.is_empty():
		return "Opponent's game is out of date."
	if not BuildInfo.same_build(BuildInfo.version(), str(s.get("build", ""))):
		return "Opponent's game version differs - whoever is older, reload the page."
	if str(s.get("pack", "")) != FactionRegistry.LoadedId() or str(s.get("pack_hash", "")) != FactionRegistry.PackHash:
		return "Opponent's pack differs (theirs %s, yours %s) - you must both play the same pack." % [
			_pack_words(str(s.get("pack", "")), str(s.get("pack_hash", ""))), _pack_words(FactionRegistry.LoadedId(), FactionRegistry.PackHash)]
	return ""


static func _pack_words(id: String, hash: String) -> String:
	return "%s %s" % [id, hash.substr(0, 8)] if not hash.is_empty() else id


func _start() -> void:
	if not _host or _lobby.guest_name.is_empty() or _loading or _uploading or not _seat_mismatch().is_empty():
		return
	if not _settings.has("seed"):
		# The host picks the seed at Start; it travels in the settings so both
		# clients build the identical galaxy.
		_settings["seed"] = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
		_lobby.set_settings(_settings)
	var game_id := str(_settings.get("load_game", ""))
	if not game_id.is_empty():
		# A saved game: its lines go to this room first (_upload_some), then Start.
		var read: Array = SaveManager.ReadH2H(game_id)
		if (read[0] as Dictionary).is_empty():
			show_error("Could not read the saved game \"%s\"." % str(_settings.get("load_name", "")))
			return
		_upload = read[1]
		_upload_at = 0
		_uploading = true
		_say(MpSetup.player_name, "Loading the saved game...")
		bar().set_proceed_enabled(false, "Loading the saved game...")
		return
	_lobby.start()
	bar().set_proceed_enabled(false, "Starting...")


## Sends the saved slot's lines to the room, as many a frame as the socket
## takes without its send buffer filling (a line that does not fit is lost), and
## starts the game when the last is out.
const UploadBufferBytes := 32 * 1024


func _upload_some() -> void:
	var t: WebSocketTransport = _lobby.transport
	if not t.is_connected_now():
		return
	while _upload_at < _upload.size() and t.buffered() < UploadBufferBytes:
		t.send(_upload[_upload_at])
		_upload_at += 1
	if _upload_at >= _upload.size():
		_uploading = false
		_upload = []
		_lobby.start()
		bar().set_proceed_enabled(false, "Starting...")


## The checkmark: page 1 goes on to page 2, and the guest follows; page 2
## starts the game.
func _on_proceed() -> void:
	if not _host:
		return
	if _page == 1:
		_host_change("page", 2)
		_show_page(2)
		_refresh_look()
	else:
		_start()


## The back arrow: page 2 returns to page 1; page 1 leaves the game.
func _on_previous() -> void:
	if _host and _page == 2 and not _loading:
		_host_change("page", 1)
		_show_page(1)
		_refresh_look()
		return
	_previous()


func _previous() -> void:
	# The seat is given up: back to Host Game or Locate Session with a fresh lobby.
	MpSetup.reset()
	go(HostGameScene if _host else LocateSessionScene)


# --- Load Game (p162): the saves both players are in ---

func _shared_saves() -> Array:
	var out: Array = []
	for s in _saves:
		if int(s.get("lines", 0)) == 0 or int(s.get("day", 0)) < 1:
			continue
		var names := [str(s.get("host", "")), str(s.get("guest", ""))]
		if names.has(MpSetup.player_name) and names.has(_lobby.guest_name):
			out.append(s)
	return out


## "" when save `s` was made on the loaded pack version, else the pack and
## version it was made with ("<title> v1.2"). A save from before saves carried
## the pack's hash is taken to be on the loaded one.
static func _save_pack_words(s: Dictionary) -> String:
	var st: Dictionary = s.get("settings", {}) if s.get("settings") is Dictionary else {}
	var hash := str(st.get("pack_hash", ""))
	if hash.is_empty() or hash == FactionRegistry.PackHash:
		return ""
	var title := str(st.get("pack_title", st.get("pack", "another pack")))
	var version := str(st.get("pack_version", ""))
	return "%s v%s" % [title, version] if not version.is_empty() else "another version of %s" % title


## The head-to-head games saved on this computer with the current opponent
## (issue #301): both names in the save, whichever of the two hosted. Newest
## first, as the Saved Games screen lists them.
func _own_saves() -> Array:
	var out: Array = []
	if _lobby.guest_name.is_empty():
		return out
	for s: Dictionary in SaveManager.Games():
		if s["side"] != "h2h":
			continue
		var names := [str(s.get("host", "")), str(s.get("guest", ""))]
		if names.has(MpSetup.player_name) and names.has(_lobby.guest_name):
			out.append(s)
	return out


## The Load list (p162): the games saved on this computer with the
## current opponent first - each resumes at the day it was saved - then the
## games the relay holds with the two of you (decision D: a game left from
## Waiting for Opponent stays loadable), which resume where play stopped.
func _open_load_list() -> void:
	var entries: Array = []   # [kind, save]
	for s in _own_saves():
		entries.append(["saved", s])
	for s in _shared_saves():
		entries.append(["relay", s])
	if entries.is_empty():
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Load Game"
	dlg.ok_button_text = "Load"
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(460, 200)
	# Only a save made on the loaded pack version loads (strangers plan): the
	# others are listed greyed, with the version they need.
	var first_ok := -1
	for i in entries.size():
		var s: Dictionary = entries[i][1]
		var line := ""
		if entries[i][0] == "saved":
			line = "Saved game: %s - Day %d - saved %s" % [str(s.get("name", "")), StrategicTickManager.Shown(int(s.get("day", 0))), SaveManager.SavedDate(s)]
		else:
			var when := Time.get_datetime_string_from_unix_time(int(float(s.get("updated", 0)) / 1000.0), true)
			line = "%s - Day %d - last played %s" % [str(s.get("name", "")), StrategicTickManager.Shown(int(s.get("day", 0))), when]
		var need := _save_pack_words(s)
		if not need.is_empty():
			line += " - made with %s" % need
		list.add_item(line)
		list.set_item_disabled(i, not need.is_empty())
		if need.is_empty() and first_ok < 0:
			first_ok = i
	if first_ok >= 0:
		list.select(first_ok)
	dlg.add_child(list)
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		var picked := list.get_selected_items()
		if picked.is_empty() or list.is_item_disabled(picked[0]):
			return
		var kind: String = entries[picked[0]][0]
		var s: Dictionary = entries[picked[0]][1]
		# "it will use the game size and difficulty settings from your previous
		# game. You will not need to choose them again" (p162).
		var saved: Dictionary = s.get("settings", {})
		_settings["side"] = str(saved.get("side", _settings.get("side")))
		_settings["size"] = int(saved.get("size", _settings.get("size")))
		_settings["hq_only"] = bool(saved.get("hq_only", _settings.get("hq_only")))
		_settings["speed_rule"] = str(saved.get("speed_rule", "slowest"))
		_settings["seed"] = int(saved.get("seed", 0))
		_settings["load_name"] = str(s.get("name", ""))
		_settings["load_day"] = int(s.get("day", 0))
		if kind == "saved":
			# Each player keeps the side they had; the side that hosted when it
			# was saved stays the one the galaxy was seeded from (apply_settings).
			_settings["side"] = str(s.get("local", _settings.get("side")))
			_settings["seeded_by"] = str(s.get("seeded_by", ""))
			_settings["load_game"] = str(s["id"])
			_settings["load"] = ""
		else:
			_settings["load"] = str(s.get("code", ""))
			_settings["load_game"] = ""
			_settings.erase("seeded_by")
		_lobby.set_settings(_settings)
		for b in _side_buttons + _size_buttons + _victory_buttons + _speed_buttons + _briefing_buttons:
			b.disabled = true
		_reflect()
		_echo("load")
		dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	dlg.popup_centered()


## Both clients: join the saved game's room by name, pull its log, then go.
func _begin_load(code: String) -> void:
	_loading = true
	_say(MpSetup.player_name, "Loading the saved game...")
	_load_client = RelayClient.new(MpSetup.relay_url(), MpSetup.player_name)
	_load_client.join(code)


func _poll_load() -> void:
	_load_client.poll()
	if not _load_client.last_error.is_empty():
		show_error("Could not load the saved game: %s." % _load_client.last_error)
		_load_client.transport.close()
		_load_client = null
		_loading = false
		return
	if _load_client.started and not _load_client.catching_up and not _load_client.caught_up:
		_load_client.fetch_log(0)
	if _load_client.caught_up:
		MpSetup.load_lines = _load_client.replayed_lines + _load_client.take_held()
		var seat := _load_client.side
		_lobby.transport.close()
		MpSetup.lobby = _load_client
		_lobby = _load_client
		MpSetup.hosting = seat == "host"
		MpSetup.apply_settings(_load_client.settings, seat)
		_loading = false
		go(MainScene)
