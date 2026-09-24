extends SceneTree
## Fleets drag between systems on the sector map (TeeJ, 2026-09-24: "I should
## be able to drag and drop fleets between planets, as in the original";
## manual p046-p052: "anything movable - character, fleet, troop, SpecForce -
## can be dragged to its destination instead of using Move"):
##   - our fleet icon picks up our fleets in orbit there (a "fleet_move" drag);
##   - dropped on another system, they set off for it;
##   - a drop on that system's corner icon counts as a drop on the system;
##   - the opponent's fleet icon cannot be dragged.
##
##   .\tools\run-gd.ps1 tests/drag_fleet_icon.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[drag_fleet_icon] ok   %s" % what)
	else:
		_fails += 1
		print("[drag_fleet_icon] FAIL %s" % what)


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
	var us: Faction = GameSettings.PlayerFaction

	# A system with a fleet of ours in orbit, in a sector with another system.
	var home: Planet = null
	var sector: Sector = null
	for s in GameState.ActiveGalaxy:
		for p in s.Planets:
			if home == null and s.Planets.size() > 1 and Lq.any(p.OrbitingFleets, func(f: Fleet) -> bool:
					return f.Faction == us and f.Status != Enums.Status.Enroute and not f.Ships.is_empty()):
				home = p
				sector = s
	_check(home != null, "a fleet of ours in orbit somewhere")
	if home == null:
		_finish()
		return
	var ours: Array = Lq.where(home.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == us and f.Status != Enums.Status.Enroute)
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	var win: Node = _window_titled(ui, sector.Name)
	_check(win != null, "the sector window of %s opens" % sector.Name)
	if win == null:
		_finish()
		return

	var icon: Button = _corner(win, home, "fleet")
	_check(icon != null, "our fleet icon at %s" % home.Name)
	var target: Planet = null
	for p in sector.Planets:
		if p != home:
			target = p
			break
	var drop: Control = _planet_button(win, target)
	_check(drop != null, "the system to drop on: %s" % target.Name)
	if icon == null or drop == null:
		_finish()
		return

	# The mouse: press on the icon's drawn pixels, move off, let go on the system.
	var from: Vector2 = _drawn_point(icon)
	_check(from != Vector2.INF, "a point on the icon's drawn pixels")
	var to: Vector2 = drop.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	root.push_input(press, true)
	for k in range(1, 11):
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = from.lerp(to, k / 10.0)
		move.global_position = move.position
		move.relative = (to - from) / 10.0
		root.push_input(move, true)
		await process_frame
	_check(str(root.gui_get_drag_data()) == "fleet_move", "dragging the fleet icon is a fleet drag")
	_check(ui.DraggedFleets.size() == ours.size() and Lq.all(ours, func(f: Fleet) -> bool: return ui.DraggedFleets.has(f)),
		"it carries our %d fleet(s) in orbit there" % ours.size())
	_check(drop._can_drop_data(Vector2.ZERO, "fleet_move"), "%s takes the drop" % target.Name)
	var release := press.duplicate()
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release, true)
	for _i in 3:
		await process_frame
	_check(Lq.all(ours, func(f: Fleet) -> bool: return f.Status == Enums.Status.Enroute and f.Destination == target),
		"let go on %s, they set off for it" % target.Name)
	_check(ui.DraggedFleets.is_empty(), "the drag is over")

	# A drop on a system's corner icon is a drop on the system: every corner
	# forwards to its own system's button.
	var forwarding := true
	var corners := 0
	for c in win.find_children("*", "Button", true, false):
		if c.has_meta("corner") and "DropTarget" in c:
			corners += 1
			if c.DropTarget == null or not ("AssociatedPlanet" in c.DropTarget):
				forwarding = false
	_check(corners > 0 and forwarding, "all %d corner icons pass a drop to their system" % corners)

	# Theirs: an icon showing only the opponent's fleets does not drag.
	var theirs_ok := true
	for c in win.find_children("*", "Button", true, false):
		if c.has_meta("corner") and c.get_meta("corner") == "fleet" and "DragFleets" in c:
			for f in c.DragFleets:
				if (f as Fleet).Faction != us:
					theirs_ok = false
	_check(theirs_ok, "no fleet icon drags the opponent's fleets")
	_finish()


func _finish() -> void:
	print("[drag_fleet_icon] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A point, in viewport pixels, where the icon takes the mouse (its drawn
## pixels - CornerButton._has_point); INF if there is none.
static func _drawn_point(b: Control) -> Vector2:
	for y in int(b.size.y):
		for x in int(b.size.x):
			var p := Vector2(x + 0.5, y + 0.5)
			if b._has_point(p):
				return b.get_global_transform_with_canvas() * p
	return Vector2.INF


## The system's corner icon of one kind, in a sector window.
static func _corner(win: Node, p: Planet, kind: String) -> Button:
	var button: Control = _planet_button(win, p)
	for c in win.find_children("*", "Button", true, false):
		if c.has_meta("corner") and c.get_meta("corner") == kind and "DropTarget" in c and c.DropTarget == button:
			return c
	return null


static func _planet_button(win: Node, p: Planet) -> Control:
	for c in win.find_children("*", "Button", true, false):
		if "AssociatedPlanet" in c and c.AssociatedPlanet == p:
			return c
	return null


static func _window_titled(ui: Node, title: String) -> Node:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
