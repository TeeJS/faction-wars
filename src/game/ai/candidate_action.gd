class_name CandidateAction
extends RefCounted
## A proposed AI action, scored against the current objective bottleneck.
## docs/ai-framework/01-architecture.md "Action selection". One design decision
## replaces the old Preferred() list — six findings traced to that list. Every
## operational policy (economy/fleet/missions/diplomacy/combat) emits these; the
## action-selection stage scores them and spends the per-day budget on the best.
##
## SCORING IS INTEGER (fixed-point, scale 1000), an OURS-design choice, NOT the
## float form sketched in 01-architecture.md. Reason: the AI runs inside the
## lockstep sim (strategic_tick_manager -> replayer / lockstep_session), so its
## decisions must be byte-identical across desktop and web-wasm. Integer maths is
## deterministic across those targets; IEEE float ops are not guaranteed to be.
## The engine already scores missions in integer percents (mission_manager
## SuccessPercent/ScoreFor), so this matches the house idiom. (BUILD-PLAN A2.)

const SCALE := 1000   ## fixed-point unit: 1.0 == 1000

enum Loop { Economy, Fleet, Missions, Diplomacy, Combat }

var loop: int = Loop.Missions
var kind: String = ""             ## short tag for logs, e.g. "mission:Abduction"
var action: Callable              ## executes it; returns truthy on success
var justification: String = ""    ## why, in words, so a decision can be explained

## Score terms, all fixed-point ints (see SCALE). Priced on different objects:
var objective_fit: int = 0        ## how much this advances the current bottleneck
var expected_value: int = 0       ## p_success x objective_gain — priced on the TARGET
var asset_risk: int = 0           ## p_loss x replacement_cost — priced on the ACTOR
var urgency: int = 0              ## situational, not type-based

## Deterministic total-order tiebreak on equal scores (BUILD-PLAN A2). Stable
## integers only: action-kind ordinal, then target id, then actor id.
var tb_type: int = 0
var tb_target: int = 0
var tb_actor: int = 0


func score() -> int:
	return objective_fit + expected_value - asset_risk + urgency


## Strict weak ordering for Array.sort_custom: highest score first, ties broken by
## the stable integer keys so a replay never diverges on equal scores.
static func Better(a: CandidateAction, b: CandidateAction) -> bool:
	var sa := a.score()
	var sb := b.score()
	if sa != sb:
		return sa > sb
	if a.tb_type != b.tb_type:
		return a.tb_type < b.tb_type
	if a.tb_target != b.tb_target:
		return a.tb_target < b.tb_target
	return a.tb_actor < b.tb_actor
