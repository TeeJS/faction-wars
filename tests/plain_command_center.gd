extends SceneTree
## THE PLAIN BUILD'S COMMAND CENTER (the plain build parity plan, phase 1;
## TeeJ, 2026-09-28: "why is the artwork-free version missing the sidebars,
## none of that is the original's IP, we built it"). With no art set, both
## sides: the frame is built, drawn by us, with everything in the original's
## places - the left-hand GID menu, the Message Alert slots (lit with unread
## mail, each opening its category), the Game Options monitor, the Control
## Panel's monitors, the droids' names where they stand (the message droid
## opening the Messages), the Speed Control and resource displays on the
## frame's boxes, the shelf taking a minimised window, Feedback at the foot of
## the sector column - and the old plain pieces gone: the blue bar, the grey
## row of finders, the message column.
##
##   .\tools\run-gd.ps1 tests/plain_command_center.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[plain_command_center] ok   %s" % what)
	else:
		_fails += 1
		print("[plain_command_center] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-plain-cc-noart"
	Art.Reset()
	FactionRegistry.EnsureLoaded()
	for side in ["alliance", "empire"]:
		await _side(side)
	print("[plain_command_center] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _side(side: String) -> void:
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(side)
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var frame: CommandFrame = ui.CommandFrameRef
	_check(not CommandFrame.HasArt(side) and CommandFrame.CanBuild(side), "%s: no art, and still the frame" % side)
	_check(frame != null and frame.Plain, "%s: the Command Center is the frame, drawn by us" % side)
	if frame == null:
		root.remove_child(main)
		main.free()
		return
	var lay: Dictionary = CommandFrame.Layout[side]
	var s: float = frame.S
	var o: Vector2 = frame.Origin

	# The left-hand menu, and the old plain pieces gone.
	_check(ui.GidMenu() != null and ui.GidMenu().visible, "%s: the left-hand GID menu" % side)
	var row: Control = ui.get_node_or_null("HBoxContainer")
	var comms: Control = ui.get_node_or_null("CommsPanel")
	var bar: GidBar = ui.ActiveGalaxyMap.Bar() if ui.ActiveGalaxyMap != null else null
	_check((row == null or not row.visible) and (comms == null or not comms.visible) and (bar == null or bar.Panel() == null or not bar.Panel().visible),
		"%s: no grey row of finders, no message column, no blue bar" % side)

	# The Message Alert slots where the original's icons sit, lit with mail.
	var alerts: Array = []
	for cat in CommandFrame.Categories:
		alerts.append(frame.get_node_or_null("Alert" + cat))
	var placed := true
	for n in alerts.size():
		var b: Control = alerts[n]
		placed = placed and b != null and b.position.is_equal_approx(o + ((lay["slot"] as Vector2) + Vector2(0, n * CommandFrame.SlotPitch)) * s)
	_check(placed, "%s: the nine Message Alert slots in the original's places" % side)
	var loyalty: Control = alerts[0]
	EventBus.BroadcastMessage(GameMessage.new("A test", "Loyalty news", Enums.MessageCategory.Loyalty))
	frame.RefreshAlerts()
	_check(loyalty != null and bool(loyalty.get("Lit")) and loyalty.tooltip_text.contains("unread"), "%s: a slot lights with unread mail (%s)" % [side, loyalty.tooltip_text if loyalty != null else "-"])
	(loyalty as BaseButton).pressed.emit()
	await process_frame
	var mw: Control = ui._openWindows.get("Communications")
	# Phase 2: the Message Index in the original's look (our stand-ins), at its
	# own size, docked at the map window's corner, as with the art.
	_check(mw != null and mw.position.is_equal_approx(ui.MapFrame.position) and (mw as MessageWindow)._original
		and mw.size.is_equal_approx((mw as MessageWindow).OriginalSize()),
		"%s: it opens the Message Index, in the original's look, at the map window's corner" % side)
	if mw != null:
		(mw as DraggableWindow).CloseWindow()
	await process_frame

	# The Game Options monitor and the Control Panel's monitors.
	var mon: Control = frame.get_node_or_null("GameOptions")
	_check(mon != null and mon.position.is_equal_approx(o + (lay["monitor"] as Rect2).position * s), "%s: the Game Options monitor" % side)
	var consoles: Dictionary = frame.Consoles()
	var at := true
	for key in lay["consoles"]:
		at = at and consoles.has(key) and (consoles[key] as Control).position.is_equal_approx(o + (lay["consoles"][key] as Rect2).position * s)
	_check(consoles.size() == 6 and at, "%s: the six Control Panel monitors in their places (%s)" % [side, str(consoles.keys())])
	(consoles["system_finder"] as BaseButton).pressed.emit()
	await process_frame
	_check(ui._openWindows.has("PlanetFinder"), "%s: the System Finder monitor opens it" % side)

	# The droids' names where they stand; the message droid opens the Messages.
	var standins: Array = frame.StandIns()
	_check(standins.size() == 2 and (standins[0] as Control).position.is_equal_approx(o + (lay["agent"] as Rect2).position * s)
		and (standins[1] as Control).position.is_equal_approx(o + (lay["messenger"] as Rect2).position * s),
		"%s: the agent's and the message droid's names where they stand" % side)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	(standins[1] as Control).gui_input.emit(click)
	await process_frame
	_check(ui._openWindows.has("Communications"), "%s: a click on the message droid opens the Messages" % side)
	ui.CloseAllWindows()
	await process_frame

	# The readouts on the frame's boxes.
	var speed: Control = main.find_child("PlainSpeed", true, false)
	var res: Control = main.find_child("PlainResources", true, false)
	var hud: Dictionary = preload("res://src/ui/game_manager.gd").HudFrame[side]
	_check(speed != null and res != null, "%s: the Speed Control and the resource displays, drawn by us" % side)
	if speed != null and res != null:
		_check(speed.get_parent().position.is_equal_approx((o + (hud["speed"] as Vector2) * s).floor()) and res.position.is_equal_approx((o + (hud["resources"] as Vector2) * s).floor()),
			"%s: on the frame's boxes" % side)

	# A system window minimised goes to the shelf.
	var planet: Planet = GameState.ActiveGalaxy[0].Planets[0]
	ui.OnDefenseClicked(planet)
	await process_frame
	var dw: DraggableWindow = ui._openWindows.get(planet.Name + " Defenses")
	dw.MinimizeWindow()
	await process_frame
	var shelf: Control = ui.get_node_or_null("ReferenceBar")
	_check(shelf != null and shelf.get_child_count() == 1 and shelf.position.is_equal_approx(frame.Shelf().position), "%s: a minimised window goes to the shelf" % side)

	# Feedback at the foot of the sector column.
	var fb: Control = ui.get_node_or_null("FeedbackPanel")
	if fb != null:
		var screen: Vector2 = root.get_visible_rect().size
		_check(fb.get_global_rect().end.x > screen.x - 160.0 and fb.get_global_rect().end.y > screen.y - 60.0, "%s: Feedback at the foot of the sector column" % side)
	root.remove_child(main)
	main.free()
	await process_frame
