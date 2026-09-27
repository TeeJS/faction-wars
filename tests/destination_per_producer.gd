extends SceneTree
## Select Destination per production area (BACKLOG #50; manual p045, p084:
## "right-clicking under Facilities Under Construction and selecting the
## Destination menu option. Click on the destination system with the cross
## hairs"). TeeJ, 2026-09-27: "select destination is by facility, not planet";
## "for destination, I should be able to click on another planet's defense/mfg
## window as well as the planet".
##   - Ship Construction, Troops in Training and Facilities Under Construction
##     each keep their own destination, each on its own Destination line;
##   - it outlives the window;
##   - Build orders from a queue go to that queue's destination;
##   - the crosshair takes a click anywhere on another system's Defense or
##     Manufacturing window as that system.
##
##   .\tools\run-gd.ps1 tests/destination_per_producer.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[destination_per_producer] ok   %s" % what)
	else:
		_fails += 1
		print("[destination_per_producer] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.PendingLoadPath = ""
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 6:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var briefing: Node = ui.Briefing()
	if briefing != null:
		briefing.Skip()
		briefing.Skip()
	await process_frame
	var us: Faction = GameSettings.PlayerFaction
	var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	_check(ours.size() >= 4, "four worlds of ours (%d)" % ours.size())
	if ours.size() < 4:
		_finish(main)
		return
	var home: Planet = ours[0]
	var a: Planet = ours[1]
	var b: Planet = ours[2]
	var c: Planet = ours[3]
	ui.OnEconomyClicked(home)
	for _i in 3:
		await process_frame
	var ew: EconomyWindow = ui._openWindows.get(home.Name + " Economy")

	# Ship Construction to a, Troops in Training to b; facilities stay home.
	ew.OpenDestinationChooser(home, "produces_unit")
	ui.ResolveTarget(a)
	ew.OpenDestinationChooser(home, "produces_troop")
	ui.ResolveTarget(b)
	await process_frame
	var ship: String = (ew.get_node("%ShipDestLabel") as Label).text
	var troop: String = (ew.get_node("%TroopDestLabel") as Label).text
	var fac: String = (ew.get_node("%FacDestLabel") as Label).text
	_check(ship.begins_with("Destination: %s" % a.Name) and troop.begins_with("Destination: %s" % b.Name) and fac == "Destination: %s" % home.Name,
		"each queue its own destination: '%s' / '%s' / '%s'" % [ship, troop, fac])
	ew.CloseWindow()
	await process_frame
	await process_frame
	ui.OnEconomyClicked(home)
	for _i in 3:
		await process_frame
	ew = ui._openWindows.get(home.Name + " Economy")
	_check((ew.get_node("%ShipDestLabel") as Label).text.begins_with("Destination: %s" % a.Name)
		and EconomyWindow.DestinationOf(home, "produces_troop") == b, "closed and opened again: still each its own")
	_check(EconomyWindow.DestinationOf(home, "produces_unit") == a and EconomyWindow.DestinationOf(home, "produces_facility") == home,
		"a Build from Ship Construction goes to %s, one from Facilities Under Construction stays home" % a.Name)

	# The crosshair on another system's Defense window, anywhere on it.
	ui.OnDefenseClicked(c)
	for _i in 3:
		await process_frame
	var dw: Control = ui._openWindows.get(c.Name + " Defenses")
	ew.OpenDestinationChooser(home, "produces_facility")
	_click(dw.get_global_rect().get_center())
	await process_frame
	_check(not ui.IsTargeting and EconomyWindow.DestinationOf(home, "produces_facility") == c,
		"a click on %s's Defense window names %s (facilities: %s)" % [c.Name, c.Name, EconomyWindow.DestinationOf(home, "produces_facility").Name])

	# ...and on another system's Manufacturing window.
	ui.OnEconomyClicked(b)
	for _i in 3:
		await process_frame
	var bw: Control = ui._openWindows.get(b.Name + " Economy")
	ew.OpenDestinationChooser(home, "produces_unit")
	_click(bw.get_global_rect().get_center())
	await process_frame
	_check(not ui.IsTargeting and EconomyWindow.DestinationOf(home, "produces_unit") == b,
		"a click on %s's Manufacturing window names %s" % [b.Name, b.Name])
	_finish(main)


func _click(at: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		root.push_input(e, true)


func _finish(main: Node) -> void:
	if main != null:
		main.queue_free()
	print("[destination_per_producer] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
