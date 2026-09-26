extends SceneTree
## Smoke test of the head-to-head screens (docs/multiplayer-ui-design.md,
## manual Figs 5.1-5.9): each scene instantiates headless without a relay, and
## the elements the figures name are present with the manual's wording. The
## relay-driven flow is tests/mp_flow.gd.
##
##   Godot_console.exe --headless --path . -s tests/mp_screens.gd

var _fails: int = 0
var _checks: int = 0


const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-mp-screens-art"


func _init() -> void:
	await process_frame
	# Never the player's own art: the screens take the original's look from it.
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	FactionRegistry.EnsureLoaded()
	await _menu()
	await _configuration()
	await _host_game()
	await _locate()
	await _options(true)
	await _options(false)
	await _compose()
	await _chat_tab()
	# Then each screen in the original's look, on stand-in pictures of the
	# original's.
	_stand_in_art()
	await _configuration_original()
	await _locate_original()
	await _host_original()
	await _options_original(true)
	await _options_original(false)
	_remove(ArtRoot)
	Art.Reset()
	print("[mp_screens] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _open(path: String) -> Node:
	var scene: PackedScene = load(path)
	var node: Node = scene.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	return node


func _close(node: Node) -> void:
	root.remove_child(node)
	node.free()
	await process_frame


func _menu() -> void:
	var m := await _open("res://Menu.tscn")
	var region: Button = m.get_node_or_null("Regions/Region_multiplayer")
	if region != null:
		# The pack's picture: the panel is a region, placed where the pack says.
		var frame: Rect2 = m.call("_picture_frame")
		_check(region.visible and region.size.x > 0, "Fig 5.1: the Cockpit picture has the Multiplayer panel")
		_check(region.position.x < frame.position.x + frame.size.x * 0.3 and region.position.y > frame.position.y + frame.size.y * 0.6, "Fig 5.1: it sits at the lower left")
	else:
		var b: Button = m.get_node_or_null("%BtnMultiplayer")
		_check(b != null and b.text == "Multiplayer", "Fig 5.1: the Cockpit has the Multiplayer control")
		_check(b != null and b.anchor_top == 1.0 and b.offset_left < 100.0, "Fig 5.1: it sits at the lower left")
	# The build version: bottom right on the button form; with the picture, in
	# the black right of it, with "Provide feedback" (TeeJ, 2026-09-25).
	var ver: Label = m.get_node_or_null("BuildVersion")
	var placed: bool = ver != null and (ver.get_global_rect().position.x >= (m.call("_picture_frame") as Rect2).end.x
		if region != null else ver.anchor_left == 1.0)
	_check(ver != null and ver.text == BuildInfo.version() and placed, "addition: the build version at the Cockpit's lower right (%s)" % BuildInfo.version())
	await _close(m)


func _configuration() -> void:
	var s := await _open("res://src/ui/mp/MultiplayerConfiguration.tscn")
	_check(s.get_node_or_null("Original") == null, "without the original's screen imported, the plain screen")
	var list: ItemList = s.get_node("%Providers")
	_check(list.item_count == 2 and list.get_item_text(0) == "Open-games list" and list.get_item_text(1) == "Shared Invite code",
		"TeeJ 2026-09-25: the list is Open-games list, Shared Invite code")
	_check(list.is_item_disabled(0) and not list.is_item_disabled(1) and list.is_selected(1), "TeeJ: Open-games list greyed; Shared Invite code selected")
	_check(_label(s, "HowCaption") == "How do you want to play?", "Fig 5.2: 'How do you want to play?'")
	var connect_btn: Button = s.get_node("%BtnConnectToGame")
	var setup_btn: Button = s.get_node("%BtnSetupGame")
	_check(connect_btn.text == "Connect To Game" and setup_btn.text == "Setup Game", "Fig 5.2: Connect To Game / Setup Game")
	var bar: MpBottomBar = s.get_node("%BottomBar")
	var proceed: Button = bar.get_node("%BtnProceed")
	var prev: Button = bar.get_node("%BtnPrevious")
	_check(proceed.visible and proceed.disabled and not prev.visible, "Fig 5.2: the right arrow waits for a choice; no Previous on the first screen")
	_check((bar.get_node("%BtnCancel") as Button).visible, "Fig 5.2: Cancel")
	setup_btn.pressed.emit()
	_check(setup_btn.button_pressed and not connect_btn.button_pressed and not proceed.disabled, "Fig 5.2: Setup Game stays depressed and the right arrow goes on")
	connect_btn.pressed.emit()
	_check(connect_btn.button_pressed and not setup_btn.button_pressed, "Fig 5.2: one choice at a time")
	await _close(s)


## Stand-ins for exporter 2.4.7's head-to-head pictures, at the original's sizes.
func _stand_in_art() -> void:
	var dir := "%s/%s" % [ArtRoot, FactionRegistry.Pack.Manifest.ArtSets[0]]
	for sub in ["screens", "buttons", "windows"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for sc in ["mp_connection", "mp_connect", "mp_setup", "mp_options"]:
		_png("%s/screens/%s.png" % [dir, sc], 640, 480, Color(0.4, 0.4, 0.42))
	for b in ["mp_back", "mp_next", "mp_start", "mp_cancel"]:
		_png("%s/buttons/%s.png" % [dir, b], 89, 26, Color(0.3, 0.3, 0.3))
		_png("%s/buttons/%s.pressed.png" % [dir, b], 89, 26, Color(0.9, 0.9, 0.2))
		_png("%s/buttons/%s.disabled.png" % [dir, b], 89, 26, Color(0.2, 0.2, 0.2))
	_png("%s/windows/mp_choice.png" % dir, 152, 33, Color(0.3, 0.3, 0.3))
	_png("%s/windows/mp_choice.chosen.png" % dir, 152, 33, Color(0.25, 0.25, 0.25))
	for pic in ["mp_side.alliance", "mp_side.empire", "mp_size.standard", "mp_size.large", "mp_size.huge"]:
		_png("%s/windows/%s.png" % [dir, pic], 36, 36, Color(0.3, 0.3, 0.3))
		_png("%s/windows/%s.chosen.png" % [dir, pic], 36, 36, Color(1, 0.1, 0.1))
		_png("%s/windows/%s.grey.png" % [dir, pic], 36, 36, Color(0.5, 0.5, 0.5))
	for pic in ["mp_lamp.on", "mp_lamp.off", "mp_lamp.grey"]:
		_png("%s/windows/%s.png" % [dir, pic], 29, 27, Color(0.2, 0.8, 0.2))
	_png("%s/buttons/mp_load.png" % dir, 48, 43, Color(0.3, 0.3, 0.3))
	_png("%s/buttons/mp_load.pressed.png" % dir, 48, 43, Color(0.9, 0.9, 0.2))
	_png("%s/buttons/mp_load.disabled.png" % dir, 48, 43, Color(0.2, 0.2, 0.2))
	Art.Reset()


## Opens a screen at twice the original's 640 x 480 and returns its canvas, or
## null (checked) when the original's look did not build.
func _open_original(path: String, plain: String) -> Array:
	var s: Control = await _open(path)
	s.size = Vector2(1280, 960)
	await process_frame
	var look: Control = s.get_node_or_null("Original")
	_check(look != null and not (s.get_node(plain) as Control).visible,
		"%s: with the original's screen imported, its look; the plain parts hidden" % path.get_file())
	return [s, look.get_node("Canvas") if look != null else null]


## The screen's own bottom-bar handler for `sig` would change scene: take it off.
func _unhook(s: Node, sig: Signal) -> void:
	for conn in sig.get_connections():
		if (conn["callable"] as Callable).get_object() == s:
			sig.disconnect(conn["callable"])


func _configuration_original() -> void:
	var opened := await _open_original("res://src/ui/mp/MultiplayerConfiguration.tscn", "CenterContainer")
	var s: Control = opened[0]
	_check(not (s.get_node("%BottomBar") as Control).visible, "the plain bottom bar hidden")
	if opened[1] == null:
		await _close(s)
		return
	var look: Control = s.get_node("Original")
	var c: Control = look.get_node("Canvas")
	var plate: TextureRect = c.get_node("Plate")
	_check(plate.size == Vector2(1280, 960) and c.position == Vector2.ZERO, "the original's screen fills ours, doubled")
	var h0: Label = c.get_node("Heading0")
	var h1: Label = c.get_node("Heading1")
	_check(h0.text == "Please select a service provider for the type of" and h1.text == "connection you want to use from the list below.",
		"Fig 5.2: the heading, verbatim, on the original's two lines")
	var p0: Label = c.get_node("Provider0")
	var p1: Label = c.get_node("Provider1")
	_check(p0.text == "Open-games list" and p1.text == "Shared Invite code" and p1.get_theme_color("font_color") == Color(1, 0, 0)
		and p0.get_theme_color("font_color").r < 0.4 and not p0.tooltip_text.is_empty(), "TeeJ: Open-games list greyed, Shared Invite code chosen in red")
	_check(is_equal_approx(p1.position.x, 145 * 2.0) and is_equal_approx(p1.position.y - p0.position.y, 20 * 2.0), "measured: the list from x 145, a row every 20")
	var box0: TextureButton = c.get_node("Choice0")
	var box1: TextureButton = c.get_node("Choice1")
	_check(box0.position == Vector2(139, 313) * 2.0 and box1.position == Vector2(346, 313) * 2.0 and box0.size == Vector2(152, 33) * 2.0,
		"measured: the choice boxes at (139,313) and (346,313)")
	var back: TextureButton = c.get_node("Back")
	var next: TextureButton = c.get_node("Next")
	var cancel: TextureButton = c.get_node("Cancel")
	_check(back.position == Vector2(141, 442) * 2.0 and next.position == Vector2(290, 442) * 2.0 and cancel.position == Vector2(437, 442) * 2.0,
		"measured: back, forward, cancel at y 442")
	_check(back.disabled and next.disabled and not cancel.disabled, "the original's first screen: back greyed; forward greyed until a choice")
	box1.pressed.emit()
	var w1: Label = c.get_node("ChoiceText1")
	var w0: Label = c.get_node("ChoiceText0")
	_check(box1.texture_normal == Art.WindowPicture("mp_choice.chosen") and w1.get_theme_color("font_color") == Color(1, 0, 0)
		and w0.get_theme_color("font_color") == Color(0, 1, 0), "measured: the chosen box, its words red; the other's green")
	_check(not next.disabled and (s.get_node("%BtnSetupGame") as Button).button_pressed, "a choice made: forward goes on")
	var bar: MpBottomBar = s.get_node("%BottomBar")
	_unhook(s, bar.cancel)
	var cancelled := [false]
	bar.cancel.connect(func() -> void: cancelled[0] = true, CONNECT_ONE_SHOT)
	cancel.pressed.emit()
	_check(cancelled[0], "cancel is the bottom bar's Cancel")
	s.size = Vector2(640, 600)
	await process_frame
	_check(plate.size == Vector2(640, 480) and c.position == Vector2(0, 60) and box1.position == Vector2(346, 313),
		"resized: the picture's aspect kept, centred")
	await _close(s)


## Connect To Game (TeeJ 2026-09-25): the original's Join Game screen with the
## player name, and the game code in place of its game list.
func _locate_original() -> void:
	MpSetup.reset()
	MpSetup.player_name = "Luke"
	var opened := await _open_original("res://src/ui/mp/LocateSession.tscn", "CenterContainer")
	var s: Control = opened[0]
	var c: Control = opened[1]
	if c == null:
		await _close(s)
		return
	var name_box: LineEdit = s.get_node_or_null("%PlayerName")
	var code_box: LineEdit = s.get_node_or_null("%CodeBox")
	_check(name_box != null and code_box != null and name_box.get_parent() == c and code_box.get_parent() == c,
		"the name and code boxes moved onto the original's screen, still found by name")
	_check(name_box != null and name_box.text == "Luke" and name_box.get_theme_color("font_color") == Color(0, 1, 0)
		and name_box.get_theme_color("caret_color") == Color.WHITE, "measured: the name typed in green, the caret white")
	var heads: Array = []
	for n in c.get_children():
		if n is Label and (n as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			heads.append((n as Label).text)
	_check(heads.has("What would you like your player name to be?") and heads.has("Enter the game code of the session host."),
		"TeeJ: 'What would you like your player name to be?' and 'Enter the game code of the session host.'")
	# Where the original has its text (x 124; capitals at 148, and the list's row).
	var cap := func(f: Control, px: float) -> float: return f.position.y / 2.0 + 3.0 + 0.19 * px
	_check(is_equal_approx(name_box.position.x, 124 * 2.0) and is_equal_approx(cap.call(name_box, 13.0), 148.0),
		"measured: the name at x 124, capitals at y 148")
	_check(is_equal_approx(code_box.position.x, 124 * 2.0) and code_box.position.y > name_box.position.y + 200, "the code in the list's panel")
	var back: TextureButton = c.get_node("Back")
	var next: TextureButton = c.get_node("Next")
	_check(not back.disabled and next.disabled, "the original's screen 2: back lit; forward greyed until there is a code")
	code_box.text = "ab12cd"
	code_box.text_changed.emit(code_box.text)
	_check(code_box.text == "AB12CD" and not next.disabled, "six characters light the forward arrow (OK)")
	var bar: MpBottomBar = (s.get_node("Original") as Control).call("Bar")
	_unhook(s, bar.previous)
	_unhook(s, bar.cancel)
	var went := []
	bar.previous.connect(func() -> void: went.append("back"))
	bar.cancel.connect(func() -> void: went.append("cancel"))
	back.pressed.emit()
	(c.get_node("Cancel") as TextureButton).pressed.emit()
	_check(went == ["back", "cancel"], "back and cancel are the bar's")
	await _close(s)
	MpSetup.reset()


## Setup Game (TeeJ 2026-09-25): the original's Host Game screen.
func _host_original() -> void:
	MpSetup.reset()
	MpSetup.player_name = "Han"
	MpSetup.game_name = "The End of the Empire"
	var opened := await _open_original("res://src/ui/mp/HostGame.tscn", "CenterContainer")
	var s: Control = opened[0]
	var c: Control = opened[1]
	if c == null:
		await _close(s)
		return
	var name_box: LineEdit = s.get_node_or_null("%PlayerName")
	var game_box: LineEdit = s.get_node_or_null("%GameName")
	_check(name_box != null and game_box != null and name_box.get_parent() == c and game_box.get_parent() == c,
		"the two boxes moved onto the original's screen, still found by name")
	var heads: Array = []
	for n in c.get_children():
		if n is Label and (n as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			heads.append((n as Label).text)
	_check(heads.has("What would you like your player name to be?") and heads.has("What would you like to call your game?"),
		"Fig 5.3: both questions, verbatim")
	var cap := func(f: Control) -> float: return f.position.y / 2.0 + 3.0 + 0.19 * 13.0
	_check(is_equal_approx(name_box.position.x, 124 * 2.0) and is_equal_approx(cap.call(name_box), 148.0)
		and is_equal_approx(cap.call(game_box), 305.0), "measured: the answers at x 124, capitals at y 148 and 305")
	_check(name_box.text == "Han" and game_box.text == "The End of the Empire" and game_box.get_theme_color("font_color") == Color(0, 1, 0),
		"the names typed in green")
	var back: TextureButton = c.get_node("Back")
	var next: TextureButton = c.get_node("Next")
	_check(not back.disabled and not next.disabled, "the original's screen 3: back and forward lit")
	await _close(s)
	MpSetup.reset()


## Multiplayer Options on the original's screen, rearranged as TeeJ chose
## (2026-09-26, mockup 2): the speed row under the galaxy size, the lower rows
## 62 down, the code and Copy on the Chat> bar.
func _options_original(host: bool) -> void:
	var who := "host" if host else "guest"
	MpSetup.player_name = "Han" if host else "Luke"
	MpSetup.game_name = "The End of the Empire"
	MpSetup.hosting = host
	var lobby := RelayClient.new("ws://127.0.0.1:1/ws", MpSetup.player_name)
	lobby.code = "TEST01"
	lobby.side = who
	lobby.host_name = "Han"
	lobby.name = MpSetup.game_name
	if not host:
		lobby.settings = { "side": "empire", "size": 2, "hq_only": true, "speed_rule": "average" }
	MpSetup.lobby = lobby
	var opened := await _open_original("res://src/ui/mp/MultiplayerOptions.tscn", "CenterContainer")
	var s: Control = opened[0]
	var c: Control = opened[1]
	if c == null:
		await _close(s)
		MpSetup.reset()
		return
	var q: Array = []
	for i in 3:
		q.append((c.get_node("Question%d" % i) as Label).text)
	_check(q == ["Which side do you want to play?", "What size galaxy would you like?", "What speed rule would you like?"],
		"%s: the two questions, and TeeJ's third row" % who)
	_check((c.get_node("Side0") as Control).position == Vector2(389, 71) * 2.0 and (c.get_node("Size2") as Control).position == Vector2(491, 133) * 2.0
		and (c.get_node("Speed1") as Control).position == Vector2(440, 195) * 2.0, "%s: sides, sizes, and the speed row one row under the sizes" % who)
	_check((c.get_node("Lamp0") as Control).position == Vector2(142, 267) * 2.0 and (c.get_node("Load") as Control).position == Vector2(502, 261) * 2.0,
		"%s: Standard Game / HQ Victory and Load Game 62 lower" % who)
	_check((c.get_node("Code") as Label).text == "Code: TEST01" and (c.get_node("Copy") as Label).get_theme_color("font_color") == Color(1, 0, 0),
		"%s: the game code and Copy on the Chat> bar" % who)
	var entry: LineEdit = s.get_node("%ChatEntry")
	var log: RichTextLabel = s.get_node("%ChatLog")
	_check(entry.get_parent() == c and log.get_parent() == c and is_equal_approx(log.size.y, 32 * 2.0), "%s: the chat entry and a two-line log on the screen" % who)
	var start: TextureButton = c.get_node("Next")
	_check(start.texture_normal == Art.ButtonIcon("mp_start") and start.disabled, "%s: the checkmark, waiting" % who)
	var s1: TextureButton = c.get_node("Size1")
	var s2: TextureButton = c.get_node("Size2")
	if host:
		_check(s1.texture_normal == Art.WindowPicture("mp_size.large.chosen") and s2.texture_normal == Art.WindowPicture("mp_size.huge"),
			"host: Large chosen, the others as they are")
		s2.pressed.emit()
		_check(int(s._settings.get("size", -1)) == 2 and s2.texture_normal == Art.WindowPicture("mp_size.huge.chosen")
			and s1.texture_normal == Art.WindowPicture("mp_size.large"), "host: a click on Huge chooses it")
		(c.get_node("Speed1") as TextureButton).pressed.emit()
		_check(str(s._settings.get("speed_rule", "")) == "average" and (c.get_node("SpeedMark1") as Control).visible
			and not (c.get_node("SpeedMark0") as Control).visible, "host: a click on Average chooses it, its brackets shown")
	else:
		_check(s2.texture_normal == Art.WindowPicture("mp_size.huge.chosen") and s1.texture_normal == Art.WindowPicture("mp_size.large.grey"),
			"guest: the host's Huge lit, the others greyed")
		s1.pressed.emit()
		_check(int(s._settings.get("size", -1)) == 2, "guest: a click changes nothing")
		_check((c.get_node("SpeedMark1") as Control).visible and (c.get_node("Lamp1") as TextureRect).texture == Art.WindowPicture("mp_lamp.on"),
			"guest: the host's Average and HQ Victory shown")
	await _close(s)
	MpSetup.reset()


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)


func _host_game() -> void:
	var s := await _open("res://src/ui/mp/HostGame.tscn")
	_check(_label(s, "PlayerCaption") == "What would you like your player name to be?", "Fig 5.3: player name caption")
	_check(_label(s, "GameCaption") == "What would you like to call your game?", "Fig 5.3: game name caption")
	_check(not (s.get_node("%PlayerName") as LineEdit).text.is_empty(), "Fig 5.3: the player name has a default")
	_check(not (s.get_node("%GameName") as LineEdit).text.is_empty(), "Fig 5.3: the game name has a default")
	var bar: MpBottomBar = s.get_node("%BottomBar")
	_check((bar.get_node("%BtnPrevious") as Button).visible and (bar.get_node("%BtnPrevious") as Button).text.ends_with("Go back"), "Fig 5.3: Go back")
	await _close(s)


func _locate() -> void:
	MpSetup.reset()
	var s := await _open("res://src/ui/mp/LocateSession.tscn")
	_check(s.get_node("%CodeBox") != null and (s.get_node("%CodeBox") as LineEdit).placeholder_text == "XXXXXX", "Fig 5.6: one box, code placeholder")
	_check(s.get_node("%BtnOK") != null and s.get_node("%BtnCancel") != null and s.get_node("%BtnClose") != null, "Fig 5.6: OK, Cancel, X")
	_check((s.get_node("CenterContainer/Dialog/VBox/Body/Left/PlayerCaption") as Label).text == "What would you like your player name to be?", "Fig 5.8's player-name box, moved here (TeeJ #197)")
	_check(not (s.get_node("%PlayerName") as LineEdit).text.is_empty(), "the player name has a default")
	var ok: Button = s.get_node("%BtnOK")
	_check(ok.disabled, "TeeJ #197: OK waits for a six-character code")
	var box: LineEdit = s.get_node("%CodeBox")
	box.text = "ab12cd"
	box.text_changed.emit(box.text)
	_check(box.text == "AB12CD", "Fig 5.6: the code is upper-cased as typed")
	_check(not ok.disabled, "TeeJ #197: six characters enable OK")
	_check(s.get_node_or_null("%Status") != null, "the relay's answer has a line to land on")
	await _close(s)
	MpSetup.reset()


func _options(host: bool) -> void:
	var who := "host" if host else "guest"
	MpSetup.player_name = "Han" if host else "Luke"
	MpSetup.game_name = "The End of the Empire"
	MpSetup.hosting = host
	var lobby := RelayClient.new("ws://127.0.0.1:1/ws", MpSetup.player_name)
	lobby.code = "TEST01"
	lobby.side = who
	lobby.host_name = "Han"
	lobby.name = MpSetup.game_name
	if not host:
		lobby.settings = { "side": "empire", "size": 2, "hq_only": true, "speed_rule": "average" }
	MpSetup.lobby = lobby
	var s := await _open("res://src/ui/mp/MultiplayerOptions.tscn")
	_check(_label(s, "SideRow/SideCaption") == "Which side do you want to play?", "Fig 5.9 (%s): side caption" % who)
	_check(_label(s, "SizeRow/SizeCaption") == "What size galaxy would you like?", "Fig 5.9 (%s): size caption" % who)
	var sides := (s.get_node("%SideHBox") as HBoxContainer).get_children()
	var sizes := (s.get_node("%SizeHBox") as HBoxContainer).get_children()
	_check(sides.size() == 2 and (sides[0] as Button).get_theme_color("font_color").r > 0.9 and (sides[1] as Button).get_theme_color("font_color").g > 0.8, "Fig 5.9 (%s): red and green side symbols" % who)
	_check(sizes.size() == 3 and (sizes[0] as Button).text == "Standard" and (sizes[2] as Button).text == "Huge", "Fig 5.9 (%s): standard, large, huge" % who)
	_check((s.get_node("%BtnStandardGame") as Button).text == "Standard Game" and (s.get_node("%BtnHQOnlyVictory") as Button).text == "HQ Only Victory", "Fig 5.9 (%s): Standard Game / HQ Only Victory" % who)
	_check((s.get_node("%BtnStandardGame") as Button).tooltip_text.begins_with("Rebel Win Conditions: Capture Coruscant and capture Emperor Palpatine and Darth Vader."), "p162 (%s): the win conditions verbatim" % who)
	var rules := (s.get_node("%SpeedRuleHBox") as HBoxContainer).get_children()
	_check(rules.size() == 2 and (rules[0] as Button).text == "Slowest wins" and (rules[1] as Button).text == "Average" and (rules[0] as Button).button_pressed == host, "speed rule (%s): Slowest wins / Average, Slowest the default for the host" % who)
	_check((s.get_node("%BtnLoadGame") as Button).text == "Load Game" and (s.get_node("%BtnLoadGame") as Button).disabled, "Fig 5.9 (%s): Load Game, unavailable without a shared save" % who)
	_check(_label(s, "ChatRow/ChatLabel") == "Chat>" and s.get_node("%ChatEntry") != null, "Fig 5.9 (%s): Chat> and the space to its right" % who)
	_check((s.get_node("%CodeValue") as Label).text == "TEST01" and (s.get_node("%BtnCopyCode") as Button).text == "Copy", "addition (%s): the game code with a Copy button" % who)
	var log: RichTextLabel = s.get_node("%ChatLog")
	var text := log.get_parsed_text()
	_check(text.contains("galaxy size selected.") and text.contains("victory selected.") and text.contains("Host has chosen the"), "Fig 5.9 (%s): the settings are echoed into the chat view" % who)
	var bar: MpBottomBar = s.get_node("%BottomBar")
	var proceed: Button = bar.get_node("%BtnProceed")
	_check(proceed.text == "Start Game" and proceed.disabled, "Fig 5.9 (%s): the checkmark starts, and waits" % who)
	if host:
		_check(not (sides[0] as Button).disabled and (sides[0] as Button).button_pressed, "Fig 5.9 (host): the host edits; Alliance preselected")
		_check((sizes[1] as Button).button_pressed and (s.get_node("%BtnStandardGame") as Button).button_pressed, "Fig 5.9 (host): Large and Standard Game preselected")
		_start_gate(s, lobby, proceed)
	else:
		_check(not (sides[1] as Button).disabled and (sides[1] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE and (sides[1] as Button).button_pressed, "Fig 5.9 (guest): sees the host's side pressed, cannot change it")
		_check((sizes[2] as Button).button_pressed and (s.get_node("%BtnHQOnlyVictory") as Button).button_pressed, "Fig 5.9 (guest): sees Huge and HQ Only Victory")
		_check(text.contains("Huge galaxy size selected.") and text.contains("HQ Only victory selected."), "Fig 5.9 (guest): the host's choices are in the view")
		_check(text.contains("Average speed rule selected.") and (rules[1] as Button).button_pressed and (rules[1] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE, "speed rule (guest): sees Average pressed, cannot change it")
	await _close(s)
	MpSetup.reset()


## The hard block before Start (strangers plan, PR 1): with a guest seated the
## host's Start waits for the guest's seat_info, and stays off on another
## build or another pack. Builds match on their commit; "dev" (a local run)
## plays any build; a missing one plays none.
func _start_gate(s: Node, lobby: RelayClient, proceed: Button) -> void:
	lobby.guest_name = "Luke"
	lobby.seat_info = {}
	s._refresh_start()
	_check(proceed.disabled and proceed.tooltip_text == "Opponent's game is out of date.", "host: a seated guest who sent no seat_info - Start stays off")
	var was: String = BuildInfo._cached
	BuildInfo._cached = "2026-09-26 abc1234"
	lobby.seat_info = { "build": "2026-09-26 abc1234", "pack": FactionRegistry.LoadedId(), "pack_hash": FactionRegistry.PackHash }
	s._refresh_start()
	_check(not proceed.disabled, "host: the guest's build and pack match - Start is on")
	lobby.seat_info["build"] = "2026-09-27 abc1234"
	s._refresh_start()
	_check(not proceed.disabled, "host: the same commit built another day is the same build")
	lobby.seat_info["build"] = "2026-09-26 def5678"
	s._refresh_start()
	_check(proceed.disabled and proceed.tooltip_text == "Opponent's game version differs - whoever is older, reload the page.", "host: another build - Start stays off")
	lobby.seat_info["build"] = "2026-09-26 abc1234"
	lobby.seat_info["pack_hash"] = "0".repeat(64)
	s._refresh_start()
	_check(proceed.disabled and proceed.tooltip_text.begins_with("Opponent's pack differs"), "host: the same pack id with other files - Start stays off")
	lobby.seat_info["pack_hash"] = FactionRegistry.PackHash
	lobby.seat_info["pack"] = "ww2"
	s._refresh_start()
	_check(proceed.disabled and proceed.tooltip_text.begins_with("Opponent's pack differs"), "host: another pack - Start stays off")
	BuildInfo._cached = was
	_check(BuildInfo.same_build("dev", "2026-09-26 abc1234") and BuildInfo.same_build("2026-09-26 abc1234", "dev")
		and not BuildInfo.same_build("", "dev") and not BuildInfo.same_build("web-dev", "2026-09-26 abc1234"),
		"builds: a local run (dev) plays any build; a missing build or a web export without its version plays none")
	var diff := LockstepSession.hello_differences({ "build": "a 1", "pack": "p", "pack_hash": "h", "seed": 1, "size": 1, "difficulty": 1 },
		{ "build": "a 2", "pack": "p", "pack_hash": "h2", "seed": 2, "size": 1, "difficulty": 1 })
	_check(diff.contains("game version") and diff.contains("pack content differs") and diff.contains("seed"), "the hello names every difference, not only the last: %s" % diff)
	lobby.guest_name = ""
	lobby.seat_info = {}


func _compose() -> void:
	var w := await _open("res://src/ui/ComposeChatMessageWindow.tscn")
	_check((w.get_node("%TitleBarLabel") as Label).text.strip_edges() == "Compose Chat Message", "Fig 5.11: title")
	_check((w.get_node("%MessageEntry") as LineEdit).placeholder_text == "Type your message here.", "Fig 5.11: 'Type your message here'")
	_check((w.get_node("%BtnSend") as Button).text.ends_with("Send message"), "Fig 5.11: Send message")
	_check((w.get_node("%BtnCancel") as Button).text.ends_with("Cancel"), "Fig 5.11: Cancel")
	_check((w.get_node("%BtnReturn") as Button).text.replace("\n", " ") == "Return to Display Message Index", "Fig 5.11: Return to Display Message Index")
	_check((w.get_node("%CloseButton") as Button).visible, "Fig 5.11: Close button")
	await _close(w)


func _chat_tab() -> void:
	GameSettings.HumanFactions = [FactionRegistry.Playable[0], FactionRegistry.Playable[1]]
	var w := await _open("res://src/ui/MessageWindow.tscn")
	# The window re-parents its tab column in _ready, which drops the unique-name owner.
	var tabs: TabContainer = w.find_child("MessageTabs", true, false)
	var title := ""
	for i in tabs.get_child_count():
		if tabs.get_child(i).name == "Chat":
			title = tabs.get_tab_title(i)
	_check(title == "Chat Messages", "Fig 5.10: the tab is 'Chat Messages'")
	var compose: Button = null
	for row in (w.find_child("DetailView", true, false) as VBoxContainer).get_children():
		for c in row.get_children():
			if c is Button and (c as Button).text == "Compose Chat Message":
				compose = c
	_check(compose != null, "Fig 5.10: Compose chat message, bottom of the right-hand column")
	var last := (w.find_child("DetailView", true, false) as VBoxContainer).get_child((w.find_child("DetailView", true, false) as VBoxContainer).get_child_count() - 1)
	_check(compose != null and compose.get_parent() == last, "Fig 5.10: it is the last thing in the column")
	await _close(w)
	GameSettings.HumanFactions = []
	var w2 := await _open("res://src/ui/MessageWindow.tscn")
	var any := false
	for row in (w2.find_child("DetailView", true, false) as VBoxContainer).get_children():
		for c in row.get_children():
			if c is Button and (c as Button).text == "Compose Chat Message":
				any = true
	_check(not any, "single player: no Compose button")
	await _close(w2)


func _label(s: Node, path: String) -> String:
	var l: Label = s.get_node_or_null("CenterContainer/Console/" + path)
	return l.text if l != null else ""
