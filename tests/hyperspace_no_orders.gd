extends SceneTree
## Nobody in hyperspace takes orders (manual p111: "You cannot give orders to
## units in hyperspace; you must wait until they reach their destination"),
## a character aboard a fleet in transit included (TeeJ, 2026-09-25, with a
## screenshot of the original): their menu greys Move, Confirmed Move,
## Mission, Command and Retire and leaves Encyclopedia and Status, and the
## engine refuses to send them on a mission.
##
##   .\tools\run-gd.ps1 tests/hyperspace_no_orders.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[hyperspace_no_orders] ok   %s" % what)
	else:
		_fails += 1
		print("[hyperspace_no_orders] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	CommandBus.Immediate = true

	# A fleet of ours in orbit, a character aboard, and a world to send it to.
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and f.Status != Enums.Status.Enroute and not f.Ships.is_empty():
				fleet = f
	var home: Planet = fleet.Attached if fleet != null else null
	var rider: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.CanTakeOrders() and not c.IsOffMap() and c.Attached is Planet \
			and not MissionManager.IsOnMissionTeam(c))
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	var to: Planet = Lq.first_or_null(sector.Planets if sector != null else [], func(p: Planet) -> bool: return p != home)
	_check(fleet != null and rider != null and to != null, "a fleet, someone to put aboard, and somewhere to go")
	if fleet == null or rider == null or to == null:
		_finish()
		return
	rider.Attached = fleet
	rider.Status = Enums.Status.AwaitingOrders

	# A mission they COULD run before the fleet leaves, so the refusal below
	# is the hyperspace rule and nothing else.
	var mission := -1
	var target: Planet = null
	for t in Enums.MissionType.values():
		if MissionManager.NeedsCharacterTarget(t) or MissionManager.NeedsObjectTarget(t) or not MissionManager.SideRuns(us, t) \
				or not MissionManager.CanPerform(rider, t) or not MissionManager.TeamMeetsExtraRule([rider], t).ok:
			continue
		target = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
			return p != home and p != to and MissionManager.CanTarget(t, us, p).ok)
		if target != null:
			mission = t
			break
	_check(mission >= 0, "a mission %s could run" % rider.Name)

	ui.ExecuteSingleFleetMove(fleet, to, false)
	await process_frame
	_check(fleet.Status == Enums.Status.Enroute and rider.Attached == fleet and rider.Status == Enums.Status.Enroute,
		"%s rides %s into hyperspace" % [rider.Name, fleet.Name])

	if mission >= 0:
		var m: Mission = MissionManager.Launch(mission, [rider], to, target)
		_check(m == null and MissionManager.LastRefusal.contains("hyperspace"),
			"the engine will not send them on a mission ('%s')" % MissionManager.LastRefusal)

	# Their menu in the Fleet window, the fleet shown where it is going.
	ui.OnFleetClicked(to)
	for _i in 3:
		await process_frame
	var w: FleetWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is FleetWindow)
	_check(w != null, "the Fleet window opens at %s" % to.Name)
	if w == null:
		_finish()
		return
	w.DisplayFleetContents(fleet)
	await process_frame
	var btn: Button = null
	for b in w.find_children("*", "Button", true, false):
		if b.get("CharacterData") == rider and not b.is_queued_for_deletion():
			btn = b
	var menu: PopupMenu = null
	if btn != null:
		for c in btn.find_children("*", "PopupMenu", true, false):
			if c.name != "CommandSubmenu":
				menu = c
	_check(menu != null, "%s's row carries their menu" % rider.Name)
	if menu != null:
		var state := {}
		for i in menu.item_count:
			if not menu.is_item_separator(i):
				state[menu.get_item_text(i)] = not menu.is_item_disabled(i)
		for item in ["Move", "Confirmed Move", "Mission", "Command", "Retire"]:
			_check(state.get(item, true) == false, "%s is greyed" % item)
		for item in ["Encyclopedia", "Status"]:
			_check(state.get(item, false) == true, "%s is live" % item)
	_finish()


func _finish() -> void:
	print("[hyperspace_no_orders] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
