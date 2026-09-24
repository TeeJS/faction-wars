extends SceneTree
## Clicks reach the Encyclopedia's list through its frame (TeeJ, 2026-09-24:
## "We need to be able to double click entries in the encyclopedia and see
## their details page"): a click on a name, sent through the viewport as a
## real mouse press, selects it; a double-click opens its topic. The frame is
## dragged by, but only where it is drawn. Needs the imported art.
##
##   .\tools\run-gd.ps1 tests/ency_clicks.gd

const OUI := preload("res://src/ui/original_ui.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ency_clicks] ok   %s" % what)
	else:
		_fails += 1
		print("[ency_clicks] FAIL %s" % what)


func _init() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("[ency_clicks] skipped: needs a window (headless picks no control under the mouse)")
		quit(0)
		return
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	ui.OpenEncyclopedia()
	for _i in 3:
		await process_frame
	var w: EncyclopediaWindow = ui._openWindows.get("Encyclopedia")
	if w == null or not w._original:
		print("[ency_clicks] skipped: no imported art")
		quit(0)
		return
	var list: Control = w._index
	var row: int = 2
	var at: Vector2 = list.global_position + Vector2(40, (row * 20 + 10)) * OUI.K
	await _click(at, false)
	_check(list.get_selected_items().size() == 1 and list.get_selected_items()[0] == row, "a click on a name selects it")
	await _click(at, true)
	_check(w._inTopic and w._current == row, "a double-click opens its topic")
	# The frame still drags: a press on its drawn edge is the frame's.
	var frame: Control = w.find_child("Frame", true, false)
	var edge: Vector2 = frame.global_position + Vector2(3, 160) * OUI.K
	_check(frame.get_global_rect().has_point(edge) and frame._has_point(edge - frame.global_position), "the frame takes a press on its edge")
	_check(not frame._has_point(Vector2(100, 200) * OUI.K), "and lets one through its middle")
	w.CloseWindow()
	for _i in 2:
		await process_frame

	# The System Finder's list, through its frame the same way.
	ui.OpenPlanetFinder()
	for _i in 3:
		await process_frame
	var f: PlanetFinder = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is PlanetFinder)
	if f != null and not f._o.is_empty():
		var flist: Control = f._o["list"]
		var fat: Vector2 = flist.global_position + Vector2(40, 1 * 20 + 10) * OUI.K
		await _click(fat, false)
		_check(flist.get_selected_items().size() == 1 and flist.get_selected_items()[0] == 1, "a click on a system in the System Finder selects it")
		var tab: TextureButton = f._o["tabs"][1]
		await _click(tab.global_position + tab.size / 2.0, false)
		_check(f._tab == 1, "a click on a Finder tab turns to it")
	_finish()


func _click(at: Vector2, double: bool) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.double_click = double and pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame


func _finish() -> void:
	print("[ency_clicks] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
