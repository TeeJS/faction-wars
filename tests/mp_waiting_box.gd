extends SceneTree
## Waiting for Opponent in the original's alert box (BACKLOG #56; TeeJ,
## 2026-09-27: "this is not the right UI"). Manual p163: "Your opponent will
## receive a Waiting for Opponent message, until you return to the game"; the
## words are REBDLOG.DLL's (4614 / 4615; 4612 when the opponent has left;
## 4618 "Quit and return to cockpit?"). On a game given a head-to-head session
## over files (MailboxTransport: no relay, no sockets), stand-in plates:
##   - the opponent pauses: the original's box, its two lines, no button, over
##     the whole screen (it takes every click);
##   - after a minute the To Cockpit cross; it asks first, in the same box -
##     the cross there goes back;
##   - the opponent gone: "Your Opponent Has Left The Game", the game code,
##     the cross at once;
##   - the opponent back: the box goes; their opening briefing puts up none.
##
##   .\tools\run-gd.ps1 tests/mp_waiting_box.gd

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-mp-wait-art"
const Box := "user://test-mp-wait-box"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mp_waiting_box] ok   %s" % what)
	else:
		_fails += 1
		print("[mp_waiting_box] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = ArtRoot
	_remove(ArtRoot)
	_remove(Box)
	var dir := "%s/swr-original" % ArtRoot
	for sub in ["windows", "buttons"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for n in 3:
		_png("%s/windows/dialog_plate%d.png" % [dir, n], 412, 176, Color(0.4, 0.4, 0.45))
	for b in ["dialog_ok", "dialog_cancel"]:
		_png("%s/buttons/%s.png" % [dir, b], 57, 28, Color(0.2, 0.2, 0.2))
	FactionRegistry.EnsureLoaded()
	Art.Reset()
	var a: Faction = FactionRegistry.Playable[0]
	var b: Faction = FactionRegistry.Playable[1]
	DirAccess.make_dir_recursive_absolute(Box)
	var host := LockstepSession.new(MailboxTransport.new(Box, "host", "guest"), a, b, true)
	var guest := LockstepSession.new(MailboxTransport.new(Box, "guest", "host"), b, a, false)
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
	var ui: UIManager = main.get_node("UIManager")
	var briefing: Node = ui.Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	MpSetup.session = guest

	# The opponent pauses.
	host.set_speed(0)
	for _i in 4:
		await process_frame
	var wait: Control = ui.get_node_or_null("OriginalWait")
	_check(wait != null and _text(wait, 0) == "Waiting For Opponent To Resume" and _text(wait, 1) == "See the Troubleshooting Guide for more help.",
		"the opponent pauses: the original's box, in its words (REBDLOG 4614 / 4615)")
	_check(wait != null and wait.find_child("dialog_cancel", true, false) == null and wait.find_child("dialog_ok", true, false) == null
		and (main._waitBox == null or not main._waitBox.visible), "... with no button, and no plain box")
	_check(wait != null and wait.size == root.get_visible_rect().size and wait.mouse_filter == Control.MOUSE_FILTER_STOP,
		"... over the whole screen, taking every click (%s)" % (str(wait.size) if wait != null else "none"))

	# A minute on: the To Cockpit cross, which asks first.
	main._waitingSince = Time.get_ticks_msec() - main.LeaveAfterMs - 1
	for _i in 3:
		await process_frame
	wait = ui.get_node_or_null("OriginalWait")
	var cross: TextureButton = wait.find_child("dialog_cancel", true, false) if wait != null else null
	_check(cross != null and cross.tooltip_text == "To Cockpit", "a minute on: the To Cockpit cross")
	if cross != null:
		cross.pressed.emit()
		await process_frame
		var ask: Control = ui.get_node_or_null("OriginalLeave")
		_check(ask != null and _text(ask, 0) == "Quit and return to cockpit?" and ask.find_child("dialog_ok", true, false) != null
			and ask.find_child("dialog_cancel", true, false) != null, "... it asks first: \"Quit and return to cockpit?\", a check and a cross")
		if ask != null:
			(ask.find_child("dialog_cancel", true, false) as TextureButton).pressed.emit()
			await process_frame
			await process_frame
		_check(ui.get_node_or_null("OriginalLeave") == null and ui.get_node_or_null("OriginalWait") != null, "... its cross goes back to waiting")

	# The opponent gone.
	var lobby := RelayClient.new("ws://127.0.0.1:1/ws", "Luke")
	lobby.code = "TEST01"
	MpSetup.lobby = lobby
	guest.opponent_gone = true
	for _i in 3:
		await process_frame
	wait = ui.get_node_or_null("OriginalWait")
	_check(wait != null and _text(wait, 0) == "Your Opponent Has Left The Game" and _text(wait, 1).contains("TEST01")
		and wait.find_child("dialog_cancel", true, false) != null, "the opponent gone: \"Your Opponent Has Left The Game\", the game code, the cross at once")

	# Back: the box goes.
	guest.opponent_gone = false
	MpSetup.lobby = null
	host.set_speed(2)
	for _i in 4:
		await process_frame
	_check(ui.get_node_or_null("OriginalWait") == null or ui.get_node("OriginalWait").is_queued_for_deletion(), "the opponent back: the box goes")

	# Their opening briefing: no box.
	host.set_speed(0, "briefing")
	for _i in 4:
		await process_frame
	_check(ui.get_node_or_null("OriginalWait") == null and (main._waitBox == null or not main._waitBox.visible), "the opponent's opening briefing: no box")
	MpSetup.session = null
	main.queue_free()
	for _i in 3:
		await process_frame
	MpSetup.reset()
	_remove(ArtRoot)
	_remove(Box)
	Art.Reset()
	print("[mp_waiting_box] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _text(alert: Control, i: int) -> String:
	var l: Label = alert.find_child("Text%d" % i, true, false)
	return l.text if l != null else ""


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
