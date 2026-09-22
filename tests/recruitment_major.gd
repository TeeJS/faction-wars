extends SceneTree
## "Only a major character can perform it" (GAMEPLAY.md mission table, manual
## p105-p108): Recruitment is not offered to a team without a major character,
## a refused launch comes back as a refused order with the reason, a major's
## Recruitment on their own world puts them On Mission at once, and the status
## bar reads the engine's day from the first frame (TeeJ, 2026-09-22: WWII
## operatives sent to recruit stayed put with only a console line, and the bar
## read "Day: 0" for the first 15 s).
##
##   .\tools\run-gd.ps1 tests/recruitment_major.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/recruitment_major.gd              (Star Wars)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[recruitment_major] ok   %s" % what)
	else:
		_fails += 1
		print("[recruitment_major] FAIL %s" % what)


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

	var gm: GameManager = main
	_check(gm._dayLabel.text.begins_with("Day: %d" % StrategicTickManager.Today),
		"the status bar reads the engine's day from the start ('%s', day %d)" % [gm._dayLabel.text, StrategicTickManager.Today])

	var us: Faction = GameSettings.PlayerFaction
	var at_home := func(c: Character) -> bool:
		return c.Faction == us and c.Attached is Planet and (c.Attached as Planet).ControllingFaction == us \
			and c.CanTakeOrders() and not MissionManager.IsOnMissionTeam(c)
	var minor: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return at_home.call(c) and not c.IsMajor)
	var major: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return at_home.call(c) and c.IsMajor)
	_check(minor != null and major != null, "%s has a minor and a major character at home (%s, %s)"
		% [us.Id, minor.Name if minor != null else "-", major.Name if major != null else "-"])
	if minor == null or major == null:
		quit(1)
		return

	# The team filter: not offered without a major, offered with one.
	var rule: Result = MissionManager.TeamMeetsExtraRule([minor], Enums.MissionType.Recruitment)
	_check(not rule.ok and rule.error.contains("major character"), "a minor alone is refused by the team rule: '%s'" % rule.error)
	_check(rule.error.contains(major.Name), "the refusal names the side's major characters")
	_check(not MissionManager.TeamCanPerform([minor], Enums.MissionType.Recruitment), "Recruitment is not on a minor's mission list")
	_check(MissionManager.TeamCanPerform([major], Enums.MissionType.Recruitment), "Recruitment is on a major's mission list")
	_check(MissionManager.TeamCanPerform([minor, major], Enums.MissionType.Recruitment), "a mixed team with a major qualifies")

	# A refused launch is a refused order, with the reason.
	var home: Planet = minor.Attached
	CommandBus.Immediate = true
	var r: Result = CommandBus.issue("launch_mission", {"type": Enums.MissionType.Recruitment,
		"team": EntityIndex.ids_of_units([minor]), "origin": home.Name, "target": home.Name, "decoys": [], "victim": ""})
	_check(not r.ok and r.error.contains("major character"), "the launch order comes back refused with the reason: '%s'" % r.error)
	_check(minor.Status == Enums.Status.AwaitingOrders and not MissionManager.IsOnMissionTeam(minor), "the minor is untouched by the refusal")

	# The major's Recruitment on their own world: On Mission at once.
	var seat: Planet = major.Attached
	var r2: Result = CommandBus.issue("launch_mission", {"type": Enums.MissionType.Recruitment,
		"team": EntityIndex.ids_of_units([major]), "origin": seat.Name, "target": seat.Name, "decoys": [], "victim": ""})
	_check(r2.ok, "the major's launch order is accepted")
	_check(major.Status == Enums.Status.OnMission and MissionManager.IsOnMissionTeam(major), "%s is On Mission at %s" % [major.Name, seat.Name])
	var busy: Result = MissionManager.TeamMeetsExtraRule([major], Enums.MissionType.Recruitment)
	_check(busy.ok, "the team rule itself still passes for a major (busy-ness is Launch's check)")

	print("[recruitment_major] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
