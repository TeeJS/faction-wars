extends SceneTree
## The Comms Center is docked (TeeJ, 2026-09-23): it opens on the left edge of
## the map frame - at full frame height with no tab strip of its own, or, with
## the imported art, as the original's Message Index with its own tabs; the Message
## Alert column's buttons are its tabs and the one on show reads as pressed;
## minimised and reopened, it re-docks. Also: the day box shows the day only -
## no unread count and no list of category names (TeeJ, 2026-09-23).
##
##   .\tools\run-gd.ps1 tests/comms_dock.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/comms_dock.gd              (Star Wars)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[comms_dock] ok   %s" % what)
	else:
		_fails += 1
		print("[comms_dock] FAIL %s" % what)


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
	var gm: GameManager = main
	var list: VBoxContainer = ui.get_node("CommsPanel/Margin/CommsList")

	ui.OnMessageIndexClicked("Fleets")
	for _i in 3:
		await process_frame
	var w: DraggableWindow = ui._openWindows.get("Communications")
	_check(w != null and w.visible, "the Comms Center opens")
	_check(w.position == UIManager.CommsRect.position, "it is docked at the map frame's top-left (%s)" % str(w.position))
	var tabs: TabContainer = w._tabContainer
	if w._original:
		# With the imported art it is the original's Message Index (manual p078
		# Fig 3.18): its own frame drawn 2x, and its own ten category tabs.
		_check(w.size == w.OriginalSize(), "it is the original's Message Index, its frame drawn 2x (%s)" % str(w.size))
		_check(w._oTabs.size() == 10 and w._oCaption.text == "Fleet Messages", "with the original's ten tabs, on Fleets")
	else:
		_check(w.size.y >= UIManager.CommsRect.size.y - 1, "it is the frame's full height (%.0f)" % w.size.y)
		_check(not tabs.tabs_visible, "it has no tab strip of its own")
	_check(tabs.get_child(tabs.current_tab).name == "Fleets", "it opened on the category asked for")
	_check((list.get_node("Fleets") as Button).has_meta("active_tab"), "the column's Fleets button reads as pressed")

	# The column switches the category.
	(list.get_node("Loyalty") as Button).pressed.emit()
	for _i in 3:
		await process_frame
	_check(tabs.get_child(tabs.current_tab).name == "Loyalty", "pressing a column button switches the category")
	_check((list.get_node("Loyalty") as Button).has_meta("active_tab") and not (list.get_node("Fleets") as Button).has_meta("active_tab"), "the pressed look follows the category")

	# Minimise, drag (simulated), reopen: docked again, pressed look back.
	w.MinimizeWindow()
	for _i in 2:
		await process_frame
	ui.RefreshCommsHighlights()
	_check(not (list.get_node("Loyalty") as Button).has_meta("active_tab"), "minimised: no column button reads as pressed")
	w.position = Vector2(400, 300)
	ui.OnMessageIndexClicked("Advice")
	for _i in 3:
		await process_frame
	_check(w.visible and w.position == UIManager.CommsRect.position, "reopened from the column it re-docks")
	_check(tabs.get_child(tabs.current_tab).name == "Advice", "and shows the category pressed")

	# The day box: a count, never a list of names.
	EventBus.Tell(GameSettings.PlayerFaction, GameMessage.new("A", "a", Enums.MessageCategory.Defense, StrategicTickManager.Today, null, null))
	EventBus.Tell(GameSettings.PlayerFaction, GameMessage.new("B", "b", Enums.MessageCategory.Conflict, StrategicTickManager.Today, null, null))
	gm.RefreshStatusBar()
	var text: String = gm._dayLabel.text
	# ...and no count either (TeeJ, 2026-09-23: "not needed there").
	_check(not text.contains("Defense") and not text.contains("Conflict") and not text.contains("unread"), "the day box shows the day only ('%s')" % text)

	print("[comms_dock] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
