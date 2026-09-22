extends SceneTree
## THE BUILT-IN AI READS WHAT IT SAW, NOT WHAT IS TRUE TODAY. IntelManager.Knows only
## says "we saw this once"; every read below used to go on from there to the LIVE
## world - today's support, facilities, hulls and people on a world scouted long ago.
## Each case takes a sighting, changes the world behind it, and checks the AI still
## believes the sighting - then looks again and checks it now believes the new one.
##
##   Godot_console.exe --headless --path . -s tests/ai_fog.gd

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
	var today: int = StrategicTickManager.Today

	var seat: Planet = _first(func(p): return p.ControllingFaction == empire)
	var spy: Character = _first_char(func(c): return c.Faction == empire and c.Status != Enums.Status.Dead and not c.IsCaptured())
	# A Rebel world that is NOT their headquarters, with a Rebel fleet over it if one exists.
	var world: Planet = _first(func(p): return p.ControllingFaction == alliance and not p.HasHeadquarters() \
		and Lq.any(p.OrbitingFleets, func(f): return f.Faction == alliance and not f.IsEmpty() and f.Status != Enums.Status.Enroute))
	if world == null:
		world = _first(func(p): return p.ControllingFaction == alliance and not p.HasHeadquarters())
	_check(seat != null and spy != null and world != null, "an Imperial seat, an Imperial agent and a Rebel world exist")
	if _fails > 0:
		_finish(); return
	spy.Status = Enums.Status.AwaitingOrders
	MilitaryCatalog.Relocate(spy, seat)

	# --- 1. THE CONTEXT SPLIT (ai_context.gd Build) and 2. SeenSupportFor ------------
	world.SetSupportFor(alliance, 90)
	IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)
	var seen_support: int = _ctx(empire).SeenSupportFor(world, alliance)
	_check(world in _ctx(empire).TheirsStrong, "seen at %d%%: %s is one of THEIR STRONG worlds" % [seen_support, world.Name])
	world.SetSupportFor(alliance, 10)
	var live_support: int = world.SupportFor(alliance)
	_check(live_support < AIContext.WeakSupportCeiling, "its support has since fallen to %d%%" % live_support)
	var ctx := _ctx(empire)
	_check(world in ctx.TheirsStrong and not (world in ctx.TheirsWeak), "...and we have not looked: it is still one of their STRONG worlds to us")
	_check(ctx.SeenSupportFor(world, alliance) == seen_support, "SeenSupportFor is what we saw (%d), not today's %d" % [seen_support, live_support])

	# 6. THE ODDS (_estimate_success): the engine's formula over what we saw.
	var est_seen: int = AIActionSelection._estimate_success(ctx, Enums.MissionType.InciteUprising, [spy], world, null)
	world.SetSupportFor(alliance, 90)   # back to what we saw: the live odds ARE the seen odds
	var est_same: int = _live_odds(empire, Enums.MissionType.InciteUprising, spy, world)
	world.SetSupportFor(alliance, 10)
	var est_live: int = _live_odds(empire, Enums.MissionType.InciteUprising, spy, world)
	_check(est_seen == est_same, "an uprising there is priced from the sighting (%d%% == %d%%)" % [est_seen, est_same])
	print("  [odds] incite at %s: %d%% from what we saw, %d%% if we could see today" % [world.Name, est_seen, est_live])

	IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)
	ctx = _ctx(empire)
	_check(world in ctx.TheirsWeak, "we look again: now it is one of their WEAK worlds")
	_check(AIActionSelection._estimate_success(ctx, Enums.MissionType.InciteUprising, [spy], world, null) == est_live,
		"...and the uprising is priced at today's odds (%d%%)" % est_live)

	# A world that is CHARTED and nothing more (an espionage leak does this): we do not
	# know whose it is, so it is a world to go and look at - not neutral, not theirs.
	var dark: Planet = _first(func(p): return p.IsInhabited and not p.ExploredBy(empire) and p.ControllingFaction != empire)
	if dark != null:
		dark.SetExplored(empire, true)
		ctx = _ctx(empire)
		_check(dark in ctx.Unexplored, "%s is charted but never seen: still unknown to us" % dark.Name)
		_check(not (dark in ctx.Neutral) and not (dark in ctx.TheirsWeak) and not (dark in ctx.TheirsStrong), "...and in no list that reads its owner")

	# --- 3. + 8. PEOPLE (_enemy_target_characters, AIObjectives._target_located) -------
	var names: Array = VictoryManager.CaptureTargets(empire)
	var victim: Character = _first_char(func(c): return c.Faction == alliance and names.has(c.PackId) and c.Status != Enums.Status.Dead)
	_check(victim != null, "a Rebel the Empire must capture exists")
	if victim != null:
		var elsewhere: Planet = _first(func(p): return p != world and p.ControllingFaction == alliance and not p.HasHeadquarters())
		victim.Status = Enums.Status.AwaitingOrders
		victim.CapturedBy = null
		MilitaryCatalog.Relocate(victim, elsewhere if elsewhere != null else seat)
		IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)   # we see who is on `world` - not them
		MilitaryCatalog.Relocate(victim, world)                                      # ...and then they walk onto it
		ctx = _ctx(empire)
		_check(IntelManager.Knows(empire, world, Enums.IntelSection.Characters), "we have seen who is on %s" % world.Name)
		_check(not AIActionSelection._enemy_target_characters(ctx, Enums.MissionType.Abduction).has(victim),
			"%s arrived AFTER we looked: not an abduction target" % victim.Name)
		_check(not AIObjectives._target_located(ctx, victim.PackId), "...and not 'located' to the objectives stage")
		IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)
		ctx = _ctx(empire)
		_check(AIActionSelection._enemy_target_characters(ctx, Enums.MissionType.Abduction).has(victim), "we look again and see them: now a target")
		_check(AIObjectives._target_located(ctx, victim.PackId), "...and located")
		# Seen there, then GONE: not offered at the old address (and not at the new one).
		MilitaryCatalog.Relocate(victim, elsewhere if elsewhere != null else seat)
		ctx = _ctx(empire)
		_check(not AIActionSelection._enemy_target_characters(ctx, Enums.MissionType.Abduction).has(victim), "they leave: no longer a target anywhere we have not seen them")

	# --- 4. FACILITIES (_sabotage_targets) ---------------------------------------------
	var yards_seen: int = world.CountOf("shipyard")
	var shields_seen: int = world.CountOf("planetary_shield")
	IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)
	world.AddFacility("shipyard")          # both built AFTER we looked
	world.AddFacility("planetary_shield")
	ctx = _ctx(empire)
	_check(_offered(ctx, world, "shipyard") == yards_seen, "a shipyard built since we looked is not a sabotage target (%d seen, %d offered)" % [yards_seen, _offered(ctx, world, "shipyard")])
	_check(_offered(ctx, world, "planetary_shield") == shields_seen, "nor is the new shield (%d seen)" % shields_seen)
	IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)
	ctx = _ctx(empire)
	_check(_offered(ctx, world, "shipyard") == yards_seen + 1, "we look again: the new shipyard is a target")
	_check(_offered(ctx, world, "planetary_shield") == shields_seen + 1, "...and the new shield")

	# --- 5. HULLS (_seen_defending_ships) ----------------------------------------------
	var hulls_seen: int = AIActionSelection._seen_defending_ships(ctx, world)
	_check(hulls_seen >= 0, "we have seen the orbit of %s (%d hulls)" % [world.Name, hulls_seen])
	for f: Fleet in world.OrbitingFleets:
		if f.Faction == alliance:
			f.Ships.clear()                                  # the fleet is gone today
	ctx = _ctx(empire)
	_check(AIActionSelection._seen_defending_ships(ctx, world) == hulls_seen, "the fleet has left since: we still count the %d hulls we saw" % hulls_seen)
	IntelManager.Capture(empire, world, today, IntelManager.EspionageCategories)
	_check(AIActionSelection._seen_defending_ships(_ctx(empire), world) == 0, "we look again: none")
	var unseen: Planet = _first(func(p): return p.ControllingFaction == alliance and not IntelManager.Knows(empire, p, Enums.IntelSection.OrbitingShips))
	if unseen != null:
		_check(AIActionSelection._seen_defending_ships(_ctx(empire), unseen) == -1, "an orbit we never saw is -1 (do not commit blind)")

	# --- 7. THE HIDDEN HEADQUARTERS (AIObjectives._rebel_hq_known) ----------------------
	var hq: Planet = _first(func(p): return p.ControllingFaction == alliance and p.HasHeadquarters())
	_check(hq != null and not hq.ExploredBy(empire), "the Rebel headquarters starts unknown to the Empire")
	if hq != null:
		hq.SetExplored(empire, true)   # charted only - what the old gate (ExploredBy) took for "found"
		_check(AIObjectives._rebel_hq_known(_ctx(empire), alliance, GameState.ActiveGalaxy) == null, "charting %s does not find the headquarters on it" % hq.Name)
		IntelManager.Capture(empire, hq, today, IntelManager.ReconnaissanceCategories)
		_check(AIObjectives._rebel_hq_known(_ctx(empire), alliance, GameState.ActiveGalaxy) == hq, "a reconnaissance that SEES the building does")

	_finish()


func _ctx(us: Faction) -> AIContext:
	return AIContext.Build(GameState.ActiveGalaxy, us, StrategicTickManager.Today)


## What the ENGINE would roll today (MissionManager.SuccessPercent over the live world).
func _live_odds(us: Faction, type: int, op: Unit, target: Planet) -> int:
	var m := Mission.new()
	m.Type = type
	m.Faction = us
	m.Target = target
	return MissionManager.SuccessPercent(m, MissionManager.AttributeFor(type, op))


func _offered(ctx: AIContext, where: Planet, type: String) -> int:
	return Lq.count(AIActionSelection._sabotage_targets(ctx), func(t: Dictionary): return t["where"] == where and (t["obj"] as Facility).Family() == type)


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


func _finish() -> void:
	print("[ai_fog] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
