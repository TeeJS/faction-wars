extends SceneTree
## Smoke test of the head-to-head screens (docs/multiplayer-ui-design.md,
## manual Figs 5.1-5.9): each scene instantiates headless without a relay, and
## the elements the figures name are present with the manual's wording. The
## relay-driven flow is tests/mp_flow.gd.
##
##   Godot_console.exe --headless --path . -s tests/mp_screens.gd

var _fails: int = 0
var _checks: int = 0


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	await _menu()
	await _configuration()
	await _host_game()
	await _locate()
	await _join()
	await _options(true)
	await _options(false)
	await _compose()
	await _chat_tab()
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
	var b: Button = m.get_node_or_null("%BtnMultiplayer")
	_check(b != null and b.text == "Multiplayer", "Fig 5.1: the Cockpit has the Multiplayer control")
	_check(b != null and b.anchor_top == 1.0 and b.offset_left < 100.0, "Fig 5.1: it sits at the lower left")
	var ver: Label = m.get_node_or_null("BuildVersion")
	_check(ver != null and ver.text == BuildInfo.version() and ver.anchor_left == 1.0, "addition: the build version bottom right of the Cockpit (%s)" % BuildInfo.version())
	await _close(m)


func _configuration() -> void:
	var s := await _open("res://src/ui/mp/MultiplayerConfiguration.tscn")
	_check(_label(s, "ProviderCaption") == "Please select a service provider for the type of connection you want to use from the list below.", "Fig 5.2: provider caption verbatim")
	var providers: ItemList = s.get_node("%Providers")
	_check(providers.item_count == 1 and providers.get_item_text(0) == "Internet Connection" and providers.is_selected(0), "Fig 5.2: one honest provider, selected")
	_check(providers.get_item_custom_fg_color(0).r > 0.9, "Fig 5.2: the selected provider appears in red")
	_check(_label(s, "HowCaption") == "How do you want to play?", "Fig 5.2: 'How do you want to play?'")
	var connect_btn: Button = s.get_node("%BtnConnectToGame")
	var setup_btn: Button = s.get_node("%BtnSetupGame")
	_check(connect_btn.text == "Connect To Game" and setup_btn.text == "Setup Game", "Fig 5.2: Connect To Game / Setup Game")
	var bar: MpBottomBar = s.get_node("%BottomBar")
	var proceed: Button = bar.get_node("%BtnProceed")
	var prev: Button = bar.get_node("%BtnPrevious")
	_check(proceed.disabled and not prev.visible, "Fig 5.2: Proceed waits for a choice; no Previous on the first screen")
	setup_btn.button_pressed = true
	await process_frame
	_check(not proceed.disabled, "Fig 5.2: Setup Game enables Proceed")
	_check(setup_btn.get_theme_color("font_color").r < 0.3, "Fig 5.2: the selected option's text appears dark")
	_check((bar.get_node("%BtnCancel") as Button).visible, "Fig 5.2: Cancel")
	await _close(s)


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
	var s := await _open("res://src/ui/mp/LocateSession.tscn")
	_check(s.get_node("%CodeBox") != null and (s.get_node("%CodeBox") as LineEdit).placeholder_text == "XXXXXX", "Fig 5.6: one box, code placeholder")
	_check(s.get_node("%BtnOK") != null and s.get_node("%BtnCancel") != null and s.get_node("%BtnClose") != null, "Fig 5.6: OK, Cancel, X")
	var box: LineEdit = s.get_node("%CodeBox")
	box.text = "ab12cd"
	box.text_changed.emit(box.text)
	_check(box.text == "AB12CD", "Fig 5.6: the code is upper-cased as typed")
	await _close(s)


func _join() -> void:
	MpSetup.player_name = "Luke"
	var s := await _open("res://src/ui/mp/JoinGame.tscn")
	_check(_label(s, "PlayerCaption") == "What would you like your player name to be?", "Fig 5.8: player name caption")
	_check(_label(s, "ListCaption") == "Select a game to connect to from the following list.", "Fig 5.8: list caption verbatim")
	var bar: MpBottomBar = s.get_node("%BottomBar")
	_check((bar.get_node("%BtnProceed") as Button).disabled, "Fig 5.8: Proceed waits for a selection")
	_check((bar.get_node("%BtnPrevious") as Button).visible, "Fig 5.8: Previous")
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
	else:
		_check(not (sides[1] as Button).disabled and (sides[1] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE and (sides[1] as Button).button_pressed, "Fig 5.9 (guest): sees the host's side pressed, cannot change it")
		_check((sizes[2] as Button).button_pressed and (s.get_node("%BtnHQOnlyVictory") as Button).button_pressed, "Fig 5.9 (guest): sees Huge and HQ Only Victory")
		_check(text.contains("Huge galaxy size selected.") and text.contains("HQ Only victory selected."), "Fig 5.9 (guest): the host's choices are in the view")
		_check(text.contains("Average speed rule selected.") and (rules[1] as Button).button_pressed and (rules[1] as Button).mouse_filter == Control.MOUSE_FILTER_IGNORE, "speed rule (guest): sees Average pressed, cannot change it")
	await _close(s)
	MpSetup.reset()


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
