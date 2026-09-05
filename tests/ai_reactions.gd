extends SceneTree
## M4 VERIFY (BUILD-PLAN.md): EventBus events REPRIORITISE the AI's plan without
## spending budget (AR-4). An uprising on our world raises urgency to subdue it
## (RULE-06-09); an uprising on an enemy world is an opening (RULE-06-12); a battle
## report is a fog-legal inference, not an interrupt (RULE-09-03).
##
##   Godot_console.exe --headless --path . -s tests/ai_reactions.gd

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
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var empire: Faction = FactionRegistry.ById("empire")
	var alliance: Faction = FactionRegistry.ById("alliance")

	# new_game -> AiManager.Reset -> AIReactions.Reset (unsubscribed). Re-subscribe.
	AIReactions.Subscribe()

	var mine: Planet = _first(func(p): return p.ControllingFaction == empire)
	var theirs: Planet = _first(func(p): return p.ControllingFaction == alliance)
	_check(mine != null and theirs != null, "an Imperial and a Rebel world exist")
	if mine == null or theirs == null:
		_finish(); return

	# Baseline: no events -> no urgency.
	var ctx0 := AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today)
	AIReactions.Apply(ctx0)
	_check(AIReactions.urgency_for(ctx0, "defend_own", mine) == 0, "no urgency before any event")

	# Fire an uprising on OUR world -> defend_own interrupt, high urgency (RULE-06-09).
	_tell(empire, Enums.MessageType.Uprising, mine)
	var ctx1 := AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today)
	AIReactions.Apply(ctx1)
	_check(AIReactions.urgency_for(ctx1, "defend_own", mine) == AIReactions.U_DEFEND_OWN,
		"our uprising raises defend_own urgency to %d" % AIReactions.U_DEFEND_OWN)

	# Fire an uprising on THEIR world -> enemy_window opening (RULE-06-12).
	_tell(empire, Enums.MessageType.Uprising, theirs)
	var ctx2 := AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today)
	AIReactions.Apply(ctx2)
	_check(AIReactions.urgency_for(ctx2, "enemy_window", theirs) == AIReactions.U_ENEMY_WINDOW,
		"an enemy uprising is an opening (urgency %d)" % AIReactions.U_ENEMY_WINDOW)

	# A battle report is a fog-legal INFERENCE, not an interrupt (RULE-09-03).
	_tell(empire, Enums.MessageType.TacticalAfterActionReport, theirs)
	var ctx3 := AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today)
	AIReactions.Apply(ctx3)
	_check(ctx3.Inferences.get(theirs, "") == "battle-observed", "battle report recorded as an inference")
	_check(AIReactions.urgency_for(ctx3, "defend_own", theirs) == 0, "a battle report raises no interrupt")

	# AR-4: applying events must NOT launch anything or move state — it only writes ctx.
	var missions_before := MissionManager.Active().size()
	var ctx4 := AIContext.Build(GameState.ActiveGalaxy, empire, StrategicTickManager.Today)
	_tell(empire, Enums.MessageType.Uprising, mine)
	AIReactions.Apply(ctx4)
	_check(MissionManager.Active().size() == missions_before, "Apply reprioritises but does not spend (AR-4)")

	# Human faction's events are not queued (its queue would never drain).
	_tell(alliance, Enums.MessageType.Uprising, theirs)
	var ctxA := AIContext.Build(GameState.ActiveGalaxy, alliance, StrategicTickManager.Today)
	AIReactions.Apply(ctxA)
	_check(ctxA.Interrupts.is_empty(), "no interrupts queued for the human faction")

	AIReactions.Reset()
	_finish()


func _tell(to: Faction, type: int, where: Planet) -> void:
	var m := GameMessage.new("evt", "evt", Enums.MessageCategory.Conflict, StrategicTickManager.Today, where, null)
	m.Type = type
	EventBus.Tell(to, m)


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _finish() -> void:
	print("[ai_reactions] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
