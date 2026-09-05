class_name AIActionSelection
extends RefCounted
## STAGE: ACTION SELECTION — propose, score, pick (docs/ai-framework/01-architecture.md).
## The five operational policies (economy/fleet/missions/diplomacy/combat) each emit
## CandidateActions; this stage scores them against the objective bottleneck weight
## and spends the per-day budget on the best. Replaces the old Preferred() list —
## six findings traced to that one decision, so it is removed, not patched.
##
## Budgets are OURS per-tier throttles (AITiers): "missions" (launches), "ships"
## (builds), "moves" (fleet movement AND assault — so difficulty has grip on combat,
## the P2 fix). All scoring magnitudes are OURS-design ranking seeds (BASE_VALUE) or
## engine-derived (success % from mission_manager); M3 objective weights bias them.
## Two-kind rule: every constant here is labelled OURS or cites its engine source.

# OURS-design base worth of each mission type (fixed-point, CandidateAction.SCALE).
# Ranking seeds only; the M3 objective layer's weights dominate. Ordered by strategic
# value: character captures (victory conditions) highest, intel next, then expansion.
const BASE_VALUE := {
	Enums.MissionType.Abduction: 900,
	Enums.MissionType.Rescue: 850,
	Enums.MissionType.DeathStarSabotage: 700,
	Enums.MissionType.Assassination: 600,
	Enums.MissionType.Sabotage: 520,
	Enums.MissionType.Espionage: 460,
	Enums.MissionType.Reconnaissance: 420,
	Enums.MissionType.Diplomacy: 410,
	Enums.MissionType.InciteUprising: 360,
	Enums.MissionType.SubdueUprising: 320,
	Enums.MissionType.Recruitment: 300,
	Enums.MissionType.ShipDesignResearch: 300,
	Enums.MissionType.TroopTrainingResearch: 300,
	Enums.MissionType.FacilityDesignResearch: 300,
	Enums.MissionType.JediTraining: 250,
}

const DEFAULT_SUCCESS := 50   # OURS: estimate when a type has no shipped odds table


## STAGE ENTRY. Run one faction's daily action selection against its plan/budget.
static func Run(ctx: AIContext, plan: AIObjectives.Plan, rng: Prng) -> void:
	var tier := AITiers.For(ctx.Us)
	var budget := {"moves": tier.MovesPerDay, "missions": tier.MissionsPerDay, "ships": tier.ShipsPerDay}
	var candidates := _propose(ctx, plan, rng)
	candidates.sort_custom(CandidateAction.Better)   # deterministic total order (A2)
	_spend(candidates, budget)


## Gather CandidateActions from every operational policy.
static func _propose(ctx: AIContext, plan: AIObjectives.Plan, rng: Prng) -> Array:
	var out: Array = []
	out.append_array(_propose_missions(ctx, plan))
	out.append_array(_propose_economy(ctx, plan))
	out.append_array(_propose_fleet(ctx, plan))
	out.append_array(_propose_combat(ctx, plan, rng))
	out.append_array(_propose_defense(ctx, plan))
	return out


# ===========================================================================
# DEFENSE policy — RULE-09-04 (Medium+): the Alliance relocates its (movable) HQ
# off a threatened seat. The mechanic + blockade pin are built (order_manager.gd
# MoveHeadquarters); this is the AI USE deferred from P4. The Empire's Coruscant
# is not Movable, so this yields nothing for it. Prophylactic-timer relocation
# (RULE-11-01) and fallback-sector choice (RULE-11-02, RULE-09-05) are Hard-tier
# refinements handled at M5.
# ===========================================================================

static func _propose_defense(ctx: AIContext, plan: AIObjectives.Plan) -> Array:
	var out: Array = []
	var us := ctx.Us
	if us.Hq == null or not us.Hq.Movable:
		return out   # only a hidden, movable HQ (the Alliance) can relocate
	if GameSettings.SelectedDifficulty == Enums.Difficulty.Easy:
		return out   # RULE-09-04 is Medium+ (OURS tiering)
	var seat := _hq_seat(us)
	if seat == null or not (seat in ctx.Threatened):
		return out   # reactive: only when the seat is actually threatened
	if BlockadeManager.IsBlockaded(seat):
		return out   # pinned — cannot relocate (the engine would reject it anyway)
	var safe := Lq.where(ctx.Held, func(p): return p != seat and not (p in ctx.Threatened) and not BlockadeManager.IsBlockaded(p))
	if safe.is_empty():
		return out
	var dest := _nearest_of(seat, safe)
	var c := CandidateAction.new()
	c.loop = CandidateAction.Loop.Fleet
	c.kind = "relocate_hq"
	c.budget_key = "moves"
	c.expected_value = 300      # OURS
	c.urgency = 500             # OURS — the HQ is a victory condition under threat
	c.objective_fit = _objective_fit(plan, c.loop, -1, dest)
	c.justification = "relocate HQ off threatened %s to %s (RULE-09-04)" % [seat.Name, dest.Name]
	c.tb_type = 4
	c.tb_target = dest.get_instance_id()
	c.action = func() -> bool:
		return OrderManager.MoveHeadquarters(us, dest).ok
	out.append(c)
	return out


static func _hq_seat(us: Faction) -> Planet:
	for p in GameState.AllPlanets():
		if p.HasHeadquarters() and p.ControllingFaction == us:
			return p
	return null


## Execute the best affordable candidates until each budget bucket is exhausted.
static func _spend(candidates: Array, budget: Dictionary) -> void:
	for c in candidates:
		var key: String = c.budget_key
		if not budget.has(key) or budget[key] < c.budget_cost:
			continue
		if c.action.is_valid() and c.action.call():
			budget[key] -= c.budget_cost
		# a candidate whose action failed does not spend budget — try the next.


# ===========================================================================
# MISSIONS / DIPLOMACY policy — every legal mission type, teams passed properly.
# ===========================================================================

static func _propose_missions(ctx: AIContext, plan: AIObjectives.Plan) -> Array:
	var out: Array = []
	var operatives: Array = ctx.FreeCharacters + ctx.FreeSpecForces
	for op in operatives:
		if not (op.Attached is Planet):
			continue
		for type in MissionManager.PerformableBy([op]):
			var pick = _best_mission_target(ctx, type, op)
			if pick == null:
				continue
			var team := _team_for(ctx, type, op)
			out.append(_mission_candidate(ctx, plan, type, team, op, pick))
	return out


## High-value captures/sabotage get a second operative from the same world when one
## can also perform the mission — RULE-06-05 "concentrate" for the missions that
## most reward it. Team members are marked busy on Launch, so no double-use. Decoys
## (RULE-05-10) are deferred to M5: the engine does not mark a decoy busy, so naive
## auto-decoying could double-commit a unit — a competence lever handled deliberately.
static func _team_for(ctx: AIContext, type: int, op) -> Array:
	var team: Array = [op]
	if not _is_high_value(type):
		return team
	var here = op.Attached
	for other in (ctx.FreeCharacters + ctx.FreeSpecForces):
		if other == op or other.Attached != here:
			continue
		if MissionManager.TeamCanPerform([op, other], type):
			return [op, other]
	return team


static func _is_high_value(type: int) -> bool:
	return type == Enums.MissionType.Abduction or type == Enums.MissionType.Assassination \
		or type == Enums.MissionType.Rescue or type == Enums.MissionType.Sabotage \
		or type == Enums.MissionType.DeathStarSabotage


## Choose ONE target for (operative, type) by a cheap heuristic, then the candidate
## is scored once. Returns a small dict {target, victim, sab} or null. Keeps the
## per-day proposal bounded (operatives x types), not O(x targets).
static func _best_mission_target(ctx: AIContext, type: int, op) -> Variant:
	var from: Planet = op.Attached
	match type:
		Enums.MissionType.Diplomacy:
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.Neutral + ctx.OursWeak))
		Enums.MissionType.Espionage:
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.TheirsWeak + ctx.TheirsStrong))
		Enums.MissionType.Reconnaissance:
			# Recon can go to unexplored — the Empire's HQ search leans on this.
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.Unexplored + ctx.TheirsWeak + ctx.TheirsStrong + ctx.Neutral))
		Enums.MissionType.InciteUprising:
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.TheirsWeak + ctx.TheirsStrong))
		Enums.MissionType.SubdueUprising:
			var mine_revolting := Lq.where(ctx.Held, func(p): return p.IsInUprising)
			return _wrap(_nearest_legal(type, ctx.Us, from, mine_revolting))
		Enums.MissionType.Recruitment:
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.Held))
		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.Held))
		Enums.MissionType.JediTraining:
			return _wrap(_nearest_legal(type, ctx.Us, from, ctx.Held))
		Enums.MissionType.Abduction, Enums.MissionType.Assassination:
			var v = _best_enemy_target_character(ctx, type)
			if v == null:
				return null
			return {"target": v.Attached, "victim": v, "sab": null}
		Enums.MissionType.Rescue:
			var cap = _best_rescue_target(ctx)
			if cap == null:
				return null
			return {"target": cap.Attached, "victim": cap, "sab": null}
		Enums.MissionType.Sabotage:
			var s = _best_sabotage_target(ctx)
			if s == null:
				return null
			return {"target": s["where"], "victim": null, "sab": s["obj"]}
		Enums.MissionType.DeathStarSabotage:
			var known := Lq.where(ctx.TheirsWeak + ctx.TheirsStrong, func(p): return MissionManager.CanTarget(type, ctx.Us, p).ok)
			return _wrap(_nearest_of(from, known))
	return null


static func _wrap(target) -> Variant:
	if target == null:
		return null
	return {"target": target, "victim": null, "sab": null}


static func _mission_candidate(ctx: AIContext, plan: AIObjectives.Plan, type: int, team: Array, op, pick: Dictionary) -> CandidateAction:
	var target: Planet = pick["target"]
	var victim = pick["victim"]
	var sab = pick["sab"]
	var c := CandidateAction.new()
	c.loop = _loop_of(type)
	c.kind = "mission:%s" % JsonUtil.enum_name(Enums.MissionType, type)
	c.budget_key = "missions"
	var est := _estimate_success(type, team, target, victim)
	var base: int = BASE_VALUE.get(type, 300)
	c.expected_value = base * est / 100
	c.objective_fit = _objective_fit(plan, c.loop, type, target)
	c.asset_risk = 0   # RULE-05-03 (risk the best characters less) deferred to M5; flagged
	# Reactions reprioritise (AR-4): an uprising/garrison-warning on our world makes
	# subduing it urgent (RULE-06-09); an enemy uprising is an opening (RULE-06-12).
	if type == Enums.MissionType.SubdueUprising:
		c.urgency = AIReactions.urgency_for(ctx, "defend_own", target)
	elif type == Enums.MissionType.InciteUprising:
		c.urgency = AIReactions.urgency_for(ctx, "enemy_window", target)
	c.justification = "%s vs %s (est %d%%)" % [c.kind, target.Name if target != null else "?", est]
	c.tb_type = type
	c.tb_target = target.get_instance_id() if target != null else 0
	c.tb_actor = op.get_instance_id()
	var from: Planet = op.Attached
	c.action = func() -> bool:
		# Re-validate at execution: another candidate this turn may have moved state.
		if MissionManager.IsOnMissionTeam(op):
			return false
		if _mission_already_active(ctx.Us, type, target):
			return false
		return MissionManager.Launch(type, team, from, target, null, victim, sab) != null
	return c


static func _estimate_success(type: int, team: Array, target: Planet, victim) -> int:
	var m := Mission.new()
	m.Type = type
	m.Faction = team[0].Faction
	m.Target = target
	m.TargetCharacter = victim
	var rating := 0
	for u in team:
		rating = max(rating, MissionManager.AttributeFor(type, u))
	var pct := MissionManager.SuccessPercent(m, rating)
	return pct if pct >= 0 else DEFAULT_SUCCESS


static func _mission_already_active(us: Faction, type: int, target: Planet) -> bool:
	return Lq.any(MissionManager.Active(), func(m): return m.Faction == us and m.Type == type and m.Target == target)


## Highest-value enemy character whose LOCATION we legitimately know (intel-gated:
## we hold Characters intel on the planet they are on). Fog-legal (BUILD-PLAN F-flag).
static func _best_enemy_target_character(ctx: AIContext, type: int):
	var best = null
	var best_score := -1
	for ch in GameState.ActiveRoster:
		if ch.Faction == null or ch.Faction == ctx.Us:
			continue
		if not (ch.Attached is Planet):
			continue
		var where: Planet = ch.Attached
		if not IntelManager.Knows(ctx.Us, where, Enums.IntelSection.Characters):
			continue   # we don't legitimately know this character is here
		if not MissionManager.CanTargetPerson(type, ctx.Us, ch).ok:
			continue
		if not MissionManager.CanTarget(type, ctx.Us, where).ok:
			continue
		# Majors (victory-condition characters) are worth more.
		var s := (100 if ch.IsMajor else 10) + ch.CombatRating
		if s > best_score or (s == best_score and best != null and ch.get_instance_id() < best.get_instance_id()):
			best_score = s
			best = ch
	return best


## Our own captured character we could rescue (its holding location known to us).
static func _best_rescue_target(ctx: AIContext):
	for ch in GameState.ActiveRoster:
		if ch.Faction == ctx.Us and ch.IsCaptured() and ch.Attached is Planet:
			if MissionManager.CanTargetPerson(Enums.MissionType.Rescue, ctx.Us, ch).ok:
				return ch
	return null


## A legal enemy sabotage object (facility or unit) on a world we have intel on.
static func _best_sabotage_target(ctx: AIContext):
	for p in ctx.TheirsWeak + ctx.TheirsStrong:
		if not IntelManager.Knows(ctx.Us, p, Enums.IntelSection.ProductionFacilities):
			continue
		for f in p.Facilities:
			if MissionManager.CanSabotage(ctx.Us, f, p).ok:
				return {"where": p, "obj": f}
	return null


static func _loop_of(type: int) -> int:
	match type:
		Enums.MissionType.Diplomacy, Enums.MissionType.InciteUprising, Enums.MissionType.SubdueUprising:
			return CandidateAction.Loop.Diplomacy
	return CandidateAction.Loop.Missions


## The objective bottleneck's bias for this candidate: its loop weight plus, for a
## mission, any per-mission-type weight the M3 plan set (e.g. Abduction when capture
## targets are located). type < 0 for non-mission candidates.
static func _objective_fit(plan: AIObjectives.Plan, loop: int, type: int, _target: Planet) -> int:
	if plan == null:
		return 0
	var fit := int(plan.weights.get(loop, 0))
	if type >= 0:
		fit += int(plan.type_weights.get(type, 0))
	return fit


# ===========================================================================
# Targeting helpers (fog-legal: operate on lists Context already gated).
# ===========================================================================

static func _nearest_legal(type: int, us: Faction, from: Planet, pool: Array) -> Planet:
	var legal := Lq.where(pool, func(p): return MissionManager.CanTarget(type, us, p).ok)
	return _nearest_of(from, legal)


static func _nearest_of(from: Planet, pool: Array) -> Planet:
	if pool.is_empty():
		return null
	var sorted := Lq.order_by(pool, func(p): return from.DeploymentDaysTo(p))
	return sorted[0]


# ===========================================================================
# ECONOMY policy — build the most capable hull the maintenance budget allows.
# Ported from the original's BuildWarships; the maintenance gate is the game's
# (FUN_0052e970), the hull choice is OURS.
# ===========================================================================

static func _propose_economy(ctx: AIContext, plan: AIObjectives.Plan) -> Array:
	var out: Array = []
	var yards := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == ctx.Us and p.HasIdleShipyards())
	var by_size := Lq.order_by(yards, func(p): return p.Shipyards(), true)
	if by_size.is_empty():
		return out
	var yard: Planet = by_size[0]
	var headroom := Economy.MaintenanceAvailable(ctx.Us)
	var affordable := Lq.where(MilitaryCatalog.All(), func(u): return u.Type == "CapitalShip" and MilitaryCatalog.CanBeBuiltBy(u, ctx.Us) and u.MaintenanceCost <= headroom)
	var picks := Lq.order_by(affordable, func(u): return u.ConstructionCost, true)
	if picks.is_empty():
		return out
	var pick = picks[0]
	var c := CandidateAction.new()
	c.loop = CandidateAction.Loop.Economy
	c.kind = "build:%s" % pick.Name
	c.budget_key = "ships"
	c.expected_value = 300   # OURS ranking seed; economy underpins everything
	c.objective_fit = _objective_fit(plan, c.loop, -1, null)
	c.justification = "lay down %s at %s (maint %d of %d free)" % [pick.Name, yard.Name, pick.MaintenanceCost, headroom]
	c.tb_type = 0
	c.tb_target = yard.get_instance_id()
	c.action = func() -> bool:
		return yard.TryQueueUnit(pick, yard).ok
	out.append(c)
	return out


# ===========================================================================
# FLEET policy — relieve threatened worlds; press weak enemy worlds. Ported from
# the original's MoveFleets, in candidate form. Movement spends "moves".
# ===========================================================================

static func _propose_fleet(ctx: AIContext, plan: AIObjectives.Plan) -> Array:
	var out: Array = []
	var idle: Array = ctx.IdleFleets.duplicate()

	# 1. RELIEVE THREATENED WORLDS, weakest first (defensive — high urgency).
	for target in Lq.order_by(ctx.Threatened, func(p): return _strength_at(p, ctx.Us)):
		var relief := _nearest_fleet(idle, target)
		if relief == null:
			continue
		out.append(_move_candidate(ctx, plan, relief, target, 700, "relieve threatened %s" % target.Name))

	# 2. PRESS WEAK ENEMY WORLDS we can see to be beatable (offensive).
	for target in ctx.TheirsWeak:
		var defending := _seen_defending_ships(ctx.Us, target)
		if defending < 0:
			continue   # we cannot see the defence — do not commit blind
		var strike := _nearest_fleet(idle, target)
		if strike == null:
			continue
		if strike.Ships.size() < defending:
			continue
		if not _can_afford_to_commit(ctx.Us, strike):
			continue
		out.append(_move_candidate(ctx, plan, strike, target, 380, "press weak %s (%d seen defending)" % [target.Name, defending]))
	return out


static func _move_candidate(ctx: AIContext, plan: AIObjectives.Plan, fleet: Fleet, target: Planet, base: int, why: String) -> CandidateAction:
	var c := CandidateAction.new()
	c.loop = CandidateAction.Loop.Fleet
	c.kind = "move"
	c.budget_key = "moves"
	c.expected_value = base
	c.objective_fit = _objective_fit(plan, c.loop, -1, target)
	# Reactions reprioritise (AR-4): relieve a world under an uprising/garrison warning
	# more urgently; press an enemy world that just revolted (an opening).
	c.urgency = AIReactions.urgency_for(ctx, "defend_own", target) + AIReactions.urgency_for(ctx, "enemy_window", target)
	c.justification = why
	c.tb_type = 1
	c.tb_target = target.get_instance_id()
	c.tb_actor = fleet.get_instance_id()
	c.action = func() -> bool:
		if _already_answered(target, ctx.Us):
			return false
		return OrderManager.MoveFleets([fleet], target).ok
	return c


static func _strength_at(p: Planet, f: Faction) -> int:
	var ships := Lq.sum(Lq.where(p.FleetsInOrbit(), func(x): return x.Faction == f), func(x): return x.Ships.size())
	var troops := Lq.count(p.Garrison, func(u): return u.Faction == f)
	return ships + troops


## Seen defenders via intel (fog-legal): -1 if we do not know the orbit.
static func _seen_defending_ships(us: Faction, p: Planet) -> int:
	if not IntelManager.Knows(us, p, Enums.IntelSection.OrbitingShips):
		return -1
	return Lq.sum(Lq.where(p.FleetsInOrbit(), func(x): return x.Faction == p.ControllingFaction), func(x): return x.Ships.size())


static func _nearest_fleet(fleets: Array, to: Planet) -> Fleet:
	var in_orbit := Lq.where(fleets, func(f): return f.Attached is Planet)
	var sorted := Lq.order_by(in_orbit, func(f): return (f.Attached as Planet).DeploymentDaysTo(to))
	return sorted[0] if not sorted.is_empty() else null


static func _already_answered(target: Planet, us: Faction) -> bool:
	if Lq.any(target.OrbitingFleets, func(f): return f.Faction == us and not f.IsEmpty()):
		return true
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction == us and not f.IsEmpty() and f.Destination == target:
				return true
	return false


static func _can_afford_to_commit(us: Faction, f: Fleet) -> bool:
	return Economy.MaintenanceAvailable(us) >= Lq.sum(f.Ships, func(s): return s.MaintenanceCost)


# ===========================================================================
# COMBAT policy — assault with a loaded fleet already in position; else load
# troops. Ported from the original's Invade, in candidate form. Assault spends
# "moves" so difficulty reaches combat (the P2 fix, OURS).
# ===========================================================================

static func _propose_combat(ctx: AIContext, plan: AIObjectives.Plan, rng: Prng) -> Array:
	var out: Array = []
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Faction != ctx.Us or f.Status == Enums.Status.Enroute:
				continue
			if not (f.Attached is Planet):
				continue
			var here: Planet = f.Attached
			# (a) ready assault: a fleet sitting on a target it can assault.
			if AssaultManager.CanAssault(f, here).ok:
				out.append(_assault_candidate(ctx, plan, f, here, rng))
			# (b) load troops from a held world with a spare garrison, to project power.
			elif here.ControllingFaction == ctx.Us:
				out.append_array(_load_candidates(ctx, plan, f, here))
	return out


static func _assault_candidate(ctx: AIContext, plan: AIObjectives.Plan, f: Fleet, target: Planet, rng: Prng) -> CandidateAction:
	var day := StrategicTickManager.Today
	var c := CandidateAction.new()
	c.loop = CandidateAction.Loop.Combat
	c.kind = "assault"
	c.budget_key = "moves"
	c.expected_value = 600   # OURS ranking seed; taking a world is high value
	c.objective_fit = _objective_fit(plan, c.loop, -1, target)
	c.justification = "assault %s" % target.Name
	c.tb_type = 2
	c.tb_target = target.get_instance_id()
	c.tb_actor = f.get_instance_id()
	c.action = func() -> bool:
		if not AssaultManager.CanAssault(f, target).ok:
			return false
		AssaultManager.Resolve(f, target, rng, day)
		return true
	return c


static func _load_candidates(ctx: AIContext, plan: AIObjectives.Plan, f: Fleet, home: Planet) -> Array:
	var out: Array = []
	if Lq.sum(f.Ships, func(sh): return sh.TroopCapacity) == 0:
		return out
	if Lq.any(f.Ships, func(sh): return Lq.any(sh.Hangar, func(h): return h.Type == Enums.UnitType.Troop)):
		return out   # already carrying troops
	var spare: int = home.TrooperRegiments() - max(1, home.GarrisonRequirement())
	if spare <= 0:
		return out
	var lift := Lq.where(home.Garrison, func(u): return u.Type == Enums.UnitType.Troop).slice(0, spare)
	if lift.is_empty():
		return out
	var c := CandidateAction.new()
	c.loop = CandidateAction.Loop.Combat
	c.kind = "load_troops"
	c.budget_key = "moves"
	c.expected_value = 200   # OURS: preparation, lower than an actual assault
	c.objective_fit = _objective_fit(plan, c.loop, -1, home)
	c.justification = "embark %d regiment(s) on %s at %s" % [lift.size(), f.Name, home.Name]
	c.tb_type = 3
	c.tb_target = home.get_instance_id()
	c.tb_actor = f.get_instance_id()
	c.action = func() -> bool:
		return OrderManager.LoadAboard(lift, f).value > 0
	out.append(c)
	return out
