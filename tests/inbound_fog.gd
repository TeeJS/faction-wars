extends SceneTree
## An enemy character in transit TO a world we hold must not appear on that world's
## Personnel tab - that is fog we have not earned (reported from play: "enemy
## personnel enroute to my planet, why am I seeing it?"). Our OWN inbound personnel
## are still listed, as they always were.
##
##   Godot_console.exe --headless --path . -s tests/inbound_fog.gd

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

	var ours: Planet = _first(func(p): return p.ControllingFaction == alliance)
	var ours2: Planet = _first(func(p): return p.ControllingFaction == alliance and p != ours)
	var theirs: Planet = _first(func(p): return p.ControllingFaction == empire)
	_check(ours != null and theirs != null, "we hold a world; an enemy world exists")
	if ours == null or theirs == null:
		_finish(); return

	# An Empire character in transit to OUR world.
	var enemy: Character = _first_char(func(c): return c.Faction == empire and c.Status != Enums.Status.Dead)
	enemy.Attached = theirs
	enemy.Destination = ours
	enemy.Status = Enums.Status.Enroute
	enemy.DaysToDestination = 5

	# One of OUR characters, also in transit to our world (should still show).
	var mine: Character = _first_char(func(c): return c.Faction == alliance and c.Status != Enums.Status.Dead)
	mine.Attached = ours2 if ours2 != null else theirs
	mine.Destination = ours
	mine.Status = Enums.Status.Enroute
	mine.DaysToDestination = 5

	var ui := UIManager.new()
	ui.name = "UIManager"
	root.add_child(ui)
	var w = load("res://src/ui/DefenseWindow.tscn").instantiate()
	root.add_child(w)
	await process_frame
	w.Populate(ours, ui)
	await process_frame

	var texts := _all_text(w.get_node("%PersonnelList"))
	_check(not _mentions(texts, enemy.Name), "the enemy character in transit is NOT shown on our Personnel tab")
	_check(_mentions(texts, mine.Name), "our own inbound character IS still shown")

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
	print("[inbound_fog] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
