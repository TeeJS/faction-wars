extends SceneTree
## Esc closes the window in focus (TeeJ, 2026-09-24: "in the original hitting
## ESC will close the focused window"; manual p064 "Cancel/Close Window"):
##   - the window last opened is in focus: Esc closes it and only it;
##   - a click in a window behind focuses it: Esc closes that one;
##   - with the focused one gone, Esc closes the front-most open window;
##   - with nothing open, Esc does nothing;
##   - while targeting, Esc cancels the targeting and closes no window.
##
##   .\tools\run-gd.ps1 tests/esc_closes_window.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[esc_closes_window] ok   %s" % what)
	else:
		_fails += 1
		print("[esc_closes_window] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")

	# Start from nothing open.
	ui.CloseAllWindows()
	for _i in 3:
		await process_frame
	_check(ui.FocusedWindow() == null, "nothing open, nothing in focus")
	await _esc()
	_check(ui.FocusedWindow() == null, "Esc with nothing open does nothing")

	# Two windows: a planet's, then the Galaxy Overview on top.
	var planet: Planet = GameState.ActiveGalaxy[0].Planets[0]
	ui.OnPlanetClicked(planet)
	for _i in 3:
		await process_frame
	var a: Node = _window_titled(ui, planet.Name)
	ui.OpenGalaxyOverview()
	for _i in 3:
		await process_frame
	var b: Node = ui.get_node_or_null("GalaxyOverviewWindow")
	_check(a != null and b != null, "a planet window and the Galaxy Overview are open")
	_check(ui.FocusedWindow() == b, "the window last opened is in focus")
	await _esc()
	_check(not is_instance_valid(b) or b.is_queued_for_deletion(), "Esc closes it")
	_check(is_instance_valid(a) and not a.is_queued_for_deletion(), "... and only it")

	# Open the Overview again, then click in the planet window behind it.
	ui.OpenGalaxyOverview()
	for _i in 3:
		await process_frame
	b = ui.get_node_or_null("GalaxyOverviewWindow")
	var spot: Vector2 = _point_only_in(a as Control, b as Control)
	_check(spot != Vector2.INF, "a point in the planet window clear of the Overview")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT   # a click that orders nothing
	click.pressed = true
	click.position = spot
	root.push_input(click, true)   # in the viewport's pixels, whatever the window's size
	var up := click.duplicate()
	up.pressed = false
	root.push_input(up, true)
	for _i in 2:
		await process_frame
	_check(ui.FocusedWindow() == a, "a click in the window behind puts it in focus")
	await _esc()
	_check(not is_instance_valid(a) or a.is_queued_for_deletion(), "Esc closes the window in focus, though another is in front")
	_check(is_instance_valid(b) and not b.is_queued_for_deletion(), "... and leaves the one in front")
	_check(ui.FocusedWindow() == b, "the front-most open window is next")
	await _esc()
	_check(not is_instance_valid(b) or b.is_queued_for_deletion(), "Esc again closes it")

	# Targeting: Esc cancels the targeting, not the window.
	ui.OpenGalaxyOverview()
	for _i in 3:
		await process_frame
	b = ui.get_node_or_null("GalaxyOverviewWindow")
	ui.StartTargeting(func(_p: Planet) -> void: pass)
	_check(ui.IsTargeting, "targeting is on")
	await _esc()
	_check(not ui.IsTargeting, "Esc cancels the targeting")
	_check(is_instance_valid(b) and not b.is_queued_for_deletion(), "... and closes no window")

	print("[esc_closes_window] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _esc() -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_ESCAPE
		k.physical_keycode = KEY_ESCAPE
		k.pressed = pressed
		root.push_input(k)
	for _i in 3:
		await process_frame


## A point inside `a` and outside `b`, in viewport pixels; INF if there is none.
static func _point_only_in(a: Control, b: Control) -> Vector2:
	var ra := a.get_global_rect()
	var rb := b.get_global_rect()
	for fy in [0.5, 0.1, 0.9]:
		for fx in [0.1, 0.5, 0.9]:
			var p := ra.position + ra.size * Vector2(fx, fy)
			if not rb.has_point(p):
				return a.get_canvas_transform() * p
	return Vector2.INF


static func _window_titled(ui: Node, title: String) -> DraggableWindow:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
