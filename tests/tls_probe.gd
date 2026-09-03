extends SceneTree
## Can this Godot binary open a wss:// WebSocket? (Gate B needs it headless.)
##   Godot_console.exe --headless --path . -s tests/tls_probe.gd -- --url=wss://host/ws [--unsafe]
func _init() -> void:
	var url := "wss://wars.schmitzplex.com/ws"
	var unsafe := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--url="):
			url = a.substr(6)
		if a == "--unsafe":
			unsafe = true
	var peer := WebSocketPeer.new()
	var err := peer.connect_to_url(url, TLSOptions.client_unsafe() if unsafe else TLSOptions.client())
	print("[tls_probe] connect_to_url(%s, unsafe=%s) -> %d" % [url, str(unsafe), err])
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		peer.poll()
		var st := peer.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			peer.send_text(JSON.stringify({ "t": "list" }))
			OS.delay_msec(300)
			peer.poll()
			var got := ""
			while peer.get_available_packet_count() > 0:
				got = peer.get_packet().get_string_from_utf8()
			print("[tls_probe] OPEN; reply: %s" % got.left(80))
			peer.close()
			quit(0)
			return
		if st == WebSocketPeer.STATE_CLOSED:
			print("[tls_probe] CLOSED: code %d reason '%s'" % [peer.get_close_code(), peer.get_close_reason()])
			quit(2)
			return
		OS.delay_msec(50)
	print("[tls_probe] still connecting after 6 s (state %d)" % peer.get_ready_state())
	quit(3)
