extends SceneTree
## The opening briefing in head-to-head (TeeJ, 2026-09-27): the host chooses
## on the Multiplayer Options' second page whether it plays (tests/mp_screens.gd
## has the screen); here what the choice does:
##   - the settings' "briefing" reaches the game (GameSettings.MpBriefing):
##     plays unless "skip";
##   - while a side's briefing plays its speed goes to the other as a pause
##     with its reason, which stops both clocks under either speed rule and
##     goes. Two sessions over files (MailboxTransport): no relay, no sockets;
##   - the side that finished first waits as the original's (TeeJ, 2026-09-27,
##     testing it): it looks at the board, but an order is dropped as if taken
##     (chat still goes), no box says anything, the day shows 0 greyed out, and
##     the Speed Control and its keys do nothing - until the other's ends.
##
##   .\tools\run-gd.ps1 tests/mp_briefing.gd

const Dir := "user://test-mp-briefing"
const OriginalMp := preload("res://src/ui/mp/original_mp.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mp_briefing] ok   %s" % what)
	else:
		_fails += 1
		print("[mp_briefing] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	var a: Faction = FactionRegistry.Playable[0]
	var b: Faction = FactionRegistry.Playable[1]

	# The choice reaches the game.
	MpSetup.reset()
	_check(GameSettings.MpBriefing, "by default the briefing plays")
	MpSetup.apply_settings({"side": a.Id, "size": 1, "briefing": "skip"}, "host")
	_check(not GameSettings.MpBriefing, "\"skip\": no briefing")
	MpSetup.apply_settings({"side": a.Id, "size": 1, "briefing": "play"}, "guest")
	_check(GameSettings.MpBriefing, "\"play\": the briefing")
	MpSetup.apply_settings({"side": a.Id, "size": 1}, "guest")
	_check(GameSettings.MpBriefing, "a room from before the choice: the briefing")
	MpSetup.reset()

	# A briefing's pause, with its reason.
	_remove(Dir)
	var host := LockstepSession.new(MailboxTransport.new(Dir, "host", "guest"), a, b, true)
	var guest := LockstepSession.new(MailboxTransport.new(Dir, "guest", "host"), b, a, false)
	host.my_speed = 2
	guest.my_speed = 2
	guest.remote_speed = 2
	host.set_speed(0, "briefing")
	guest.pump()
	_check(guest.remote_speed == 0 and guest.remote_why == "briefing", "the host's briefing plays: the guest hears a pause, and why")
	for rule in ["slowest", "average"]:
		GameSettings.SpeedRule = rule
		_check(guest.effective_speed() == 0, "... both clocks stop (%s)" % rule)
	_check(guest.opponent_briefing(), "... the guest waits for the host's briefing")

	# While it waits, an order is dropped as if taken; chat goes.
	CommandBus.Session = guest
	var sent: int = _batched(guest)
	var r: Result = CommandBus.issue("scrap_unit", {"unit": 1})
	_check(r.ok and _batched(guest) == sent, "an order while the host's briefing plays: dropped, with nothing said")
	CommandBus.issue("chat", {"text": "Ready when you are."})
	_check(_batched(guest) == sent + 1, "... chat still goes")

	host.set_speed(3)
	guest.pump()
	_check(guest.remote_speed == 3 and guest.remote_why == "" and not guest.opponent_briefing(), "the host's briefing ends: its speed again, the reason gone")
	CommandBus.issue("scrap_unit", {"unit": 1})
	_check(_batched(guest) == sent + 2, "... and orders go again")
	CommandBus.Reset()
	GameSettings.SpeedRule = "slowest"

	await _Waiting(a, b)
	_remove(Dir)
	print("[mp_briefing] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The side that finished first, on the game screen: a game in progress given
## the guest's session while the host's briefing plays.
func _Waiting(a: Faction, b: Faction) -> void:
	_remove(Dir)
	var host := LockstepSession.new(MailboxTransport.new(Dir, "host", "guest"), a, b, true)
	var guest := LockstepSession.new(MailboxTransport.new(Dir, "guest", "host"), b, a, false)
	host.my_speed = 2
	guest.my_speed = 2
	guest.remote_speed = 2
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = b
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	MpSetup.session = guest
	host.set_speed(0, "briefing")
	for _i in 4:
		await process_frame
	var label: Label = main._dayLabel
	_check(main.WaitingForBriefing() and label.text == "Day: 0" and label.modulate == OriginalMp.Grey,
		"the host's briefing plays: the guest's day shows 0, greyed out (%s)" % label.text)
	_check(main._tickTimer.is_stopped() and (main._waitBox == null or not main._waitBox.visible) and not main._PauseShowing(),
		"... the clock stopped, and no box says anything")
	var speed: int = main._speed
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(main._timeControls as Control).gui_input.emit(click)
	var alt_p := InputEventKey.new()
	alt_p.keycode = KEY_P
	alt_p.alt_pressed = true
	alt_p.pressed = true
	main._unhandled_key_input(alt_p)
	await process_frame
	_check(not (main._speedMenu as PopupMenu).visible and main._speed == speed and not main._PauseShowing(),
		"... a click on the Speed Control and Alt+P do nothing")
	host.set_speed(2)
	for _i in 4:
		await process_frame
	_check(not main.WaitingForBriefing() and label.text == "Day: %d" % StrategicTickManager.Today and label.modulate == Color.WHITE,
		"the host's briefing ends: the day again, as it was (%s)" % label.text)
	MpSetup.session = null
	main.queue_free()
	for _i in 3:
		await process_frame
	MpSetup.reset()


static func _batched(s: LockstepSession) -> int:
	var n := 0
	for p in s._batch:
		n += (s._batch[p] as Array).size()
	return n


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
