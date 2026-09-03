extends SceneTree
## The M4 gate (docs/multiplayer-ui-design.md): two headless clients drive the
## REAL screens through a relay - Host Game / Locate Session + Join Game,
## Multiplayer Options, Start - into Main.tscn running in lockstep, then play N
## days at Fast and write their day hashes. With --load the host instead picks
## the saved game from the Load Game list (M5) and both resume it.
##
##   Godot_console.exe --headless --path . -s tests/mp_flow.gd -- \
##       --role=host|guest --relay=ws://127.0.0.1:8787/ws --box=D:/tmp/box --days=30 --replay-log=h.log [--load]

const HostGameScene := "res://src/ui/mp/HostGame.tscn"
const JoinGameScene := "res://src/ui/mp/JoinGame.tscn"

var _role: String
var _box: String
var _days: int
var _load: bool
var _log: FileAccess


func _init() -> void:
	await process_frame
	_role = _arg("--role=", "host")
	_box = _arg("--box=", "")
	_days = int(_arg("--days=", "30"))
	_load = OS.get_cmdline_user_args().has("--load")
	var log_path := _arg("--replay-log=", "")
	_log = FileAccess.open(log_path, FileAccess.WRITE) if not log_path.is_empty() else null
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	MpSetup.player_name = "Han" if _role == "host" else "Luke"
	MpSetup.game_name = "The End of the Empire"
	if _role == "host":
		await _host()
	else:
		await _guest()
	await _play()


func _fail(what: String) -> void:
	push_error("[mp_flow] %s: %s" % [_role, what])
	print("[mp_flow] %s FAILED: %s" % [_role, what])
	quit(3)


## Wait until cond() is true, or fail after `seconds`.
func _until(cond: Callable, what: String, seconds: float = 60.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > deadline:
			await _fail("timed out waiting for " + what)
			return false
		await process_frame
	return true


func _scene_named(n: String) -> Callable:
	return func() -> bool: return current_scene != null and current_scene.name == n


func _bar() -> MpBottomBar:
	return current_scene.get_node("%BottomBar") as MpBottomBar


func _proceed_enabled() -> bool:
	return current_scene != null and current_scene.has_node("%BottomBar") and not (_bar().get_node("%BtnProceed") as Button).disabled


# --- the host's path: Fig 5.3 -> 5.9 -> Start ---

func _host() -> void:
	change_scene_to_file(HostGameScene)
	if not await _until(_scene_named("HostGame"), "the Host Game screen"): return
	(current_scene.get_node("%PlayerName") as LineEdit).text = MpSetup.player_name
	(current_scene.get_node("%GameName") as LineEdit).text = MpSetup.game_name
	_bar().proceed.emit()
	if not await _until(_scene_named("MultiplayerOptions"), "the Multiplayer Options screen"): return
	print("[mp_flow] host in room %s" % MpSetup.lobby.code)
	var f := FileAccess.open("%s/room.code" % _box, FileAccess.WRITE)
	f.store_string(MpSetup.lobby.code)
	f.close()
	# Start is enabled once the guest is seated.
	if not await _until(_proceed_enabled, "the opponent to join", 120.0): return
	if _load:
		var load_btn: Button = current_scene.get_node("%BtnLoadGame")
		if not await _until(func() -> bool: return not load_btn.disabled, "Load Game to become available", 20.0): return
		load_btn.pressed.emit()
		await process_frame
		var dlg: ConfirmationDialog = null
		for c in current_scene.get_children():
			if c is ConfirmationDialog:
				dlg = c
		if dlg == null:
			await _fail("the Load Game list did not open")
			return
		var list: ItemList = null
		for c in dlg.get_children():
			if c is ItemList:
				list = c
		print("[mp_flow] host loads: %s" % list.get_item_text(0))
		list.select(0)
		dlg.confirmed.emit()
		await process_frame
	_bar().proceed.emit()
	if not await _until(func() -> bool: return current_scene is GameManager, "the game to start", 120.0): return


# --- the guest's path: Fig 5.6 -> 5.8 -> wait for Start ---

func _guest() -> void:
	var code_file := "%s/room.code" % _box
	if not await _until(func() -> bool: return FileAccess.file_exists(code_file), "the host's room code", 60.0): return
	await process_frame
	MpSetup.join_code = FileAccess.get_file_as_string(code_file).strip_edges()
	MpSetup.hosting = false
	change_scene_to_file(JoinGameScene)
	if not await _until(_scene_named("JoinGame"), "the Join Game screen"): return
	(current_scene.get_node("%PlayerName") as LineEdit).text = MpSetup.player_name
	if not await _until(_proceed_enabled, "the game to be listed", 30.0): return
	_bar().proceed.emit()
	if not await _until(_scene_named("MultiplayerOptions"), "the Multiplayer Options screen"): return
	print("[mp_flow] guest in room %s" % MpSetup.lobby.code)
	if not await _until(func() -> bool: return current_scene is GameManager, "the host to start", 180.0): return


# --- both: play N days at Fast, log the hashes ---

func _play() -> void:
	var gm: GameManager = current_scene
	var us: Faction = GameSettings.PlayerFaction
	var start := StrategicTickManager.Today
	print("[mp_flow] %s plays %s from day %d" % [_role, us.Id, start])
	if _log != null:
		_log.store_line("# role=%s side=%s from=%d" % [_role, us.Id, start])
	gm.SetSpeed(4)   # Fast
	var last := -1
	var deadline := Time.get_ticks_msec() + 600000
	var ui: UIManager = gm.get_node("UIManager")
	var menu_opened_at := -1
	var saw_waiting := false
	var saw_opponent_speed := false
	var slowed := false
	var restored := false
	while StrategicTickManager.Today < start + _days:
		var d := StrategicTickManager.Today - start
		# The host chats on day 3, opens the Game Options screen on day 6 for
		# 4 s (the guest must see Waiting for Opponent), and the guest sets
		# Medium on day 10 for 2 days (the host's face must say so).
		if _role == "host" and d == 3 and last != StrategicTickManager.Today:
			CommandBus.issue("chat", { "text": "I have you now." })
		if _role == "host" and d == 6 and menu_opened_at < 0:
			ui.OnMenuButtonClicked()
			print("[mp_flow] host opens the Game Options screen")
			menu_opened_at = Time.get_ticks_msec()
		if menu_opened_at > 0 and Time.get_ticks_msec() - menu_opened_at > 4000:
			menu_opened_at = 0
			for w in ui.get_children():
				if w is DraggableWindow and w.scene_file_path.ends_with("InGameMenuWindow.tscn"):
					print("[mp_flow] host closes the Game Options screen")
					(w as DraggableWindow).CloseWindow()
		if _role == "guest" and d == 10 and not slowed:
			slowed = true
			gm.SetSpeed(3)
		if _role == "guest" and d == 12 and slowed and not restored:
			restored = true
			gm.SetSpeed(4)
		if gm._waitBox != null and gm._waitBox.visible:
			saw_waiting = true
		if gm._speedReadout.text.contains("set by opponent"):
			saw_opponent_speed = true
		if Time.get_ticks_msec() > deadline:
			await _fail("the game stalled on day %d" % StrategicTickManager.Today)
			return
		# A battle we are in waits for OUR answer (the modal alert).
		for r in FleetBattleManager.AwaitingOrders():
			if r.Ours.Faction == us or r.Theirs.Faction == us:
				CommandBus.issue("battle_answer", { "where": r.Where.Name, "ours": r.Ours.Name, "theirs": r.Theirs.Name, "answer": "simulate" })
		if StrategicTickManager.Today != last:
			last = StrategicTickManager.Today
			if _log != null and last > start:
				_log.store_line("%d,%s" % [last, GameSignature.ReplayHash(GameState.ActiveGalaxy)])
		await process_frame
	if _log != null:
		_log.close()
	var chat := false
	for m in EventBus.VisibleMessages():
		if m.Category == Enums.MessageCategory.Chat and m.Title == "Message From The Alliance":
			chat = true
	print("[mp_flow] %s done: day %d, session %s" % [_role, StrategicTickManager.Today, LockstepSession.State.keys()[MpSetup.session.state]])
	if _role == "guest":
		print("[mp_flow] guest checks: waiting box seen=%s, chat from the Alliance received=%s" % [str(saw_waiting), str(chat)])
	else:
		print("[mp_flow] host checks: opponent's slower speed shown=%s" % str(saw_opponent_speed))
	# A closed browser: nothing tidy - the relay keeps the game.
	quit(0)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
