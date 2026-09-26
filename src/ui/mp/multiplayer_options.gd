extends MpScreen
## Multiplayer Options screen (manual p161-p162, Fig 5.9). "This screen allows
## the host to select the game parameters and load a previously saved game. This
## screen also lets both players chat with each other before the game is
## started." The host edits; the guest sees the same screen with the choices
## disabled; every host choice is echoed into the chat view as a line from the
## host (the figure's "Darth Vader: Standard game victory selected."), which is
## how the guest learns the settings. The checkmark starts the game (host only).
##
## In the original's look when its screen is imported (original_mp.gd): the
## original's Multiplayer Options screen (COMMON.DLL 10103), rearranged as
## TeeJ chose (2026-09-26, mockup 2) to hold our two additions. A third row,
## "What speed rule would you like?", is the side row's band again under the
## galaxy-size row. Standard Game, HQ Victory and Load Game sit 62 lower, and
## the chat box is 62 shorter: its message list goes from 4 lines to 2, and
## the green-light strip under it is given up. The game code and Copy sit at
## the right end of the Chat> bar (TeeJ's pick of three).

const OriginalMp := preload("res://src/ui/mp/original_mp.gd")
const Art := preload("res://src/ui/artwork.gd")
const OUI := preload("res://src/ui/original_ui.gd")

## The rearranged screen: each piece is [its first row, the row after its
## last, the row it moves to], across the content between the left rail and
## the frame (x 133-575).
const PlateX := Vector2i(133, 575)
const PlatePieces := [[62, 124, 186], [186, 256, 248], [256, 294, 318], [294, 326, 356], [366, 372, 388], [392, 400, 394]]
## The rows under the new one moved down by this much.
const Down := 62
## The parts (px of the original's 640 x 480, measured on TeeJ's screenshot):
## the questions green Arial 15.5 centred on x 258, capitals at y 82 and 145,
## the speed row's at 82 + 124; the side symbols (36 x 36) at (389, 71) and
## (440, 71), the galaxy sizes at x 389 / 440 / 491, y 133; the speed choices
## in the new row's two empty slots, (389, 195) and (440, 195); the lamps
## (29 x 27) at (142, 205) and (318, 205), their words Arial 13 centred on
## x 231 and 407.5, capitals at 213; Load Game (48 x 43) at (502, 199);
## "Chat>" at x 181, capitals at 266; the rest, the lower rows' parts, all
## `Down` lower.
const QuestionCentre := 258.0
const QuestionTops := [82, 145, 206]
const QuestionPx := 15.5
const Questions := ["Which side do you want to play?", "What size galaxy would you like?", "What speed rule would you like?"]
const SideAt := [Vector2(389, 71), Vector2(440, 71)]
const SizeAt := [Vector2(389, 133), Vector2(440, 133), Vector2(491, 133)]
const SizePictures := ["standard", "large", "huge"]
const SpeedAt := [Vector2(389, 195), Vector2(440, 195)]
const Slot := Vector2(36, 36)
## Each speed choice's words in its slot: the lines, Arial 9, their capitals
## this far down the slot.
const SpeedWords := [[["Slowest", 11], ["wins", 22]], [["Average", 16]]]
const SpeedPx := 9.0
const LampAt := [Vector2(142, 205 + Down), Vector2(318, 205 + Down)]
## The lamp and the bar of words beside it take the click.
const LampHit := [Rect2(137, 200 + Down, 155, 36), Rect2(313, 200 + Down, 157, 36)]
const LampWords := [[231.0, "Standard Game"], [407.5, "HQ Victory"]]
const LampTop := 213 + Down
const LoadAt := Vector2(502, 199 + Down)
const ChatTop := 266 + Down
const ChatX := 181
const EntryX := 222
const EntryW := 182
const CodeX := 410
const LogX := 150
const LogTop := 297 + Down
const LogW := 386
const LogLines := 2

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
var _loading: bool = false
var _load_client: RelayClient = null
var _left: bool = false
## Joined a game that had already started (a rejoin by code, TeeJ room #110):
## the relay's whole log is pulled and the game rebuilt, as Load does.
var _rejoining: bool = false
## The original's look: its screen, and its parts per choice.
var _look: OriginalMp
var _oSides: Array = []
var _oSizes: Array = []
var _oSpeeds: Array = []
var _oLamps: Array = []
var _oLoad: TextureButton


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

	# 5 The checkmark starts the game - host only.
	bar().set_proceed("Start Game")
	bar().set_previous(true, "Previous")
	bar().proceed.connect(_start)
	bar().previous.connect(_previous)
	bar().cancel.connect(cancel_to_cockpit)

	if _host:
		_settings = { "pack": FactionRegistry.LoadedId(), "pack_hash": FactionRegistry.PackHash,
			"side": FactionRegistry.Playable[0].Id, "size": int(Enums.GalaxySize.Large), "hq_only": false, "speed_rule": "slowest" }
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
		for b in _side_buttons + _size_buttons + _victory_buttons + _speed_buttons:
			_lock(b)
		load_btn.disabled = true
		load_btn.tooltip_text = "Only the host loads a saved game."
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
		var shared := _shared_saves()
		var load_btn: Button = get_node("%BtnLoadGame")
		load_btn.disabled = shared.is_empty()
		load_btn.tooltip_text = "Load a game saved with your current opponent." if not shared.is_empty() else "Available once you have saved a game from a previous session with your current opponent."
		_sync_load()
	# Errors.
	if not _lobby.last_error.is_empty():
		show_error(_lobby.last_error.capitalize() + ".")
		_lobby.last_error = ""
	# Started - both go to the game.
	if _lobby.started and not _loading:
		_settings = _lobby.settings.duplicate()
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


## The original's screen with the speed row put in (PlatePieces).
static func _plate() -> Texture2D:
	var tex: Texture2D = Art.Screen("mp_options")
	var src: Image = tex.get_image() if tex != null else null
	if src == null:
		return tex
	var out: Image = src.duplicate()
	for p in PlatePieces:
		out.blit_rect(src, Rect2i(PlateX.x, p[0], PlateX.y - PlateX.x, p[1] - p[0]), Vector2i(PlateX.x, p[2]))
	return ImageTexture.create_from_image(out)


## The red corner brackets of a chosen galaxy size - the pixels that set its
## chosen picture apart from the plain one - to mark the chosen speed rule the
## same way.
static func _brackets() -> Texture2D:
	var on: Texture2D = Art.WindowPicture("mp_size.huge.chosen")
	var off: Texture2D = Art.WindowPicture("mp_size.huge")
	if on == null or off == null or on.get_size() != off.get_size():
		return null
	var a: Image = on.get_image()
	var b: Image = off.get_image()
	var out := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_RGBA8)
	for y in a.get_height():
		for x in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if ca.r > 0.6 and ca.g < 0.35 and absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.25:
				out.set_pixel(x, y, ca)
	return ImageTexture.create_from_image(out)


func _dress() -> void:
	_look = OriginalMp.Dress(self, "mp_options", _plate()) as OriginalMp
	for i in Questions.size():
		_look.Text(Questions[i], QuestionCentre - 150, QuestionTops[i], 300, QuestionPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "Question%d" % i)
	for i in 2:
		var f: Faction = FactionRegistry.Playable[i]
		_oSides.append(_slot("Side%d" % i, SideAt[i], (_side_buttons[i] as Button).tooltip_text, "side", f.Id))
	for i in SizeAt.size():
		_oSizes.append(_slot("Size%d" % i, SizeAt[i], (_size_buttons[i] as Button).tooltip_text, "size", i))
	var marks: Texture2D = _brackets()
	for i in SpeedAt.size():
		var b := _slot("Speed%d" % i, SpeedAt[i], (_speed_buttons[i] as Button).tooltip_text, "speed_rule", str(_speed_buttons[i].get_meta("id")))
		var words: Array = []
		for line in SpeedWords[i]:
			var l: Label = _look.Text(line[0], SpeedAt[i].x, SpeedAt[i].y + line[1], Slot.x, SpeedPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER, "SpeedWords%d_%d" % [i, words.size()])
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			words.append(l)
		var mark := _look.Place(marks, SpeedAt[i].x, SpeedAt[i].y, "SpeedMark%d" % i)
		b.set_meta("words", words)
		b.set_meta("mark", mark)
		_oSpeeds.append(b)
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
	_oLoad = _look.PicButton("mp_load", LoadAt.x, LoadAt.y, "Load")
	_oLoad.pressed.connect(_open_load_list)
	# Chat> and the space to its right; the game code and Copy at the bar's end.
	_look.Text("Chat>", ChatX, ChatTop, 40, 13.0, OriginalMp.Green, HORIZONTAL_ALIGNMENT_LEFT, "ChatLabel")
	var entry: LineEdit = get_node("%ChatEntry")
	entry.placeholder_text = ""
	_look.Field(entry, EntryX, ChatTop, EntryW, 13.0, OriginalMp.Green)
	var code_text := "Code: %s" % (_lobby.code if not _lobby.code.is_empty() else "------")
	var code_w: float = OUI.Face(false).get_string_size(code_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_look.Text(code_text, CodeX, ChatTop, code_w + 2, 12.0, OriginalMp.Green, HORIZONTAL_ALIGNMENT_LEFT, "Code")
	var copy: Label = _look.Text("Copy", CodeX + code_w + 8, ChatTop, 30, 12.0, OriginalMp.Red, HORIZONTAL_ALIGNMENT_LEFT, "Copy")
	copy.mouse_filter = Control.MOUSE_FILTER_STOP
	copy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	copy.tooltip_text = "Copy the game code, to give to your opponent."
	copy.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_copy_code())
	_look.Log(_log, LogX, LogTop, LogW, LogLines, 12.0, 16.0, OriginalMp.Green)


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
	for i in _oSpeeds.size():
		var b: TextureButton = _oSpeeds[i]
		var chosen: bool = str((_speed_buttons[i] as Button).get_meta("id")) == str(_settings.get("speed_rule", "slowest"))
		for l in b.get_meta("words"):
			(l as Label).add_theme_color_override("font_color", OriginalMp.Red if chosen else (OriginalMp.Grey if locked else OriginalMp.Green))
		(b.get_meta("mark") as Control).visible = chosen
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
		"load":
			_say(host_name, "Loaded \"%s\", Day %d." % [str(_settings.get("load_name", "")), int(_settings.get("load_day", 0))])


func _echo_all() -> void:
	for k in ["side", "size", "hq_only", "speed_rule"]:
		_echo(k)
	if not str(_settings.get("load", "")).is_empty():
		_echo("load")


func _echo_diff() -> void:
	for k in ["side", "size", "hq_only", "speed_rule", "load"]:
		if _settings.get(k) != _seen_settings.get(k):
			_echo(k)


func _say(who: String, text: String) -> void:
	_log.append_text("%s: %s\n" % [who, text])


## A guest on the wrong pack is told so here; the lockstep hello refuses the
## start as well, so a host who ignores the warning still cannot desync.
func _check_pack() -> void:
	var why := MpSetup.pack_mismatch(_settings)
	if not why.is_empty():
		show_error(why)
		_say(MpSetup.player_name, why)


# --- start / previous ---

func _refresh_start() -> void:
	if not _host:
		bar().set_proceed_enabled(false, "The host starts the game.")
	elif _lobby.guest_name.is_empty():
		bar().set_proceed_enabled(false, "Waiting for an opponent to join. Game code: %s" % _lobby.code)
	else:
		bar().set_proceed_enabled(true)


func _start() -> void:
	if not _host or _lobby.guest_name.is_empty() or _loading:
		return
	if not _settings.has("seed"):
		# The host picks the seed at Start; it travels in the settings so both
		# clients build the identical galaxy.
		_settings["seed"] = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
		_lobby.set_settings(_settings)
	_lobby.start()
	bar().set_proceed_enabled(false, "Starting...")


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


func _open_load_list() -> void:
	var shared := _shared_saves()
	if shared.is_empty():
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "Load Game"
	dlg.ok_button_text = "Load"
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(460, 200)
	for s in shared:
		var when := Time.get_datetime_string_from_unix_time(int(float(s.get("updated", 0)) / 1000.0), true)
		list.add_item("%s - Day %d - last played %s" % [str(s.get("name", "")), int(s.get("day", 0)), when])
	list.select(0)
	dlg.add_child(list)
	add_child(dlg)
	dlg.confirmed.connect(func() -> void:
		var picked := list.get_selected_items()
		if picked.is_empty():
			return
		var s: Dictionary = shared[picked[0]]
		# "it will use the game size and difficulty settings from your previous
		# game. You will not need to choose them again" (p162).
		var saved: Dictionary = s.get("settings", {})
		_settings["side"] = str(saved.get("side", _settings.get("side")))
		_settings["size"] = int(saved.get("size", _settings.get("size")))
		_settings["hq_only"] = bool(saved.get("hq_only", _settings.get("hq_only")))
		_settings["speed_rule"] = str(saved.get("speed_rule", "slowest"))
		_settings["seed"] = int(saved.get("seed", 0))
		_settings["load"] = str(s.get("code", ""))
		_settings["load_name"] = str(s.get("name", ""))
		_settings["load_day"] = int(s.get("day", 0))
		_lobby.set_settings(_settings)
		for b in _side_buttons + _size_buttons + _victory_buttons + _speed_buttons:
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
