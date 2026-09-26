extends MpScreen
## Host Game screen (manual p158, Fig 5.3): "What would you like your player
## name to be?", "What would you like to call your game?", Proceed, Go back,
## Cancel. Proceed creates the room on the relay and opens Multiplayer Options.
## The game name follows the player name while it is still that player's
## default "<name>'s game" (TeeJ, room #197 item 1).
##
## In the original's look when its screen is imported (original_mp.gd): the
## original's Host Game screen (COMMON.DLL 10102), as TeeJ asked (2026-09-25:
## "setup game should be similar to this").

const OriginalMp := preload("res://src/ui/mp/original_mp.gd")

## The original's Host Game screen (px of its 640 x 480, measured on TeeJ's
## screenshot): the two questions centred on x 296, capitals at y 106 and 266,
## green Arial 15.5; the answers typed at x 124, capitals at 148 and 305, green
## Arial 13, the caret white.
const HeadCentre := 296.0
const HeadTops := [106, 266]
const HeadPx := 15.5
const FieldX := 124
const FieldW := 348
const FieldTops := [148, 305]
const FieldPx := 13.0

var _creating: bool = false
var _last_player: String = ""
var _look: OriginalMp


static func default_game_name(player: String) -> String:
	return "%s's game" % player


func _ready() -> void:
	MpSetup.load_names()
	var player_box: LineEdit = get_node("%PlayerName")
	var game_box: LineEdit = get_node("%GameName")
	player_box.text = MpSetup.player_name
	game_box.text = MpSetup.game_name
	_last_player = MpSetup.player_name
	player_box.text_changed.connect(func(t: String) -> void:
		var game := game_box.text.strip_edges()
		if game.is_empty() or game == default_game_name(_last_player):
			game_box.text = default_game_name(t.strip_edges()) if not t.strip_edges().is_empty() else ""
		_last_player = t.strip_edges())
	bar().set_previous(true, "Go back")
	bar().proceed.connect(_proceed)
	bar().previous.connect(func() -> void: go(ConfigurationScene))
	bar().cancel.connect(cancel_to_cockpit)
	if OriginalMp.CanBuild("mp_setup"):
		_dress()


func _dress() -> void:
	_look = OriginalMp.Dress(self, "mp_setup") as OriginalMp
	for i in 2:
		_look.Line(get_node("CenterContainer/Console/%s" % ["PlayerCaption", "GameCaption"][i]) as Label,
			HeadCentre - 200, HeadTops[i], 400, HeadPx, OriginalMp.Green, HORIZONTAL_ALIGNMENT_CENTER)
		_look.Field(get_node(["%PlayerName", "%GameName"][i]) as LineEdit, FieldX, FieldTops[i], FieldW, FieldPx, OriginalMp.Green)


func _proceed() -> void:
	if _creating:
		return
	var player := (get_node("%PlayerName") as LineEdit).text.strip_edges()
	var game := (get_node("%GameName") as LineEdit).text.strip_edges()
	MpSetup.player_name = player if not player.is_empty() else "Player"
	MpSetup.game_name = game if not game.is_empty() else default_game_name(MpSetup.player_name)
	MpSetup.remember_names()
	MpSetup.hosting = true
	var lobby := MpSetup.new_lobby()
	# Created with its pack and build, so the open-games list and a code's
	# lookup show them from the start (strangers plan PR 5).
	lobby.create(MpSetup.game_name, MpSetup.pack_settings(), true)
	_creating = true
	bar().set_proceed_enabled(false, "Creating the game on the relay...")


func _process(_delta: float) -> void:
	if not _creating or MpSetup.lobby == null:
		return
	var lobby := MpSetup.lobby
	lobby.poll()
	if not lobby.code.is_empty():
		go(OptionsScene)
	elif not lobby.last_error.is_empty():
		_creating = false
		bar().set_proceed_enabled(true)
		show_error("The relay refused the game: %s" % lobby.last_error)
		lobby.last_error = ""
	elif not lobby.transport.last_error.is_empty():
		_creating = false
		bar().set_proceed_enabled(true)
		show_error("Could not reach the relay at %s (%s)." % [lobby.transport.url, lobby.transport.last_error])
		MpSetup.reset()
