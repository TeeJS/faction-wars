class_name AiManager
extends RefCounted
## THE OPPONENT — clean-slate rebuild (branch ai-rebuild) to the four-stage
## architecture in docs/ai-framework/01-architecture.md:
##
##   CONTEXT  (shared reader) → OBJECTIVES → ACTION SELECTION
##                                   ▲              ▲
##                              REACTIONS (EventBus) writes context, never spends (AR-4)
##
## Replaces the original single-file driver. The game ENGINE is untouched — this
## file only decides; MissionManager/EventBus/IntelManager/assault/etc. execute.
##
## Sourced invariants preserved from the original (they are the game's, not ours):
##  - neutral entities are never acted on (was ai_manager.gd:3, from the binary);
##  - dispatch is gated on the maintenance budget (FUN_0052e970) — enforced by the
##    economy/fleet policies at M2;
##  - daily cadence: one entry per strategic day (strategic_tick_manager.gd:154).
## Per-day caps and all scoring weights are OURS (BUILD-PLAN.md two-kind rule).

static var _announced: bool = false
static var DriveAllFactions: bool = false
static var _subscribed: bool = false


## Called from game_session.gd:41 on a new game / reset.
static func Reset() -> void:
	_announced = false
	DriveAllFactions = false
	AIReactions.Reset()
	_subscribed = false


## Called once per strategic day from strategic_tick_manager.gd:154.
static func ProcessDay(galaxy: Array, day: int, rng: Prng) -> void:
	if galaxy == null:
		return
	if not _subscribed:
		AIReactions.Subscribe()
		_subscribed = true
	for f in FactionRegistry.Playable:
		if not DriveAllFactions and GameSettings.IsHuman(f):
			continue
		# Production and garrison micro stay delegated to the AgentDroid, as in the
		# original — that is engine automation, not the strategic brain.
		if not AgentDroid.ManagingProduction(f):
			AgentDroid.SetManageProduction(f, true)
		if not AgentDroid.ManagingGarrisons(f):
			AgentDroid.SetManageGarrisons(f, true)
		if not _announced:
			print("[AI] %s is under AI control (new brain)." % f.DisplayName)
		_run_faction(galaxy, f, day, rng)
	_announced = true


## One faction's turn through the four stages.
static func _run_faction(galaxy: Array, us: Faction, day: int, rng: Prng) -> void:
	var ctx := AIContext.Build(galaxy, us, day)   # CONTEXT
	AIReactions.Apply(ctx)                         # fold queued events in (reprioritise)
	var plan := AIObjectives.Compute(ctx)          # OBJECTIVES — the bottleneck
	AIActionSelection.Run(ctx, plan, rng)          # ACTION SELECTION — propose/score/pick
