extends SceneTree
## Issue #7: Command Center keyboard shortcuts open/close the right screens.
## Covers the first set wired into UIManager._unhandled_input:
##   F1 Game Options, F2 System Finder, F5 Character Finder, F6/Alt+I message
##   index, Alt+0 Galaxy Overview, Alt+W close all.
## (Alt+P/speed live in game_manager; Alt+G/U + Alt+1-9 are a follow-up PR.)
##
##   Godot_console.exe --headless --path . -s tests/keyboard_shortcuts.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _key(ui: Node, keycode: int, alt: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	ev.alt_pressed = alt
	ui._unhandled_input(ev)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var ui: Node = main.get_node_or_null("UIManager")
	_check(ui != null, "UIManager is present")
	if ui == null:
		_finish(); return

	_key(ui, KEY_F2, false)
	await process_frame
	_check(ui._openWindows.has("PlanetFinder"), "F2 opens the System (Planet) Finder")

	_key(ui, KEY_F5, false)
	await process_frame
	_check(ui._openWindows.has("PersonnelFinder"), "F5 opens the Character (Personnel) Finder")

	_key(ui, KEY_F6, false)
	await process_frame
	_check(ui._openWindows.has("Communications"), "F6 opens the message index")

	_key(ui, KEY_0, true)
	await process_frame
	_check(ui.get_node_or_null("GalaxyOverviewWindow") != null, "Alt+0 opens the Galaxy Overview")

	_key(ui, KEY_F1, false)
	await process_frame
	_check(ui.get_node_or_null("GameOptionsWindow") != null, "F1 opens Game Options")

	# Alt+W closes every window tracked in _openWindows (the data windows).
	var had: int = ui._openWindows.size()
	_check(had >= 3, "several data windows are open before Alt+W")
	_key(ui, KEY_W, true)
	await process_frame
	await process_frame
	_check(ui._openWindows.is_empty(), "Alt+W closes all tracked data windows")

	_finish()


func _finish() -> void:
	print("[keyboard_shortcuts] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
