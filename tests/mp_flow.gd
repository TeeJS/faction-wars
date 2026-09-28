extends SceneTree
## The M4 gate (docs/multiplayer-ui-design.md): two headless clients drive the
## REAL screens through a relay - Host Game / Locate Session + Join Game,
## Multiplayer Options, Start - into Main.tscn running in lockstep, then play N
## days at Fast and write their day hashes. With --load the host instead picks
## the relay's saved game from the Load Game list (M5) and both resume it.
##
## THE HEAD-TO-HEAD SAVE (issue #301). --save: on day 6, with the Game Options
## screen up, the host saves in slot 3 through the screen; both then check
## their own slot 3 (--save-dir keeps the two computers' saves apart, as they
## share one user:// here), and the host writes the save's day and state hash
## to <box>/save.json. --load-slot: the host picks that slot from the Load
## Game list; both check they resumed at the saved day and state.
##
##   Godot_console.exe --headless --path . -s tests/mp_flow.gd -- \
##       --role=host|guest --relay=ws://127.0.0.1:8787/ws --box=D:/tmp/box --days=30 --replay-log=h.log
##       [--load | --save | --load-slot] [--save-dir=user://mpflow-saves-host]

const Art := preload("res://src/ui/artwork.gd")
const HostGameScene := "res://src/ui/mp/HostGame.tscn"
const LocateSessionScene := "res://src/ui/mp/LocateSession.tscn"

var _role: String
var _box: String
var _days: int
var _load: bool
var _speed_rule: String = ""
var _quit_at: int = 0
var _rejoin_code: bool = false
var _save: bool = false
var _load_slot: bool = false
var _log: FileAccess
const SaveSlot := 2   # slot 3
const SaveName := "The Battle of Hoth"


func _init() -> void:
	await process_frame
	# ONLY EVER A RELAY ON THIS MACHINE. Without --relay the screens use the
	# game's own address, the live one: a sweep of the tests ran this with no
	# arguments and hosted a room there (2026-09-25). tools/mp-flow-local.ps1
	# starts a relay here and passes its address.
	var relay := _arg("--relay=", "")
	if not (relay.begins_with("ws://127.0.0.1:") or relay.begins_with("ws://localhost:")):
		print("[mp_flow] SKIP: needs a local relay (--relay=ws://127.0.0.1:<port>/ws) - run tools/mp-flow-local.ps1")
		quit(0)
		return
	_role = _arg("--role=", "host")
	_box = _arg("--box=", "")
	_days = int(_arg("--days=", "30"))
	_load = OS.get_cmdline_user_args().has("--load")
	_speed_rule = _arg("--speed-rule=", "")
	_quit_at = int(_arg("--quit-at=", "0"))
	_rejoin_code = OS.get_cmdline_user_args().has("--rejoin-code")
	_save = OS.get_cmdline_user_args().has("--save")
	_load_slot = OS.get_cmdline_user_args().has("--load-slot")
	var save_dir := _arg("--save-dir=", "")
	if not save_dir.is_empty():
		SaveManager.Dir = save_dir
	# --compact-every=N: the session compacts its history every N phase ends
	# (LockstepSession.CompactEvery), so a short game compacts before its save.
	LockstepSession.CompactEvery = int(_arg("--compact-every=", str(LockstepSession.CompactEvery)))
	# --no-art: the plain windows, whatever art this machine has imported.
	if OS.get_cmdline_user_args().has("--no-art"):
		Art.IgnoreProjectFolder = true
		Art.UserArtRoot = "user://mpflow-no-art"
	var log_path := _arg("--replay-log=", "")
	_log = FileAccess.open(log_path, FileAccess.WRITE) if not log_path.is_empty() else null
	FactionRegistry.EnsureLoaded()
	# --pack-dir=<folder>: this client starts on that copy of the pack - another
	# version of the host's - and must switch to the host's on joining
	# (strangers plan PR 5; tools/mp-flow-local.ps1 -GuestOtherVersion).
	var pack_dir := _arg("--pack-dir=", "")
	if not pack_dir.is_empty():
		if not FactionRegistry.SwitchTo(pack_dir):
			await _fail("could not load --pack-dir=%s" % pack_dir)
			return
		print("[mp_flow] %s starts on another version of %s (hash %s)" % [_role, FactionRegistry.LoadedId(), FactionRegistry.PackHash.substr(0, 12)])
	MpSetup.reset()
	MpSetup.player_name = "Han" if _role == "host" else "Luke"
	MpSetup.game_name = "The End of the Empire"
	if _role == "host":
		await _host()
	elif _rejoin_code:
		await _guest_rejoin_by_code()
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
	# The guest joins (page 1's arrow is the host's at once, so wait for the name).
	if not await _until(func() -> bool: return not MpSetup.lobby.guest_name.is_empty(), "the opponent to join", 120.0): return
	if _load or _load_slot:
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
		# A slot's save (--load-slot) or the relay's game (--load): the list
		# holds both, the slots first ("Slot 3: ...").
		var pick := -1
		for i in list.item_count:
			if list.get_item_text(i).begins_with("Slot ") == _load_slot:
				pick = i
				break
		if pick < 0:
			await _fail("no %s in the Load Game list" % ("saved slot" if _load_slot else "relay game"))
			return
		print("[mp_flow] host loads: %s" % list.get_item_text(pick))
		list.select(pick)
		dlg.confirmed.emit()
		await process_frame
	# On to page 2 (the opening briefing and the speed rule), then Start once
	# the guest's game checks out.
	_bar().proceed.emit()
	await process_frame
	if _speed_rule == "average" and not _load and not _load_slot:
		for b in (current_scene.get_node("%SpeedRuleHBox") as HBoxContainer).get_children():
			if (b as Button).text == "Average":
				(b as Button).button_pressed = true
				(b as Button).pressed.emit()
		await process_frame
	if not await _until(_proceed_enabled, "Start to be on", 60.0): return
	_bar().proceed.emit()
	if not await _until(func() -> bool: return current_scene is GameManager, "the game to start", 120.0): return


# --- the guest's path: Fig 5.6 -> 5.8 -> wait for Start ---

func _guest() -> void:
	var code_file := "%s/room.code" % _box
	if not await _until(func() -> bool: return FileAccess.file_exists(code_file), "the host's room code", 60.0): return
	await process_frame
	await _locate_and_join(FileAccess.get_file_as_string(code_file).strip_edges(), "the game to be found by code")
	print("[mp_flow] guest in room %s" % MpSetup.lobby.code)
	print("[mp_flow] guest plays on %s (hash %s)" % [FactionRegistry.LoadedDir, FactionRegistry.PackHash.substr(0, 12)])
	if not await _until(func() -> bool: return current_scene is GameManager, "the host to start", 180.0): return


## The dropped guest comes back the way a player would: types the code into
## Locate Session, and Multiplayer Options rebuilds the game from the relay's log.
func _guest_rejoin_by_code() -> void:
	await _locate_and_join(FileAccess.get_file_as_string("%s/room.code" % _box).strip_edges(), "the started game to be found by code")
	print("[mp_flow] guest rejoining room %s by code" % MpSetup.lobby.code)
	if not await _until(func() -> bool: return current_scene is GameManager, "the rebuilt game", 120.0): return


## Locate Session (Fig 5.6) as the player uses it since TeeJ #197: name, code, OK.
func _locate_and_join(code: String, what: String) -> void:
	MpSetup.join_code = ""
	MpSetup.hosting = false
	change_scene_to_file(LocateSessionScene)
	if not await _until(_scene_named("LocateSession"), "the Locate Session screen"): return
	(current_scene.get_node("%PlayerName") as LineEdit).text = MpSetup.player_name
	# An unstarted game is in the open-games list first (strangers plan PR 6):
	# the relay's listing, polled by the screen.
	if what == "the game to be found by code":
		var games: ItemList = current_scene.get_node("%Games")
		var listed := func() -> bool:
			for i in games.item_count:
				if games.get_item_tooltip(i).contains(code):
					return true
			return false
		if not await _until(listed, "the host's game in the open-games list", 20.0): return
		for i in games.item_count:
			if games.get_item_tooltip(i).contains(code):
				print("[mp_flow] guest sees the game in the open-games list: %s" % games.get_item_text(i))
	var box: LineEdit = current_scene.get_node("%CodeBox")
	box.text = code
	box.text_changed.emit(code)
	await process_frame
	(current_scene.get_node("%BtnOK") as Button).pressed.emit()
	if not await _until(_scene_named("MultiplayerOptions"), what, 30.0): return


# --- both: play N days at Fast, log the hashes ---

func _play() -> void:
	var gm: GameManager = current_scene
	var us: Faction = GameSettings.PlayerFaction
	var start := StrategicTickManager.Today
	print("[mp_flow] %s plays %s from day %d" % [_role, us.Id, start])
	if _log != null:
		_log.store_line("# role=%s side=%s from=%d" % [_role, us.Id, start])
	# --load-slot: the game resumed where the host saved it.
	if _load_slot:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/save.json" % _box))
		var now := GameSignature.ReplayHash(GameState.ActiveGalaxy)
		print("[mp_flow] %s LOAD-SLOT resumed on day %d (saved on day %d), state %s" % [_role, start, int(saved.get("day", -1)),
			"MATCHES the save" if now == str(saved.get("hash", "")) else "DIFFERS from the save (%s, saved %s)" % [now.substr(0, 12), str(saved.get("hash", "")).substr(0, 12)]])
	gm.SetSpeed(4)   # Fast
	var save_said := ""
	var last := -1
	var deadline := Time.get_ticks_msec() + 600000
	var ui: UIManager = gm.get_node("UIManager")
	var menu_opened_at := -1
	var saw_waiting := false
	var saw_opponent_speed := false
	var saw_average := false
	var saw_paused_text := false
	var chat_arrival := ""
	var slowed := false
	var restored := false
	# A rejoiner stops where the host stops (day 1 + days); a loaded pair starts
	# together and plays --days more.
	var target: int = (1 + _days) if _rejoin_code else (start + _days)
	while StrategicTickManager.Today < target:
		var d := StrategicTickManager.Today - start
		# The host chats on day 3, opens the Game Options screen on day 6 for
		# 4 s (the guest must see Waiting for Opponent), and the guest sets
		# Medium on day 10 for 2 days (the host's face must say so).
		if _role == "host" and d == 3 and last != StrategicTickManager.Today:
			CommandBus.issue("chat", { "text": "I have you now. day=%d t=%d" % [StrategicTickManager.Today, int(Time.get_unix_time_from_system() * 1000.0)] })
			print("[mp_flow] host chat issued on day %d, phase %d, at %d" % [StrategicTickManager.Today, MpSetup.session.phase, int(Time.get_unix_time_from_system() * 1000.0)])
		if _role == "host" and d == 6 and menu_opened_at < 0:
			ui.OnMenuButtonClicked()
			print("[mp_flow] host opens the Game Options screen")
			menu_opened_at = Time.get_ticks_msec()
			if _save:
				# The day's hash first, as the guest logs it: the save holds
				# this loop a while, and an order goes in during the day.
				if StrategicTickManager.Today != last:
					last = StrategicTickManager.Today
					if _log != null and last > start:
						_log.store_line("%d,%s" % [last, GameSignature.ReplayHash(GameState.ActiveGalaxy)])
				await _save_through_screen(ui)
		# --save: the screen's answer, "Saved on both computers" or not.
		if _save and _role == "host" and save_said.is_empty():
			for dlg in root.find_children("*", "AcceptDialog", true, false):
				if (dlg as AcceptDialog).title == "Save Game":
					save_said = (dlg as AcceptDialog).dialog_text
					print("[mp_flow] host SAVE says: %s" % save_said)
		if menu_opened_at > 0 and Time.get_ticks_msec() - menu_opened_at > 4000 \
				and (not _save or not save_said.is_empty() or Time.get_ticks_msec() - menu_opened_at > 15000):
			menu_opened_at = 0
			for w in ui.get_children():
				if w is DraggableWindow and w.scene_file_path.ends_with("InGameMenuWindow.tscn"):
					print("[mp_flow] host closes the Game Options screen")
					(w as DraggableWindow).CloseWindow()
			# With the original's art imported the Menu opens the original's
			# Game Options screen instead (original_options_screen.gd): its
			# Return to the Command Center.
			var screen: Node = ui.get_node_or_null("OptionsScreen")
			if screen != null and screen.has_method("_return"):
				print("[mp_flow] host closes the Game Options screen")
				screen.call("_return")
		if _role == "guest" and d == 10 and not slowed:
			slowed = true
			gm.SetSpeed(3)
		if _role == "guest" and d == 12 and slowed and not restored:
			restored = true
			gm.SetSpeed(4)
		if _role == "guest" and chat_arrival.is_empty():
			for m in EventBus.VisibleMessages():
				if m.Category == Enums.MessageCategory.Chat and m.Body.begins_with("I have you now. day="):
					var sent := int(m.Body.get_slice("t=", 1))
					var issued_day := int(m.Body.get_slice("day=", 1).get_slice(" ", 0))
					chat_arrival = "arrived on day %d (issued day %d) after %d ms, at phase %d - %s" % [StrategicTickManager.Today, issued_day, int(Time.get_unix_time_from_system() * 1000.0) - sent, MpSetup.session.phase, "SAME DAY" if StrategicTickManager.Today == issued_day else "A DAY LATE"]
					print("[mp_flow] guest: chat %s" % chat_arrival)
		if gm._waitBox != null and gm._waitBox.visible:
			saw_waiting = true
			if gm._waitBox.dialog_text.begins_with("Opponent paused."):
				saw_paused_text = true
		if gm._speedReadout.text.contains("set by opponent"):
			saw_opponent_speed = true
		if gm._speedReadout.text == "Medium (averaged with opponent)":
			saw_average = true
		if _quit_at > 0 and StrategicTickManager.Today == _quit_at:
			print("[mp_flow] %s drops on day %d (simulated close)" % [_role, _quit_at])
			if _log != null:
				_log.close()
			MpSetup.lobby.transport.close()
			quit(0)
			return
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
		print("[mp_flow] guest checks: waiting box seen=%s (paused text=%s), chat from the Alliance received=%s; chat %s" % [str(saw_waiting), str(saw_paused_text), str(chat), chat_arrival])
	else:
		if _speed_rule == "average":
			print("[mp_flow] host checks: rule=%s, 'Medium (averaged with opponent)' shown=%s" % [GameSettings.SpeedRule, str(saw_average)])
		else:
			print("[mp_flow] host checks: opponent's slower speed shown=%s" % str(saw_opponent_speed))
	if _save:
		_report_slot()
	# A closed browser: nothing tidy - the relay keeps the game.
	quit(0)


## --save, the host: on the Game Options screen that is up - the original's
## (art imported) or the plain one through the Game Menu's Game Options - type
## the name into slot 3 and press its Save. Writes <box>/save.json: the day
## and the state hash the save holds.
func _save_through_screen(ui: UIManager) -> void:
	# Not on the day's first phase: phases run on while the screen is up (the
	# day does not), and an order goes in among them - the save point is then
	# phases after the day's tick, holding an order, which a Load must re-apply.
	await _wait_ms(1000)
	CommandBus.issue("chat", { "text": "Saving the game now." })
	await _wait_ms(1000)
	var hash_now := GameSignature.ReplayHash(GameState.ActiveGalaxy)
	var screen: Node = ui.get_node_or_null("OptionsScreen")
	if screen != null:
		((screen.get("_names") as Array)[SaveSlot] as LineEdit).text = SaveName
		screen.call("_save", SaveSlot)
		print("[mp_flow] host saves in slot %d on the original's Game Options screen" % (SaveSlot + 1))
	else:
		for b in root.find_children("*", "Button", true, false):
			if (b as Button).text == "Game Options" and (b as Button).is_visible_in_tree():
				(b as Button).pressed.emit()
				break
		await process_frame
		var gow: Node = root.find_child("GameOptionsWindow", true, false)
		if gow == null:
			await _fail("the Game Options window did not open")
			return
		(((gow.get("_rows") as Array)[SaveSlot] as Dictionary)["name"] as LineEdit).text = SaveName
		gow.call("_on_save", SaveSlot)
		print("[mp_flow] host saves in slot %d on the Game Options window" % (SaveSlot + 1))
	var read: Array = SaveManager.ReadH2H(SaveSlot)
	var h2h: Dictionary = (read[0] as Dictionary).get("h2h", {})
	print("[mp_flow] host save holds day %d, state %s (%s the state when Save was pressed)" % [int(h2h.get("day", -1)), str(h2h.get("state_hash", "")).substr(0, 12),
		"=" if str(h2h.get("state_hash", "")) == hash_now else "DIFFERENT from"])
	var f := FileAccess.open("%s/save.json" % _box, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "day": int(h2h.get("day", -1)), "hash": str(h2h.get("state_hash", "")), "id": str(h2h.get("id", "")) }))
	f.close()


func _wait_ms(ms: int) -> void:
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame


## --save, both: what this computer's slot 3 holds. The runner compares the two
## computers' lines.
func _report_slot() -> void:
	var s: Dictionary = SaveManager.Slots()[SaveSlot]
	var read: Array = SaveManager.ReadH2H(SaveSlot)
	var h2h: Dictionary = (read[0] as Dictionary).get("h2h", {})
	var orders: Array = []
	for m: Dictionary in read[1]:
		if str(m.get("t", "")) in ["cmd", "end"]:
			orders.append(JSON.stringify(m, "", true))
	orders.sort()
	print("[mp_flow] %s SLOT %d: used=%s side=%s name=\"%s\" day=%d id=%s lines=%d orders+ends=%d digest=%s" % [_role, SaveSlot + 1, str(s["used"]), s["side"], s["name"], int(s["day"]),
		str(h2h.get("id", "")), (read[1] as Array).size(), orders.size(), "\n".join(PackedStringArray(orders)).sha256_text().substr(0, 16)])


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
