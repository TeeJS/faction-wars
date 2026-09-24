extends SceneTree
## Which side runs which mission is missions.json `available_to`, for every
## mission (TeeJ, 2026-09-24; manual p105 "Only the Empire may perform this
## mission", the original's MISSNSD.DAT side columns). It was enforced for
## Assassination alone. Here:
##   - the Star Wars pack's one-sided missions refuse the other side;
##   - a pack that gives Diplomacy to one side only (as a mod might) keeps it
##     from the other: not in the Create Mission list, not proposed by the AI,
##     and refused at launch.
##
##   .\tools\run-gd.ps1 tests/mission_sides.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mission_sides] ok   %s" % what)
	else:
		_fails += 1
		print("[mission_sides] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded("star-wars-rebellion")
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4242)
	var alliance: Faction = FactionRegistry.ById("alliance")
	var empire: Faction = FactionRegistry.ById("empire")

	# The pack's own one-sided missions.
	var A := Enums.MissionType.Assassination
	var S := Enums.MissionType.SuperweaponSabotage
	_check(MissionManager.SideRuns(empire, A) and not MissionManager.SideRuns(alliance, A), "Assassination is the Empire's alone")
	_check(MissionManager.SideRuns(alliance, S) and not MissionManager.SideRuns(empire, S), "Superweapon Sabotage is the Alliance's alone")
	var leader: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == alliance and c.Attached is Planet and c.CanTakeOrders())
	_check(leader != null, "an Alliance character to send")
	if leader == null:
		_finish()
		return
	_check(not MissionManager.PerformableBy([leader]).has(A), "the AI's list for %s has no Assassination" % leader.Name)
	var victim: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == empire and c.Attached is Planet and not c.IsOffMap())
	var home: Planet = leader.Attached
	var m: Mission = MissionManager.Launch(A, [leader], home, victim.Attached if victim != null else home, null, victim)
	_check(m == null and MissionManager.LastRefusal.contains("does not carry out"), "an Alliance assassination is refused ('%s')" % MissionManager.LastRefusal)

	# A pack that gives Diplomacy to the Empire alone.
	var D := Enums.MissionType.Diplomacy
	var def: PackDefs.MissionDefPack = MissionCatalog.DefFor(D)
	var was: Array[String] = def.AvailableTo.duplicate()
	var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return MissionManager.CanTarget(D, alliance, p).ok)
	_check(target != null and DraggableWindow.LegalMissions([leader], target, null, null).has(D), "as shipped, %s may run Diplomacy at %s" % [leader.Name, target.Name if target != null else "-"])
	def.AvailableTo.assign(["empire"])
	_check(not MissionManager.SideRuns(alliance, D) and MissionManager.SideRuns(empire, D), "given to the Empire alone, the Alliance does not run Diplomacy")
	_check(not DraggableWindow.LegalMissions([leader], target, null, null).has(D), "... Create Mission does not offer it")
	_check(not MissionManager.PerformableBy([leader]).has(D), "... the AI does not propose it")
	m = MissionManager.Launch(D, [leader], home, target)
	_check(m == null and MissionManager.LastRefusal == "%s does not carry out %s." % [alliance.DisplayName, MissionCatalog.DisplayNameFor(D)],
		"... and a launch is refused ('%s')" % MissionManager.LastRefusal)
	def.AvailableTo.assign(was)
	_finish()


func _finish() -> void:
	print("[mission_sides] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
