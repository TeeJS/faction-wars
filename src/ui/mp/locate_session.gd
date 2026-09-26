extends MpScreen
## Locate Session dialog (manual p159, Fig 5.6), the join side: the game code,
## your player name, OK, Cancel. A typed value is a GAME CODE (the web's
## deviation from an IP address, settled with Doof - docs/multiplayer-ui-design.md
## question A).
##
## Deviation, at TeeJ's instruction (room #197 item 4, #68): the Join Game
## screen (Fig 5.8) is gone - the code already names the game, so OK looks the
## code up on the relay and joins it straight into Multiplayer Options. With
## it went "leave blank to search": the code is required. The player-name box
## Fig 5.8 carried moved here, since a rejoining player must give the name
## they played under.
##
## In the original's look when its screen is imported (original_mp.gd): the
## original's Join Game screen (COMMON.DLL 10101), as TeeJ asked (2026-09-25:
## "similar to the original's ... but with these fields"): the player name in
## its top panel, and "Enter the game code of the session host." with the code
## in place of its game list. Back returns to Multiplayer Configuration, the
## forward arrow is OK, the X returns to the Shuttle Cockpit (Fig 5.2's X).

const OriginalMp := preload("res://src/ui/mp/original_mp.gd")

const CodeLength := 6

## The original's Join Game screen (px of its 640 x 480, measured on TeeJ's
## screenshot): "What would you like your player name to be?" centred on x
## 296, capitals at y 106, and "Select a game to connect to from the following
## list." at 255 - green Arial 15.5; the name typed at x 124, capitals at 148,
## green Arial 13, the caret white. The code sits in the list's panel as the
## name sits in its own, 12 below the panel's top edge (273); the relay's
## answer on the row under it.
const HeadCentre := 296.0
const HeadTops := [106, 255]
const HeadPx := 15.5
const FieldX := 124
const FieldW := 348
const NameTop := 148
const CodeTop := 285
const StatusTop := 305
const FieldPx := 13.0

var _lobby: RelayClient
var _phase: String = ""   # "" | "lookup" | "join"
var _code: String = ""
var _look: OriginalMp


func _ready() -> void:
	MpSetup.load_names()
	var box: LineEdit = get_node("%CodeBox")
	box.text = MpSetup.join_code
	box.text_changed.connect(func(t: String) -> void:
		var up := t.to_upper()
		if up != t:
			box.text = up
			box.caret_column = up.length()
		_refresh())
	box.text_submitted.connect(func(_t: String) -> void: _ok())
	(get_node("%PlayerName") as LineEdit).text = MpSetup.player_name
	(get_node("%BtnOK") as Button).pressed.connect(_ok)
	(get_node("%BtnCancel") as Button).pressed.connect(func() -> void: go(ConfigurationScene))
	(get_node("%BtnClose") as Button).pressed.connect(func() -> void: go(ConfigurationScene))
	if OriginalMp.CanBuild("mp_connect"):
		_dress()
	_refresh()
	box.grab_focus()


func _dress() -> void:
	_look = OriginalMp.Dress(self, "mp_connect") as OriginalMp
	_look.Line(get_node("CenterContainer/Dialog/VBox/Body/Left/PlayerCaption") as Label, HeadCentre - 200, HeadTops[0], 400, HeadPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER)
	_look.Line(get_node("CenterContainer/Dialog/VBox/Body/Left/Instruction") as Label, HeadCentre - 200, HeadTops[1], 400, HeadPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER)
	_look.Field(get_node("%PlayerName") as LineEdit, FieldX, NameTop, FieldW, FieldPx, OriginalMp.Green)
	_look.Field(get_node("%CodeBox") as LineEdit, FieldX, CodeTop, FieldW, FieldPx, OriginalMp.Green)
	_look.Line(get_node("%Status") as Label, FieldX, StatusTop, FieldW, FieldPx, OriginalMp.Grey)
	var bar := _look.Bar()
	bar.set_previous(true, "Go back")
	bar.previous.connect(func() -> void: go(ConfigurationScene))
	bar.proceed.connect(_ok)
	bar.cancel.connect(cancel_to_cockpit)


func _typed_code() -> String:
	return (get_node("%CodeBox") as LineEdit).text.strip_edges().to_upper()


func _refresh() -> void:
	var ok: Button = get_node("%BtnOK")
	ok.disabled = _typed_code().length() != CodeLength or not _phase.is_empty()
	ok.tooltip_text = "Join the game with this code." if not ok.disabled else "Enter the six-character game code the host gave you."
	if _look != null:
		_look.Bar().set_proceed_enabled(not ok.disabled, ok.tooltip_text)


func _say(text: String) -> void:
	(get_node("%Status") as Label).text = text


func _ok() -> void:
	if not _phase.is_empty() or _typed_code().length() != CodeLength:
		return
	_code = _typed_code()
	var player := (get_node("%PlayerName") as LineEdit).text.strip_edges()
	MpSetup.player_name = player if not player.is_empty() else "Player"
	MpSetup.remember_names()
	MpSetup.hosting = false
	MpSetup.join_code = _code
	_lobby = MpSetup.new_lobby()
	_lobby.player = MpSetup.player_name
	_lobby.lookup(_code)
	_phase = "lookup"
	_say("Looking for game %s..." % _code)
	_refresh()


func _stop(text: String) -> void:
	_phase = ""
	_say(text)
	_refresh()


func _process(_delta: float) -> void:
	if _lobby == null or _phase.is_empty():
		return
	_lobby.poll()
	if not _lobby.last_error.is_empty():
		var err := _lobby.last_error
		_lobby.last_error = ""
		_stop(err.capitalize() + ".")
		return
	var t: WebSocketTransport = _lobby.transport
	if not t.last_error.is_empty() and t.received == 0:
		_stop("Could not reach the relay at %s." % t.url)
		MpSetup.lobby = null
		return
	if _phase == "lookup":
		var info: Dictionary = _lobby.looked_up
		if info.is_empty() or str(info.get("code", "")) != _code:
			return
		if not bool(info.get("found", false)):
			_stop("No game has the code %s." % _code)
		elif bool(info.get("full", false)):
			_stop("Game %s is full - a player rejoining must use the same player name." % _code)
		else:
			_phase = "join"
			_say("Joining %s, hosted by %s..." % [str(info.get("name", _code)), str(info.get("host", "?"))])
			_lobby.join(_code)
	elif _phase == "join":
		if _lobby.side != "" and not _lobby.code.is_empty():
			go(OptionsScene)
