class_name AIObjectives
extends RefCounted
## STAGE: OBJECTIVES — what we are for (docs/ai-framework/01-architecture.md,
## 08-victory.md). Victory conditions as a PLAN, not a checklist: it emits the
## current *bottleneck* — the weight action selection reads. Stateful across days
## (game-phase clock), unlike action selection (per-day).
##
## Populated at M3, GATED on C3PO's 08-victory ordering spec (room #23). M0 ships a
## neutral plan so the brain runs.

## The bottleneck states the objective layer cycles through (C3PO spec, 08-victory):
enum State {
	OWN_CHAR_CAPTURED,          ## RESCUE — highest (RULE-05-19)
	CHARS_LOCATED_NOT_CAPTURED, ## Abduction + blockade first (RULE-10-08 / 09-13)
	CHAR_CAPTURED_NOT_HELD,     ## prison hardening / custody (RULE-05-02)
	HQ_UNKNOWN,                 ## Empire only — recon/espionage toward Rim (RULE-11-14)
	HQ_LOCATED_NOT_REDUCED,     ## blockade to pin, bombard/assault (RULE-02-05)
	CHARS_UNLOCATED,            ## espionage breadth; territory denial (RULE-11-04)
	ALL_MET,                    ## done
}

class Plan:
	var state: int = State.CHARS_UNLOCATED
	## per-loop weights (fixed-point, CandidateAction.SCALE) the scorer applies.
	var weights: Dictionary = {}
	var justification: String = ""


## STAGE ENTRY. Compute the current plan for a faction. M3.
static func Compute(_ctx: AIContext) -> Plan:
	return Plan.new()
