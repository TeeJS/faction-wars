class_name StoryManager
extends RefCounted
## backend/StoryManager.cs - THE SCRIPTED SET-PIECES, manual p094-p097, p100, and
## the tables behind them: the Force encounter (heritage), the bounty hunters and
## Jabba's palace, and the Final Battle. Keyed by name, as the original is.

const LukeName := "Luke Skywalker"
const LeiaName := "Leia Organa"
const HanName := "Han Solo"
const ChewieName := "Chewbacca"
const VaderName := "Darth Vader"
const EmperorName := "Emperor Palpatine"

static var _next_encounter_scan: int = -1
static var _bounty_hunters_due_on: int = -1
static var _bounty_hunters_fired: bool = false
static var _final_battle_decided: bool = false
static var _palace_rolls_from: int = -1

## ⚠ THE FOUR NAMED PAIRINGS ARE ALL THERE ARE: [aggressor, antagonist, scale id, min id]
const Pairings := [
	[LukeName, VaderName,   RuleId.LukeVsVaderGainScale,   RuleId.LukeVsVaderGainMin],
	[LukeName, EmperorName, RuleId.LukeVsEmperorGainScale, RuleId.LukeVsEmperorGainMin],
	[LeiaName, VaderName,   RuleId.LeiaVsVaderGainScale,   RuleId.LeiaVsVaderGainMin],
	[LeiaName, EmperorName, RuleId.LeiaVsEmperorGainScale, RuleId.LeiaVsEmperorGainMin],
]


static func Who(name: String) -> Character:
	return Lq.first_or_null(GameState.ActiveRoster, func(c): return c.Name == name)


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
		var a := Who(p[0])
		var b := Who(p[1])
		if a == null or b == null:
			continue
		if a.Status == Enums.Status.Dead or b.Status == Enums.Status.Dead:
			continue
		if a.IsOffMap() or b.IsOffMap():
			continue
		if a.Attached == null or a.Attached != b.Attached:
			continue
		if not a.IsKnownJedi:
			continue
		if a.JediLevel < RuleManager.Get(RuleId.EncounterOwnSideMinRank, a.Faction):
			continue
		if b.JediLevel < RuleManager.Get(RuleId.EncounterEnemyMinRank, a.Faction):
			continue
		var chance := a.JediLevel + b.JediLevel + RuleManager.Get(RuleId.EncounterProbabilityOffset, a.Faction)
		if chance <= 0 or rng.NextRange(1, 101) > chance:
			continue
		ResolveEncounter(a, b, p, day, rng)


static func ResolveEncounter(a: Character, b: Character, p: Array, day: int, rng: Prng) -> void:
	var first := not a.KnowsHeritage
	a.KnowsHeritage = true

	var hurt := false
	if a.JediLevel < RuleManager.Get(RuleId.DagobahInjuryCeiling, a.Faction):
		hurt = true
		MissionManager.Injure(a, rng, RuleId.HeritageInjuryBase, RuleId.HeritageInjurySpread)

	var gain := 0
	if not a.IsCaptured() and a.Status != Enums.Status.Dead:
		var scale := RuleManager.Get(p[2], a.Faction)
		var floor_v := RuleManager.Get(p[3], a.Faction)
		gain = max(floor_v, (b.JediLevel - a.JediLevel) * scale / 100)
		a.JediLevel += gain

	var rank_name := JsonUtil.enum_name(Enums.ForceRanking, a.ForceRank())
	print("[Story] %s encountered %s at %s: heritage %s, %s, Force +%d -> %d (%s)." % [
		a.Name, b.Name, a.Attached.Name if a.Attached != null else "", "REVEALED" if first else "already known",
		("injured %d" % a.Injury) if hurt else "unharmed", gain, a.JediLevel, rank_name])

	if not GameSettings.IsHuman(a.Faction):
		return
	var body := ""
	body += ("%s has met %s face to face, and has learned the truth of their own parentage.\n\n" % [a.Name, b.Name]) if first \
		else ("%s has met %s face to face once more.\n\n" % [a.Name, b.Name])
	if hurt and a.Status != Enums.Status.Dead:
		body += "%s was badly hurt in the encounter and cannot be sent on missions or hold a command until they have recovered.\n\n" % a.Name
	if gain > 0:
		body += "Standing against one so strong has taught them something all the same: %s is now %s." % [a.Name, rank_name]
	EventBus.Tell(a.Faction, GameMessage.new(
		("%s has learned the truth" % a.Name) if first else ("%s has faced %s" % [a.Name, b.Name]),
		body.strip_edges(false, true), Enums.MessageCategory.Missions, day, a.Attached if a.Attached is Planet else null, a))


# --- 2. THE BOUNTY HUNTERS, AND JABBA'S PALACE (entries 103/104/105; RLEVADTB) ---

static func ProcessBountyHunters(day: int, rng: Prng) -> void:
	var han := Who(HanName)
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
		EventBus.Tell(han.Faction, GameMessage.new("Bounty hunters tried for %s" % han.Name,
			"%s was set upon by bounty hunters at %s and fought his way clear." % [han.Name, han.Attached.Name if han.Attached != null else "his post"],
			Enums.MessageCategory.Missions, day, han.Attached if han.Attached is Planet else null, han))
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

	_palace_rolls_from = day + MissionCatalog.RollLengthById(MissionCatalog.Palace, rng, 0)

	ForceManager.InterruptDagobah()

	var party := []
	for name in [LukeName, LeiaName, ChewieName]:
		var c := Who(name)
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
	EventBus.Tell(han.Faction, GameMessage.new("%s has been taken" % han.Name,
		"Bounty hunters have seized %s and carried him to Jabba's palace.\n\n%s" % [han.Name,
			("%s %s gone after him without waiting for orders. None of them can be located or given orders until this is settled." % [names, "has" if party.size() == 1 else "have"]) if not party.is_empty()
			else "There is nobody free to go after him."],
		Enums.MessageCategory.Missions, day, null, han))


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
		var chance := MissionTableManager.Lookup(MissionTableManager.Rescue, score)
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
		Enums.MessageCategory.Missions, day, home if home is Planet else null, han))


## ⚠ OURS: the headquarters world when held, any held world otherwise.
static func HomeFor(f: Faction) -> Location:
	if f == null or GameState.ActiveRoster == null:
		return null
	var worlds := Lq.where(GameState.AllPlanets(), func(p): return p.ControllingFaction == f)
	if worlds.is_empty():
		return null
	var seat: String = f.Hq.Planet if f.Hq != null else ""
	var at_seat: Planet = Lq.first_or_null(worlds, func(p): return p.Name == seat)
	return at_seat if at_seat != null else worlds[0]


# --- 3. THE FINAL BATTLE (0x56F7A0 ARMED at entry 55; 0x54B040 DECIDED at entry 106) ---

static func ProcessFinalBattle(day: int, rng: Prng) -> void:
	var luke := Who(LukeName)
	if luke == null or luke.Status == Enums.Status.Dead:
		return

	if not luke.FinalBattleReady and luke.KnowsHeritage \
			and luke.JediLevel >= RuleManager.Get(RuleId.LukeKnowsHeritageThresh, luke.Faction):
		luke.FinalBattleReady = true
		print("[Story] %s is ready for the final confrontation (Force %d)." % [luke.Name, luke.JediLevel])

	if not luke.FinalBattleReady or _final_battle_decided:
		return

	var vader := Who(VaderName)
	var emperor := Who(EmperorName)
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
	var wins := luke.JediLevel >= threshold
	print("[Story] THE FINAL BATTLE at %s: %s at Force %d vs %d -> %s." % [emperor.Attached.Name, luke.Name, luke.JediLevel, threshold, "LUKE WINS" if wins else "Luke loses"])
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

	if GameSettings.IsHuman(vader.Faction):
		EventBus.Tell(vader.Faction, GameMessage.new("Our leaders have been taken",
			"%s and %s confronted %s and were overcome. Both are now prisoners of the %s." % [vader.Name, emperor.Name, luke.Name, luke.Faction.DisplayName],
			Enums.MessageCategory.Missions, day, home if home is Planet else null))
		EventBus.BroadcastChanged()
	if not GameSettings.IsHuman(luke.Faction):
		return

	EventBus.Tell(luke.Faction, GameMessage.new("%s has prevailed" % luke.Name,
		"%s brought %s before %s, and it was the two of them who did not walk away.\n\n%s is free, and both %s and %s are our prisoners at %s." % [
			vader.Name, luke.Name, emperor.Name, luke.Name, vader.Name, emperor.Name, home.Name if home != null else "our headquarters"],
		Enums.MessageCategory.Missions, day, home if home is Planet else null, luke))
	EventBus.BroadcastChanged()


static func FinalBattleLost(luke: Character, day: int, rng: Prng) -> void:
	luke.CanEscape = false
	MissionManager.Injure(luke, rng, RuleId.FinalBattleLossInjuryBase, RuleId.FinalBattleLossInjurySpread)
	print("[Story] %s lost the final confrontation: injured %d, and can no longer attempt escape." % [luke.Name, luke.Injury])
	if not GameSettings.IsHuman(luke.Faction):
		return
	EventBus.Tell(luke.Faction, GameMessage.new("%s has been broken" % luke.Name,
		"%s was brought before the Emperor and was not strong enough.\n\nHe remains a prisoner, badly hurt, and will not get himself out. Only a Rescue mission or the retaking of the system holding him will free him now." % luke.Name,
		Enums.MessageCategory.Missions, day, luke.Attached if luke.Attached is Planet else null, luke))
