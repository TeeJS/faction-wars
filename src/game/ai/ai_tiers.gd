class_name AITiers
extends RefCounted
## Difficulty tiers — OURS, and labelled OURS everywhere (charter §"Difficulty";
## table from 10-difficulty-and-fairness.md §4, the document TeeJ asked for).
## The original does NOT change AI behaviour by difficulty; it varies STARTING
## POSITION only. Behavioural tiers are a deliberate departure requested by TeeJ
## (room #27). This class is the COMPETENCE axis only; the handicap axis is the
## original's and untouched.
##
## Two segments of the ladder (10-diff §2):
##   Easy -> Medium = CAPABILITY (budgets, planning, decision noise, objective use)
##   Medium -> Hard = SELF-PROTECTION (DEFEND rules) + INFERENCE channels
## Every value here is an OURS-design value (two-kind rule). The DEFEND rule-id
## lists are the corpus's (09-counter-exploit.md, mapped by C3PO, room #51).

# --- DEFEND rule sets (09-counter-exploit.md; the ids are the corpus's) --------
const DEFEND_ALL := ["RULE-05-23"]   # scatter roster day one; omitting it looks broken
const DEFEND_MEDIUM := [
	"RULE-10-03", "RULE-09-02", "RULE-07-07", "RULE-09-12", "RULE-05-17",
	"RULE-05-07", "RULE-11-05", "RULE-05-06", "RULE-03-15", "RULE-04-15", "RULE-05-21",
]
const DEFEND_HARD := [
	"RULE-09-01", "RULE-06-13", "RULE-05-18", "RULE-01-09", "RULE-11-04",
	"RULE-11-15", "RULE-10-18", "RULE-10-02", "RULE-08-16", "RULE-04-16",
]

# Inference channels a tier may act on (fog-legal; 10-diff §3).
enum Inference { NONE, BATTLE_AND_FLIP, ALL }


class Config:
	var Difficulty: int = Enums.Difficulty.Medium
	# Capability (Easy->Medium)
	var MovesPerDay: int = 2
	var MissionsPerDay: int = 2
	var ShipsPerDay: int = 1
	var Horizon: int = 2           ## planning depth in days (OURS)
	var DecisionNoise: int = 80    ## score jitter range, fixed-point (OURS); consumes Prng
	var UseObjectives: bool = true ## Easy=false: pursue by value only, no bottleneck bias
	# Self-protection + inference (Medium->Hard)
	var InferenceLevel: int = Inference.BATTLE_AND_FLIP
	var DefendRuleIds: Array = []  ## active self-protection rule ids (corpus)
	var ProphylacticHqDays: int = 0 ## Hard: relocate HQ every N days pre-emptively (RULE-11-01)

	func defends(rule_id: String) -> bool:
		return DefendRuleIds.has(rule_id)


## The active tier for a faction. Difficulty is a game setting; it changes how WELL
## the AI plays, never WHAT it sees (G3 — same context object at every tier).
static func For(_us: Faction) -> Config:
	return _config_for(GameSettings.SelectedDifficulty)


static func _config_for(diff: int) -> Config:
	var c := Config.new()
	c.Difficulty = diff
	match diff:
		Enums.Difficulty.Easy:
			c.MovesPerDay = 1; c.MissionsPerDay = 1; c.ShipsPerDay = 1
			c.Horizon = 1; c.DecisionNoise = 300; c.UseObjectives = false
			c.InferenceLevel = Inference.NONE
			c.DefendRuleIds = DEFEND_ALL.duplicate()               # 1
			c.ProphylacticHqDays = 0
		Enums.Difficulty.Hard:
			c.MovesPerDay = 3; c.MissionsPerDay = 3; c.ShipsPerDay = 2
			c.Horizon = 4; c.DecisionNoise = 0; c.UseObjectives = true
			c.InferenceLevel = Inference.ALL
			c.DefendRuleIds = DEFEND_ALL + DEFEND_MEDIUM + DEFEND_HARD  # 22
			c.ProphylacticHqDays = 30                              # OURS timer
		_:  # Medium (also the Multiplayer default, 10-diff §6 recommendation)
			c.MovesPerDay = 2; c.MissionsPerDay = 2; c.ShipsPerDay = 1
			c.Horizon = 2; c.DecisionNoise = 80; c.UseObjectives = true
			c.InferenceLevel = Inference.BATTLE_AND_FLIP
			c.DefendRuleIds = DEFEND_ALL + DEFEND_MEDIUM           # 12
			c.ProphylacticHqDays = 0
	return c
