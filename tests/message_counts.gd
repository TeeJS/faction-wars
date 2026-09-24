extends SceneTree
## The unread counts clear only when a message is read or deleted - not when
## its list is viewed (TeeJ, 2026-09-23) - in both looks of the Message Index,
## and the original's index carries each category's count on its own tab
## (the top row), as the left column's sockets do.
##
##   .\tools\run-gd.ps1 tests/message_counts.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[message_counts] ok   %s" % what)
	else:
		_fails += 1
		print("[message_counts] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var missions: int = Enums.MessageCategory.Missions

	for look in ["plain", "original"]:
		EventBus.MessageLog.clear()
		Art.IgnoreProjectFolder = look == "plain"
		Art.Reset()
		var a := GameMessage.new("Count check one", "First.", missions, StrategicTickManager.Today, null, null)
		var b := GameMessage.new("Count check two", "Second.", missions, StrategicTickManager.Today, null, null)
		EventBus.Tell(us, a)
		EventBus.Tell(us, b)
		_check(EventBus.UnreadCount(missions) == 2, "%s: two unread mission messages" % look)

		ui.OnMessageIndexClicked("Missions")
		for _i in 3:
			await process_frame
		var w: Control = ui._openWindows.get("Communications")
		_check(w != null, "%s: the Message Index opens on Missions" % look)
		if w == null:
			continue
		var original: bool = w._original
		if look == "original" and not original:
			print("[message_counts] (no art in this checkout - the original index not exercised)")
			w.CloseWindow()
			continue
		_check(EventBus.UnreadCount(missions) == 2, "%s: viewing the list reads nothing (still 2)" % look)
		ui.OnMessageIndexClicked("All")
		for _i in 2:
			await process_frame
		_check(EventBus.UnreadCount(missions) == 2, "%s: nor does changing category" % look)

		if original:
			var tab: Control = Lq.first_or_null(w._oTabs, func(t: Control) -> bool: return t.name == "Tab_Missions")
			var badge: Label = tab.get_node_or_null("Badge") if tab != null else null
			_check(badge != null and badge.visible and badge.text == "2", "the index's Missions tab shows 2 (%s)" % (badge.text if badge != null else "none"))
			w._o_show_summary(a)
		else:
			w.ShowDetail(a, null)
		for _i in 2:
			await process_frame
		_check(EventBus.UnreadCount(missions) == 1 and a.IsRead, "%s: opening one reads it (1 left)" % look)
		EventBus.DeleteMessage(b)
		for _i in 2:
			await process_frame
		_check(EventBus.UnreadCount(missions) == 0, "%s: deleting the other clears the count" % look)
		if original:
			w._o_show_index()
			var tab2: Control = Lq.first_or_null(w._oTabs, func(t: Control) -> bool: return t.name == "Tab_Missions")
			var badge2: Label = tab2.get_node_or_null("Badge") if tab2 != null else null
			_check(badge2 == null or not badge2.visible, "and the tab's count is gone")
		w.CloseWindow()
		for _i in 2:
			await process_frame

	Art.IgnoreProjectFolder = false
	print("[message_counts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
