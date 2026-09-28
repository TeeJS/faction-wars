extends SceneTree
## Renders the Multiplayer Options screen in the original's look, page 1 and
## page 2 (the host's, a dead local relay - never the live one), to two PNGs.
## Needs a window (NOT --headless) and the art:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_mp_options.gd -- --out=C:/tmp/p1.png --page2=C:/tmp/p2.png

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://mp_options1.png")
	var out2 := _arg("--page2=", "user://mp_options2.png")
	MpSetup.RelayOverride = "ws://127.0.0.1:1/ws"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	MpSetup.player_name = "TeeJ"
	MpSetup.game_name = "Capture"
	MpSetup.hosting = true
	var lobby := RelayClient.new("ws://127.0.0.1:1/ws", MpSetup.player_name)
	lobby.code = "P6PWDY"
	lobby.side = "host"
	lobby.host_name = "TeeJ"
	lobby.name = MpSetup.game_name
	MpSetup.lobby = lobby
	var s: Control = (load("res://src/ui/mp/MultiplayerOptions.tscn") as PackedScene).instantiate()
	root.add_child(s)
	for _i in 4:
		await process_frame
	if s.get_node_or_null("Original") == null:
		print("[capture_mp_options] the original's look did not build (art imported?)")
		quit(1)
		return
	_shot(out)
	s.call("_on_proceed")
	for _i in 4:
		await process_frame
	_shot(out2)
	MpSetup.reset()
	quit(0)


func _shot(path: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	print("[capture_mp_options] %s %s" % [path, str(img.get_size())])
	img.save_png(path)


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
