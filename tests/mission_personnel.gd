extends SceneTree
## A character on a mission leaves the Personnel tab and is shown in the
## Mission window instead, as in the original (TeeJ's screenshots of it,
## 2026-09-23: the Emperor recruiting on Coruscant is gone from Coruscant's
## Personnel page). Called off, they are listed again. A team on its way to
## another world is not listed there as inbound either. Special Forces the
## same (TeeJ, 2026-09-24: "they behave the same as characters").
##
##   .\tools\run-gd.ps1 tests/mission_personnel.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mission_personnel] ok   %s" % what)
	else:
		_fails += 1
		print("[mission_personnel] FAIL %s" % what)


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

	var recruit: int = Enums.MissionType.Recruitment
	var who: Character = null
	for c in GameState.ActiveRoster:
		if c.Faction == us and not c.IsOffMap() and c.Attached is Planet and MissionManager.TeamCanPerform([c], recruit) \
				and MissionManager.CanTarget(recruit, us, c.Attached).ok:
			who = c
			break
	_check(who != null, "a recruiter of ours standing on a world")
	if who == null:
		_finish()
		return
	var home: Planet = who.Attached
	_check(_listed(ui, home).has(who.Name), "%s is on %s's Personnel tab before the mission" % [who.Name, home.Name])

	var m: Mission = MissionManager.Launch(recruit, [who], home, home)
	_check(m != null and m.Arrived(), "recruiting on the world they stand on")
	_check(not _listed(ui, home).has(who.Name), "on the mission, %s leaves the Personnel tab" % who.Name)

	CommandBus.issue("abort_mission", { "mission": m.Serial })
	_check(_listed(ui, home).has(who.Name), "called off, %s is listed again" % who.Name)

	# A team sent elsewhere: not listed at the target while inbound.
	var dip: int = Enums.MissionType.Diplomacy
	var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and not c.IsOffMap() and c.Attached is Planet and c.CanTakeOrders() and not MissionManager.IsOnMissionTeam(c))
	var from: Planet = agent.Attached if agent != null else null
	var far: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return from != null and p != from and p.IsExplored and MissionManager.CanTarget(dip, us, p).ok and from.DeploymentDaysTo(p) > 0)
	if agent != null and far != null:
		var m2: Mission = MissionManager.Launch(dip, [agent], from, far)
		_check(m2 != null and not m2.Arrived(), "%s sent on Diplomacy to %s, in hyperspace" % [agent.Name, far.Name])
		_check(not _listed(ui, far).has(agent.Name), "not listed on %s as inbound" % far.Name)
		_check(not _listed(ui, from).has(agent.Name), "nor on %s, left behind" % from.Name)
	else:
		_check(false, "an agent and a world to send them to")

	# Special Forces: off the Personnel page while on a mission. Day zero's
	# seeding is random, and some galaxies deal us none (seed 3's Alliance):
	# then raise one of ours on a world we hold, as training would.
	var ours_sf: bool = Lq.any(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and Lq.any(p.SpecForces(), func(u: Unit) -> bool: return u.Faction == us))
	if not ours_sf:
		var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(d: PackDefs.UnitDef) -> bool:
			return d.Kind == "spec_force" and d.BuildableBy.has(us.Id) and not MissionCatalog.SpecForceMissions(d.Id).is_empty())
		var held: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
		if def != null and held != null:
			DayZeroGenerator.AssignUnitToPlanet(held, MilitaryCatalog.Create(def, us, held))
	var sent := false
	for p: Planet in GameState.AllPlanets():
		if sent or p.ControllingFaction != us:
			continue
		for u: Unit in p.SpecForces():
			if sent or u.Faction != us or MissionManager.IsOnMissionTeam(u):
				continue
			for t in MissionCatalog.SpecForceMissions(u.PackId):
				if sent or MissionManager.NeedsCharacterTarget(t) or MissionManager.NeedsObjectTarget(t):
					continue
				var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(q: Planet) -> bool: return MissionManager.CanTarget(t, us, q).ok)
				if target == null:
					continue
				var before: int = _units_listed(ui, p)
				var m3: Mission = MissionManager.Launch(t, [u], p, target)
				if m3 == null:
					continue
				sent = true
				_check(_units_listed(ui, p) == before - 1, "%s on %s leaves %s's Personnel page (%d -> %d)"
					% [u.Name, MissionCatalog.DisplayNameFor(t), p.Name, before, _units_listed(ui, p)])
	_check(sent, "a Special Forces unit of ours could be sent on a mission")
	_finish()


## How many of our Special Forces the Personnel page lists on a world.
func _units_listed(ui: UIManager, planet: Planet) -> int:
	ui.OnDefenseClicked(planet)
	var w: DraggableWindow = ui._openWindows.get(planet.Name + " Defenses")
	if w == null:
		return -1
	var list := VBoxContainer.new()
	w.add_child(list)
	var n: int = w.DrawOwnUnits(list, planet.SpecForces(), ui, [])
	list.queue_free()
	return n


## The names on a world's Personnel tab, as the Defenses window draws them.
func _listed(ui: UIManager, planet: Planet) -> Array:
	ui.OnDefenseClicked(planet)
	var w: DraggableWindow = ui._openWindows.get(planet.Name + " Defenses")
	var names: Array = []
	if w == null:
		return names
	var list := VBoxContainer.new()
	w.add_child(list)
	w.DrawOwnPersonnel(list, planet, ui)
	for row in list.find_children("*", "Button", true, false):
		if "CharacterData" in row and row.CharacterData != null:
			names.append(row.CharacterData.Name)
	list.queue_free()
	return names


func _finish() -> void:
	print("[mission_personnel] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
