extends SceneTree
## Personnel sent on a mission from a fleet LEAVE the fleet (TeeJ, 2026-09-24:
## "when sending personnel on a mission from a fleet, they do not 'leave' the
## fleet"): a character aboard, and a Special Forces unit in a ship's hangar,
## set off from the fleet's system - off the fleet's Personnel list and
## hangars, so a fleet wiped out no longer takes them with it - and the
## system's Personnel page does not list them either (they are in the Mission
## window).
##
##   .\tools\run-gd.ps1 tests/mission_leaves_fleet.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mission_leaves_fleet] ok   %s" % what)
	else:
		_fails += 1
		print("[mission_leaves_fleet] FAIL %s" % what)


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
	var us: Faction = GameSettings.PlayerFaction
	CommandBus.Immediate = true

	# A fleet of ours in orbit, with a ship.
	var fleet: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and f.Status != Enums.Status.Enroute and not f.Ships.is_empty():
				fleet = f
	_check(fleet != null and fleet.Attached is Planet, "a fleet of ours in orbit")
	if fleet == null:
		_finish()
		return
	var home: Planet = fleet.Attached

	# A character of ours, put aboard it, and a mission with some way to go.
	var mission := -1
	var agent: Character = null
	var far: Planet = null
	for t in Enums.MissionType.values():
		if MissionManager.NeedsCharacterTarget(t) or MissionManager.NeedsObjectTarget(t) or not MissionManager.SideRuns(us, t):
			continue
		var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
			return c.Faction == us and c.CanTakeOrders() and not c.IsOffMap() and c.Attached is Planet \
				and not MissionManager.IsOnMissionTeam(c) and MissionManager.CanPerform(c, t) \
				and MissionManager.TeamMeetsExtraRule([c], t).ok)
		if who == null:
			continue
		var where: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
			return p != home and home.DeploymentDaysTo(p) > 0 and MissionManager.CanTarget(t, us, p).ok)
		if where != null:
			mission = t
			agent = who
			far = where
			break
	_check(agent != null, "a character and a mission for them")
	if agent == null:
		_finish()
		return
	agent.Attached = fleet
	agent.Status = Enums.Status.AwaitingOrders
	_check(_aboard(fleet).has(agent), "%s is aboard %s" % [agent.Name, fleet.Name])

	var m: Mission = MissionManager.Launch(mission, [agent], home, far)
	_check(m != null and not m.Arrived(), "%s is sent to %s, %d days away (%s)" % [agent.Name, far.Name,
		m.DaysToTarget if m != null else 0, MissionManager.LastRefusal])
	_check(not _aboard(fleet).has(agent), "and is no longer aboard %s" % fleet.Name)
	_check(agent.Attached == home and agent.Status == Enums.Status.Enroute and agent.Destination == far,
		"but on the way to %s from %s" % [far.Name, home.Name])
	_check(MissionManager.IsOnMissionTeam(agent), "on the mission, so %s's Personnel page leaves them to the Mission window" % home.Name)

	# The fleet wiped out: they are not aboard to die with it.
	var report := FleetBattleManager.BattleReport.new()
	report.Ours = fleet
	var ships: Array = fleet.Ships.duplicate()
	fleet.Ships.clear()
	FleetBattleManager.LoseCrews(report)
	fleet.Ships.append_array(ships)
	_check(agent.Status != Enums.Status.Dead, "a fleet lost with every ship does not take them with it")

	# A Special Forces unit in a ship's hangar, the same.
	var sf: Unit = null
	var sfMission := -1
	var sfFar: Planet = null
	for p in GameState.AllPlanets():
		for u in p.SpecForces():
			if sf != null or u.Faction != us or u.Status == Enums.Status.Enroute or MissionManager.IsOnMissionTeam(u):
				continue
			for t in Enums.MissionType.values():
				if MissionManager.NeedsCharacterTarget(t) or MissionManager.NeedsObjectTarget(t) or not MissionManager.SideRuns(us, t) \
						or not MissionManager.CanPerform(u, t) or not MissionManager.TeamMeetsExtraRule([u], t).ok:
					continue
				var where: Planet = Lq.first_or_null(GameState.AllPlanets(), func(q: Planet) -> bool:
					return q != home and home.DeploymentDaysTo(q) > 0 and MissionManager.CanTarget(t, us, q).ok)
				if where != null:
					sf = u
					sfMission = t
					sfFar = where
					break
	if sf == null:
		print("[mission_leaves_fleet] SKIP no Special Forces unit of ours with a mission to run")
	else:
		(sf.Attached as Planet).Garrison.erase(sf)
		fleet.Ships[0].Hangar.append(sf)
		sf.Attached = home   # as a fleet's move leaves a hangar payload (CascadeFleetPayloads)
		var m2: Mission = MissionManager.Launch(sfMission, [sf], home, sfFar)
		_check(m2 != null, "%s is sent to %s (%s)" % [sf.Name, sfFar.Name, MissionManager.LastRefusal])
		_check(not Lq.any(fleet.Ships, func(s: Unit) -> bool: return s.Hangar.has(sf)), "and has left the ship's hangar")
		_check(sf.Attached == home and home.Garrison.has(sf), "setting off from %s" % home.Name)
	_finish()


## Everyone the Fleet window lists on its Personnel page.
static func _aboard(fleet: Fleet) -> Array:
	return Lq.where(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == fleet)


func _finish() -> void:
	print("[mission_leaves_fleet] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
