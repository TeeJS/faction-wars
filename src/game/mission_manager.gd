class_name MissionManager
extends RefCounted
## backend/Mission.cs MissionManager - launching, running and resolving missions.
## Every fitted constant is marked as the source marks it; every sourced rule
## cites the same page. Order of operations is the source's exactly, because the
## PRNG stream depends on it.

static var _active: Array[Mission] = []


static func Active() -> Array:
	return _active


## WHAT EACH SPECFORCE MAY BE SENT TO DO - manual p098's roster, entire.
## Name-matched because nothing in the unit tables flags capability.
const SpecForceMissions := {
	# --- Alliance ---
	"Longprobe Y-wing Recon Team": [Enums.MissionType.Reconnaissance],
	"Bothan Spies":                [Enums.MissionType.Espionage],
	"Guerrillas":                  [Enums.MissionType.InciteUprising, Enums.MissionType.SubdueUprising],
	"Infiltrators":                [Enums.MissionType.Abduction, Enums.MissionType.Rescue, Enums.MissionType.Sabotage, Enums.MissionType.DeathStarSabotage],
	# --- Empire ---
	"Imperial Probe Droid":        [Enums.MissionType.Reconnaissance],
	"Imperial Espionage Droid":    [Enums.MissionType.Espionage],
	"Imperial Commandos":          [Enums.MissionType.SubdueUprising, Enums.MissionType.InciteUprising, Enums.MissionType.Sabotage],
	"Noghri Death Commandos":      [Enums.MissionType.Abduction, Enums.MissionType.Assassination, Enums.MissionType.Rescue],
	# Not player-buildable - a scripted event.
	"Bounty Hunters":              [],
}

## ⚠ THE EMPEROR IS EXCLUDED BY THE PROJECT COORDINATOR'S RULING, NOT BY A SOURCE.
const EmperorName := "Emperor Palpatine"

## ⚠ THE OLD FITTED SUCCESS CURVE - only for the four missions the original has no
## outcome table for (the three R&D missions and Jedi Training).
const SuccessDivisor := 2
const MinSuccessPercent := 5
const MaxSuccessPercent := 95

## ⚠ FITTED magnitudes; the STRUCTURE around each is sourced (see the source).
const AssassinationKillPercent := 20
const InjuryProvesFatalPercent := 10
const UprisingSupportSwing := 10       # Incite only; Subdue reads entries 141-144
const TeamSizeBonusPercent := 5
const BetrayalPercent := 40
const JediTrainingDivisor := 12
const FoiledSeizeKilledPercent := 20   # of those seized
const FoiledEscapeInjuryPercent := 35

## Family 24 in CAPSHPSD.DAT, and the only member of it.
const DeathStarFamily := 24


static func Clear() -> void:
	_active.clear()


## CAN THIS UNIT RUN THIS MISSION AT ALL, target aside.
static func CanPerform(u: Unit, type: int) -> bool:
	if u == null:
		return false
	if type == Enums.MissionType.JediTraining:
		return CanTeachJedi(u) or CanBeJediStudent(u)
	if type == Enums.MissionType.ShipDesignResearch or type == Enums.MissionType.TroopTrainingResearch or type == Enums.MissionType.FacilityDesignResearch:
		if not (u is Character):
			return false
		var rc := u as Character
		match type:
			Enums.MissionType.ShipDesignResearch:    return rc.ShipDesign > 0
			Enums.MissionType.TroopTrainingResearch: return rc.TroopTraining > 0
		return rc.FacilityDesign > 0
	# "ONLY Longprobe Y-wing Recon Teams and Imperial Probe Droids may perform it" (p107).
	if u is Character:
		return type != Enums.MissionType.Reconnaissance
	if not SpecForceMissions.has(u.Name):
		return false
	return SpecForceMissions[u.Name].has(type)


## EVERY member has to be able to do the job, decoys included (p102-p103).
static func TeamCanPerform(team: Array, type: int) -> bool:
	return team != null and team.size() > 0 and Lq.all(team, func(u): return CanPerform(u, type)) \
		and TeamMeetsExtraRule(team, type).ok


## A FORCE USER IS ONE WHO KNOWS IT (manual p094).
static func IsForceAware(u: Unit) -> bool:
	return u is Character and (u as Character).IsKnownJedi and (u as Character).JediLevel > 0


static func CanBeJediStudent(u: Unit) -> bool:
	return IsForceAware(u) and u is Character and not (u as Character).CanTrainJedi and (u as Character).Name != EmperorName


## WHO MAY TEACH: CanTrainJedi AND Jedi Knight - entry 42 "Force Qualified
## Character Threshold" = 100.
static func CanTeachJedi(u: Unit) -> bool:
	if not (u is Character):
		return false
	var t := u as Character
	return t.CanTrainJedi and t.JediLevel >= RuleManager.Get(RuleId.ForceQualifiedThresh, t.Faction)


## RULES A PER-MEMBER TEST CANNOT EXPRESS: Jedi Training needs a teacher and
## somebody else Force-aware (Encyclopedia; manual mission table; character tables).
static func TeamMeetsExtraRule(team: Array, type: int) -> Result:
	if type != Enums.MissionType.JediTraining:
		return Result.success()
	if not Lq.any(team, CanTeachJedi):
		return Result.fail("Only Luke Skywalker or Darth Vader can lead a Jedi Training mission.")
	if not Lq.any(team, CanBeJediStudent):
		return Result.fail("There is no Force-aware character here to train.")
	return Result.success()


## Every mission this team could run somewhere, target not considered.
static func PerformableBy(team: Array) -> Array:
	var out := []
	for t in Enums.MissionType.values():
		if TeamCanPerform(team, t):
			out.append(t)
	return out


## Which shipped table each mission rolls against (REBEXE.EXE 0x58B420).
static func TableFor(type: int) -> Variant:
	match type:
		Enums.MissionType.Diplomacy:         return MissionTableManager.Diplomacy
		Enums.MissionType.Rescue:            return MissionTableManager.Rescue
		Enums.MissionType.Sabotage:          return MissionTableManager.Sabotage
		Enums.MissionType.DeathStarSabotage: return MissionTableManager.DeathStarSabotage
		Enums.MissionType.Espionage:         return MissionTableManager.Espionage
		Enums.MissionType.Recruitment:       return MissionTableManager.Recruitment
		Enums.MissionType.Abduction:         return MissionTableManager.Abduction
		Enums.MissionType.InciteUprising:    return MissionTableManager.InciteUprising
		Enums.MissionType.SubdueUprising:    return MissionTableManager.SubdueUprising
		Enums.MissionType.Assassination:     return MissionTableManager.Assassination
	return null


## THE DEFENCE TERM, "a2": against a named person their own rating in the same
## attribute; against a system the support enjoyed by whoever opposes us there.
static func DefenceTerm(m: Mission) -> int:
	if m.TargetCharacter != null:
		return AttributeFor(m.Type, m.TargetCharacter)
	var worst := 0
	for f in FactionRegistry.Playable:
		if f != m.Faction:
			worst = max(worst, m.Target.SupportFor(f))
	return worst


## "A DEATH STAR WITH A KNOWN LOCATION" (manual p105) - reading B of the source's
## three candidates: ordinary intel staleness.
static func CanSabotageDeathStar(actor: Faction, target: Planet) -> Result:
	if GameState.ActiveGalaxy.is_empty():
		return Result.fail("No galaxy.")
	var station := DeathStarAt(target)
	if station == null:
		return Result.fail("There is no Death Star at %s." % target.Name)
	if station.Faction == actor:
		return Result.fail("That Death Star is ours.")
	if station.Status == Enums.Status.Enroute \
			or Lq.any(target.OrbitingFleets, func(f): return f.Ships.has(station) and f.Status == Enums.Status.Enroute):
		return Result.fail("That Death Star is in hyperspace.")
	var seen := IntelManager.View(actor, target, Enums.IntelSection.OrbitingShips)
	if not seen.Known or not Lq.any(seen.Lines, func(l): return l.begins_with(station.Name)):
		return Result.fail("We do not know of a Death Star at %s. Reconnaissance or an Espionage mission would find one." % target.Name)
	return Result.success()


static func DeathStarAt(where: Planet) -> Unit:
	if where == null:
		return null
	for f in where.OrbitingFleets:
		for s in f.Ships:
			if s.FamilyId == DeathStarFamily:
				return s
	return null


## A SUCCESSFUL ESPIONAGE MISSION LEAKS MORE THAN ITS TARGET (REBEXE.EXE 0x55C940;
## entries 131-136). WHICH systems is OURS: unexplored worlds picked at random.
static func LeakExtraSystems(m: Mission, rng: Prng) -> String:
	if GameState.ActiveGalaxy.is_empty():
		return ""
	var capital := Lq.any(FactionRegistry.Playable, func(f): return f.Hq != null and not f.Hq.Planet.is_empty() and f.Hq.Planet == m.Target.Name)
	var floor_id := RuleId.EspionageRevealCoruscantFloor if capital else RuleId.EspionageRevealFloor
	var spread_id := RuleId.EspionageRevealCoruscantSpread if capital else RuleId.EspionageRevealSpread
	var count := RuleManager.Roll(floor_id, spread_id, rng, m.Faction)
	if count <= 0:
		return ""
	var dark := Lq.where(GameState.AllPlanets(), func(p): return not p.ExploredBy(m.Faction) and p != m.Target)
	if dark.is_empty():
		return ""
	var found := []
	var i := 0
	while i < count and dark.size() > 0:
		var pick := rng.NextMax(dark.size())
		var world: Planet = dark[pick]
		dark.remove_at(pick)
		world.SetExplored(m.Faction, true)
		found.append(world.Name)
		i += 1
	print("[Mission] Espionage at %s also leaked %d system(s)%s: %s" % [m.Target.Name, found.size(), " - a capital, so more of them" if capital else "", Lq.join(found)])
	return "\n\nThey came back with more than they went for%s. These systems are now charted: %s." % [
		" - a seat of government is where a war's traffic passes through" if capital else "", Lq.join(found)]


## THE THIRD SCORE TERM, "a3": the number of STORMTROOPER REGIMENTS on the target
## (the original hardcodes the unit; matched by name).
static func GarrisonTerm(m: Mission) -> int:
	if m.Target == null or m.Target.Garrison == null:
		return 0
	return Lq.count(m.Target.Garrison, func(u): return u.Type == Enums.UnitType.Troop and u.Name == "Stormtrooper Regiment")


## The score that indexes the table (REBEXE.EXE 0x55C680-0x55C8D0).
static func ScoreFor(m: Mission, rating: int) -> int:
	match m.Type:
		Enums.MissionType.Espionage, Enums.MissionType.Rescue:
			return rating
		Enums.MissionType.Sabotage, Enums.MissionType.DeathStarSabotage:
			return rating
		Enums.MissionType.Diplomacy, Enums.MissionType.SubdueUprising:
			return rating + GarrisonTerm(m) - DefenceTerm(m)
		Enums.MissionType.InciteUprising:
			return rating - DefenceTerm(m) - GarrisonTerm(m)
	return rating - DefenceTerm(m)


## -1 when this mission has no shipped table and the fitted path should be used.
static func SuccessPercent(m: Mission, rating: int) -> int:
	var table: Variant = TableFor(m.Type)
	if table == null or not MissionTableManager.Has(table):
		return -1
	return MissionTableManager.Lookup(table, ScoreFor(m, rating))


static func Pretty(r: int) -> String:
	match r:
		Enums.ForceRanking.JediStudent: return "Jedi Student"
		Enums.ForceRanking.JediKnight:  return "Jedi Knight"
		Enums.ForceRanking.JediMaster:  return "Jedi Master"
	return JsonUtil.enum_name(Enums.ForceRanking, r)


## Does this unit go on missions at all? (manual p045, p047, p098)
static func CanEverPerformMissions(u: Unit) -> bool:
	return u is Character or (u != null and SpecForceMissions.has(u.Name))


## The cross on a mission report (manual p109). The team is released HERE.
static func Abort(m: Mission) -> void:
	if m == null or m.Finished:
		return
	m.Finished = true
	print("[Mission] %s at %s aborted." % [m.DisplayName(), m.Target.Name])
	Conclude(m)
	_active.erase(m)
	EventBus.BroadcastChanged()


## WHO IS RUNNING THIS: the best-rated non-decoy, who the success roll reads.
static func Leader(m: Mission) -> Unit:
	var agents := Lq.where(m.Team, func(u): return not m.Decoys.has(u))
	if agents.is_empty():
		agents = m.Team.duplicate()
	var sorted := Lq.order_by(agents, func(u): return AttributeFor(m.Type, u), true)
	return sorted[0] if not sorted.is_empty() else null


## "Any successful mission (Force-aware characters) - small growth" (p094-p095),
## entries 58/59 = 1. Only characters who ALREADY know they are Force-aware grow.
static func AwardForceForSuccess(m: Mission, day: int) -> void:
	var reward := RuleManager.Get(RuleId.OrdinaryMissionForceReward, m.Faction)
	if reward <= 0:
		return
	for c in Lq.of_type_character(m.Team):
		if not c.IsKnownJedi or c.JediLevel <= 0:
			continue
		var before: int = c.ForceRank()
		c.JediLevel += reward
		if c.ForceRank() == before:
			continue
		print("[Force] %s has advanced to %s (level %d)." % [c.Name, JsonUtil.enum_name(Enums.ForceRanking, c.ForceRank()), c.JediLevel])
		if not GameSettings.IsHuman(m.Faction):
			continue
		EventBus.Tell(m.Faction, GameMessage.new(
			"%s is now a %s" % [c.Name, Pretty(c.ForceRank())],
			"%s's command of the Force has deepened through service. They stand at %s." % [c.Name, Pretty(c.ForceRank())],
			Enums.MessageCategory.Missions, day, m.Target, c))


## Characters improve the skill their mission exercised, on success (guide p094-095;
## "SPECIAL FORCES CANNOT IMPROVE"). Lq.of_type_character filters SpecForce units out,
## which honours that rule and matches the AwardForceForSuccess / DeathStarSabotage
## precedent. Magnitudes are shipped gnprtb entries 111,112,114-121 (each 1), read via
## RuleManager - never invented. DeathStarSabotage grants its own 122/123 in the success
## block, so it is excluded here; the three Research types grow faction research, not a
## character rating, and are left out (entry 113's rating target is unconfirmed).
static func AwardSkillForSuccess(m: Mission) -> void:
	for c in Lq.of_type_character(m.Team):
		match m.Type:
			Enums.MissionType.Diplomacy:
				c.DiplomacyRating += RuleManager.Get(RuleId.DiplomacySuccessDiplomacyGain, m.Faction)
			Enums.MissionType.Espionage:
				c.EspionageRating += RuleManager.Get(RuleId.EspionageSuccessEspionageGain, m.Faction)
			Enums.MissionType.Recruitment:
				c.LeadershipRating += RuleManager.Get(RuleId.RecruitmentSuccessLeadershipGain, m.Faction)
			Enums.MissionType.InciteUprising:
				c.LeadershipRating += RuleManager.Get(RuleId.InciteUprisingSuccessLeadershipGain, m.Faction)
			Enums.MissionType.SubdueUprising:
				c.LeadershipRating += RuleManager.Get(RuleId.SubdueUprisingSuccessLeadershipGain, m.Faction)
			Enums.MissionType.Rescue:
				c.CombatRating += RuleManager.Get(RuleId.RescueSuccessCombatGain, m.Faction)
			Enums.MissionType.Abduction:
				c.CombatRating += RuleManager.Get(RuleId.AbductionSuccessCombatGain, m.Faction)
			Enums.MissionType.Assassination:
				c.CombatRating += RuleManager.Get(RuleId.AssassinationSuccessCombatGain, m.Faction)
			Enums.MissionType.Sabotage:
				c.EspionageRating += RuleManager.Get(RuleId.SabotageSuccessEspionageGain, m.Faction)
				c.CombatRating += RuleManager.Get(RuleId.SabotageSuccessCombatGain, m.Faction)


## Rank first, as the original addresses them - "Admiral Ackbar".
static func DisplayNameOf(u: Unit) -> Variant:
	if u is Character and (u as Character).Rank != Enums.Rank.None:
		return "%s %s" % [JsonUtil.enum_name(Enums.Rank, (u as Character).Rank), u.Name]
	return u.Name if u != null else null


static func Report(m: Mission, day: int, title: String, body: String, asks_to_continue: bool = false) -> void:
	if not GameSettings.IsHuman(m.Faction):
		return
	var leader := Leader(m)
	var who: Variant = DisplayNameOf(leader)
	var character: Character = leader as Character
	if character == null:
		var people := Lq.of_type_character(m.Team)
		character = people[0] if not people.is_empty() else null
	var msg := GameMessage.new(title if who == null else "%s: %s" % [who, title], body,
		Enums.MessageCategory.Missions, day, m.Target, character)
	msg.PendingMission = m if asks_to_continue else null
	msg.Type = Enums.MessageType.MissionReport   # ALWAYS MissionReport, NEVER MissionFailed (see source)
	EventBus.Tell(m.Faction, msg)


## Eligibility is the intersection of what the unit can do and what the target
## accepts (manual p102, p106-p111).
static func CanTarget(type: int, actor: Faction, target: Planet) -> Result:
	if target == null:
		return Result.fail("No target.")
	if not target.ExploredBy(actor) and type != Enums.MissionType.Reconnaissance:
		return Result.fail("%s is unexplored - only Reconnaissance can go there." % target.Name)

	match type:
		Enums.MissionType.Diplomacy:
			if target.IsInUprising:
				return Result.fail("%s is in uprising." % target.Name)
			if target.ControllingFaction != null and target.ControllingFaction != actor and FactionRegistry.OrderOf(target.ControllingFaction) >= 0:
				return Result.fail("%s is enemy-held - diplomacy needs a neutral or friendly system." % target.Name)
			return Result.success()
		Enums.MissionType.Espionage:
			return Result.success()
		Enums.MissionType.InciteUprising:
			if target.ControllingFaction == actor:
				return Result.fail("%s is already yours." % target.Name)
			if FactionRegistry.OrderOf(target.ControllingFaction) < 0:
				return Result.fail("%s has no government to turn against." % target.Name)
			return Result.success()
		Enums.MissionType.SubdueUprising:
			if target.ControllingFaction != actor:
				return Result.fail("%s is not yours." % target.Name)
			if not target.IsInUprising:
				return Result.fail("%s is not in uprising." % target.Name)
			return Result.success()
		Enums.MissionType.Reconnaissance:
			if target.ControllingFaction == actor:
				return Result.fail("%s is already yours - there is nothing to scout." % target.Name)
			return Result.success()
		Enums.MissionType.Recruitment:
			if target.ControllingFaction != actor:
				return Result.fail("%s is not yours." % target.Name)
			return Result.success()
		Enums.MissionType.Abduction, Enums.MissionType.Assassination, Enums.MissionType.Rescue:
			return Result.success()
		Enums.MissionType.Sabotage:
			return Result.success()   # the OBJECT carries every qualifier (see source)
		Enums.MissionType.DeathStarSabotage:
			return CanSabotageDeathStar(actor, target)
		Enums.MissionType.JediTraining:
			if target.ControllingFaction != actor:
				return Result.fail("%s is not ours." % target.Name)
			return Result.success()
		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			if target.ControllingFaction != actor:
				return Result.fail("%s is not ours." % target.Name)
			var needed: int
			match type:
				Enums.MissionType.ShipDesignResearch:    needed = Enums.FacilityType.Shipyard
				Enums.MissionType.TroopTrainingResearch: needed = Enums.FacilityType.TrainingFacility
				_:                                       needed = Enums.FacilityType.ConstructionYard
			if target.CountOf(needed) == 0:
				return Result.fail("%s has no %s." % [target.Name, JsonUtil.enum_name(Enums.FacilityType, needed)])
			return Result.success()
	return Result.fail("Unknown mission type.")


## WHOSE JOURNEY BELONGS TO A MISSION - the movement loops leave them alone.
static func IsOnMissionTeam(u: Unit) -> bool:
	if u == null:
		return false
	for m in _active:
		if not m.Finished and m.Team.has(u):
			return true
	return false


## WOUND SOMEBODY, and roll the manual's standing risk that it finishes them
## (p096). Returns true if the wound killed them.
static func Injure(c: Character, rng: Prng, base_id: int = RuleId.FallbackInjuryBase, spread_id: int = RuleId.FallbackInjurySpread) -> bool:
	if c == null or c.Status == Enums.Status.Dead:
		return false
	var severity := RuleManager.Roll(base_id, spread_id, rng, c.Faction)
	c.Injury = max(c.Injury, max(1, severity))
	c.DaysResting = 0
	c.Commanding = null
	if c.IsMajor:
		return false
	if rng.NextRange(1, 101) > InjuryProvesFatalPercent:
		return false
	Kill(c)
	return true


## Dead (manual p096). They keep their roster slot and leave the map.
static func Kill(c: Character) -> void:
	if c == null:
		return
	c.Status = Enums.Status.Dead
	c.Injury = 0
	c.CapturedBy = null
	c.Commanding = null
	c.Attached = null
	c.Destination = null
	c.DaysToDestination = 0


static func NeedsCharacterTarget(type: int) -> bool:
	return type == Enums.MissionType.Abduction or type == Enums.MissionType.Assassination or type == Enums.MissionType.Rescue


static func NeedsObjectTarget(type: int) -> bool:
	return type == Enums.MissionType.Sabotage


static func _is_empire(actor: Faction) -> bool:
	return actor != null and actor.Id.to_lower() == "empire"


## IS THIS A LEGAL SABOTAGE TARGET? Manual p108. `target` is a Facility or a Unit.
static func CanSabotage(actor: Faction, target: Variant, where: Planet) -> Result:
	if target is Facility:
		var f := target as Facility
		if where == null or not where.Facilities.has(f):
			return Result.fail("That facility is not there.")
		if where.ControllingFaction == actor:
			return Result.fail("The %s is ours." % f.Name())
		if f.Type == Enums.FacilityType.Headquarters and not _is_empire(actor):
			return Result.fail("Only the Empire can sabotage a headquarters.")
		return Result.success()
	if target is Unit:
		var u := target as Unit
		if u.Faction == actor:
			return Result.fail("%s is one of ours." % u.Name)
		if u.Status == Enums.Status.Enroute:
			return Result.fail("%s is in hyperspace." % u.Name)
		if u is Character:
			return Result.fail("People are not sabotaged - use Abduction or Assassination.")
		if u.Name == "Death Star":
			return Result.fail("A Death Star needs a Death Star Sabotage mission.")
		return Result.success()
	return Result.fail("That cannot be sabotaged.")


## IS THIS PERSON A LEGAL TARGET for that mission? (manual p106-p111)
static func CanTargetPerson(type: int, actor: Faction, victim: Character) -> Result:
	if not NeedsCharacterTarget(type):
		return Result.success()
	if victim == null:
		return Result.fail("That mission needs a person as its target.")
	if victim.Status == Enums.Status.Dead:
		return Result.fail("%s is dead." % victim.Name)
	if victim.Status == Enums.Status.Enroute:
		return Result.fail("%s is in hyperspace." % victim.Name)
	if victim.IsOffMap():
		return Result.fail("%s cannot be located." % victim.Name)
	match type:
		Enums.MissionType.Abduction, Enums.MissionType.Assassination:
			if victim.Faction == actor:
				return Result.fail("%s is one of yours." % victim.Name)
			if victim.IsCaptured():
				return Result.fail("%s is already captured." % victim.Name)
			if type == Enums.MissionType.Assassination and not _is_empire(actor):
				return Result.fail("Only the Empire carries out assassinations.")
			return Result.success()
		Enums.MissionType.Rescue:
			if not victim.IsCaptured():
				return Result.fail("%s is not a prisoner." % victim.Name)
			if victim.CapturedBy == actor:
				return Result.fail("%s is already in your hands." % victim.Name)
			return Result.success()
	return Result.success()


static func Launch(type: int, team: Array, from: Planet, target: Planet, decoys: Variant = null,
		victim: Character = null, saboteur_target: Variant = null) -> Mission:
	if team == null or team.is_empty() or from == null:
		return null
	var actor: Faction = team[0].Faction
	if actor == null or Lq.any(team, func(c): return c.Faction != actor):
		print("[Mission] A mission team must all belong to the same faction.")
		return null

	var why := CanTarget(type, actor, target)
	if not why.ok:
		print("[Mission] %s" % why.error)
		return null
	var party := TeamMeetsExtraRule(team, type)
	if not party.ok:
		print("[Mission] %s" % party.error)
		return null
	var who := CanTargetPerson(type, actor, victim)
	if not who.ok:
		print("[Mission] %s" % who.error)
		return null
	if NeedsObjectTarget(type):
		var what := CanSabotage(actor, saboteur_target, target)
		if not what.ok:
			print("[Mission] %s" % what.error)
			return null

	var unable: Unit = Lq.first_or_null(team, func(u): return not CanPerform(u, type))
	if unable != null:
		print("[Mission] %s cannot perform %s." % [unable.Name, JsonUtil.enum_name(Enums.MissionType, type)])
		return null

	var unfit: Unit = Lq.first_or_null(team, func(u): return u is Character and not (u as Character).CanTakeOrders())
	if unfit != null:
		print("[Mission] %s is in no condition to go." % unfit.Name)
		return null

	if type == Enums.MissionType.JediTraining:
		var people := Lq.of_type_character(team)
		if not Lq.any(people, CanTeachJedi):
			print("[Mission] Jedi Training needs Luke Skywalker or Darth Vader.")
			return null
		if not Lq.any(people, CanBeJediStudent):
			print("[Mission] Jedi Training needs at least one Force-aware student.")
			return null

	var busy: Unit = Lq.first_or_null(team, IsOnMissionTeam)
	if busy != null:
		print("[Mission] %s is already on a mission." % busy.Name)
		return null

	if type == Enums.MissionType.Recruitment and not Lq.any(Lq.of_type_character(team), func(c): return c.IsMajor):
		print("[Mission] Recruitment requires a major character on the team.")
		return null

	var mission := Mission.new()
	mission.Type = type
	mission.Faction = actor
	mission.Target = target
	mission.TargetCharacter = victim
	mission.TargetFacility = saboteur_target as Facility if saboteur_target is Facility else null
	mission.TargetUnit = saboteur_target as Unit if saboteur_target is Unit else null
	mission.HomeBase = from
	for u in team:
		mission.Team.append(u)
	if decoys != null:
		for u in decoys:
			mission.Decoys.append(u)
	mission.DaysToTarget = from.DeploymentDaysTo(target)

	for c in team:
		if mission.Arrived():
			MilitaryCatalog.Relocate(c, target)
			c.Destination = null
			c.DaysToDestination = 0
			c.Status = Enums.Status.OnMission
		else:
			c.Status = Enums.Status.Enroute
			c.Destination = target
			c.DaysToDestination = mission.DaysToTarget
	_active.append(mission)

	# "CHARACTERS STRONG IN THE FORCE CAN ALSO FERRET OUT TRAITORS IN A PARTY" (p094).
	for exposed in LoyaltyManager.FerretOutTraitors(mission.Team):
		print("[Loyalty] %s exposed as a traitor." % exposed.Name)
		EventBus.BroadcastMessage(GameMessage.new(
			"%s is a traitor" % exposed.Name,
			"My Force-sensitive companions have seen through %s, who has turned against us. They are still with the team bound for %s.\n\nThey can be retired from their right-click menu. Or leave them be - if our fortunes improve, so will theirs." % [exposed.Name, target.Name],
			Enums.MessageCategory.Missions, StrategicTickManager.Today, from, exposed))

	EventBus.BroadcastChanged()
	print("[Mission] %s launched at %s by %s - %dd transit." % [JsonUtil.enum_name(Enums.MissionType, type), target.Name, Lq.join(Lq.select(team, func(t): return t.Name)), mission.DaysToTarget])
	return mission


static func ProcessDay(rng: Prng, day: int) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var m: Mission = _active[i]

		# ✅ THE TRAINING ABORT, FROM THE ENCYCLOPEDIA: "OR CONTROL PASSES OVER TO
		# THE ENEMY, the training mission is considered FOILED."
		if m.Type == Enums.MissionType.JediTraining and m.Arrived() and m.Target.ControllingFaction != m.Faction:
			var lost := SeizeFoiledTeam(m, rng)
			Report(m, day, "Jedi Training foiled at %s" % m.Target.Name,
				"%s is no longer ours. The training was broken off.\n\n%s" % [m.Target.Name, lost])
			Conclude(m)
			_active.remove_at(i)
			EventBus.BroadcastChanged()
			continue

		if not m.Arrived():
			m.DaysToTarget -= 1
			for c in m.Team:
				c.DaysToDestination = m.DaysToTarget
			if m.Arrived():
				for c in m.Team:
					MilitaryCatalog.Relocate(c, m.Target)
					c.Destination = null
					c.DaysToDestination = 0
					c.Status = Enums.Status.OnMission
			if not m.Arrived():
				continue   # still in hyperspace
			# THE DAY THEY LAND IS THE FIRST DAY ON STATION.
			m.Announced = true
			m.DaysOnStation = m.RollWorkDays(rng)
			Report(m, day, "%s team has arrived" % m.DisplayName(),
				"My %s team has reached %s and is beginning work." % [m.DisplayName().to_lower(), m.Target.Name])

		# A TEAM ALREADY STANDING ON THE TARGET DOES NOT "ARRIVE".
		if not m.Announced:
			m.Announced = true
			m.DaysOnStation = m.RollWorkDays(rng)
			Report(m, day, "%s mission begun" % m.DisplayName(),
				"My %s team is already at %s and has begun work." % [m.DisplayName().to_lower(), m.Target.Name])

		# ON STATION AND WORKING.
		if m.DaysOnStation > 0:
			m.DaysOnStation -= 1
			continue

		Resolve(m, rng, day)

		if m.Finished:
			Conclude(m)
			_active.remove_at(i)
			EventBus.BroadcastChanged()
		else:
			m.DaysOnStation = m.RollWorkDays(rng)


## "Before a mission can have a chance at success, team members must sneak past
## enemy defenses" (manual p103). Scored as the original does (DISASSEMBLY-NOTES.md)
## and rolled against FOILTB.DAT.
static func Foiled(m: Mission, rng: Prng) -> bool:
	if m.Target.ControllingFaction == m.Faction:
		return false

	# THE WATCH - units (ours: p103 with entry 70's scale by analogy).
	var watch := Lq.sum(m.Target.Garrison, func(u): return u.Detection) \
		+ Lq.sum(m.Target.FighterSquadrons, func(u): return u.Detection) \
		+ Lq.sum(m.Target.OrbitingFleets, func(f): return Lq.sum(f.Ships, func(s): return s.Detection))

	# THE BASE IS THE TEAM'S MEAN, NOT ITS BEST (0x5887A0); ESPIONAGE IS THE STAT;
	# NON-DECOYS ONLY.
	var members := Lq.where(m.Team, func(u): return not m.Decoys.has(u))
	if members.is_empty():
		members = m.Team.duplicate()
	var mean := Lq.sum(members, func(u): return u.EspionageRating) / members.size()

	# THE WATCH - personnel, entry 70's input: the defending commander's Espionage.
	var defender_espionage := 0
	for c in GameState.ActiveRoster:
		if c.Commanding == m.Target and c.Faction != m.Faction and c.Rank != Enums.Rank.None:
			defender_espionage = max(defender_espionage, c.EspionageRating)

	if watch <= 0 and defender_espionage <= 0:
		return false

	var scale := RuleManager.Get(RuleId.DefenderEspionagePenalty, m.Faction)   # entry 70 = 35
	var bias := RuleManager.Get(RuleId.HostileFoilScoreBias, m.Faction)         # entry 65 = -1, subtracted

	var score := mean \
		- defender_espionage * scale / 100 \
		- watch * scale / 100 \
		- bias

	var chance := MissionTableManager.Lookup(MissionTableManager.Foil, score)
	if chance < 0:
		return false   # no table loaded - do not invent one

	print("[Mission] %s foil score %d (mean espionage %d, personnel espionage %d, unit watch %d, scale %d%%) -> %d%% per member; %d decoy(s) in reserve." % [
		m.Target.Name, score, mean, defender_espionage, watch, scale, chance, m.Decoys.size()])

	var spent: Array = []
	for agent in m.Team:
		if rng.NextRange(1, 101) > chance:
			continue
		if m.Decoys.has(agent):
			print("[Mission] %s drew attention at %s - the mission continues." % [agent.Name, m.Target.Name])
			continue
		if DecoyScreens(m, agent, defender_espionage, spent, rng):
			continue
		print("[Mission] %s at %s FOILED - %s was detected." % [JsonUtil.enum_name(Enums.MissionType, m.Type), m.Target.Name, agent.Name])
		m.FoiledBy = agent
		return true
	return false


## THE DECOY CONTEST - FDECOYTB.DAT: a decoy picked uniformly at random steps in
## AFTER a primary is spotted, and is consumed if it works.
static func DecoyScreens(m: Mission, member: Unit, defender_espionage: int, spent: Array, rng: Prng) -> bool:
	var reserve := Lq.where(m.Decoys, func(d): return not spent.has(d))
	if reserve.is_empty():
		return false
	var decoy: Unit = reserve[rng.NextMax(reserve.size())]
	var scale := RuleManager.Get(RuleId.DecoyStatDebuffPercent, m.Faction)
	var score := decoy.EspionageRating - defender_espionage * scale / 100
	var chance := MissionTableManager.Lookup(MissionTableManager.Decoy, score)
	if chance < 0:
		return false
	if rng.NextRange(1, 101) > chance:
		print("[Mission] %s failed to draw attention off %s (score %d -> %d%%)." % [decoy.Name, member.Name, score, chance])
		return false
	spent.append(decoy)
	print("[Mission] %s drew the watch off %s at %s (score %d -> %d%%) and is spent." % [decoy.Name, member.Name, m.Target.Name, score, chance])
	return true


## THE PRICE OF BEING CAUGHT, per member (manual p103, p096): the evasion roll
## against RLEVADTB.DAT, then capture or death.
static func SeizeFoiledTeam(m: Mission, rng: Prng) -> String:
	var commander_combat := 0
	for c in GameState.ActiveRoster:
		if c.Commanding == m.Target and c.Faction != m.Faction and c.Rank != Enums.Rank.None:
			commander_combat = max(commander_combat, c.CombatRating)

	var captured := []
	var killed := []
	var hurt := []

	for member in m.Team.duplicate():
		var evade_score: int = member.CombatRating - commander_combat
		var evade := MissionTableManager.Lookup(MissionTableManager.Evasion, evade_score)
		if evade < 0 or rng.NextRange(1, 101) <= evade:
			if member is Character and rng.NextRange(1, 101) <= FoiledEscapeInjuryPercent:
				var runner := member as Character
				if Injure(runner, rng):
					killed.append(runner.Name)
				else:
					hurt.append(runner.Name)
			continue

		var dies := rng.NextRange(1, 101) <= FoiledSeizeKilledPercent
		if member is Character:
			var person := member as Character
			if dies and not person.IsMajor:
				Kill(person)
				killed.append(person.Name)
			else:
				person.CapturedBy = m.Target.ControllingFaction
				person.Status = Enums.Status.Kidnapped
				person.Commanding = null
				person.Destination = null
				person.DaysToDestination = 0
				captured.append(person.Name)
		else:
			# SpecForce - lost outright.
			if member.Attached is Planet:
				var where: Planet = member.Attached
				where.Garrison.erase(member)
				where.FighterSquadrons.erase(member)
			m.Team.erase(member)
			killed.append(member.Name)

	var parts := []
	if not captured.is_empty():
		parts.append("Captured: %s." % Lq.join(captured))
	if not killed.is_empty():
		parts.append("Lost: %s." % Lq.join(killed))
	if not hurt.is_empty():
		parts.append("Wounded escaping: %s." % Lq.join(hurt))
	if parts.is_empty():
		parts.append("The whole team broke contact and is returning to base.")
	else:
		parts.append("Any survivors are returning to base.")
	EventBus.BroadcastChanged()
	return " ".join(parts)


static func Resolve(m: Mission, rng: Prng, day: int) -> void:
	# Detection happens before anything else, and only on the first approach.
	if m.Attempts == 0 and Foiled(m, rng):
		var fate := SeizeFoiledTeam(m, rng)
		Report(m, day, "%s mission foiled" % m.DisplayName(),
			"%s was detected by defenders at %s. The mission was foiled.\n\n%s" % [m.FoiledBy.Name if m.FoiledBy != null else "My team", m.Target.Name, fate])
		m.Finished = true
		return

	# "IF YOU SEND A TRAITOR ON A MISSION, HE OR SHE MAY BETRAY THE MISSION" (p094).
	if m.Attempts == 0:
		var betrayer: Character = null
		for c in Lq.of_type_character(m.Team):
			if c.IsTraitorous() and rng.NextRange(1, 101) <= BetrayalPercent:
				betrayer = c
				break
		if betrayer != null:
			betrayer.TraitorRevealed = true
			print("[Mission] %s at %s BETRAYED by %s." % [JsonUtil.enum_name(Enums.MissionType, m.Type), m.Target.Name, betrayer.Name])
			Report(m, day, "%s mission betrayed" % m.DisplayName(),
				"%s betrayed our %s mission at %s. Nothing was achieved.\n\nTheir loyalty has been in question for some time. They can be retired from their right-click menu, or left to come round if our fortunes improve." % [betrayer.Name, m.DisplayName().to_lower(), m.Target.Name])
			m.Finished = true
			EventBus.BroadcastChanged()
			return

	m.Attempts += 1

	var agents := Lq.where(m.Team, func(c): return not m.Decoys.has(c))
	if agents.is_empty():
		agents = m.Team.duplicate()
	var rating := Lq.max_of(agents, func(c): return AttributeFor(m.Type, c))

	var chance: int
	if m.Type == Enums.MissionType.Reconnaissance:
		chance = 100
	else:
		var from_table := SuccessPercent(m, rating)
		if from_table >= 0:
			chance = clampi(from_table + (agents.size() - 1) * TeamSizeBonusPercent, 0, 100)
		else:
			chance = clampi(rating / SuccessDivisor + (agents.size() - 1) * TeamSizeBonusPercent, MinSuccessPercent, MaxSuccessPercent)

	var success := rng.NextRange(1, 101) <= chance

	if not success:
		print("[Mission] %s at %s failed (attempt %d, %d%%)." % [JsonUtil.enum_name(Enums.MissionType, m.Type), m.Target.Name, m.Attempts, chance])
		var persistent := m.IsPersistent()
		Report(m, day, "%s attempt %d failed" % [m.DisplayName(), m.Attempts],
			("My team made no progress at %s on attempt %d.\n\nDo you wish the mission to continue?" % [m.Target.Name, m.Attempts]) if persistent
			else ("The %s mission at %s failed. The team is returning to base." % [m.DisplayName().to_lower(), m.Target.Name]),
			persistent)
		if not persistent:
			m.Finished = true
		return

	AwardForceForSuccess(m, day)
	AwardSkillForSuccess(m)

	match m.Type:
		Enums.MissionType.Diplomacy:
			# Entries 137-140, split by target.
			var neutral_target := FactionRegistry.OrderOf(m.Target.ControllingFaction) < 0
			var gain := RuleManager.Roll(RuleId.DiploNeutralGainBase, RuleId.DiploNeutralGainSpread, rng, m.Faction) if neutral_target \
				else RuleManager.Roll(RuleId.DiploOccupiedGainBase, RuleId.DiploOccupiedGainSpread, rng, m.Faction)
			m.Target.ShiftSupport(m.Faction, gain)
			var now := m.Target.SupportFor(m.Faction)
			print("[Mission] Diplomacy at %s: support for %s now %d%%." % [m.Target.Name, m.Faction.DisplayName, now])
			if now >= 50 and FactionRegistry.OrderOf(m.Target.ControllingFaction) < 0:
				var before := m.Target.ControllingFaction
				m.Target.ControllingFaction = m.Faction
				print("[Mission] %s has joined the %s." % [m.Target.Name, m.Faction.DisplayName])
				MilitaryCatalog.OnControlChanged(m.Target, before)
			Report(m, day, "Diplomacy succeeding at %s" % m.Target.Name,
				"Support for the %s on %s has risen to %d%%.%s" % [m.Faction.DisplayName, m.Target.Name, now,
					" The system is now wholly with us and the mission is complete." if now >= 100 else "\n\nDo you wish the mission to continue?"],
				now < 100)
			if now >= 100:
				m.Finished = true

		Enums.MissionType.Espionage:
			IntelManager.Capture(m.Faction, m.Target, day, IntelManager.EspionageCategories)
			print("[Mission] Espionage at %s succeeded - full snapshot taken." % m.Target.Name)
			var leaked := LeakExtraSystems(m, rng)
			Report(m, day, "Espionage successful at %s" % m.Target.Name,
				"My agents have returned detailed intelligence on %s.\n\nEverything the System Defenses and Manufacturing windows show for it is accurate as of today. It will not update itself.%s" % [m.Target.Name, leaked])
			m.Finished = true

		Enums.MissionType.InciteUprising:
			var holder := m.Target.ControllingFaction
			m.Target.ShiftSupport(holder, -UprisingSupportSwing)
			var rioting := m.Target.IsInUprising
			Report(m, day, "Unrest spreading on %s" % m.Target.Name,
				"Support for the %s on %s has fallen to %d%%.%s%s" % [holder.DisplayName if holder != null else "occupier", m.Target.Name, m.Target.SupportFor(holder),
					" The system is in open revolt." if rioting else "",
					" The system has thrown them out." if m.Target.ControllingFaction != holder else "\n\nDo you wish the mission to continue?"],
				m.Target.ControllingFaction == holder)
			if m.Target.ControllingFaction != holder:
				m.Finished = true

		Enums.MissionType.SubdueUprising:
			var neutral_target := FactionRegistry.OrderOf(m.Target.ControllingFaction) < 0
			var swing := RuleManager.Roll(RuleId.SubdueNeutralShiftBase, RuleId.SubdueNeutralShiftSpread, rng, m.Faction) if neutral_target \
				else RuleManager.Roll(RuleId.SubdueMatchingShiftBase, RuleId.SubdueMatchingShiftSpread, rng, m.Faction)
			m.Target.ShiftSupport(m.Faction, swing)
			var restored := m.Target.SupportFor(m.Faction)
			var still_rioting := m.Target.IsInUprising
			Report(m, day, "Order returning to %s" % m.Target.Name,
				"Support on %s has risen to %d%%.%s" % [m.Target.Name, restored,
					"\n\nDo you wish the mission to continue?" if still_rioting else " The uprising has ended."],
				still_rioting)
			if not still_rioting:
				m.Finished = true

		Enums.MissionType.Reconnaissance:
			IntelManager.Capture(m.Faction, m.Target, day, IntelManager.ReconnaissanceCategories)
			var owner := m.Target.ControllingFaction.DisplayName if m.Target.ControllingFaction != null else "no one"
			var lines := [
				"Controller: %s" % owner,
				"Popular support for us: %d%%" % m.Target.SupportFor(m.Faction),
				"Resources: %d raw material slots, %d energy slots" % [m.Target.BaseRawMaterials, m.Target.BaseEnergy],
				"Facilities: %d" % m.Target.Facilities.size(),
				"Trooper regiments: %d" % m.Target.Garrison.size(),
				"Fighter squadrons: %d" % m.Target.FighterSquadrons.size(),
				"Fleets in orbit: %d" % m.Target.OrbitingFleets.size(),
			]
			print("[Mission] Reconnaissance of %s complete - system charted." % m.Target.Name)
			Report(m, day, "Reconnaissance report: %s" % m.Target.Name,
				"\n".join(lines) + "\n\nOur probe detected no information on personnel or special forces.")
			m.Finished = true
			EventBus.BroadcastChanged()

		Enums.MissionType.Recruitment:
			var recruit := Recruitable(m.Faction, rng)
			if recruit == null:
				print("[Mission] Recruitment at %s succeeded but no one remains to recruit." % m.Target.Name)
				Report(m, day, "Recruitment at %s" % m.Target.Name, "My agents found no new officers to recruit.")
				m.Finished = true
			else:
				recruit.Attached = m.Target
				recruit.Destination = null
				recruit.DaysToDestination = 0
				recruit.Status = Enums.Status.AwaitingOrders
				print("[Mission] Recruitment at %s succeeded - %s joins." % [m.Target.Name, recruit.Name])
				Report(m, day, "Recruitment successful at %s" % m.Target.Name, "%s has joined our cause at %s." % [recruit.Name, m.Target.Name])
				m.Finished = true
				EventBus.BroadcastChanged()

		Enums.MissionType.Abduction:
			var victim := m.TargetCharacter
			if victim == null or victim.IsCaptured():
				m.Finished = true
			else:
				victim.CapturedBy = m.Faction
				victim.Status = Enums.Status.Kidnapped
				victim.Commanding = null
				victim.Destination = null
				victim.DaysToDestination = 0
				print("[Mission] %s abducted at %s by %s." % [victim.Name, m.Target.Name, m.Faction.DisplayName])
				Report(m, day, "%s captured" % victim.Name,
					"My team has taken %s prisoner at %s. They will be held there until rescued or the system is retaken." % [victim.Name, m.Target.Name])
				m.Finished = true
				EventBus.BroadcastChanged()

		Enums.MissionType.Assassination:
			var victim := m.TargetCharacter
			if victim == null or victim.Status == Enums.Status.Dead:
				m.Finished = true
			else:
				var can_die := not victim.IsMajor and rng.NextRange(1, 101) <= AssassinationKillPercent
				if can_die:
					Kill(victim)
					print("[Mission] %s assassinated at %s." % [victim.Name, m.Target.Name])
					Report(m, day, "%s is dead" % victim.Name, "My team reached %s at %s. The target did not survive." % [victim.Name, m.Target.Name])
				else:
					var died := Injure(victim, rng, RuleId.AssassinInjuryBase, RuleId.AssassinInjurySpread)
					print("[Mission] %s %s at %s." % [victim.Name, "died of wounds" if died else "injured", m.Target.Name])
					Report(m, day, ("%s is dead" % victim.Name) if died else ("%s injured" % victim.Name),
						("My team struck %s at %s. The wounds proved fatal." % [victim.Name, m.Target.Name]) if died
						else ("My team reached %s at %s. They are badly hurt - %sand will not recover until they rest on a system their own side controls." % [
							victim.Name, m.Target.Name,
							"too well protected to kill outright, but far easier to capture now, " if victim.IsMajor else "unable to take a mission or hold a command, "]))
				m.Finished = true
				EventBus.BroadcastChanged()

		Enums.MissionType.Sabotage:
			var what: String = m.TargetObjectName() if m.TargetObjectName() != null else "the target"
			var gone := m.Target.DestroyFacility(m.TargetFacility) if m.TargetFacility != null else m.Target.DestroyUnit(m.TargetUnit)
			if not gone:
				Report(m, day, "%s is already gone" % what, "My team reached %s to find %s no longer there." % [m.Target.Name, what])
				m.Finished = true
			else:
				print("[Mission] Sabotage at %s destroyed %s." % [m.Target.Name, what])
				Report(m, day, "%s destroyed" % what, "My team has destroyed %s at %s." % [what, m.Target.Name])
				m.Finished = true

		Enums.MissionType.DeathStarSabotage:
			var station := DeathStarAt(m.Target)
			if station == null:
				Report(m, day, "The Death Star has gone", "My team reached %s to find the Death Star no longer there." % m.Target.Name)
				m.Finished = true
			else:
				for f in m.Target.OrbitingFleets.duplicate():
					if not f.Ships.has(station):
						continue
					f.Ships.erase(station)
					if f.IsEmpty():
						m.Target.OrbitingFleets.erase(f)
				print("[Mission] DEATH STAR DESTROYED at %s." % m.Target.Name)
				# Entries 122 and 123, both 1.
				for agent in Lq.of_type_character(m.Team):
					agent.EspionageRating += RuleManager.Get(RuleId.DeathStarSabotageEspionageGain, m.Faction)
					agent.CombatRating += RuleManager.Get(RuleId.DeathStarSabotageCombatGain, m.Faction)
				Report(m, day, "Death Star Sabotaged", "The %s has sabotaged the Death Star at %s.\n\nIt is destroyed." % [m.Faction.DisplayName, m.Target.Name])
				m.Finished = true
				EventBus.BroadcastChanged()

		Enums.MissionType.JediTraining:
			var people := Lq.of_type_character(m.Team)
			var teacher: Character = Lq.first_or_null(people, CanTeachJedi)
			var students := Lq.where(people, CanBeJediStudent)
			if teacher == null or students.is_empty():
				m.Finished = true
			else:
				var gain: int = maxi(1, teacher.JediLevel / JediTrainingDivisor)
				var risen := []
				for s in students:
					var was: int = s.ForceRank()
					s.IsKnownJedi = true
					s.JediLevel += gain
					if s.ForceRank() != was:
						risen.append("%s is now a %s" % [s.Name, Pretty(s.ForceRank())])
				print("[Mission] Jedi Training at %s: +%d to %s" % [m.Target.Name, gain, Lq.join(Lq.select(students, func(s): return s.Name))])
				Report(m, day, "Jedi Training at %s" % m.Target.Name,
					(".\n".join(risen) + ".\n\n" if not risen.is_empty() else "") + "%s has completed a course of training." % teacher.Name)
				m.Finished = true

		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			ResearchManager.MissionProgress(m.Faction, m.ResearchTrack(), day, rng)
			print("[Mission] %s at %s advanced our research." % [JsonUtil.enum_name(Enums.MissionType, m.Type), m.Target.Name])
			Report(m, day, "%s progress at %s" % [m.DisplayName(), m.Target.Name],
				"My researchers have made progress.\n\nDo you wish the mission to continue?", true)

		Enums.MissionType.Rescue:
			var prisoner := m.TargetCharacter
			if prisoner == null or not prisoner.IsCaptured():
				m.Finished = true
			else:
				prisoner.CapturedBy = null
				prisoner.Status = Enums.Status.AwaitingOrders
				print("[Mission] %s rescued at %s." % [prisoner.Name, m.Target.Name])
				Report(m, day, "%s rescued" % prisoner.Name,
					"%s is free, at %s.%s" % [prisoner.Name, m.Target.Name,
						" They remain injured and will need to rest on one of our systems." if prisoner.IsInjured() else ""])
				m.Finished = true
				EventBus.BroadcastChanged()


## Stand a team down (manual p110, p045). THE JOURNEY HOME IS A REAL JOURNEY.
static func Conclude(m: Mission) -> void:
	var landing: Planet = m.HomeBase if (not m.Arrived() or m.Target.ControllingFaction != m.Faction) else m.Target
	var from: Planet = m.Target if m.Arrived() else m.HomeBase

	for c in m.Team:
		# THE TAKEN AND THE DEAD DO NOT GO HOME.
		if c is Character and ((c as Character).IsCaptured() or c.Status == Enums.Status.Dead):
			continue
		if landing == null or landing == from:
			if landing != null:
				MilitaryCatalog.Relocate(c, landing)
			c.Destination = null
			c.DaysToDestination = 0
			c.Status = Enums.Status.AwaitingOrders
			continue
		MilitaryCatalog.Relocate(c, from)
		c.Destination = landing
		c.DaysToDestination = max(1, from.DeploymentDaysTo(landing))
		c.Status = Enums.Status.Enroute


## An undeployed minor character of that faction.
static func Recruitable(f: Faction, rng: Prng) -> Character:
	var pool := Lq.where(GameState.ActiveRoster, func(c): return c.Faction == f and not c.IsMajor and c.Attached == null and c.Status != Enums.Status.Dead)
	return null if pool.is_empty() else pool[rng.NextMax(pool.size())]


## Which rating the success roll reads, from the mission table (manual p106-p111).
static func AttributeFor(type: int, u: Unit) -> int:
	if u == null:
		return 0
	match type:
		Enums.MissionType.Diplomacy:      return u.DiplomacyRating
		Enums.MissionType.Espionage:      return u.EspionageRating
		Enums.MissionType.Recruitment:    return u.LeadershipRating
		Enums.MissionType.InciteUprising: return u.LeadershipRating
		Enums.MissionType.SubdueUprising: return u.LeadershipRating
		Enums.MissionType.Abduction:      return u.CombatRating
		Enums.MissionType.Assassination:  return u.CombatRating
		Enums.MissionType.Rescue:         return u.CombatRating
		# The mean, truncating toward zero (0x55C8D0).
		Enums.MissionType.Sabotage:          return (u.CombatRating + u.EspionageRating) / 2
		Enums.MissionType.DeathStarSabotage: return (u.CombatRating + u.EspionageRating) / 2
		Enums.MissionType.ShipDesignResearch:     return (u as Character).ShipDesign if u is Character else 0
		Enums.MissionType.TroopTrainingResearch:  return (u as Character).TroopTraining if u is Character else 0
		Enums.MissionType.FacilityDesignResearch: return (u as Character).FacilityDesign if u is Character else 0
		Enums.MissionType.JediTraining:           return (u as Character).JediLevel if u is Character else 0
	return 0
