extends MpScreen
## Host Game screen (manual p158, Fig 5.3): "What would you like your player
## name to be?", "What would you like to call your game?", Proceed, Go back,
## Cancel. Proceed creates the room on the relay and opens Multiplayer Options.
## The game name follows the player name while it is still that player's
## default "<name>'s game" (TeeJ, room #197 item 1).

var _creating: bool = false
var _last_player: String = ""


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
	lobby.create(MpSetup.game_name, {}, true)
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
