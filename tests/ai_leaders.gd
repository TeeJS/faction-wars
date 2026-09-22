extends SceneTree
## The AI's head of state - the character the pack starts at the headquarters
## (`starts_at_hq`) - runs Diplomacy and Recruitment only, never a mission a
## foil could seize them on (TeeJ, 2026-09-22: the Star Wars soaks sent the
## Emperor on 90 sabotage runs; the WWII pack sent Hitler to Britain to be
## caught). Plays DAYS days with the AI on the side that is not `--faction=`
## and inspects every mission that side ever has active.
##
##   .\tools\run-gd.ps1 tests/ai_leaders.gd                      (Star Wars: the Emperor)
##   .\tools\run-gd.ps1 tests/ai_leaders.gd -- --pack=ww2 --faction=allies   (Hitler)

const DAYS := 150

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[ai_leaders] ok   %s" % what)
	else:
		_fails += 1
		print("[ai_leaders] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var human := _arg("--faction=", "alliance")
	var engine: StrategicTickManager = GameSession.new_game(human, Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var ai: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f): return not GameSettings.IsHuman(f))
	_check(ai != null, "one side is AI-driven")
	var leaders := Lq.where(GameState.ActiveRoster, func(c): return c.Faction == ai and c.HasRole("starts_at_hq"))
	_check(leaders.size() > 0, "%s has a head of state (%s)" % [ai.Id, ", ".join(Lq.select(leaders, func(c): return c.Name))])

	var seen: Dictionary = {}     # mission instance id -> true
	var bad: Array = []
	var allowed_runs := 0
	for _day in DAYS:
		engine.AdvanceDay()
		for m in MissionManager.Active():
			if m.Faction != ai or seen.has(m.get_instance_id()):
				continue
			seen[m.get_instance_id()] = true
			for member in m.Team:
				if member is Character and (member as Character).HasRole("starts_at_hq"):
					var ok: bool = m.Type == Enums.MissionType.Diplomacy or m.Type == Enums.MissionType.Recruitment
					if ok:
						allowed_runs += 1
					else:
						bad.append("%s on %s at %s (day %d)" % [(member as Character).Name, JsonUtil.enum_name(Enums.MissionType, m.Type), m.Target.Name, StrategicTickManager.Today])
		if VictoryManager.IsOver():
			break
	_check(bad.is_empty(), "no head of state ever ran a mission other than Diplomacy or Recruitment (%d missions seen)%s"
		% [seen.size(), "" if bad.is_empty() else ": " + ", ".join(bad.slice(0, 5))])
	print("[ai_leaders] the head of state ran %d Diplomacy/Recruitment missions in %d days" % [allowed_runs, StrategicTickManager.Today])

	# The leader is still free at the end, or at least not captured by a foil.
	for c in leaders:
		_check(not (c as Character).IsCaptured(), "%s was not captured" % (c as Character).Name)

	print("[ai_leaders] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
