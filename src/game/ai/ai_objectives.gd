class_name AIObjectives
extends RefCounted
## STAGE: OBJECTIVES — what we are for (docs/ai-framework/01-architecture.md,
## 08-victory.md; spec in agent room AM-BH4LZPVZLMY4ZM6W5WGTFR2HMK #23/#30 by C3PO).
## Victory conditions as a PLAN, not a checklist: it reads the engine's declared
## conditions (VictoryManager) and emits the current bottleneck plus per-loop and
## per-mission-type weights that Action Selection adds to every candidate's score.
##
## Stateful intent, per-day recomputed. All weights are OURS-design (fixed-point,
## CandidateAction.SCALE); the states and their ORDER are the corpus's.
##
## FACTION ASYMMETRY (RULE-01-03): the Alliance HQ condition is "hold Coruscant"
## (a siege; location always known); the Empire's is "destroy the hidden Rebel HQ"
## (a search). VictoryManager.HeadquartersConditionMet encodes both. The Empire has
## an HQ_UNKNOWN state; the Alliance never does.
##
## RULE-10-12 (Hard tier ONLY, per 08-victory §6): "save the HQ for last." At Hard
## the HQ pursuit stays low while capture targets remain. At Easy/Medium the AI
## pursues the HQ in parallel (a fixed order, OURS).

const W_DOMINANT := 500   # OURS bias units
const W_STRONG := 400
const W_MEDIUM := 300
const W_MILD := 150
const W_TRACE := 100

enum State {
	OWN_CHAR_CAPTURED,          ## RESCUE — highest (RULE-05-19)
	CHARS_LOCATED_NOT_CAPTURED, ## Abduction + blockade-before-invade (RULE-10-08 / 09-13)
	CHAR_CAPTURED_NOT_HELD,     ## prison hardening / custody (RULE-05-02)
	HQ_UNKNOWN,                 ## Empire only — recon/espionage toward the Rim (RULE-11-14)
	HQ_LOCATED_NOT_REDUCED,     ## blockade to pin, bombard/assault (RULE-02-05)
	CHARS_UNLOCATED,            ## espionage breadth (RULE-11-04)
	ALL_MET,                    ## done
}

class Plan:
	var state: int = State.CHARS_UNLOCATED
	var weights: Dictionary = {}       ## CandidateAction.Loop -> fixed-point bonus
	var type_weights: Dictionary = {}  ## Enums.MissionType -> fixed-point bonus
	var justification: String = ""


## STAGE ENTRY. Compute the current plan for a faction.
static func Compute(ctx: AIContext) -> Plan:
	var plan := Plan.new()
	var us := ctx.Us
	var tier := AITiers.For(us)
	# Easy has NO objective ordering (10-diff §4): it pursues whatever scores highest
	# by intrinsic value (BASE_VALUE), with no victory-directed bottleneck bias. It
	# still plays every loop and still abducts when handed the chance — it just does
	# not steer toward the win. Return a neutral, weightless plan.
	if not tier.UseObjectives:
		plan.state = State.CHARS_UNLOCATED
		plan.justification = "Easy: no objective ordering (pursue by value)"
		return plan

	var galaxy: Array = GameState.ActiveGalaxy
	var opponent := _opponent(us)
	var hard := tier.Difficulty == Enums.Difficulty.Hard

	# STATE 1 — our own character captured: rescue dominates ("bend most of your
	# efforts", RULE-05-19). Highest priority; returns immediately.
	if _own_captured(us):
		plan.state = State.OWN_CHAR_CAPTURED
		_bump(plan.weights, CandidateAction.Loop.Missions, W_DOMINANT)
		plan.type_weights[Enums.MissionType.Rescue] = W_DOMINANT
		plan.justification = "own character captured — rescue"
		return plan

	var hq_only: bool = GameSettings.HQOnlyVictory
	var caps: Array = [] if hq_only else VictoryManager.CaptureTargets(us)
	var remaining: Array = Lq.where(caps, func(n): return not VictoryManager.HoldsCaptive(us, n))
	var located: Array = Lq.where(remaining, func(n): return _target_located(us, n))

	var hq_met: bool = opponent != null and VictoryManager.HeadquartersConditionMet(us, opponent, galaxy)
	var hq_known := true
	if opponent != null and opponent.HasHiddenHq():
		hq_known = _rebel_hq_known(us, opponent, galaxy) != null

	if not remaining.is_empty():
		# Capture targets outstanding — pursue the characters first.
		_bump(plan.weights, CandidateAction.Loop.Missions, W_STRONG)
		_bump(plan.weights, CandidateAction.Loop.Diplomacy, W_TRACE)
		if not located.is_empty():
			plan.state = State.CHARS_LOCATED_NOT_CAPTURED
			plan.type_weights[Enums.MissionType.Abduction] = W_DOMINANT
			# Capture BEFORE invasion (RULE-10-08 / 09-13): a blockade pins the target
			# so it cannot flee, but we do NOT assault the HQ yet.
			_bump(plan.weights, CandidateAction.Loop.Fleet, W_MILD)
			plan.justification = "capture targets located — abduct (pin, don't assault yet)"
		else:
			plan.state = State.CHARS_UNLOCATED
			plan.type_weights[Enums.MissionType.Espionage] = W_MEDIUM
			plan.type_weights[Enums.MissionType.Reconnaissance] = W_MEDIUM - 50
			plan.justification = "capture targets unlocated — find them (espionage/recon breadth)"
		# RULE-10-12: at Hard the HQ waits until captures are done. Easy/Medium pursue
		# the HQ in parallel (fixed order, OURS) with a mild combat bias.
		if not hard:
			_bump(plan.weights, CandidateAction.Loop.Combat, W_TRACE)
	else:
		# Captures complete (or HQ-only victory). Now the HQ is the bottleneck.
		if hq_met:
			plan.state = State.ALL_MET
			plan.justification = "all conditions met"
		elif not hq_known:
			plan.state = State.HQ_UNKNOWN
			plan.type_weights[Enums.MissionType.Reconnaissance] = W_STRONG
			plan.type_weights[Enums.MissionType.Espionage] = W_STRONG - 50
			_bump(plan.weights, CandidateAction.Loop.Missions, W_MEDIUM)
			plan.justification = "HQ unknown — search the Rim (recon/espionage)"
		else:
			plan.state = State.HQ_LOCATED_NOT_REDUCED
			_bump(plan.weights, CandidateAction.Loop.Fleet, W_STRONG)   # blockade to pin
			_bump(plan.weights, CandidateAction.Loop.Combat, W_DOMINANT) # assault / bombard
			plan.justification = "HQ located — pin and reduce"
	return plan


static func _opponent(us: Faction) -> Faction:
	return Lq.first_or_null(FactionRegistry.Playable, func(o): return o != us)


static func _own_captured(us: Faction) -> bool:
	return Lq.any(GameState.ActiveRoster, func(c): return c.Faction == us and c.IsCaptured())


## A named capture target we legitimately know the location of (Characters intel on
## the world it stands on). Fog-legal (same gate as the missions policy).
static func _target_located(us: Faction, name: String) -> bool:
	var c: Character = Lq.first_or_null(GameState.ActiveRoster, func(x): return x.Name == name)
	if c == null or not (c.Attached is Planet):
		return false
	return IntelManager.Knows(us, c.Attached, Enums.IntelSection.Characters)


## The opponent's hidden HQ world, IF we have explored it (fog-legal). null == unknown.
static func _rebel_hq_known(us: Faction, opponent: Faction, galaxy: Array) -> Planet:
	if galaxy == null:
		return null
	for s in galaxy:
		for p in s.Planets:
			if p.HasHeadquarters() and p.ControllingFaction == opponent and p.ExploredBy(us):
				return p
	return null


static func _bump(d: Dictionary, key: int, amount: int) -> void:
	d[key] = int(d.get(key, 0)) + amount
