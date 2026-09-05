extends SceneTree
## M2 VERIFY (BUILD-PLAN.md, R2D2's criterion): the new brain reaches the mission
## types the old one could not, and drives MissionManager.Launch with a real victim
## and a real team — not the old single-agent, four-of-seven-args call. The headline
## is ABDUCTION (two of three victory conditions per side; absent from the old AI).
##
##   Godot_console.exe --headless --path . -s tests/ai_missions.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	# Human plays Alliance, so the EMPIRE is the AI faction under test.
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var empire: Faction = FactionRegistry.ById("empire")
	var alliance: Faction = FactionRegistry.ById("alliance")
	_check(empire != null and alliance != null, "both factions exist")
	_check(not GameSettings.IsHuman(empire), "the Empire is AI-driven")

	# --- Build a winnable abduction scenario -------------------------------
	# An Imperial operative free to act, on an Imperial world.
	var seat: Planet = _first(func(p): return p.ControllingFaction == empire)
	_check(seat != null, "the Empire holds a world")
	var spy: Character = _free_character(empire, seat)
	_check(spy != null, "an Imperial operative is free at %s" % (seat.Name if seat else "?"))

	# A Rebel MAJOR character, parked on a world the Empire has scouted (fog-legal).
	var hideout: Planet = _first(func(p): return p != seat and p.ControllingFaction == alliance)
	if hideout == null:
		hideout = _first(func(p): return p != seat)
	var victim: Character = _first_char(func(c): return c.Faction == alliance and c.IsMajor and c.Status != Enums.Status.Dead)
	_check(hideout != null and victim != null, "a Rebel major and a hideout world exist")
	if _fails > 0:
		_finish(); return

	victim.Status = Enums.Status.AwaitingOrders
	victim.CapturedBy = null
	MilitaryCatalog.Relocate(victim, hideout)
	# The Empire legitimately KNOWS the major is here — it captured Characters intel.
	IntelManager.Capture(empire, hideout, StrategicTickManager.Today, [Enums.IntelCategory.Characters])
	_check(IntelManager.Knows(empire, hideout, Enums.IntelSection.Characters), "Empire has Characters intel on %s" % hideout.Name)
	_check(MissionManager.CanTargetPerson(Enums.MissionType.Abduction, empire, victim).ok, "the major is a legal abduction victim")

	# --- Run the new brain for one day -------------------------------------
	var before := _abductions_by(empire)
	AiManager.ProcessDay(GameState.ActiveGalaxy, StrategicTickManager.Today, Prng.Session)
	var after := _active_abductions_by(empire)
	_check(after.size() > before, "the AI launched an Abduction (had %d, now %d)" % [before, after.size()])

	# The Launch call carried a real victim and a non-empty team (not the old 4-of-7).
	var hit: Mission = null
	for m in after:
		if m.TargetCharacter == victim:
			hit = m
			break
	_check(hit != null, "an Abduction targets the Rebel major by name")
	if hit != null:
		_check(hit.TargetCharacter != null, "Launch received a victim argument")
		_check(hit.Team.size() >= 1 and hit.Team[0].Faction == empire, "Launch received an Imperial team")
		print("  [args] Abduction team=%d victim=%s target=%s" % [hit.Team.size(), hit.TargetCharacter.Name, hit.Target.Name])

	# Sanity: the operative can, in principle, reach many mission types (old AI: 6).
	var reachable := MissionManager.PerformableBy([spy]).size()
	_check(reachable >= 6, "the operative can perform %d mission types" % reachable)

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


func _free_character(f: Faction, at: Planet) -> Character:
	# Prefer one already free at the seat; otherwise draft one there.
	for c in GameState.ActiveRoster:
		if c.Faction == f and c.Status == Enums.Status.AwaitingOrders and c.Attached == at and not c.IsCaptured():
			return c
	for c in GameState.ActiveRoster:
		if c.Faction == f and c.Status != Enums.Status.Dead and not c.IsCaptured():
			c.Status = Enums.Status.AwaitingOrders
			MilitaryCatalog.Relocate(c, at)
			return c
	return null


func _abductions_by(f: Faction) -> int:
	return _active_abductions_by(f).size()


func _active_abductions_by(f: Faction) -> Array:
	return Lq.where(MissionManager.Active(), func(m): return m.Faction == f and m.Type == Enums.MissionType.Abduction)


func _finish() -> void:
	print("[ai_missions] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
