class_name AITiers
extends RefCounted
## Difficulty tiers — OURS, and labelled OURS everywhere (charter §"Difficulty").
## The original does NOT change AI behaviour by difficulty (four sources, charter
## §Difficulty); it varies STARTING POSITION only. Behavioural tiers are a
## deliberate departure requested by TeeJ (room #27).
##
## Two axes stay separate: handicap (the original's, untouched) vs competence
## (ours, here). This class is competence only. Filled with the concrete switch
## table at M5 (BUILD-PLAN.md "M5 tier switch table"); M0 ships safe defaults so
## the brain runs. Every value here is an OURS-design value (two-kind rule).

class Config:
	var MovesPerDay: int = 1
	var MissionsPerDay: int = 1
	var ShipsPerDay: int = 1
	var Horizon: int = 1          ## planning depth (OURS); M5
	var DecisionNoise: int = 0    ## decision noise, fixed-point (OURS); M5
	var DefendRuleIds: Array = [] ## active self-protection rule ids; M5


## The active tier for a faction. Difficulty is a game setting, not an AI dial for
## *knowledge* — tiers change how WELL the AI plays, never WHAT it sees (G3).
static func For(_us: Faction) -> Config:
	return _config_for(GameSettings.SelectedDifficulty)


static func _config_for(diff: int) -> Config:
	var c := Config.new()
	match diff:
		Enums.Difficulty.Easy:
			c.MovesPerDay = 1; c.MissionsPerDay = 1; c.ShipsPerDay = 1
		Enums.Difficulty.Hard:
			c.MovesPerDay = 3; c.MissionsPerDay = 3; c.ShipsPerDay = 2
		_:
			c.MovesPerDay = 2; c.MissionsPerDay = 2; c.ShipsPerDay = 1
	return c
