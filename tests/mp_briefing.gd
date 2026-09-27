extends SceneTree
## The opening briefing in head-to-head (TeeJ, 2026-09-27): the host chooses
## on the Multiplayer Options' second page whether it plays (tests/mp_screens.gd
## has the screen); here what the choice does:
##   - the settings' "briefing" reaches the game (GameSettings.MpBriefing):
##     plays unless "skip";
##   - while a side's briefing plays its speed goes to the other as a pause
##     with its reason, which stops both clocks under either speed rule and
##     tells the other side whose briefing it waits for; at the end the reason
##     goes. Two sessions over files (MailboxTransport): no relay, no sockets.
##
##   .\tools\run-gd.ps1 tests/mp_briefing.gd

const Dir := "user://test-mp-briefing"

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
	host.set_speed(3)
	guest.pump()
	_check(guest.remote_speed == 3 and guest.remote_why == "", "the host's briefing ends: its speed again, the reason gone")
	GameSettings.SpeedRule = "slowest"
	_remove(Dir)
	print("[mp_briefing] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
