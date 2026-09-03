extends MpScreen
## Join Game screen (manual p160-p161, Fig 5.8): player name, "Select a game to
## connect to from the following list.", Proceed, Previous, Cancel. The list is
## the relay's: every open game when Locate Session was left blank, or the one
## game whose code was typed. Re-polled every 2 s while the screen is open.

const RefreshSeconds := 2.0

var _lobby: RelayClient
var _rooms: Array = []
var _shown: Array = []   # the rooms in the list, after the code filter
var _joining: bool = false
var _since_refresh: float = 0.0
var _unreachable_shown: bool = false
# The on-screen diagnostics (a browser has no console to hand): what the relay
# said last, and when the list last arrived.
var _last_relay: String = ""
var _listed_at: float = -1.0
var _clock: float = 0.0


func _codes_of(rooms: Array) -> Array:
	var out: Array = []
	for r in rooms:
		if r is Dictionary:
			out.append(str(r.get("code", "")))
	return out


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
	_clock += delta
	if _joining:
		if _lobby.side != "" and not _lobby.code.is_empty():
			_last_relay = "joined %s as %s" % [_lobby.code, _lobby.side]
			_status()
			go(OptionsScene)
		elif not _lobby.last_error.is_empty():
			_joining = false
			_last_relay = "relay refused the join: %s" % _lobby.last_error
			bar().set_proceed_enabled(true)
			show_error(_lobby.last_error.capitalize() + ".")
			_lobby.last_error = ""
		_status()
		return
	if not _lobby.last_error.is_empty():
		_last_relay = "relay error: %s" % _lobby.last_error
		_lobby.last_error = ""
	# Rebuild the list only when the SET of rooms changes (by code): the relay's
	# reply every 2 s arrives as new objects, and rebuilding on every reply
	# flickered and could swallow a click on the rebuild frame.
	if _codes_of(_lobby.rooms) != _codes_of(_rooms):
		_rooms = _lobby.rooms.duplicate()
		_fill()
	if _lobby.transport.received > 0 and _listed_at < 0.0:
		_listed_at = _clock
	_since_refresh += delta
	if _since_refresh >= RefreshSeconds:
		_since_refresh = 0.0
		_lobby.list()
		_listed_at = _clock
	if not _lobby.transport.last_error.is_empty() and _lobby.transport.received == 0 and not _unreachable_shown:
		_unreachable_shown = true
		(get_node("%Games") as ItemList).clear()
		(get_node("%Games") as ItemList).add_item("Could not reach the relay at %s." % _lobby.transport.url)
		_refresh_proceed()
	_status()


## The status line under the list: connection, listing, joining, the relay's
## last word. Written every frame; cheap, and the only diagnostic a browser
## player can read without DevTools.
func _status() -> void:
	var t: WebSocketTransport = _lobby.transport
	var conn := "connected" if t.is_connected_now() else ("dropped, reconnecting" if t.received > 0 else "connecting")
	var parts: Array = ["Relay %s (%s)" % [conn, t.url]]
	if not t.last_error.is_empty():
		parts.append("transport: %s" % t.last_error)
	if t.received > 0:
		parts.append("%d game(s) listed, %d message(s) received" % [_rooms.size(), t.received])
	var picked := (get_node("%Games") as ItemList).get_selected_items()
	parts.append("selected: %s" % (str(_shown[picked[0]].get("code", "?")) if picked.size() > 0 and picked[0] < _shown.size() else "none"))
	if _joining:
		parts.append("joining...")
	if not _last_relay.is_empty():
		parts.append(_last_relay)
	(get_node("%Status") as Label).text = " - ".join(parts)


func _fill() -> void:
	var list: ItemList = get_node("%Games")
	var picked := list.get_selected_items()
	var picked_code := str(_shown[picked[0]].get("code", "")) if picked.size() > 0 and picked[0] < _shown.size() else ""
	list.clear()
	var shown: Array = []
	for r in _rooms:
		# A typed code narrows the list to that one game.
		if not MpSetup.join_code.is_empty() and str(r.get("code", "")) != MpSetup.join_code:
			continue
		shown.append(r)
		# Addition, recorded: the host's name after the game name.
		list.add_item("%s (%s)" % [str(r.get("name", "")), str(r.get("host", ""))])
	_shown = shown
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
	var ok := list.get_selected_items().size() > 0 and not _shown.is_empty()
	bar().set_proceed_enabled(ok and not _joining, "" if ok else "Select a game to join.")


func _proceed() -> void:
	if _joining:
		return
	var list: ItemList = get_node("%Games")
	var picked := list.get_selected_items()
	if picked.is_empty() or picked[0] >= _shown.size():
		return
	var player := (get_node("%PlayerName") as LineEdit).text.strip_edges()
	MpSetup.player_name = player if not player.is_empty() else "Player"
	MpSetup.remember_names()
	_lobby.player = MpSetup.player_name
	_lobby.join(str(_shown[picked[0]].get("code", "")))
	_joining = true
	bar().set_proceed_enabled(false, "Joining...")
