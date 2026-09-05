extends SceneTree
## An enemy character standing on a world WE hold who is dispatched onto a mission
## (Status == OnMission) must NOT appear on that world's Personnel tab. The Live
## branch queries the global roster for enemy characters with Attached == planet
## and Status != Enroute, which previously swept in OnMission agents - fog we have
## not earned (issue #2a: enemy personnel visible on sabotage). Our OWN personnel
## are drawn separately and unconditionally, so this guard must not touch them.
##
##   Godot_console.exe --headless --path . -s tests/onmission_fog.gd

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
	var empire: Faction = FactionRegistry.ById("empire")

	# A world WE hold: this puts the Personnel tab on the Live branch, which
	# queries the global roster for enemy characters present on the planet.
	var ours: Planet = _first(func(p): return p.ControllingFaction == alliance)
	_check(ours != null, "we hold a world to test the Live Personnel tab")
	if ours == null:
		_finish(); return

	# An Empire character standing on OUR world who is out on a mission.
	var enemy: Character = _first_char(func(c): return c.Faction == empire and c.Status != Enums.Status.Dead)
	_check(enemy != null, "an enemy character exists to dispatch")
	if enemy == null:
		_finish(); return
	enemy.Attached = ours
	enemy.Destination = null
	enemy.Status = Enums.Status.OnMission
	enemy.DaysToDestination = 0

	# AC2: one of OUR OWN characters present on the planet must still be drawn.
	# DrawOwnPersonnel is the unconditional path (ours are never fogged from us),
	# so this guards 'the fix did not break list population' with behavior we KNOW
	# is correct. Prefer a character already standing on the world; if none, seat
	# one of ours there AWAITING ORDERS.
	var oursChar: Character = _first_char(func(c): return c.Faction == alliance and c.Status != Enums.Status.Dead and c.Attached == ours)
	if oursChar == null:
		oursChar = _first_char(func(c): return c.Faction == alliance and c.Status != Enums.Status.Dead and c != enemy)
	if oursChar != null:
		oursChar.Attached = ours
		oursChar.Destination = null
		oursChar.Status = Enums.Status.AwaitingOrders
		oursChar.DaysToDestination = 0
	_check(oursChar != null, "an own character is present to confirm list population")

	# PRECISION (synthetic) case: an enemy AwaitingOrders char sitting on our world
	# IS drawn by this predicate. This is NOT a claim that idle enemies are visible
	# in real play - that state does not arise naturally (a finished agent goes
	# Enroute home). It only proves the filter is not OVERLY broad (it hides
	# OnMission specifically, not every non-Enroute enemy). Whether a broad
	# enemy-on-your-world is fog at all is an OPEN question (Issue #4 territory).
	var enemy2: Character = _first_char(func(c): return c.Faction == empire and c.Status != Enums.Status.Dead and c != enemy and c != oursChar)
	if enemy2 != null:
		enemy2.Attached = ours
		enemy2.Destination = null
		enemy2.Status = Enums.Status.AwaitingOrders
		enemy2.DaysToDestination = 0

	var ui := UIManager.new()
	ui.name = "UIManager"
	root.add_child(ui)
	var w = load("res://src/ui/DefenseWindow.tscn").instantiate()
	root.add_child(w)
	await process_frame
	w.Populate(ours, ui)
	await process_frame

	var texts := _all_text(w.get_node("%PersonnelList"))
	_check(not _mentions(texts, enemy.Name), "the enemy character ON MISSION is NOT shown on our Personnel tab")
	if oursChar != null:
		_check(_mentions(texts, oursChar.Name), "our own character present on the world IS still shown (unconditional path)")
	if enemy2 != null:
		_check(_mentions(texts, enemy2.Name), "PRECISION (synthetic): an enemy AwaitingOrders char IS still drawn - filter is not overly broad")

	w.free()
	ui.free()
	_finish()


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _first_char(pred: Callable) -> Character:
	for c in GameState.ActiveRoster:
		if pred.call(c):
			return c
	return null


func _all_text(node: Node, out: Array = []) -> Array:
	if node is Button:
		out.append((node as Button).text)
	elif node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_all_text(c, out)
	return out


func _mentions(texts: Array, name: String) -> bool:
	for t in texts:
		if str(t).contains(name):
			return true
	return false


func _finish() -> void:
	print("[onmission_fog] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
