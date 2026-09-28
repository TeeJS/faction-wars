class_name StoryManager
extends RefCounted
## backend/StoryManager.cs - THE SCRIPTED SET-PIECES, manual p094-p097, p100, and
## the tables behind them: the Force encounter (heritage), the bounty hunters and
## Jabba's palace, and the Final Battle. The original keys them by NAME; here
## each part is a ROLE in characters.json (SCHEMA.md section 7) - pilgrim, heir,
## dark_lord, dark_master, smuggler, companion - so the engine never names anyone.

static var _next_encounter_scan: int = -1
static var _bounty_hunters_due_on: int = -1
static var _bounty_hunters_fired: bool = false
static var _final_battle_decided: bool = false
static var _palace_rolls_from: int = -1

## ⚠ THE FOUR PAIRINGS ARE ALL THERE ARE: [aggressor role, antagonist role, scale id, min id]
const Pairings := [
	["pilgrim", "dark_lord",   RuleId.PilgrimVsDarkLordGainScale,   RuleId.PilgrimVsDarkLordGainMin],
	["pilgrim", "dark_master", RuleId.PilgrimVsDarkMasterGainScale, RuleId.PilgrimVsDarkMasterGainMin],
	["heir",    "dark_lord",   RuleId.HeirVsDarkLordGainScale,   RuleId.HeirVsDarkLordGainMin],
	["heir",    "dark_master", RuleId.HeirVsDarkMasterGainScale, RuleId.HeirVsDarkMasterGainMin],
]


## The character the pack casts in a story role, or null when it casts nobody
## (then that set-piece simply never fires).
static func WhoHas(role: String) -> Character:
	return Lq.first_or_null(GameState.ActiveRoster, func(c): return c.HasRole(role))


static func Reset() -> void:
	_next_encounter_scan = -1
	_bounty_hunters_due_on = -1
	_bounty_hunters_fired = false
	_final_battle_decided = false
	_palace_rolls_from = -1


static func ProcessDay(day: int, rng: Prng) -> void:
	if GameState.ActiveRoster == null:
		return
	ProcessEncounters(day, rng)
	ProcessBountyHunters(day, rng)
	ProcessFinalBattle(day, rng)


# --- 1. THE FORCE ENCOUNTER (entries 66/67/68; REBEXE.EXE 0x560200) ---

static func ProcessEncounters(day: int, rng: Prng) -> void:
	if day < _next_encounter_scan:
		return
	_next_encounter_scan = day + max(1, RuleManager.Roll(RuleId.EncounterScanBase, RuleId.EncounterScanSpread, rng))

	for p in Pairings:
		var a := WhoHas(p[0])
		var b := WhoHas(p[1])
		if a == null or b == null:
			continue
		if a.Status == Enums.Status.Dead or b.Status == Enums.Status.Dead:
			continue
		if a.IsOffMap() or b.IsOffMap():
			continue
		if a.Attached == null or a.Attached != b.Attached:
			continue
		if not a.IsKnownSpecialPowerUser:
			continue
		if a.SpecialPowerLevel < RuleManager.Get(RuleId.EncounterOwnSideMinRank, a.Faction):
			continue
		if b.SpecialPowerLevel < RuleManager.Get(RuleId.EncounterEnemyMinRank, a.Faction):
			continue
		var chance := a.SpecialPowerLevel + b.SpecialPowerLevel + RuleManager.Get(RuleId.EncounterProbabilityOffset, a.Faction)
		if chance <= 0 or rng.NextRange(1, 101) > chance:
			continue
		ResolveEncounter(a, b, p, day, rng)


static func ResolveEncounter(a: Character, b: Character, p: Array, day: int, rng: Prng) -> void:
	var first := not a.KnowsHeritage
	a.KnowsHeritage = true

	var hurt := false
	if a.SpecialPowerLevel < RuleManager.Get(RuleId.PilgrimageInjuryCeiling, a.Faction):
		hurt = true
		MissionManager.Injure(a, rng, RuleId.HeritageInjuryBase, RuleId.HeritageInjurySpread)

	var gain := 0
	if not a.IsCaptured() and a.Status != Enums.Status.Dead:
		var scale := RuleManager.Get(p[2], a.Faction)
		var floor_v := RuleManager.Get(p[3], a.Faction)
		gain = max(floor_v, (b.SpecialPowerLevel - a.SpecialPowerLevel) * scale / 100)
		a.SpecialPowerLevel += gain

	var rank_name := Character.RankLabel(a.SpecialPowerRankOf())
	print("[Story] %s encountered %s at %s: heritage %s, %s, Force +%d -> %d (%s)." % [
		a.Name, b.Name, a.Attached.Name if a.Attached != null else "", "REVEALED" if first else "already known",
		("injured %d" % a.Injury) if hurt else "unharmed", gain, a.SpecialPowerLevel, rank_name])

	if not GameSettings.IsHuman(a.Faction):
		return
	# The original's words (TEXTSTRA 29088-29102): the first time "Luke Discovers
	# His Heritage" / "Luke has learned that Vader is his father.  " (STRATEGY
	# 1058); after, "<name> Confronts <name>" / "<name> has fought <name>.  " -
	# then who was hurt, or "Both combatants escaped uninjured."
	var injured := hurt and a.Status != Enums.Status.Dead
	var msg: GameMessage
	if first:
		var body := "%s has learned that %s is his father.  " % [ForceManager.FirstName(a), b.Name.get_slice(" ", b.Name.get_slice_count(" ") - 1)]
		if injured:
			body += "%s was injured during the battle.  " % ForceManager.FirstName(a)
		msg = GameMessage.new("%s Discovers His Heritage" % ForceManager.FirstName(a), body,
			Enums.MessageCategory.Missions, day, a.Attached if a.Attached is Planet else null, a)
		msg.Still = "message.1058"
		msg.Sound = "strategy/1133"
	else:
		msg = GameMessage.new("%s Confronts %s" % [a.Name, b.Name],
			"%s has fought %s.  %s" % [a.Name, b.Name, ("%s was injured." % a.Name) if injured else "Both combatants escaped uninjured."],
			Enums.MessageCategory.Missions, day, a.Attached if a.Attached is Planet else null, a)
	EventBus.Tell(a.Faction, msg)


# --- 2. THE BOUNTY HUNTERS, AND JABBA'S PALACE (entries 103/104/105; RLEVADTB) ---

static func ProcessBountyHunters(day: int, rng: Prng) -> void:
	var han := WhoHas("smuggler")
	if han == null:
		return
	if han.AtJabbasPalace:
		ProcessPalace(han, day, rng)
		return
	if _bounty_hunters_fired:
		return
	if _bounty_hunters_due_on < 0:
		_bounty_hunters_due_on = day + RuleManager.Roll(RuleId.BountyHunterBase, RuleId.BountyHunterSpread, rng, han.Faction)
		print("[Story] The bounty hunters will move on %s on day %d." % [han.Name, _bounty_hunters_due_on])
	if day < _bounty_hunters_due_on:
		return
	if han.Status == Enums.Status.Dead or han.IsCaptured() or han.IsOffMap():
		return

	_bounty_hunters_fired = true
	han.BountyAttack = true

	if rng.NextRange(1, 101) > RuleManager.Get(RuleId.BountyHunterChance, han.Faction):
		print("[Story] The bounty hunters passed %s over." % han.Name)
		return

	var evade := MissionTableManager.Lookup(MissionTableManager.Evasion, han.CombatRating)
	var escaped := evade < 0 or rng.NextRange(1, 101) <= evade
	print("[Story] Bounty hunters moved on %s (combat %d -> %d%% to evade): %s." % [han.Name, han.CombatRating, evade, "he got away" if escaped else "TAKEN"])

	if escaped:
		if not GameSettings.IsHuman(han.Faction):
			return
		# The original's words (TEXTSTRA 29032 / 29033).
		EventBus.Tell(han.Faction, GameMessage.new("%s Attacked by Bounty Hunters" % han.Name,
			"%s was attacked by bounty hunters, who failed to capture him." % han.Name,
			Enums.MessageCategory.Missions, day, han.Attached if han.Attached is Planet else null, han).With("", "bounty_attack").Sounding("strategy/1141"))
		return

	TakeToPalace(han, day, rng)


static func TakeToPalace(han: Character, day: int, rng: Prng) -> void:
	var captor: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f): return f != han.Faction)

	han.CapturedBy = captor   # ⚠ ours
	han.CanEscape = false     # 0x4EEB10 on the captured path
	han.CapturedByBountyHunters = true
	han.AtJabbasPalace = true
	han.Status = Enums.Status.Kidnapped
	han.Attached = null
	han.Commanding = null
	han.Rank = Enums.Rank.None
	han.Destination = null
	han.DaysToDestination = 0

	var palace := MissionCatalog.ByBehaviour("palace")
	_palace_rolls_from = day + (MissionCatalog.RollLengthById(palace.Id, rng, 0) if palace != null else 0)

	ForceManager.InterruptDagobah()

	var party := []
	for role in ["pilgrim", "heir", "companion"]:
		var c := WhoHas(role)
		if c == null or c.Status == Enums.Status.Dead or c.IsCaptured() or c.IsOffMap():
			continue
		c.AtJabbasPalace = true
		c.Attached = null
		c.Commanding = null
		c.Rank = Enums.Rank.None
		c.Destination = null
		c.DaysToDestination = 0
		c.Status = Enums.Status.OnMission
		party.append(c)

	var names := Lq.join(Lq.select(party, func(c): return c.Name))
	print("[Story] %s has been taken to Jabba's palace. Rescue party: %s." % [han.Name, "nobody available" if party.is_empty() else names])

	if not GameSettings.IsHuman(han.Faction):
		return
	# The original's words (TEXTSTRA 29036 / 29037), then each who goes after him
	# in their own voice (29162 / 29163).
	EventBus.Tell(han.Faction, GameMessage.new("%s Captured by Bounty Hunters" % han.Name,
		"%s was captured by bounty hunters and taken to Jabba's Palace." % han.Name,
		Enums.MessageCategory.Missions, day, null, han).With("captured").Sounding("strategy/1142"))
	for c in party:
		EventBus.Tell(han.Faction, GameMessage.new("%s Rescue Attempt" % c.Name,
			"%s has been captured by bounty hunters and taken to Jabba's palace.  I will be departing immediately to attempt a rescue." % han.Name,
			Enums.MessageCategory.Missions, day, null, c).With("", "rescue_attempt"))


## THE PALACE RESOLUTION (0x55C910): score = Espionage / entry 109 + Combat / entry 110,
## per rescuer, against RESCMSTB. Scored only after MISSNSD 0x44's length.
static func ProcessPalace(han: Character, day: int, rng: Prng) -> void:
	if day < _palace_rolls_from:
		return
	var party := Lq.where(GameState.ActiveRoster, func(c): return c.AtJabbasPalace and c != han and c.Status != Enums.Status.Dead)
	if party.is_empty():
		return
	var esp_div: int = maxi(1, RuleManager.Get(RuleId.PalaceEspionageDivisor, han.Faction))
	var com_div: int = maxi(1, RuleManager.Get(RuleId.PalaceCombatDivisor, han.Faction))
	for rescuer in party:
		var score: int = rescuer.EspionageRating / esp_div + rescuer.CombatRating / com_div
		var chance := MissionTableManager.Lookup(MissionManager.TableFor(Enums.MissionType.Rescue), score)
		if chance < 0:
			return
		if rng.NextRange(1, 101) > chance:
			continue
		FreeFromPalace(han, rescuer, day)
		return


static func FreeFromPalace(han: Character, rescuer: Character, day: int) -> void:
	var party := Lq.where(GameState.ActiveRoster, func(c): return c.AtJabbasPalace)
	var home := HomeFor(rescuer.Faction)
	for c in party:
		c.AtJabbasPalace = false
		c.Attached = home
		c.Status = Enums.Status.AwaitingOrders
	han.CapturedBy = null
	han.CapturedByBountyHunters = false
	han.CanEscape = true
	han.BountyAttack = false
	var home_name: String = home.Name if home != null else "our forces"
	print("[Story] %s got %s out of Jabba's palace; all returned to %s." % [rescuer.Name, han.Name, home_name])
	if not GameSettings.IsHuman(han.Faction):
		return
	EventBus.Tell(han.Faction, GameMessage.new("%s is free" % han.Name,
		"%s has got %s out of Jabba's palace.\n\n%s %s back at %s and awaiting orders." % [
			rescuer.Name, han.Name, Lq.join(Lq.select(party, func(c): return c.Name)), "is" if party.size() == 1 else "are", home_name],
		Enums.MessageCategory.Missions, day, home if home is Planet else null, han).With("released", "released"))


## ⚠ OURS: the headquarters world when held, any held world otherwise.
static func HomeFor(f: Faction) -> Location:
	if f == null or GameState.ActiveRoster == null:
		return null
	var worlds := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == f)
	if worlds.is_empty():
		return null
	var seat: String = f.Hq.Planet if f.Hq != null else ""
	var at_seat: Planet = Lq.first_or_null(worlds, func(p): return p.PackId == seat)
	return at_seat if at_seat != null else worlds[0]


# --- 3. THE FINAL BATTLE (0x56F7A0 ARMED at entry 55; 0x54B040 DECIDED at entry 106) ---

static func ProcessFinalBattle(day: int, rng: Prng) -> void:
	var luke := WhoHas("pilgrim")
	if luke == null or luke.Status == Enums.Status.Dead:
		return

	if not luke.FinalBattleReady and luke.KnowsHeritage \
			and luke.SpecialPowerLevel >= RuleManager.Get(RuleId.PilgrimKnowsHeritageThresh, luke.Faction):
		luke.FinalBattleReady = true
		print("[Story] %s is ready for the final confrontation (Force %d)." % [luke.Name, luke.SpecialPowerLevel])

	if not luke.FinalBattleReady or _final_battle_decided:
		return

	var vader := WhoHas("dark_lord")
	var emperor := WhoHas("dark_master")
	if vader == null or emperor == null:
		return

	if not luke.IsCaptured():
		return
	if vader.IsCaptured() or emperor.IsCaptured():
		return
	if vader.Status == Enums.Status.Dead or vader.Status == Enums.Status.Enroute or vader.Status == Enums.Status.OnMission:
		return
	if emperor.Status == Enums.Status.Dead or emperor.Status == Enums.Status.Enroute or emperor.Status == Enums.Status.OnMission:
		return
	if vader.IsOffMap() or emperor.IsOffMap():
		return
	if emperor.Attached == null:
		return

	luke.Attached = emperor.Attached
	vader.Attached = emperor.Attached
	_final_battle_decided = true

	var threshold := RuleManager.Get(RuleId.FinalBattleWinThreshold, luke.Faction)
	var wins := luke.SpecialPowerLevel >= threshold
	print("[Story] THE FINAL BATTLE at %s: %s at Force %d vs %d -> %s." % [emperor.Attached.Name, luke.Name, luke.SpecialPowerLevel, threshold, "LUKE WINS" if wins else "Luke loses"])
	if wins:
		FinalBattleWon(luke, vader, emperor, day)
	else:
		FinalBattleLost(luke, day, rng)


static func FinalBattleWon(luke: Character, vader: Character, emperor: Character, day: int) -> void:
	var home := HomeFor(luke.Faction)
	luke.CapturedBy = null
	luke.CanEscape = true
	luke.Status = Enums.Status.AwaitingOrders
	luke.Attached = home
	for captive in [vader, emperor]:
		captive.CapturedBy = luke.Faction
		captive.Status = Enums.Status.Kidnapped
		captive.Commanding = null
		captive.Rank = Enums.Rank.None
		captive.Destination = null
		captive.DaysToDestination = 0
		captive.Attached = home

	# The original's words (TEXTSTRA 29152 / 29153, STRATEGY 1063), to both sides.
	for side in [vader.Faction, luke.Faction]:
		if not GameSettings.IsHuman(side):
			continue
		var msg := GameMessage.new("The Final Battle",
			"%s has been brought before the Emperor by %s.  %s confronted and overcame the Emperor.  Both %s and %s were lost." % [
				ForceManager.FirstName(luke), LastName(vader), ForceManager.FirstName(luke), emperor.Name, vader.Name],
			Enums.MessageCategory.Missions, day, home if home is Planet else null, luke)
		msg.Still = "message.1063"
		msg.Sound = "strategy/1138"
		EventBus.Tell(side, msg)
	EventBus.BroadcastChanged()


## "Vader" of "Darth Vader", as the original names him.
static func LastName(c: Character) -> String:
	return c.Name.get_slice(" ", c.Name.get_slice_count(" ") - 1)


static func FinalBattleLost(luke: Character, day: int, rng: Prng) -> void:
	luke.CanEscape = false
	MissionManager.Injure(luke, rng, RuleId.FinalBattleLossInjuryBase, RuleId.FinalBattleLossInjurySpread)
	print("[Story] %s lost the final confrontation: injured %d, and can no longer attempt escape." % [luke.Name, luke.Injury])
	if not GameSettings.IsHuman(luke.Faction):
		return
	# The original's words (TEXTSTRA 29152 / 29154, STRATEGY 1064).
	var vader := WhoHas("dark_lord")
	var msg := GameMessage.new("The Final Battle",
		"%s has been brought before the Emperor by %s.  The Emperor confronted %s and captured him." % [
			ForceManager.FirstName(luke), LastName(vader) if vader != null else "Vader", ForceManager.FirstName(luke)],
		Enums.MessageCategory.Missions, day, luke.Attached if luke.Attached is Planet else null, luke)
	msg.Still = "message.1064"
	msg.Sound = "strategy/1139"
	EventBus.Tell(luke.Faction, msg)
