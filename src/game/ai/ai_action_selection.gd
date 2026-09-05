class_name AIActionSelection
extends RefCounted
## STAGE: ACTION SELECTION — propose, score, pick (docs/ai-framework/01-architecture.md).
## The five operational policies (economy/fleet/missions/diplomacy/combat) each emit
## CandidateActions; this stage scores them against the objective bottleneck and
## spends the per-day budget on the best. Replaces the old Preferred() list — six
## findings traced to that one decision, so it is removed, not patched.
##
## Populated at M2. M0 ships the loop shell (gather -> sort -> spend) with no policies
## wired, so it compiles and runs inert until the policies land.

## STAGE ENTRY. Run one faction's daily action selection against its plan/budget.
static func Run(ctx: AIContext, plan: AIObjectives.Plan, rng: Prng) -> void:
	var tier := AITiers.For(ctx.Us)
	var budget := {"moves": tier.MovesPerDay, "missions": tier.MissionsPerDay, "ships": tier.ShipsPerDay}
	var candidates := _propose(ctx, plan, rng)
	candidates.sort_custom(CandidateAction.Better)   # deterministic total order (A2)
	_spend(candidates, budget)


## Gather CandidateActions from every operational policy. M2 wires the policies.
static func _propose(_ctx: AIContext, _plan: AIObjectives.Plan, _rng: Prng) -> Array:
	var out: Array = []
	return out


## Execute the best affordable candidates until the budget is exhausted. M2.
static func _spend(_candidates: Array, _budget: Dictionary) -> void:
	pass
