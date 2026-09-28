extends SceneTree
## SHIFT-click takes every one between the last picked and this one, in any
## list (TeeJ, 2026-09-27: "just like you can CTRL-click and select multiple
## items/personnel/troops/etc, you should be able to SHIFT-click the 1st and
## last in a group"; the manual gives it for the Message Index, p079):
##   - click the second, SHIFT-click the fifth: the second to the fifth;
##   - the range survives a repaint of the list (the anchor is what was picked,
##     not its button);
##   - a click without SHIFT is one, as before.
##
##   .\tools\run-gd.ps1 tests/shift_range.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[shift_range] ok   %s" % what)
	else:
		_fails += 1
		print("[shift_range] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.PlayerFaction = FactionRegistry.ById("alliance")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")

	var w := DraggableWindow.new()
	w._uiManager = ui
	root.add_child(w)
	var things: Array = ["a", "b", "c", "d", "e", "f"]
	var picked: Array = []
	var list := _build(w, things, picked)

	_click(list, 1, false)
	_check(picked == ["b"], "a click: one (%s)" % str(picked))
	_click(list, 4, true)
	_check(_same(picked, ["b", "c", "d", "e"]), "SHIFT-click the fifth: the second to the fifth (%s)" % str(picked))

	# A repaint rebuilds the list; the anchor is what was picked.
	list.queue_free()
	await process_frame
	picked.clear()
	list = _build(w, things, picked)
	_click(list, 3, false)
	list.queue_free()
	await process_frame
	list = _build(w, things, picked)
	_click(list, 0, true)
	_check(_same(picked, ["a", "b", "c", "d"]), "after a repaint, SHIFT runs from the one picked before it (%s)" % str(picked))

	_click(list, 5, false)
	_check(picked.has("f") and picked.size() == 5, "a click without SHIFT adds one, as before (%s)" % str(picked))

	w.free()
	main.queue_free()
	print("[shift_range] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _same(a: Array, b: Array) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return x == y


func _build(w: DraggableWindow, things: Array, picked: Array) -> VBoxContainer:
	var list := VBoxContainer.new()
	w.add_child(list)
	for t in things:
		var b := Button.new()
		b.text = t
		list.add_child(b)
		w.SetupMenuButton(b, t, picked, PopupMenu.new(), func(_id: int, _targets: Array) -> void: pass)
	return list


func _click(list: VBoxContainer, i: int, shift: bool) -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_SHIFT
	k.physical_keycode = KEY_SHIFT
	k.pressed = shift
	Input.parse_input_event(k)
	Input.flush_buffered_events()
	(list.get_child(i) as Button).button_pressed = true
	var up := InputEventKey.new()
	up.keycode = KEY_SHIFT
	up.physical_keycode = KEY_SHIFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
