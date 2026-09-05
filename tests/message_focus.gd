extends SceneTree
## The Comms Center must keep the message a player has manually selected in focus
## when the list repaints (a new message arriving, a state change). Before, every
## refresh reset the detail pane to the NEWEST message, so a selection the player
## was reading kept getting yanked away (reported from play).
##
##   Godot_console.exe --headless --path . -s tests/message_focus.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var alliance: Faction = GameSettings.PlayerFaction

	var m1 := _tell(alliance, "First report", 1)
	var _m2 := _tell(alliance, "Second report", 2)
	var m3 := _tell(alliance, "Third report", 3)

	var ui := UIManager.new()
	ui.name = "UIManager"
	root.add_child(ui)
	var w = load("res://src/ui/MessageWindow.tscn").instantiate()
	root.add_child(w)
	await process_frame
	w.Setup(ui)
	w.OpenToCategory("Missions")
	await process_frame

	# It opens on the newest transmission, as before.
	_check(w._selectedMessage == m3, "opens on the newest message")

	# The player selects an OLDER message.
	w.ShowDetail(m1, null)
	_check(w._selectedMessage == m1, "manual selection focuses the older message")

	# A new message arrives and the list repaints.
	var m4 := _tell(alliance, "Fourth report", 4)
	w.RefreshCurrentTab()
	await process_frame

	# The player's selection is preserved - NOT yanked to the newest (m4).
	_check(w._selectedMessage == m1, "selection is preserved across a repaint (not reset to newest)")
	_check(w._selectedMessage != m4, "a newly arrived message does not steal focus")

	# But if the selection is deleted, the pane falls back to the newest.
	CommandBus.issue("delete_messages", { "messages": [m1.Serial] })
	w.RefreshCurrentTab()
	await process_frame
	_check(w._selectedMessage == m4, "after the selection is gone, it falls back to the newest")

	w.free()
	ui.free()
	_finish()


func _tell(to: Faction, title: String, day: int) -> GameMessage:
	var m := GameMessage.new(title, "body of %s" % title, Enums.MessageCategory.Missions, day, null, null)
	m.Type = Enums.MessageType.MissionReport
	EventBus.Tell(to, m)
	return m


func _finish() -> void:
	print("[message_focus] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
