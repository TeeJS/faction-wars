class_name RelayClient
extends RefCounted
## The lobby half of the relay protocol (docs/m3-plan.md section 2): create,
## list, join, settings, start - then hand the LockstepSession the same
## transport once `started` arrives. Game lines (hello/cmd/end/hash/speed) that
## arrive before the handoff are kept for the session.

var transport: WebSocketTransport
var code: String = ""
var name: String = ""            # the game's name
var opponent_left: bool = false  # the relay said the other seat dropped
var side: String = ""            # "host" | "guest"
var player: String = ""
var host_name: String = ""
var guest_name: String = ""
var settings: Dictionary = {}
var started: bool = false
var rooms: Array = []
var saves: Array = []           # the started games this player is in (Load, M5)
var looked_up: Dictionary = {}   # the reply to lookup(): {code, found, name, host, ...}
var lines_on_relay: int = 0
var last_error: String = ""
var lobby_chat: Array = []       # [player, text] pairs, in order
var _held: Array = []            # game lines received before the session exists
## A `since` replay in progress: lines arrive, then `caught_up`.
var catching_up: bool = false
var caught_up: bool = false
var replayed_lines: Array = []


func _init(relay_url: String, player_name: String) -> void:
	transport = WebSocketTransport.new(relay_url)
	player = player_name


# --- the lobby verbs ---

func create(game_name: String, game_settings: Dictionary, open: bool = true) -> void:
	name = game_name
	transport.send({ "t": "create", "name": game_name, "player": player, "settings": game_settings, "open": open })


func list() -> void:
	transport.send({ "t": "list" })


## The started games this player is in, newest first: the Load list once
## intersected with the other player's ("a save with the same two names").
func list_saves() -> void:
	transport.send({ "t": "saves", "player": player })


## A typed game code (Locate Session, manual p159) finds its game whether or
## not it is listed as open.
func lookup(game_code: String) -> void:
	transport.send({ "t": "lookup", "code": game_code.to_upper() })


func join(game_code: String) -> void:
	transport.send({ "t": "join", "code": game_code.to_upper(), "player": player })


func set_settings(game_settings: Dictionary) -> void:
	settings = game_settings
	transport.send({ "t": "settings", "settings": game_settings })


func start() -> void:
	transport.send({ "t": "start" })


func chat(text: String) -> void:
	transport.send({ "t": "lobby_chat", "player": player, "text": text })


## Drain the wire; lobby lines are absorbed, game lines are held for the session.
func poll() -> void:
	for msg in transport.poll():
		transport.received += 1
		match str(msg.get("t", "")):
			"room":
				code = str(msg.get("code", ""))
				side = "host"
				host_name = player
			"rooms":
				rooms = msg.get("rooms", [])
			"saves":
				saves = msg.get("saves", [])
			"room_info":
				looked_up = msg
			"joined":
				code = str(msg.get("code", ""))
				name = str(msg.get("name", name))
				side = str(msg.get("side", "guest"))
				host_name = str(msg.get("host", ""))
				guest_name = str(msg.get("guest", "")) if msg.get("guest") != null else ""
				settings = msg.get("settings", {})
				started = bool(msg.get("started", false))
				lines_on_relay = int(msg.get("lines", 0))
			"guest":
				guest_name = str(msg.get("player", ""))
				opponent_left = false
			"host":
				host_name = str(msg.get("player", ""))
				opponent_left = false
			"settings":
				settings = msg.get("settings", {})
			"started":
				settings = msg.get("settings", settings)
				started = true
			"lobby_chat":
				lobby_chat.append([str(msg.get("player", "")), str(msg.get("text", ""))])
			"left":
				opponent_left = true
			"caught_up":
				catching_up = false
				caught_up = true
			"error":
				last_error = str(msg.get("error", ""))
				push_warning("[Relay] %s" % last_error)
			_:
				if catching_up:
					replayed_lines.append(msg)
				else:
					_held.append(msg)


## Ask the relay for the room's whole log (a rejoin). Lines land in
## replayed_lines; caught_up flips when the relay is done.
func fetch_log(since: int = 0) -> void:
	catching_up = true
	caught_up = false
	replayed_lines = []
	transport.send({ "t": "since", "n": since })


## Game lines that arrived before the session took the transport over.
func take_held() -> Array:
	var h := _held
	_held = []
	return h
