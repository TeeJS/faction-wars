class_name MissionManager
extends RefCounted
## backend/Mission.cs MissionManager - launching, running and resolving missions.
## Every fitted constant is marked as the source marks it; every sourced rule
## cites the same page. Order of operations is the source's exactly, because the
## PRNG stream depends on it.

static var _active: Array[Mission] = []

## Why the last Launch returned null, in the player's words - the command
## applier hands it back so the Create Mission window can say it (TeeJ,
## 2026-09-22: a refused Recruitment used to print to the console and nothing
## else, and the operative simply stayed put).
static var LastRefusal: String = ""


static func Active() -> Array:
	return _active


## WHAT EACH SPECFORCE MAY BE SENT TO DO - manual p098's roster. It used to be
## a literal table of nine unit NAMES here; it is the pack's `spec_forces` lists
## in missions.json now, read by MissionCatalog.SpecForceMissions (and proven
## identical to the old table by tests/spec_force_missions.gd).

## ⚠ THE EMPEROR (the pack's `dark_master`) IS EXCLUDED FROM TRAINING BY THE
## PROJECT COORDINATOR'S RULING, NOT BY A SOURCE.

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

## The Death Star is the unit the pack marks `superweapon` (units.json roles).


static func Clear() -> void:
	_active.clear()


## CAN THIS UNIT RUN THIS MISSION AT ALL, target aside.
static func CanPerform(u: Unit, type: int) -> bool:
	if u == null:
		return false
	if type == Enums.MissionType.SpecialPowerTraining:
		return CanTeachSpecialPower(u) or CanBeSpecialPowerStudent(u)
	if type == Enums.MissionType.ShipDesignResearch or type == Enums.MissionType.TroopTrainingResearch or type == Enums.MissionType.FacilityDesignResearch:
		if not (u is Character):
			return false
		var rc := u as Character
		match type:
			Enums.MissionType.ShipDesignResearch:    return rc.ShipDesign > 0
			Enums.MissionType.TroopTrainingResearch: return rc.TroopTraining > 0
		return rc.FacilityDesign > 0
	# "Only a major character can perform it" (Recruitment, manual p105-p108),
	# and every member has to be able to do the job (p102-p103): a minor
	# character on the team - agent or decoy - takes Recruitment off the list
	# (TeeJ, 2026-09-23: "group-selected with a character that can NOT
	# recruit ... it is not an option at all").
	if type == Enums.MissionType.Recruitment:
		return u is Character and (u as Character).IsMajor
	# "ONLY Longprobe Y-wing Recon Teams and Imperial Probe Droids may perform it" (p107).
	if u is Character:
		return type != Enums.MissionType.Reconnaissance
	return MissionCatalog.SpecForceCanRun(u.PackId, type)


## EVERY member has to be able to do the job, decoys included (p102-p103) -
## and their side has to run that mission at all (SideRuns).
static func TeamCanPerform(team: Array, type: int) -> bool:
	return team != null and team.size() > 0 and SideRuns(team[0].Faction, type) \
		and Lq.all(team, func(u): return CanPerform(u, type)) and TeamMeetsExtraRule(team, type).ok


## WHICH SIDE RUNS WHICH MISSION: missions.json `available_to` - the original's
## per-side columns in MISSNSD.DAT, and the manual's own words for the two
## one-sided missions: Assassination "Only the Empire may perform this
## mission" (p105), Death Star Sabotage the Alliance's (p106, its Special
## Forces roster). It was enforced for Assassination alone, so a pack that gave
## any other mission to one side had it run by both (TeeJ, 2026-09-24).
static func SideRuns(side: Faction, type: int) -> bool:
	return MissionCatalog.AvailableTo(type, side)


## A FORCE USER IS ONE WHO KNOWS IT (manual p094).
static func IsForceAware(u: Unit) -> bool:
	return u is Character and (u as Character).IsKnownSpecialPowerUser and (u as Character).SpecialPowerLevel > 0


static func CanBeSpecialPowerStudent(u: Unit) -> bool:
	return IsForceAware(u) and u is Character and not (u as Character).CanTrainSpecialPower and not (u as Character).HasRole("dark_master")


## WHO MAY TEACH: CanTrainSpecialPower AND Jedi Knight - entry 42 "Force Qualified
## Character Threshold" = 100.
static func CanTeachSpecialPower(u: Unit) -> bool:
	if not (u is Character):
		return false
	var t := u as Character
	return t.CanTrainSpecialPower and t.SpecialPowerLevel >= RuleManager.Get(RuleId.ForceQualifiedThresh, t.Faction)


## RULES A PER-MEMBER TEST CANNOT EXPRESS: Jedi Training needs a teacher and
## somebody else Force-aware (Encyclopedia; manual mission table; character tables).
static func TeamMeetsExtraRule(team: Array, type: int) -> Result:
	# "Only a major character can perform it" (GAMEPLAY.md mission table,
	# manual p105-p108), and every member has to be able to do the job
	# (p102-p103): Recruitment is offered only to a team of major characters.
	if type == Enums.MissionType.Recruitment:
		var minors: Array = Lq.where(team, func(u): return not (u is Character and (u as Character).IsMajor))
		if minors.is_empty():
			return Result.success()
		var mission_name: String = MissionCatalog.DisplayNameFor(Enums.MissionType.Recruitment)
		if minors.size() < team.size():
			return Result.fail("Only major characters can go on a %s mission - %s %s not one." % [mission_name,
				", ".join(Lq.select(minors, func(u): return u.Name)), "is" if minors.size() == 1 else "are"])
		var side: Faction = team[0].Faction
		var majors := Lq.select(Lq.where(GameState.ActiveRoster,
			func(c): return c.Faction == side and c.IsMajor and c.Status != Enums.Status.Dead), func(c): return c.Name)
		return Result.fail("Only a major character can lead a %s mission%s." % [mission_name,
			"" if majors.is_empty() else " - " + ", ".join(majors)])
	if type != Enums.MissionType.SpecialPowerTraining:
		return Result.success()
	if not Lq.any(team, CanTeachSpecialPower):
		return Result.fail("Only a qualified teacher can lead a %s mission." % MissionCatalog.DisplayNameFor(Enums.MissionType.SpecialPowerTraining))
	if not Lq.any(team, CanBeSpecialPowerStudent):
		return Result.fail("There is no Force-aware character here to train.")
	return Result.success()


## Every mission this team could run somewhere, target not considered.
static func PerformableBy(team: Array) -> Array:
	var out := []
	for t in Enums.MissionType.values():
		if TeamCanPerform(team, t):
			out.append(t)
	return out


## Which shipped table each mission rolls against (REBEXE.EXE 0x58B420). A
## mission's outcome table shares the mission's id in mission_tables.json
## (SCHEMA.md section 9); null when the pack ships none for it.
static func TableFor(type: int) -> Variant:
	var d := MissionCatalog.DefFor(type)
	if d == null or not MissionTableManager.Has(d.Id):
		return null
	return d.Id


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
		return Result.fail("There is no %s at %s." % [_superweapon_name(), target.Name])
	if station.Faction == actor:
		return Result.fail("That %s is ours." % station.Name)
	if station.Status == Enums.Status.Enroute \
			or Lq.any(target.OrbitingFleets, func(f): return f.Ships.has(station) and f.Status == Enums.Status.Enroute):
		return Result.fail("That %s is %s." % [station.Name, Terms.label("in_transit")])
	var seen := IntelManager.View(actor, target, Enums.IntelSection.OrbitingShips)
	if not seen.Known or not Lq.any(seen.Lines, func(l): return l.begins_with(station.Name)):
		return Result.fail("We do not know of a %s at %s. Reconnaissance or an Espionage mission would find one." % [_superweapon_name(), target.Name])
	return Result.success()


## What the pack calls its superweapon, for messages about one not present.
static func _superweapon_name() -> String:
	var d := MilitaryCatalog.FirstWithRole("superweapon")
	return d.DisplayName if d != null else "superweapon"


static func DeathStarAt(where: Planet) -> Unit:
	if where == null:
		return null
	for f in where.OrbitingFleets:
		for s in f.Ships:
			if s.HasRole("superweapon"):
				return s
	return null


## A SUCCESSFUL ESPIONAGE MISSION LEAKS MORE THAN ITS TARGET (REBEXE.EXE 0x55C940;
## entries 131-136). WHICH systems is OURS: unexplored worlds picked at random.
static func LeakExtraSystems(m: Mission, rng: Prng) -> String:
	if GameState.ActiveGalaxy.is_empty():
		return ""
	var capital := Lq.any(FactionRegistry.Playable, func(f): return f.Hq != null and not f.Hq.Planet.is_empty() and f.Hq.Planet == m.Target.PackId)
	var floor_id := RuleId.EspionageRevealCapitalFloor if capital else RuleId.EspionageRevealFloor
	var spread_id := RuleId.EspionageRevealCapitalSpread if capital else RuleId.EspionageRevealSpread
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
	# The original's words for them (TEXTSTRA 28942, 28943): "In addition,
	# information was provided on the following systems:", one to a line.
	var said := "In addition, information was provided on the following systems:"
	for world in found:
		said += "\n     %s" % world
	return said


## THE THIRD SCORE TERM, "a3": the number of STORMTROOPER REGIMENTS on the target
## (the original hardcodes the unit; the pack marks it `garrison_troop`).
static func GarrisonTerm(m: Mission) -> int:
	if m.Target == null or m.Target.Garrison == null:
		return 0
	return Lq.count(m.Target.Garrison, func(u): return u.Type == Enums.UnitType.Troop and u.HasRole("garrison_troop"))


## The score that indexes the table (REBEXE.EXE 0x55C680-0x55C8D0).
static func ScoreFor(m: Mission, rating: int) -> int:
	match m.Type:
		Enums.MissionType.Espionage, Enums.MissionType.Rescue:
			return rating
		Enums.MissionType.Sabotage, Enums.MissionType.SuperweaponSabotage:
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


## The band's player-facing name - the PACK's wording (display.json).
static func Pretty(r: int) -> String:
	return Character.RankLabel(r)


## Does this unit go on missions at all? (manual p045, p047, p098)
static func CanEverPerformMissions(u: Unit) -> bool:
	return u is Character or (u != null and u.Type == Enums.UnitType.SpecForce)


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
		if not c.IsKnownSpecialPowerUser or c.SpecialPowerLevel <= 0:
			continue
		var before: int = c.SpecialPowerRankOf()
		c.SpecialPowerLevel += reward
		if c.SpecialPowerRankOf() == before:
			continue
		print("[Force] %s has advanced to %s (level %d)." % [c.Name, Character.RankLabel(c.SpecialPowerRankOf()), c.SpecialPowerLevel])
		TellForceGrowth(c, day, m.Target)


## Characters improve the skill their mission exercised, on success (guide p094-095;
## "SPECIAL FORCES CANNOT IMPROVE"). Lq.of_type_character filters SpecForce units out,
## which honours that rule and matches the AwardForceForSuccess / SuperweaponSabotage
## precedent. Magnitudes are shipped gnprtb entries 111,112,114-121 (each 1), read via
## RuleManager - never invented. SuperweaponSabotage grants its own 122/123 in the success
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


## `voice`: the line the reporting character speaks with it (GameMessage.Voice:
## "mission_success", "mission_failure", "mission_abort"), or "". `named`: the
## title leads with who reports; the original's own titles ("Diplomacy Mission
## Report") stand alone.
static func Report(m: Mission, day: int, title: String, body: String, asks_to_continue: bool = false, voice: String = "", named: bool = true, scene: String = "", sound: String = "") -> void:
	if not GameSettings.IsHuman(m.Faction):
		return
	var leader := Leader(m)
	var who: Variant = DisplayNameOf(leader)
	var character: Character = leader as Character
	if character == null:
		var people := Lq.of_type_character(m.Team)
		character = people[0] if not people.is_empty() else null
	var msg := GameMessage.new(title if (who == null or not named) else "%s: %s" % [who, title], body,
		Enums.MessageCategory.Missions, day, m.Target, character)
	msg.PendingMission = m if asks_to_continue else null
	msg.Scene = scene
	msg.Sound = sound if not sound.is_empty() else (ReportSound(m, voice) if not scene.is_empty() else "")
	msg.Type = Enums.MessageType.MissionReport   # ALWAYS MissionReport, NEVER MissionFailed (see source)
	msg.Advisor = "personnel_report"
	msg.Voice = voice
	EventBus.Tell(m.Faction, msg)


## THE ORIGINAL'S DIPLOMACY MISSION REPORT (TEXTSTRA RCDATA 28880-28891; TeeJ's
## screenshots of the original, 2026-09-27/28): "Diplomacy Mission Report" / "The
## diplomacy mission to <system> has increased popular support on that system."
## or "... had no effect on our popular support on that system."; a major
## character reports in the first person, "<name> Mission Report" / "My diplomacy
## mission to <system> ..." ("... had no effect on popular support in that
## system."). Then which side the population supports, then "Do you wish the
## mission to continue?". `ours`: a line of our own after them, or "".
const DiplomacyReportTitle := "Diplomacy Mission Report"


## Who reports in the first person: a major character leading the mission.
static func ReportsFirstPerson(m: Mission) -> bool:
	var leader := Leader(m)
	return leader is Character and (leader as Character).IsMajor


static func DiplomacyTitle(m: Mission) -> String:
	return "%s Mission Report" % Leader(m).Name if ReportsFirstPerson(m) else DiplomacyReportTitle


## WHICH SIDE THE POPULATION SUPPORTS (TEXTSTRA 28888-28890): a side at or over
## entry 207, the Uprising Threshold (60). Measured on TeeJ's eight screenshots
## of the original's report beside the system's loyalty bar (Empire 43-57%:
## "neither"; 59.5-78%: "supports the Empire"); manual p090 words it the same
## ("does not strongly support your side" - the garrison requirement).
static func PopulationSupport(p: Planet) -> String:
	for f in FactionRegistry.Playable:
		if p.SupportFor(f) >= RuleManager.Get(RuleId.GarrisonUprisingThresh, f):
			return "The population supports the %s." % f.ShortName
	return "The population does not strongly support either side."


## THE SCENE A MISSION'S REPORT IS DRAWN OVER - the original's message picture
## (STRATEGY, windows/message.<id>), which REBEXE's report builder (0x4927c0)
## picks by the mission's family: Diplomacy's chamber 1044, Espionage's
## surveillance room 1045, Research's R&D 1017, Incite Uprising's crowd 1005,
## Subdue Uprising's burning city 1010; every other mission the side's own
## ship - the Falcon's hold 1042 for the Alliance, an Imperial ship's 1043.
const ReportScenes := {
	Enums.MissionType.Diplomacy: 1044, Enums.MissionType.Espionage: 1045,
	Enums.MissionType.ShipDesignResearch: 1017, Enums.MissionType.TroopTrainingResearch: 1017,
	Enums.MissionType.FacilityDesignResearch: 1017,
	Enums.MissionType.InciteUprising: 1005, Enums.MissionType.SubdueUprising: 1010,
}


static func ReportScene(m: Mission) -> String:
	var ours: int = 1042 if m.Faction != null and Faction.SkinOf(m.Faction.Id) == "alliance" else 1043
	return "message.%d" % int(ReportScenes.get(m.Type, ours))


## ITS SOUND, which the builder sets beside the scene (REBEXE 0x4927c0):
## Diplomacy 1150, Espionage 1152, research 1151, Subdue Uprising 1109 when
## order is restored and 1108 when not; every other the side's own, 1148 for
## the Alliance, 1149 for the Empire. (A mission foiled, failed for want of its
## target, or aborted has its own builder, 0x491500, and 1152.)
static func ReportSound(m: Mission, voice: String) -> String:
	match m.Type:
		Enums.MissionType.Diplomacy:
			return "strategy/1150"
		Enums.MissionType.Espionage:
			return "strategy/1152"
		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			return "strategy/1151"
		Enums.MissionType.SubdueUprising:
			return "strategy/1109" if voice == "mission_success" else "strategy/1108"
	return "strategy/1148" if m.Faction != null and Faction.SkinOf(m.Faction.Id) == "alliance" else "strategy/1149"


## THE ORIGINAL'S MISSION REPORTS (TEXTSTRA 28880-29125, built by REBEXE
## 0x4927c0; TeeJ, 2026-09-28: "make all of the messages text match"): a major
## character reports in the first person under "<name> Mission Report", anyone
## else in the third under "<Mission> Mission Report" (Reconnaissance's is
## "Recon Mission Report"). `mine` / `theirs`: the two wordings, each exactly
## as the original writes it, its own line breaks included. `returning`:
## Sabotage, Recon, Abduction, Assassination and Rescue then say where the team
## is bound (28902 / 28903). `asks`: the mission goes on - "Do you wish the
## mission to continue?" (28891). `titles`: [the major's, anyone else's] in
## place of the two Mission Report titles. `sound`: in place of the report's own
## (ReportSound).
static func MissionReport(m: Mission, day: int, voice: String, mine: String, theirs: String,
		asks: bool = false, returning: bool = false, titles: Array = [], sound: String = "") -> void:
	var first := ReportsFirstPerson(m)
	var body := mine if first else theirs
	if returning:
		body += Returning(m)
	if asks:
		body += "Do you wish the mission to continue?"
	var heading: String
	if titles.size() == 2:
		heading = str(titles[0] if first else titles[1])
	else:
		heading = "%s Mission Report" % Leader(m).Name if first else ReportTitle(m)
	Report(m, day, heading, body, asks, voice, false, ReportScene(m), sound)


## A MISSION THAT FAILED, in the original's words for each (TEXTSTRA 28898-29125;
## REBEXE 0x4927c0) - word for word, spacing and line breaks too. Missions whose
## name the original writes in capitals (Incite Uprising, Subdue Uprising, Jedi
## Training, the research missions) take the pack's own name.
static func FailureReport(m: Mission, day: int, persistent: bool) -> void:
	var at := m.Target.Name
	var who: String = str(m.TargetObjectName()) if m.TargetObjectName() != null else ""
	var name := m.DisplayName()
	var mine := ""
	var theirs := ""
	var home := false
	match m.Type:
		Enums.MissionType.Sabotage, Enums.MissionType.SuperweaponSabotage:
			var thing := who if not who.is_empty() else name.trim_suffix(" Sabotage")
			mine = "My sabotage mission to %s targeting the %s is complete.    The target was not destroyed." % [at, thing]
			theirs = "The sabotage mission to %s targeting the %s is complete.    The target was not destroyed." % [at, thing]
			home = true
		Enums.MissionType.Reconnaissance:
			mine = "The reconnaissance mission to %s failed.\n" % at
			theirs = mine
			home = true
		Enums.MissionType.Abduction:
			mine = "My mission to abduct %s from %s failed." % [who, at]
			theirs = "The mission to abduct %s from %s failed.\n" % [who, at]
			home = true
		Enums.MissionType.Assassination:
			mine = "My assassination mission to %s is complete.  %s has not been eliminated.\n" % [at, who]
			theirs = "The assassination mission to %s is complete.  %s has not been eliminated.\n" % [at, who]
			home = true
		Enums.MissionType.InciteUprising:
			# Both the original's wordings say "My" (28930, 28933).
			mine = "My %s mission to %s has not produced results.\n" % [name, at]
			theirs = mine
		Enums.MissionType.Espionage:
			mine = "My espionage mission to %s was not successful." % at
			theirs = "The espionage mission to %s was not successful." % at
		Enums.MissionType.SubdueUprising:
			mine = "My %s mission to %s has not met with success.  The world is still in a state of uprising.\n" % [name, at]
			theirs = "The %s mission to %s failed.  The populace is still in a state of uprising.\n" % [name, at]
		Enums.MissionType.Recruitment:
			mine = "My recruitment mission to %s is complete.  I have failed to recruit anyone." % at
			theirs = mine
		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			mine = "My %s Research mission at %s has not produced new information.  " % [name.trim_suffix(" Research"), at]
			theirs = "The %s Mission at %s has not produced new information.  " % [name, at]
		Enums.MissionType.Rescue:
			mine = "My mission to rescue %s from %s failed." % [who, at]
			theirs = "The mission to rescue %s from %s failed.\n" % [who, at]
			home = true
		Enums.MissionType.SpecialPowerTraining:
			mine = "My %s mission on %s has not met with success." % [name, at]
			theirs = "The %s mission on  %s has failed." % [name, at]   # the original's two spaces
		_:
			mine = "My %s mission to %s has failed." % [name, at]   # ours: no mission the original reports
			theirs = "The %s mission to %s has failed." % [name, at]
			home = true
	MissionReport(m, day, "mission_failure", mine, theirs, persistent, home and not persistent)


## The target gone before the team could reach it (TEXTSTRA 28984-28987):
## "<name> Mission Failed" / "My <Mission> Mission to <system> has failed because
## the target was not found at that location." - or "<Mission> Mission Failed" /
## "The <Mission> Mission to ..." - then the way home.
static func NotFoundReport(m: Mission, day: int) -> void:
	var name := m.DisplayName()
	MissionReport(m, day, "mission_abort",
		"My %s Mission to %s has failed because the target was not found at that location.  " % [name, m.Target.Name],
		"The %s Mission to %s has failed because the target was not found at that location.  " % [name, m.Target.Name],
		false, true, ["%s Mission Failed" % Leader(m).Name, "%s Mission Failed" % name], "strategy/1152")


## "<Mission> Mission Report" - the original's own for each (TEXTSTRA).
static func ReportTitle(m: Mission) -> String:
	return "Recon Mission Report" if m.Type == Enums.MissionType.Reconnaissance else "%s Mission Report" % m.DisplayName()


## Where the team is bound (TEXTSTRA 28902 / 28903): "Personnel are returning to
## <system>." - the system Conclude sends them to - or, with none of them free,
## "All personnel assigned to the mission have failed to return."
static func Returning(m: Mission) -> String:
	var free := Lq.where(m.Team, func(u: Unit) -> bool:
		return not (u is Character and ((u as Character).IsCaptured() or u.Status == Enums.Status.Dead)))
	if free.is_empty():
		return "\nAll personnel assigned to the mission have failed to return."
	var landing: Planet = m.HomeBase if (not m.Arrived() or m.Target.ControllingFaction != m.Faction) else m.Target
	return "\nPersonnel are returning to %s." % (landing.Name if landing != null else m.Target.Name)


static func DiplomacyReport(m: Mission, increased: bool, asks: bool = true, ours: String = "") -> String:
	var mine := ReportsFirstPerson(m)
	var outcome := "has increased popular support on that system." if increased \
		else ("had no effect on popular support in that system." if mine else "had no effect on our popular support on that system.")
	var body := "%s diplomacy mission to %s %s  %s" % ["My" if mine else "The", m.Target.Name, outcome, PopulationSupport(m.Target)]
	if not ours.is_empty():
		body += "  " + ours
	return body + ("\nDo you wish the mission to continue?" if asks else "")


## Tell the defending faction that an enemy mission resolved against their world.
## Fog-blind: never names the attacker (character = null). Only human defenders
## are notified; AI-on-AI produces no message. A foil is Missions news ("news
## of enemy missions your forces have foiled", manual p079); something of ours
## destroyed is Manufacturing's (TeeJ, 2026-09-27: "messages about items being
## destroyed or failing should be manufacturing, not mission").
static func _tell_defender(planet: Planet, day: int, title: String, body: String,
		category: Enums.MessageCategory = Enums.MessageCategory.Missions, sound: String = "") -> void:
	if planet == null or planet.ControllingFaction == null:
		return
	if not GameSettings.IsHuman(planet.ControllingFaction):
		return
	var msg := GameMessage.new(title, body, category, day, planet, null)
	msg.Type = Enums.MessageType.MissionReport
	# An enemy mission foiled is the agent's report; one that struck is a loss.
	msg.Advisor = "agent_report" if title == "Enemy Mission Foiled" else "maintenance"
	msg.Sound = sound
	EventBus.Tell(planet.ControllingFaction, msg)


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
				# Its government is its own, not the enemy's (TeeJ, 2026-09-28): the
				# mission is "a revolt on an enemy controlled system" (Encyclopedia).
				return Result.fail("%s is not controlled by the enemy." % target.Name)
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
		Enums.MissionType.SuperweaponSabotage:
			return CanSabotageDeathStar(actor, target)
		Enums.MissionType.SpecialPowerTraining:
			if target.ControllingFaction != actor:
				return Result.fail("%s is not ours." % target.Name)
			return Result.success()
		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			if target.ControllingFaction != actor:
				return Result.fail("%s is not ours." % target.Name)
			# Which PRODUCER the research needs, by role.
			var needed: String
			match type:
				Enums.MissionType.ShipDesignResearch:    needed = "produces_unit"
				Enums.MissionType.TroopTrainingResearch: needed = "produces_troop"
				_:                                       needed = "produces_facility"
			if target.CountByRole(needed) == 0:
				var example := FacilityCatalog.FirstWithRole(needed)
				return Result.fail("%s has no %s." % [target.Name, example.DisplayName if example != null else needed])
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
		_notify_injured(c)
		return false
	if rng.NextRange(1, 101) > InjuryProvesFatalPercent:
		_notify_injured(c)
		return false
	Kill(c)
	return true


## Tell the owner one of their characters was wounded - the notification that pairs
## with the recovery message (strategic_tick_manager). Addressed to the owning
## faction, never broadcast (personnel status is that side's business).
## The original's words (TEXTSTRA 29024 / 29025): "<name> Injured" / "<name> has
## been injured."
static func _notify_injured(c: Character) -> void:
	if c == null or c.Faction == null:
		return
	var msg := GameMessage.new("%s Injured" % c.Name, "%s has been injured." % c.Name,
		Enums.MessageCategory.Missions, StrategicTickManager.Today,
		c.Attached if c.Attached is Planet else null, c)
	msg.Type = Enums.MessageType.CharacterHealth
	msg.Sound = "strategy/1140"
	EventBus.Tell(c.Faction, msg)


## Dead (manual p096). They keep their roster slot and leave the map. Their side
## is told in the original's words (TEXTSTRA 29028 / 29541): "<name> Killed" /
## "<name> has been killed." - or `how`, the original's own line for the cause
## ("... was killed by Imperial Assassins at <system>.", 29193).
static func Kill(c: Character, how: String = "") -> void:
	if c == null:
		return
	if c.Faction != null and c.Status != Enums.Status.Dead and GameSettings.IsHuman(c.Faction):
		var msg := GameMessage.new("%s Killed" % c.Name, how if not how.is_empty() else "%s has been killed." % c.Name,
			Enums.MessageCategory.Missions, StrategicTickManager.Today,
			c.Attached if c.Attached is Planet else null, c)
		msg.Type = Enums.MessageType.CharacterHealth
		msg.Sound = "strategy/1140"
		EventBus.Tell(c.Faction, msg)
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


## "The Empire can sabotage the Alliance headquarters" (manual p108) - and never
## the other way round. The asymmetry is the HQ's KIND (factions.json hq.kind,
## SCHEMA.md section 3): a hidden HQ is destroyed, never captured, so sabotage
## can destroy it; a fixed HQ is captured, never destroyed, so it cannot.
## Decided by TeeJ 2026-09-22 (derive from hq.kind, no new field).
static func HqCanBeSabotaged(holder: Faction) -> bool:
	return holder != null and holder.HasHiddenHq()


## IS THIS A LEGAL SABOTAGE TARGET? Manual p108. `target` is a Facility or a Unit.
static func CanSabotage(actor: Faction, target: Variant, where: Planet) -> Result:
	if target is Facility:
		var f := target as Facility
		if where == null or not where.Facilities.has(f):
			return Result.fail("That facility is not there.")
		if where.ControllingFaction == actor:
			return Result.fail("The %s is ours." % f.Name())
		if f.HasRole("headquarters") and not HqCanBeSabotaged(where.ControllingFaction):
			return Result.fail("The %s headquarters is taken, not sabotaged." % where.ControllingFaction.DisplayName)
		return Result.success()
	if target is Unit:
		var u := target as Unit
		if u.Faction == actor:
			return Result.fail("%s is one of ours." % u.Name)
		if u.Status == Enums.Status.Enroute:
			return Result.fail("%s is %s." % [u.Name, Terms.label("in_transit")])
		if u is Character:
			return Result.fail("People are not sabotaged - use Abduction or Assassination.")
		if u.HasRole("superweapon"):
			return Result.fail("%s needs a %s mission." % [u.Name, MissionCatalog.DisplayNameFor(Enums.MissionType.SuperweaponSabotage)])
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
		return Result.fail("%s is %s." % [victim.Name, Terms.label("in_transit")])
	if victim.IsOffMap():
		return Result.fail("%s cannot be located." % victim.Name)
	match type:
		Enums.MissionType.Abduction, Enums.MissionType.Assassination:
			if victim.Faction == actor:
				return Result.fail("%s is one of yours." % victim.Name)
			if victim.IsCaptured():
				return Result.fail("%s is already captured." % victim.Name)
			return Result.success()
		Enums.MissionType.Rescue:
			if not victim.IsCaptured():
				return Result.fail("%s is not a prisoner." % victim.Name)
			if victim.CapturedBy == actor:
				return Result.fail("%s is already in your hands." % victim.Name)
			return Result.success()
	return Result.success()


## A refused launch: printed, and kept for the player (LastRefusal).
static func _refuse(why: String) -> Mission:
	LastRefusal = why
	print("[Mission] %s" % why)
	return null


static func Launch(type: int, team: Array, from: Planet, target: Planet, decoys: Variant = null,
		victim: Character = null, saboteur_target: Variant = null) -> Mission:
	LastRefusal = ""
	if team == null or team.is_empty() or from == null:
		return _refuse("A mission needs a team and a starting system.")
	var actor: Faction = team[0].Faction
	if actor == null or Lq.any(team, func(c): return c.Faction != actor):
		return _refuse("A mission team must all belong to the same faction.")
	if not SideRuns(actor, type):
		return _refuse("%s does not carry out %s." % [actor.DisplayName, MissionCatalog.DisplayNameFor(type)])

	var why := CanTarget(type, actor, target)
	if not why.ok:
		return _refuse(why.error)
	var party := TeamMeetsExtraRule(team, type)
	if not party.ok:
		return _refuse(party.error)
	var who := CanTargetPerson(type, actor, victim)
	if not who.ok:
		return _refuse(who.error)
	if NeedsObjectTarget(type):
		var what := CanSabotage(actor, saboteur_target, target)
		if not what.ok:
			return _refuse(what.error)

	var unable: Unit = Lq.first_or_null(team, func(u): return not CanPerform(u, type))
	if unable != null:
		return _refuse("%s cannot perform %s." % [unable.Name, MissionCatalog.DisplayNameFor(type)])

	var unfit: Unit = Lq.first_or_null(team, func(u): return u is Character and not (u as Character).CanTakeOrders())
	if unfit != null:
		return _refuse("%s is in no condition to go." % unfit.Name)

	# "Someone in hyperspace takes no orders" (manual p111) - on their own
	# way somewhere or aboard a fleet in transit (TeeJ's screenshot of the
	# original, 2026-09-25: Mission greyed for a character in a moving fleet).
	var travelling: Unit = Lq.first_or_null(team, func(u): return u.Status == Enums.Status.Enroute)
	if travelling != null:
		return _refuse("%s is in hyperspace and cannot be given orders." % travelling.Name)

	if type == Enums.MissionType.SpecialPowerTraining:
		var people := Lq.of_type_character(team)
		if not Lq.any(people, CanTeachSpecialPower):
			return _refuse("%s needs a qualified teacher." % MissionCatalog.DisplayNameFor(Enums.MissionType.SpecialPowerTraining))
		if not Lq.any(people, CanBeSpecialPowerStudent):
			return _refuse("%s needs at least one Force-aware student." % MissionCatalog.DisplayNameFor(Enums.MissionType.SpecialPowerTraining))

	var busy: Unit = Lq.first_or_null(team, IsOnMissionTeam)
	if busy != null:
		return _refuse("%s is already on a mission." % busy.Name)

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

	# THE TEAM LEAVES ITS FLEET (TeeJ, 2026-09-24: "when sending personnel on
	# a mission from a fleet, they do not 'leave' the fleet"). The original
	# moves a team into the Mission window; one still aboard stayed in the
	# fleet's Personnel list and would have died with the fleet
	# (FleetBattleManager.LoseCrews). It sets off from the fleet's system,
	# `from` - where Conclude already lands a team whose mission ends early.
	# A Special Forces unit rides in a ship's hangar, whose Attached may name
	# the system rather than the fleet (CascadeFleetPayloads), so the hangars
	# are searched too.
	for u in team:
		var carried: bool = false
		for f in from.OrbitingFleets:
			for ship in f.Ships:
				if ship.Hangar.has(u):
					ship.Hangar.erase(u)
					carried = true
		if carried or u.Attached is Fleet:
			MilitaryCatalog.Relocate(u, from)

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
		EventBus.Tell(mission.Faction, GameMessage.new(
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
		if m.Type == Enums.MissionType.SpecialPowerTraining and m.Arrived() and m.Target.ControllingFaction != m.Faction:
			# The original's words (TEXTSTRA 28992-28997): "<name> Mission Aborted" /
			# "My <mission> mission to <system> has been aborted because the system
			# has joined the <side>." (or "has declared neutrality."), then the way home.
			var name := m.DisplayName()
			var holder := m.Target.ControllingFaction
			var why := ("the system has joined the %s.  " % holder.ShortName) if FactionRegistry.OrderOf(holder) >= 0 else "the system has declared neutrality."
			var titles := ["%s Mission Aborted" % Leader(m).Name, "%s Mission Aborted." % name]   # the original's full stop
			SeizeFoiledTeam(m, rng)
			MissionReport(m, day, "mission_failure",
				"My %s mission to %s has been aborted because %s" % [name, m.Target.Name, why],
				"The %s mission to %s has been aborted because %s" % [name, m.Target.Name, why], false, true, titles, "strategy/1152")
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
## against RLEVADTB.DAT, then capture or death. Each one's side hears it in the
## original's words, one message a person: "<name> Captured" / "<name> was
## captured by the <side> at <system>." (TEXTSTRA 29016 / 29017); the wounded
## and the dead as Injure and Kill tell them. Returns who was taken.
static func SeizeFoiledTeam(m: Mission, rng: Prng) -> Array:
	var commander_combat := 0
	for c in GameState.ActiveRoster:
		if c.Commanding == m.Target and c.Faction != m.Faction and c.Rank != Enums.Rank.None:
			commander_combat = max(commander_combat, c.CombatRating)

	var captured := []

	for member in m.Team.duplicate():
		var evade_score: int = member.CombatRating - commander_combat
		var evade := MissionTableManager.Lookup(MissionTableManager.Evasion, evade_score)
		if evade < 0 or rng.NextRange(1, 101) <= evade:
			if member is Character and rng.NextRange(1, 101) <= FoiledEscapeInjuryPercent:
				Injure(member as Character, rng)
			continue

		var dies := rng.NextRange(1, 101) <= FoiledSeizeKilledPercent
		if member is Character:
			var person := member as Character
			if dies and not person.IsMajor:
				Kill(person)
			else:
				person.CapturedBy = m.Target.ControllingFaction
				person.Status = Enums.Status.Kidnapped
				person.Commanding = null
				person.Destination = null
				person.DaysToDestination = 0
				captured.append(person)
				TellCaptured(person, m.Target)
		else:
			# SpecForce - lost outright.
			if member.Attached is Planet:
				var where: Planet = member.Attached
				where.Garrison.erase(member)
				where.FighterSquadrons.erase(member)
			m.Team.erase(member)

	EventBus.BroadcastChanged()
	return captured


## "<name> Escaped" / "<name> escaped from the <side> at <system>." (TEXTSTRA
## 29020 / 29021) over the original's picture of it (STRATEGY 1029), to the
## freed one's own side - as the original tells a rescue (TeeJ's screenshots,
## 2026-09-28: "Chewbacca escaped from the Empire at Balmorra.").
static func TellEscaped(c: Character, captor: Faction, at: Planet, day: int) -> void:
	if c == null or c.Faction == null or at == null or not GameSettings.IsHuman(c.Faction):
		return
	var msg := GameMessage.new("%s Escaped" % c.Name,
		"%s escaped from the %s at %s." % [c.Name, captor.ShortName if captor != null else "enemy", at.Name],
		Enums.MessageCategory.Missions, day, at, c)
	msg.Type = Enums.MessageType.CharacterHealth
	msg.Still = "message.1029"
	msg.Sound = "strategy/1100"
	EventBus.Tell(c.Faction, msg.With("released", "released"))


## "<name> Force Growth" / "My recent experience has given me new insights and I
## have grown in my skills in the Force.  My ranking is <rank>." (TEXTSTRA 29056 /
## 29057), in the character's own voice.
static func TellForceGrowth(c: Character, day: int, at: Variant = null) -> void:
	if c == null or c.Faction == null or not GameSettings.IsHuman(c.Faction):
		return
	var msg := GameMessage.new("%s Force Growth" % c.Name,
		"My recent experience has given me new insights and I have grown in my skills in the Force.  My ranking is %s." % Pretty(c.SpecialPowerRankOf()),
		Enums.MessageCategory.Missions, day, at if at is Planet else (c.Attached if c.Attached is Planet else null), c)
	msg.Voice = "force_growth"
	EventBus.Tell(c.Faction, msg)


## "<name> Captured" / "<name> was captured by the <side> at <system>." (TEXTSTRA
## 29016 / 29017), to the prisoner's own side.
static func TellCaptured(c: Character, at: Planet) -> void:
	if c == null or c.Faction == null or at == null or not GameSettings.IsHuman(c.Faction):
		return
	var captor: Faction = c.CapturedBy
	var msg := GameMessage.new("%s Captured" % c.Name,
		"%s was captured by the %s at %s." % [c.Name, captor.ShortName if captor != null else "enemy", at.Name],
		Enums.MessageCategory.Missions, StrategicTickManager.Today, at, c)
	msg.Type = Enums.MessageType.CharacterHealth
	msg.Sound = "strategy/1100"
	EventBus.Tell(c.Faction, msg)


static func Resolve(m: Mission, rng: Prng, day: int) -> void:
	# Detection happens before anything else, and only on the first approach.
	if m.Attempts == 0 and Foiled(m, rng):
		# The original's words (TEXTSTRA 29000-29003, 28990/28991): "<name> Mission
		# Foiled" / "My <mission> mission to <system> has been foiled by opposing
		# forces." - or "<Mission> Mission Foiled" / "The <mission> ..." - then
		# where the team is bound; each one taken, hurt or killed in their own.
		var what := m.DisplayName()
		var titles := ["%s Mission Foiled" % Leader(m).Name, "%s Mission Foiled" % what]
		SeizeFoiledTeam(m, rng)
		MissionReport(m, day, "mission_failure",
			"My %s mission to %s has been foiled by opposing forces.  " % [what, m.Target.Name],
			"The %s mission to %s has been foiled by opposing forces.  " % [what, m.Target.Name],
			false, true, titles, "strategy/1152")
		_tell_defender(m.Target, day, "Enemy Mission Foiled",
			"An enemy %s mission to %s has been foiled by our forces." % [what, m.Target.Name], Enums.MessageCategory.Missions, "strategy/1152")   # 0x491500
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
				"%s betrayed our %s mission at %s. Nothing was achieved.\n\nTheir loyalty has been in question for some time. They can be retired from their right-click menu, or left to come round if our fortunes improve." % [betrayer.Name, m.DisplayName().to_lower(), m.Target.Name], false, "mission_failure")
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
		if m.Type == Enums.MissionType.Diplomacy:
			Report(m, day, DiplomacyTitle(m), DiplomacyReport(m, false, persistent), persistent, "mission_failure", false, ReportScene(m))
			if not persistent:
				m.Finished = true
			return
		FailureReport(m, day, persistent)
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
				# The system joining is a Loyalty event the game reports (manual: C-3PO
				# "Good news, a system has joined"). Addressed to the new owner; it is
				# also the fog-legal SystemControl signal the AI infers a diplomat from.
				# In the original's words and picture (TEXTSTRA 28728 / 28731, STRATEGY
				# 1005): "<system> Joins" / "Popular support on <system> has caused that
				# world to join the <side>."
				var joined := GameMessage.new("%s Joins" % m.Target.Name,
					"Popular support on %s has caused that world to join the %s." % [m.Target.Name, m.Faction.ShortName],
					Enums.MessageCategory.Loyalty, day, m.Target, null)
				joined.Type = Enums.MessageType.SystemControl
				joined.Advisor = "support_gained"
				joined.Still = "message.1005"
				joined.Sound = "strategy/1104"
				EventBus.Tell(m.Faction, joined)
			Report(m, day, DiplomacyTitle(m), DiplomacyReport(m, true, now < 100,
					"The system is now wholly with us and the mission is complete." if now >= 100 else ""),
				now < 100, "mission_success", false, ReportScene(m))
			if now >= 100:
				m.Finished = true

		Enums.MissionType.Espionage:
			IntelManager.Capture(m.Faction, m.Target, day, IntelManager.EspionageCategories)
			print("[Mission] Espionage at %s succeeded - full snapshot taken." % m.Target.Name)
			var leaked := LeakExtraSystems(m, rng)
			# TEXTSTRA 28937 / 28940, then 28942-28943 for what else came back.
			MissionReport(m, day, "mission_success",
				"My espionage mission to %s was successful.  %s" % [m.Target.Name, leaked],
				"The espionage mission to %s was successful.  %s" % [m.Target.Name, leaked])
			m.Finished = true

		Enums.MissionType.InciteUprising:
			var holder := m.Target.ControllingFaction
			var was_rioting := m.Target.IsInUprising
			m.Target.ShiftSupport(holder, -UprisingSupportSwing)
			var rioting := m.Target.IsInUprising
			var name := m.DisplayName()
			var at := m.Target.Name
			var goes_on := m.Target.ControllingFaction == holder
			# TEXTSTRA 28929-28935: risen (or thrown out), inflamed, or nothing.
			if m.Target.ControllingFaction != holder or (rioting and not was_rioting):
				MissionReport(m, day, "mission_success",
					"My %s mission to %s was successful.  The system has gone into uprising." % [name, at],
					"The %s mission to %s was successful.  " % [name, at], goes_on)
			elif rioting:
				MissionReport(m, day, "mission_success",
					"My %s mission to %s has not yet overthrown the government, but the system is in uprising.\n" % [name, at],
					"My %s mission to %s has inflamed the uprising there, but the enemy is still in control.\n" % [name, at], goes_on)
			else:
				MissionReport(m, day, "mission_success",
					"My %s mission to %s has not produced results.\n" % [name, at],
					"My %s mission to %s has not produced results.\n" % [name, at], goes_on)
			if not goes_on:
				m.Finished = true

		Enums.MissionType.SubdueUprising:
			var neutral_target := FactionRegistry.OrderOf(m.Target.ControllingFaction) < 0
			var swing := RuleManager.Roll(RuleId.SubdueNeutralShiftBase, RuleId.SubdueNeutralShiftSpread, rng, m.Faction) if neutral_target \
				else RuleManager.Roll(RuleId.SubdueMatchingShiftBase, RuleId.SubdueMatchingShiftSpread, rng, m.Faction)
			m.Target.ShiftSupport(m.Faction, swing)
			var still_rioting := m.Target.IsInUprising
			# TEXTSTRA 28945 / 28948: order restored; else the uprising goes on -
			# 28946 / 28949 and the question, as the original asks it.
			if still_rioting:
				FailureReport(m, day, true)
			else:
				MissionReport(m, day, "mission_success",
					"My mission to subdue the uprising on %s was successful.  Order has been restored." % m.Target.Name,
					"The %s mission to %s was successful.  Order has been restored." % [m.DisplayName(), m.Target.Name])
				m.Finished = true

		Enums.MissionType.Reconnaissance:
			IntelManager.Capture(m.Faction, m.Target, day, IntelManager.ReconnaissanceCategories)
			print("[Mission] Reconnaissance of %s complete - system charted." % m.Target.Name)
			# TEXTSTRA 28905: what it found shows in the system's windows, not here.
			var seen := "The reconnaissance mission to %s was successful.\n" % m.Target.Name
			MissionReport(m, day, "mission_success", seen, seen, false, true)
			m.Finished = true
			EventBus.BroadcastChanged()

		Enums.MissionType.Recruitment:
			var recruit := Recruitable(m.Faction, rng)
			if recruit == null:
				print("[Mission] Recruitment at %s succeeded but no one remains to recruit." % m.Target.Name)
				# Nobody left at all: the original's own (TEXTSTRA 29200 / 29201,
				# REBEXE 0x48ae30) - "Recruitment Done" / "We regret to report that
				# there are no more candidates to be recruited."
				Report(m, day, "Recruitment Done", "We regret to report that there are no more candidates to be recruited.", false, "mission_failure", false)
				m.Finished = true
			else:
				recruit.Attached = m.Target
				recruit.Destination = null
				recruit.DaysToDestination = 0
				recruit.Status = Enums.Status.AwaitingOrders
				print("[Mission] Recruitment at %s succeeded - %s joins." % [m.Target.Name, recruit.Name])
				# TEXTSTRA 28955 / 28953: "<name> Recruits <recruit>" / "My recruitment
				# mission to <system> was successful. <recruit> is at your command."
				var joins := "My recruitment mission to %s was successful. %s is at your command." % [m.Target.Name, recruit.Name]
				var headline := "%s Recruits %s" % [Leader(m).Name, recruit.Name]
				MissionReport(m, day, "mission_success", joins, joins, false, false, [headline, headline])
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
				# TEXTSTRA 28913 / 28916; the victim's side hears 29016 / 29017.
				MissionReport(m, day, "mission_success",
					"My mission to abduct %s from %s was a success.\n" % [victim.Name, m.Target.Name],
					"The mission to abduct %s from %s succeeded.\n" % [victim.Name, m.Target.Name], false, true)
				TellCaptured(victim, m.Target)
				m.Finished = true
				EventBus.BroadcastChanged()

		Enums.MissionType.Assassination:
			var victim := m.TargetCharacter
			if victim == null or victim.Status == Enums.Status.Dead:
				m.Finished = true
			else:
				var can_die := not victim.IsMajor and rng.NextRange(1, 101) <= AssassinationKillPercent
				var at := m.Target.Name
				# TEXTSTRA 28921 / 28924 eliminated, 28922 / 28926 not; the victim's
				# side hears 29192 / 29193 ("... was killed by Imperial Assassins at").
				var slain := "%s was killed by %s Assassins at %s." % [victim.Name, m.Faction.Adjective, at]
				var died := can_die
				if can_die:
					Kill(victim, slain)
					print("[Mission] %s assassinated at %s." % [victim.Name, at])
				else:
					Injure(victim, rng, RuleId.AssassinInjuryBase, RuleId.AssassinInjurySpread)
					died = victim.Status == Enums.Status.Dead
					print("[Mission] %s %s at %s." % [victim.Name, "died of wounds" if died else "injured", at])
				if died:
					MissionReport(m, day, "mission_success",
						"My assassination mission is complete. %s has been eliminated.\n" % victim.Name,
						"The assassination mission to %s is complete.  %s has been eliminated.\n" % [at, victim.Name], false, true)
				else:
					MissionReport(m, day, "mission_success",
						"My assassination mission to %s is complete.  %s has not been eliminated.\n" % [at, victim.Name],
						"The assassination mission to %s is complete.  %s has been injured.\n" % [at, victim.Name], false, true)
				m.Finished = true
				EventBus.BroadcastChanged()

		Enums.MissionType.Sabotage:
			var what: String = m.TargetObjectName() if m.TargetObjectName() != null else "target"
			var gone := m.Target.DestroyFacility(m.TargetFacility) if m.TargetFacility != null else m.Target.DestroyUnit(m.TargetUnit)
			if not gone:
				NotFoundReport(m, day)
				m.Finished = true
			else:
				print("[Mission] Sabotage at %s destroyed %s." % [m.Target.Name, what])
				# TEXTSTRA 28899 / 28898 + 28900, then the way home.
				MissionReport(m, day, "mission_success",
					"My sabotage mission to %s targeting the %s is complete.  The target was destroyed." % [m.Target.Name, what],
					"The sabotage mission to %s targeting the %s is complete.  The target was destroyed." % [m.Target.Name, what], false, true)
				# The original's own words (TEXTSTRA): "Saboteurs Strike at <system>" /
				# "The following units were destroyed by saboteurs at <system>:".
				_tell_defender(m.Target, day, "Saboteurs Strike at %s" % m.Target.Name,
					"The following units were destroyed by saboteurs at %s:\n%s\n" % [m.Target.Name, what],   # 28804, then 28805 a unit
					Enums.MessageCategory.Manufacturing, "strategy/1110")   # 0x48b950
				m.Finished = true

		Enums.MissionType.SuperweaponSabotage:
			var station := DeathStarAt(m.Target)
			if station == null:
				NotFoundReport(m, day)
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
					agent.EspionageRating += RuleManager.Get(RuleId.SuperweaponSabotageEspionageGain, m.Faction)
					agent.CombatRating += RuleManager.Get(RuleId.SuperweaponSabotageCombatGain, m.Faction)
				# The original's own (TEXTSTRA 29117 / 29118): "Death Star Sabotaged" /
				# "The Rebel Alliance has sabotaged the Death Star at <system>."
				Report(m, day, "Death Star Sabotaged", "The %s has sabotaged the Death Star at %s." % [m.Faction.DisplayName, m.Target.Name], false, "mission_success", false)
				m.Finished = true
				# The original's movie 104 (manual p106), for both sides.
				EventBus.Cue("superweapon_sabotaged", [m.Faction, station.Faction])
				EventBus.BroadcastChanged()

		Enums.MissionType.SpecialPowerTraining:
			var people := Lq.of_type_character(m.Team)
			var teacher: Character = Lq.first_or_null(people, CanTeachSpecialPower)
			var students := Lq.where(people, CanBeSpecialPowerStudent)
			if teacher == null or students.is_empty():
				m.Finished = true
			else:
				var gain: int = maxi(1, teacher.SpecialPowerLevel / JediTrainingDivisor)
				var risen := []
				for s in students:
					var was: int = s.SpecialPowerRankOf()
					s.IsKnownSpecialPowerUser = true
					s.SpecialPowerLevel += gain
					if s.SpecialPowerRankOf() != was:
						risen.append(s)
				print("[Mission] Jedi Training at %s: +%d to %s" % [m.Target.Name, gain, Lq.join(Lq.select(students, func(s): return s.Name))])
				# TEXTSTRA 29121 / 29124; each student who rose says so (29056 / 29057).
				MissionReport(m, day, "mission_success",
					"My %s mission on %s was a success." % [m.DisplayName(), m.Target.Name],
					"The %s mission on %s has been a success." % [m.DisplayName(), m.Target.Name])
				for s in risen:
					TellForceGrowth(s, day, m.Target)
				m.Finished = true

		Enums.MissionType.ShipDesignResearch, Enums.MissionType.TroopTrainingResearch, Enums.MissionType.FacilityDesignResearch:
			var reached := ResearchManager.MissionProgress(m.Faction, m.ResearchTrack(), day, rng)
			print("[Mission] %s at %s advanced our research." % [JsonUtil.enum_name(Enums.MissionType, m.Type), m.Target.Name])
			# TEXTSTRA 28961 / 28965 making progress, 28962 / 28966 valuable
			# results (a design reached), then the question (28891).
			var how := "has produced valuable results.  " if reached > 0 else "is making progress.  "
			MissionReport(m, day, "mission_success",
				"My %s Research mission at %s %s" % [m.DisplayName().trim_suffix(" Research"), m.Target.Name, how],
				"The %s Mission at %s %s" % [m.DisplayName(), m.Target.Name, how], true)

		Enums.MissionType.Rescue:
			var prisoner := m.TargetCharacter
			if prisoner == null or not prisoner.IsCaptured():
				m.Finished = true
			else:
				var captor: Faction = prisoner.CapturedBy
				prisoner.CapturedBy = null
				prisoner.Status = Enums.Status.AwaitingOrders
				print("[Mission] %s rescued at %s." % [prisoner.Name, m.Target.Name])
				# TEXTSTRA 28977 / 28980, then the way home; and the prisoner's own
				# "<name> Escaped" (29020 / 29021, STRATEGY 1029) - TeeJ's screenshots
				# of the original, 2026-09-28.
				MissionReport(m, day, "mission_success",
					"My mission to rescue %s from %s was a success.\n" % [prisoner.Name, m.Target.Name],
					"The mission to rescue %s from %s succeeded.\n" % [prisoner.Name, m.Target.Name], false, true)
				TellEscaped(prisoner, captor, m.Target, day)
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
		Enums.MissionType.SuperweaponSabotage: return (u.CombatRating + u.EspionageRating) / 2
		Enums.MissionType.ShipDesignResearch:     return (u as Character).ShipDesign if u is Character else 0
		Enums.MissionType.TroopTrainingResearch:  return (u as Character).TroopTraining if u is Character else 0
		Enums.MissionType.FacilityDesignResearch: return (u as Character).FacilityDesign if u is Character else 0
		Enums.MissionType.SpecialPowerTraining:           return (u as Character).SpecialPowerLevel if u is Character else 0
	return 0
