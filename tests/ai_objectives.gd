extends SceneTree
## M3 VERIFY (BUILD-PLAN.md, R2D2's criterion): the objective layer defers the HQ
## objective while capture targets remain (RULE-10-12, Hard tier only), and activates
## HQ pursuit once they are complete. Also checks the Easy/Medium contrast: those
## tiers pursue the HQ in parallel (a fixed order, OURS).
##
##   Godot_console.exe --headless --path . -s tests/ai_objectives.gd

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
	# Human Alliance -> Empire is the AI. The Empire has BOTH a capture list and a
	# hidden-HQ search, so RULE-10-12's ordering is observable on it.
	GameSession.new_game("alliance", Enums.Difficulty.Hard, Enums.GalaxySize.Standard, 4243)
	var empire: Faction = FactionRegistry.ById("empire")
	var caps: Array = VictoryManager.CaptureTargets(empire)
	_check(caps.size() >= 1, "the Empire has capture targets (%d)" % caps.size())
	if caps.is_empty():
		_finish(); return

	# Locate the first capture target: park it on a world and give the Empire
	# Characters intel there (fog-legal knowledge of its location).
	var first_name: String = caps[0]
	var victim: Character = _char_named(first_name)
	var world: Planet = _first(func(p): return p != null)
	_check(victim != null and world != null, "target '%s' and a world exist" % first_name)
	if victim == null:
		_finish(); return
	victim.CapturedBy = null
	victim.Status = Enums.Status.AwaitingOrders
	MilitaryCatalog.Relocate(victim, world)
	IntelManager.Capture(empire, world, StrategicTickManager.Today, [Enums.IntelCategory.Characters])

	# --- PLAN A: Hard, capture target located, still uncaptured -------------
	var a := AIObjectives.Compute(AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today))
	_check(a.state == AIObjectives.State.CHARS_LOCATED_NOT_CAPTURED, "state is CHARS_LOCATED_NOT_CAPTURED (got %d)" % a.state)
	var missions_w: int = int(a.weights.get(CandidateAction.Loop.Missions, 0))
	var combat_w: int = int(a.weights.get(CandidateAction.Loop.Combat, 0))
	_check(missions_w >= 400, "missions weight is high (%d)" % missions_w)
	_check(int(a.type_weights.get(Enums.MissionType.Abduction, 0)) >= 500, "Abduction is boosted")
	# RULE-10-12: at Hard, HQ pursuit (Combat) ranks LAST while captures remain.
	_check(combat_w == 0, "HQ/combat pursuit deferred at Hard while captures remain (combat=%d)" % combat_w)
	_check(missions_w > combat_w, "capturing outranks HQ pursuit (missions %d > combat %d)" % [missions_w, combat_w])

	# --- PLAN B: captures complete -> HQ becomes the bottleneck -------------
	for n in caps:
		var c := _char_named(n)
		if c != null:
			c.CapturedBy = empire   # simulate holding every capture target
	var b := AIObjectives.Compute(AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today))
	_check(b.state == AIObjectives.State.HQ_UNKNOWN or b.state == AIObjectives.State.HQ_LOCATED_NOT_REDUCED,
		"with captures done, HQ is the bottleneck (state %d)" % b.state)
	var hq_pursuit := int(b.weights.get(CandidateAction.Loop.Combat, 0)) \
		+ int(b.type_weights.get(Enums.MissionType.Reconnaissance, 0)) \
		+ int(b.weights.get(CandidateAction.Loop.Missions, 0))
	_check(hq_pursuit > 0, "HQ pursuit activates once captures are done (%d)" % hq_pursuit)

	# --- MEDIUM CONTRAST: no RULE-10-12, so HQ is pursued in parallel while
	# captures remain (Hard deferred it to 0 above). Easy has no ordering at all
	# (covered by tests/ai_tiers.gd), so the RULE-10-12 contrast lives at Medium. ---
	for n in caps:
		var c := _char_named(n)
		if c != null:
			c.CapturedBy = null   # restore "uncaptured"
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	var med := AIObjectives.Compute(AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today))
	_check(int(med.weights.get(CandidateAction.Loop.Combat, 0)) > 0, "Medium pursues the HQ in parallel — no RULE-10-12 deferral (combat=%d)" % int(med.weights.get(CandidateAction.Loop.Combat, 0)))

	_finish()


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _char_named(name: String) -> Character:
	return Lq.first_or_null(GameState.ActiveRoster, func(c): return c.Name == name)


func _finish() -> void:
	print("[ai_objectives] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
