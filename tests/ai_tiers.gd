extends SceneTree
## M5 VERIFY (BUILD-PLAN A4): the three tiers differ ONLY in the documented OURS
## knobs (10-difficulty-and-fairness.md §4) and the corpus DEFEND rule-id sets. The
## test is mechanical: build the configs and diff them. Difficulty must change how
## WELL the AI plays, never WHAT it sees (G3) — the config carries only throttles,
## rule-sets and inference channels, no information.
##
##   Godot_console.exe --headless --path . -s tests/ai_tiers.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	var e := AITiers._config_for(Enums.Difficulty.Easy)
	var m := AITiers._config_for(Enums.Difficulty.Medium)
	var h := AITiers._config_for(Enums.Difficulty.Hard)

	# Capability ladder (Easy -> Medium -> Hard), 10-diff §4.
	_check(e.MovesPerDay == 1 and m.MovesPerDay == 2 and h.MovesPerDay == 3, "moves/day 1/2/3")
	_check(e.MissionsPerDay == 1 and m.MissionsPerDay == 2 and h.MissionsPerDay == 3, "missions/day 1/2/3")
	_check(e.ShipsPerDay == 1 and m.ShipsPerDay == 1 and h.ShipsPerDay == 2, "ships/day 1/1/2")
	_check(e.Horizon < m.Horizon and m.Horizon < h.Horizon, "planning horizon rises E<M<H")
	_check(e.DecisionNoise > m.DecisionNoise and m.DecisionNoise > h.DecisionNoise, "decision noise falls E>M>H (%d>%d>%d)" % [e.DecisionNoise, m.DecisionNoise, h.DecisionNoise])
	_check(h.DecisionNoise == 0, "Hard never takes a worse option (noise 0)")

	# Objective ordering: Easy none, Medium/Hard on.
	_check(e.UseObjectives == false, "Easy has NO objective ordering")
	_check(m.UseObjectives and h.UseObjectives, "Medium/Hard use objective ordering")

	# Inference channels: none / battle+flip / all (fog-legal; G3).
	_check(e.InferenceLevel == AITiers.Inference.NONE, "Easy infers nothing")
	_check(m.InferenceLevel == AITiers.Inference.BATTLE_AND_FLIP, "Medium: battle results + system flips")
	_check(h.InferenceLevel == AITiers.Inference.ALL, "Hard: all three channels incl logistics")

	# DEFEND rule sets (cumulative): Easy 1, Medium 12, Hard 22 (corpus, C3PO #51).
	_check(e.DefendRuleIds.size() == 1, "Easy DEFEND = 1 (got %d)" % e.DefendRuleIds.size())
	_check(m.DefendRuleIds.size() == 12, "Medium DEFEND = 12 (got %d)" % m.DefendRuleIds.size())
	_check(h.DefendRuleIds.size() == 22, "Hard DEFEND = 22 (got %d)" % h.DefendRuleIds.size())
	_check("RULE-05-23" in e.DefendRuleIds and "RULE-05-23" in m.DefendRuleIds and "RULE-05-23" in h.DefendRuleIds, "RULE-05-23 active at ALL tiers")
	_check("RULE-05-06" in m.DefendRuleIds and not ("RULE-05-06" in e.DefendRuleIds), "counter-intel (05-06) is Medium+, not Easy")
	_check("RULE-11-04" in h.DefendRuleIds and not ("RULE-11-04" in m.DefendRuleIds), "territory-denial (11-04) is Hard-only")
	_check(not ("RULE-02-13" in h.DefendRuleIds), "the dropped bluff-counter (02-13) is in NO tier")

	# Cumulative containment: Easy subset of Medium subset of Hard.
	_check(_subset(e.DefendRuleIds, m.DefendRuleIds), "Easy DEFEND subset of Medium")
	_check(_subset(m.DefendRuleIds, h.DefendRuleIds), "Medium DEFEND subset of Hard")

	# Prophylactic HQ timer only at Hard (RULE-11-01).
	_check(e.ProphylacticHqDays == 0 and m.ProphylacticHqDays == 0 and h.ProphylacticHqDays > 0, "prophylactic HQ timer is Hard-only")

	_finish()


func _subset(a: Array, b: Array) -> bool:
	for x in a:
		if not (x in b):
			return false
	return true


func _finish() -> void:
	print("[ai_tiers] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
