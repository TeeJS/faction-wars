extends SceneTree
## Moving the Alliance headquarters takes days (manual p135: "drag the HQ icon
## onto a new system or right-click, select Move, then select the destination
## (Fig. 3.82). Alternately, you can see how much transit time it will take for
## the move before you decide for sure by selecting Confirmed Move"). It went at
## once, and its Confirmed Move asked nothing. REBEXE moves it as any object is
## moved, at entry 1's rating - a facility's deployment days (OrderManager).
##   - Confirmed Move: the window with the HQ's days; the X leaves it; the check
##     sends it;
##   - on its way: at neither world, a second move refused, and the days are the
##     travel law's; it stands at its new seat on the day it arrives;
##   - plain Move: no window, it goes;
##   - its destination lost on the way: it goes to the nearest world its side holds.
##
##   .\tools\run-gd.ps1 tests/hq_move_transit.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[hq_move_transit] ok   %s" % what)
	else:
		_fails += 1
		print("[hq_move_transit] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-hq-move-transit-none"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById("alliance")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var gm: GameManager = main
	gm.SetSpeed(0)   # the days are the test's to turn
	var ui: UIManager = main.get_node("UIManager")
	var briefing: Node = ui.Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	await process_frame
	gm.SetSpeed(0)
	var engine: StrategicTickManager = gm._strategicEngine
	var us: Faction = GameSettings.PlayerFaction
	var seat: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.HasHeadquarters() and p.ControllingFaction == us)
	var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and p != seat)
	_check(seat != null and ours.size() >= 2, "the Alliance's seat and two more worlds of its own")
	if seat == null or ours.size() < 2:
		_finish(main)
		return
	# Far enough that the move is more than a day.
	var dest: Planet = ours[0]
	for p in ours:
		if seat.IntegerDistanceTo(p) > seat.IntegerDistanceTo(dest):
			dest = p
	var law: int = maxi(1, seat.IntegerDistanceTo(dest) / RuleManager.Get(RuleId.SpaceTravelDistanceDiv) * RuleManager.Get(RuleId.SpaceTravelBase) / 100)

	# Confirmed Move: the window, then the X.
	ui.OnPlanetClicked(seat)
	await process_frame
	var pw: Node = ui._openWindows.get(seat.Name)
	_check(pw != null and is_instance_valid(pw), "%s's Planet Data window" % seat.Name)
	pw._OnHqMenuAction(1, seat)
	ui.ResolveTarget(dest)
	await process_frame
	var w: Node = _confirm(ui)
	_check(w != null and _text(w).contains(": %d" % law) and seat.HasHeadquarters(),
		"Confirmed Move: the window with the move's %d days ('%s') - and it has not gone" % [law, _text(w).replace("\n", " / ") if w != null else "none"])
	if w != null:
		w.Refresh()
		await process_frame
		_check(is_instance_valid(w) and not w.is_queued_for_deletion(), "the window stays open through a refresh")
		w.OnCancelPressed()
	await process_frame
	_check(seat.HasHeadquarters() and OrderManager.HeadquartersEnRoute(us).is_empty(), "the X: it stays at %s" % seat.Name)

	# The check: it goes.
	var before: int = seat.Support().get(us.Id, 0)
	pw._OnHqMenuAction(1, seat)
	ui.ResolveTarget(dest)
	await process_frame
	w = _confirm(ui)
	if w != null:
		w.OnConfirmPressed()
	await process_frame
	var bound: Dictionary = OrderManager.HeadquartersEnRoute(us)
	_check(not bound.is_empty() and bound["to"] == dest and int(bound["days"]) == law,
		"the check: on its way to %s, %d days" % [dest.Name, int(bound.get("days", -1))])
	_check(not seat.HasHeadquarters() and not dest.HasHeadquarters(), "on its way it stands at neither world")
	_check(seat.Support().get(us.Id, 0) < before or before == 0, "the small support drop on the world it left (manual p090)")
	var again: Result = OrderManager.MoveHeadquarters(us, ours[1] if ours[1] != dest else ours[0])
	_check(not again.ok and again.error.contains("on its way"), "a second move while it travels: '%s'" % again.error)

	for _d in law - 1:
		engine.AdvanceDay()
	_check(not dest.HasHeadquarters() and not OrderManager.HeadquartersEnRoute(us).is_empty(), "a day short: still travelling")
	engine.AdvanceDay()
	_check(dest.HasHeadquarters() and OrderManager.HeadquartersEnRoute(us).is_empty() and dest.ExploredBy(us),
		"day %d: it stands at %s" % [law, dest.Name])

	# Plain Move: no window, it goes.
	ui.OnPlanetClicked(dest)
	await process_frame
	var pw2: Node = ui._openWindows.get(dest.Name)
	var next: Planet = seat if seat.ControllingFaction == us else Lq.first_or_null(ours, func(p: Planet) -> bool: return p != dest)
	if pw2 != null:
		pw2._OnHqMenuAction(0, dest)
		ui.ResolveTarget(next)
	await process_frame
	_check(_confirm(ui) == null and not OrderManager.HeadquartersEnRoute(us).is_empty() and not dest.HasHeadquarters(),
		"plain Move: no window, it goes")

	# Its destination lost on the way: the nearest world its side holds.
	var enemy: Faction = FactionRegistry.ById("empire")
	next.ControllingFaction = enemy
	var refuge: Planet = MilitaryCatalog.NearestHeldBy(us, next)
	for _d in int(OrderManager.HeadquartersEnRoute(us).get("days", 0)):
		engine.AdvanceDay()
	_check(not next.HasHeadquarters() and refuge != null and refuge.HasHeadquarters(),
		"%s lost on the way: it stands at %s instead" % [next.Name, refuge.Name if refuge != null else "?"])
	_finish(main)


func _confirm(ui: UIManager) -> Node:
	for k in ui._openWindows:
		var w: Variant = ui._openWindows[k]
		if str(k).begins_with("Confirm_") and is_instance_valid(w) and not (w as Node).is_queued_for_deletion():
			return w
	return null


func _text(w: Node) -> String:
	return (w.get_node("%MessageLabel") as Label).text if w != null else ""


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	print("[hq_move_transit] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
