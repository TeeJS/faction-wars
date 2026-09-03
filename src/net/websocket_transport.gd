class_name WebSocketTransport
extends Transport
## The wire to the relay (docs/m3-plan.md section 4): one WebSocketPeer, text
## frames of JSON lines, reconnect with backoff, and a `since` on reconnect so
## nothing the relay stored is missed. WebSocketPeer ships in every Godot
## build, the Web export included.

var url: String
var _peer: WebSocketPeer = WebSocketPeer.new()
var _connected: bool = false
var _was_connected: bool = false
var _retry_at_ms: int = 0
var _backoff_ms: int = 500
var _queue: Array[String] = []     # lines to send once connected
## Lines received from the relay that the lobby has consumed already.
var received: int = 0
var last_error: String = ""


func _init(relay_url: String) -> void:
	url = relay_url
	_connect()


func _connect() -> void:
	var err := _peer.connect_to_url(url)
	if err != OK:
		last_error = "connect_to_url failed: %d" % err
	_retry_at_ms = Time.get_ticks_msec() + _backoff_ms


func is_connected_now() -> bool:
	return _connected


func send(msg: Dictionary) -> void:
	send_line(JSON.stringify(msg))


func send_line(line: String) -> void:
	if _connected:
		_peer.send_text(line)
	else:
		_queue.append(line)


## Drain the socket. Reconnects when dropped; a reconnect asks the relay for
## everything since the last line seen.
func poll() -> Array:
	var out: Array = []
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				_backoff_ms = 500
				if _was_connected:
					_peer.send_text(JSON.stringify({ "t": "since", "n": received }))
				_was_connected = true
				for line in _queue:
					_peer.send_text(line)
				_queue.clear()
			while _peer.get_available_packet_count() > 0:
				var line: String = _peer.get_packet().get_string_from_utf8()
				var d: Variant = JSON.parse_string(line)
				if d is Dictionary:
					out.append(d)
		WebSocketPeer.STATE_CLOSED:
			_connected = false
			if Time.get_ticks_msec() >= _retry_at_ms:
				_backoff_ms = mini(_backoff_ms * 2, 10000)
				_peer = WebSocketPeer.new()
				_connect()
		_:
			pass
	return out


func close() -> void:
	if _connected:
		_peer.close()
	_connected = false
