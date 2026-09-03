extends MpScreen
## Join Game screen (manual p160-p161, Fig 5.8): player name, "Select a game to
## connect to from the following list.", Proceed, Previous, Cancel. The list is
## the relay's: every open game when Locate Session was left blank, or the one
## game whose code was typed. Re-polled every 2 s while the screen is open.

const RefreshSeconds := 2.0

var _lobby: RelayClient
var _rooms: Array = []
var _joining: bool = false
var _since_refresh: float = 0.0


func _ready() -> void:
	MpSetup.load_names()
	(get_node("%PlayerName") as LineEdit).text = MpSetup.player_name
	bar().set_previous(true, "Previous")
	bar().proceed.connect(_proceed)
	bar().previous.connect(func() -> void:
		MpSetup.reset()
		go(LocateSessionScene))
	bar().cancel.connect(cancel_to_cockpit)
	var list: ItemList = get_node("%Games")
	list.item_selected.connect(func(_i: int) -> void: _refresh_proceed())
	list.item_activated.connect(func(_i: int) -> void: _proceed())
	_lobby = MpSetup.new_lobby()
	_lobby.list()
	_refresh_proceed()


func _process(delta: float) -> void:
	if _lobby == null:
		return
	_lobby.poll()
	if _joining:
		if _lobby.side != "" and not _lobby.code.is_empty():
			go(OptionsScene)
		elif not _lobby.last_error.is_empty():
			_joining = false
			bar().set_proceed_enabled(true)
			show_error(_lobby.last_error.capitalize() + ".")
			_lobby.last_error = ""
		return
	if _lobby.rooms != _rooms:
		_rooms = _lobby.rooms.duplicate()
		_fill()
	_since_refresh += delta
	if _since_refresh >= RefreshSeconds:
		_since_refresh = 0.0
		_lobby.list()
	if not _lobby.transport.last_error.is_empty() and _lobby.transport.received == 0:
		(get_node("%Games") as ItemList).clear()
		(get_node("%Games") as ItemList).add_item("Could not reach the relay at %s." % _lobby.transport.url)
		_refresh_proceed()


func _fill() -> void:
	var list: ItemList = get_node("%Games")
	var picked := list.get_selected_items()
	var picked_code := str(_rooms[picked[0]].get("code", "")) if picked.size() > 0 and picked[0] < _rooms.size() else ""
	list.clear()
	var shown: Array = []
	for r in _rooms:
		# A typed code narrows the list to that one game.
		if not MpSetup.join_code.is_empty() and str(r.get("code", "")) != MpSetup.join_code:
			continue
		shown.append(r)
		# Addition, recorded: the host's name after the game name.
		list.add_item("%s (%s)" % [str(r.get("name", "")), str(r.get("host", ""))])
	_rooms = shown
	if shown.is_empty():
		if MpSetup.join_code.is_empty():
			list.add_item("No games are waiting on the relay.")
		else:
			list.add_item("No open game has the code %s." % MpSetup.join_code)
		list.set_item_disabled(0, true)
	for i in shown.size():
		if str(shown[i].get("code", "")) == picked_code:
			list.select(i)
	if shown.size() == 1 and picked.is_empty():
		list.select(0)
	_refresh_proceed()


func _refresh_proceed() -> void:
	var list: ItemList = get_node("%Games")
	var ok := list.get_selected_items().size() > 0 and not _rooms.is_empty()
	bar().set_proceed_enabled(ok and not _joining, "" if ok else "Select a game to join.")


func _proceed() -> void:
	if _joining:
		return
	var list: ItemList = get_node("%Games")
	var picked := list.get_selected_items()
	if picked.is_empty() or picked[0] >= _rooms.size():
		return
	var player := (get_node("%PlayerName") as LineEdit).text.strip_edges()
	MpSetup.player_name = player if not player.is_empty() else "Player"
	MpSetup.remember_names()
	_lobby.player = MpSetup.player_name
	_lobby.join(str(_rooms[picked[0]].get("code", "")))
	_joining = true
	bar().set_proceed_enabled(false, "Joining...")
