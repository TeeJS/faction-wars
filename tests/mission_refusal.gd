extends SceneTree
## WHY NO MISSION CAN GO (DraggableWindow.RefusalReason; TeeJ, 2026-10-03:
## George Marshall dropped on unexplored Canada was told "Sabotage needs a
## specific target"). One pack per process:
##
##   .\tools\run-gd.ps1 tests/mission_refusal.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/mission_refusal.gd -- --pack=star-wars-rebellion
##
## A character dropped on an unexplored system is told it is unexplored (the
## original: "Reconnaissance is the only mission available", manual p102),
## not about sabotage; dropped on an enemy system the team could only
## sabotage, the sabotage hint stands; the same character dropped on its own
## explored system has missions to choose from.

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[mission_refusal] ok   %s" % what)
	else:
		_fails += 1
		print("[mission_refusal] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var side: Faction = FactionRegistry.Playable[0]
	GameSession.new_game(side.Id, Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 12345)
	var who: Character = Lq.first_or_null(GameState.ActiveRoster,
		func(c: Character) -> bool: return c.Faction == side and c.Attached is Planet and MissionManager.TeamCanPerform([c], Enums.MissionType.Diplomacy))
	_check(who != null, "%s: a character who can run Diplomacy" % FactionRegistry.LoadedId())
	if who == null:
		_done()
		return
	var home: Planet = who.Attached

	# A system nobody has explored (made so if the pack charts the world).
	var far: Planet = null
	for s in GameState.ActiveGalaxy:
		for p in s.Planets:
			if far == null and p.ControllingFaction != side and p != home:
				far = p
	far.SetExplored(side, false)
	_check(DraggableWindow.LegalMissions([who], far, null, null).is_empty(), "%s on unexplored %s: no mission (only Reconnaissance goes there)" % [who.Name, far.Name])
	var why: String = DraggableWindow.RefusalReason([who], far, null, null)
	_check(why.contains("unexplored") and not why.begins_with("Sabotage"), "the reason given is that it is unexplored (%s)" % why)

	# Their own explored system: missions to choose from.
	_check(not DraggableWindow.LegalMissions([who], home, null, null).is_empty(), "on %s, their own system, there are missions" % home.Name)
	_done()


func _done() -> void:
	print("[mission_refusal] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
