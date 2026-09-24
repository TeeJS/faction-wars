extends SceneTree
## Our own people are never a question (TeeJ, 2026-09-24): a sighting of an
## enemy world leaves out the viewer's own characters and special forces, so
## one of ours seen there once is not shown at that world after leaving it -
## "in two places at once" (Labansat, "last seen day 10" at Uvena and on
## Coruscant). The enemy seen with them still is. The windows draw ours live.
##
##   .\tools\run-gd.ps1 tests/intel_own_people.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[intel_own_people] ok   %s" % what)
	else:
		_fails += 1
		print("[intel_own_people] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSession.new_game("empire", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var empire: Faction = GameSettings.PlayerFaction
	var alliance: Faction = FactionRegistry.ById("alliance")

	var theirs: Planet = _first(func(p): return p.ControllingFaction == alliance)
	var home: Planet = _first(func(p): return p.ControllingFaction == empire)
	var mine: Character = _first_char(func(c): return c.Faction == empire and c.Status != Enums.Status.Dead and not c.IsOffMap())
	var enemy: Character = _first_char(func(c): return c.Faction == alliance and c.Status != Enums.Status.Dead and not c.IsOffMap())
	_check(theirs != null and home != null and mine != null and enemy != null, "an enemy world, a world of ours, one of ours and one of theirs")
	if theirs == null or home == null or mine == null or enemy == null:
		_finish()
		return
	for c in [mine, enemy]:
		c.Attached = theirs
		c.Destination = null
		c.Status = Enums.Status.AwaitingOrders
	# One of our special forces standing there too.
	var sf: Unit = null
	for p in GameState.AllPlanets():
		for u in p.SpecForces():
			if u.Faction == empire and sf == null:
				sf = u
				p.Garrison.erase(u)
				theirs.Garrison.append(u)
				u.Attached = theirs

	# Seen while both stood there.
	IntelManager.Capture(empire, theirs, 10, [Enums.IntelCategory.Characters])
	var seen: IntelManager.IntelView = IntelManager.View(empire, theirs, Enums.IntelSection.Characters)
	_check(seen.Known and not seen.Live, "the enemy world is a sighting")
	_check(_mentions(seen.Lines, enemy.Name), "the enemy seen there is in the sighting (%s)" % enemy.Name)
	_check(not _mentions(seen.Lines, mine.Name), "our own character is not in it (%s)" % mine.Name)

	# Ours has since gone home: the sighting still does not put them there.
	mine.Attached = home
	seen = IntelManager.View(empire, theirs, Enums.IntelSection.Characters)
	_check(not _mentions(seen.Lines, mine.Name), "gone home, ours is not shown at the world they left")

	# A world we hold reports itself in full, ours included.
	var live: IntelManager.IntelView = IntelManager.View(empire, home, Enums.IntelSection.Characters)
	_check(live.Live and _mentions(live.Lines, mine.Name), "our own world lists our character live")

	# Our special forces likewise; theirs, when there, still are.
	if sf != null:
		IntelManager.Capture(empire, theirs, 11, [Enums.IntelCategory.SpecForces])
		var sfView: IntelManager.IntelView = IntelManager.View(empire, theirs, Enums.IntelSection.SpecForces)
		_check(not _mentions(sfView.Lines, sf.Name) or Lq.any(theirs.SpecForces(), func(u): return u.Faction != empire and u.Name == sf.Name),
			"our special forces are not in a sighting (%s)" % sf.Name)
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


func _mentions(lines: Array, name: String) -> bool:
	for t in lines:
		if str(t).contains(name):
			return true
	return false


func _finish() -> void:
	print("[intel_own_people] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
