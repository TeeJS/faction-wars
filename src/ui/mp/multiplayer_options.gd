extends MpScreen
## Multiplayer Options screen (manual p161-p162, Fig 5.9). "This screen allows
## the host to select the game parameters and load a previously saved game. This
## screen also lets both players chat with each other before the game is
## started." The host edits; the guest sees the same screen with the choices
## disabled; every host choice is echoed into the chat view as a line from the
## host (the figure's "Darth Vader: Standard game victory selected."), which is
## how the guest learns the settings. The checkmark starts the game (host only).

const SizeNames: Array[String] = ["Standard", "Large", "Huge"]
const StandardGameTip := "Rebel Win Conditions: Capture Coruscant and capture Emperor Palpatine and Darth Vader.\nImperial Win Conditions: Destroy the Rebel headquarters and capture President Mon Mothma and Luke Skywalker."
const HQOnlyTip := "Rebel Win Conditions: Capture Coruscant.\nImperial Win Conditions: Destroy the Rebel headquarters."

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
	std.tooltip_text = StandardGameTip
	hq.tooltip_text = HQOnlyTip
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

	# 5 The checkmark starts the game - host only.
	bar().set_proceed("Start Game")
	bar().set_previous(true, "Previous")
	bar().proceed.connect(_start)
	bar().previous.connect(_previous)
	bar().cancel.connect(cancel_to_cockpit)

	if _host:
		_settings = { "side": FactionRegistry.Playable[0].Id, "size": int(Enums.GalaxySize.Large), "hq_only": false, "speed_rule": "slowest" }
		_lobby.set_settings(_settings)
		_reflect()
		_say(MpSetup.player_name, "Game \"%s\" created. Code %s." % [MpSetup.game_name, _lobby.code])
		_echo_all()
		_lobby.list_saves()
	else:
		_settings = _lobby.settings.duplicate()
		_seen_settings = _settings.duplicate()
		_reflect()
		_say(MpSetup.player_name, "Joined \"%s\" hosted by %s." % [_lobby.name, _lobby.host_name])
		_echo_all()
		for b in _side_buttons + _size_buttons + _victory_buttons + _speed_buttons:
			b.disabled = true
		load_btn.tooltip_text = "Only the host loads a saved game."
	_refresh_start()
	entry.grab_focus()


func _process(_delta: float) -> void:
	if _lobby == null:
		return
	_lobby.poll()
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
	# Saves shared with the current opponent (host): depends on the list AND
	# on who the opponent is, so it is recomputed whenever either changes.
	if _host and (_lobby.saves != _saves or _lobby.guest_name != _load_for):
		_saves = _lobby.saves.duplicate()
		_load_for = _lobby.guest_name
		var shared := _shared_saves()
		var load_btn: Button = get_node("%BtnLoadGame")
		load_btn.disabled = shared.is_empty()
		load_btn.tooltip_text = "Load a game saved with your current opponent." if not shared.is_empty() else "Available once you have saved a game from a previous session with your current opponent."
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
	# The seat is given up: back to Host Game or Join Game with a fresh lobby.
	MpSetup.reset()
	go(HostGameScene if _host else JoinGameScene)


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
		_reflect()
		for b in _side_buttons + _size_buttons + _victory_buttons + _speed_buttons:
			b.disabled = true
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
