class_name ForceManager
extends RefCounted
## backend/ForceManager.cs - DISCOVERING LATENT FORCE POTENTIAL (manual p094-p095)
## and Luke's Dagobah pilgrimage (entries 101/102, 129, 130; MISSNSD 0x43).
## The discovery threshold (entry 41) is OURS in the sense the source records:
## it reproduces the manual's asymmetry and nothing in REBEXE.EXE reads it.

const PilgrimName := "Luke Skywalker"
const HeirName := "Leia Organa"

static var _departs_on: int = -1
static var _departed_on: int = -1
static var _returns_on: int = -1
static var _return_to: Location = null
static var _completed: bool = false


static func Reset() -> void:
	_departs_on = -1
	_departed_on = -1
	_returns_on = -1
	_return_to = null
	_completed = false


## MISSNSD's own length for Dagobah: 100 base, 0 spread.
static func DagobahStayDays(rng: Prng) -> int:
	return MissionCatalog.RollLengthById(MissionCatalog.Dagobah, rng, 100)


## Called by StoryManager when the hunters take Han. Ends the course there and then.
static func InterruptDagobah() -> void:
	if _completed:
		return
	var luke: Character = Lq.first_or_null(GameState.ActiveRoster, func(c): return c.Name == PilgrimName)
	if luke == null or not luke.AtDagobah:
		return
	ConcludeDagobah(luke, StrategicTickManager.Today, false)


## REBEXE.EXE 0x575216: completed -> rank + pct(rank, entry 129); interrupted ->
## rank + pct(rank, daysTrained / entry 130).
static func ConcludeDagobah(luke: Character, day: int, completed: bool) -> void:
	var before := luke.JediLevel
	var percent: int
	if completed:
		percent = RuleManager.Get(RuleId.DagobahBonusPercent, luke.Faction)
	else:
		percent = max(0, day - _departed_on) / max(1, RuleManager.Get(RuleId.DagobahPartialDivisor, luke.Faction))
	luke.JediLevel = before + before * percent / 100

	luke.AtDagobah = false
	luke.Attached = _return_to
	luke.Status = Enums.Status.AwaitingOrders
	_completed = true

	var served: int = maxi(0, day - _departed_on)
	var rank_name := JsonUtil.enum_name(Enums.ForceRanking, luke.ForceRank())
	print("[Force] %s has returned from Dagobah after %d day(s) (%s, +%d%%): Force %d -> %d (%s)." % [
		luke.Name, served, "completed" if completed else "interrupted", percent, before, luke.JediLevel, rank_name])

	if not GameSettings.IsHuman(luke.Faction):
		return
	var body: String
	if completed:
		body = "%s's training under Yoda is complete. He stands at %s, and is now strong enough in the Force to sense it in others." % [luke.Name, rank_name]
	else:
		body = "%s's training under Yoda was cut short after %d day(s). He stands at %s - what he had time to learn, and no more." % [luke.Name, served, rank_name]
	EventBus.Tell(luke.Faction, GameMessage.new("%s has returned" % luke.Name,
		body + "\n\nHe has returned to %s." % (_return_to.Name if _return_to != null else "our forces"),
		Enums.MessageCategory.Missions, day, _return_to if _return_to is Planet else null, luke))


static func ProcessDagobah(day: int) -> void:
	if _completed:
		return
	var roster := GameState.ActiveRoster
	if roster == null:
		return
	var luke: Character = Lq.first_or_null(roster, func(c): return c.Name == PilgrimName)
	if luke == null:
		return

	if _departs_on < 0:
		_departs_on = day + RuleManager.Roll(RuleId.DagobahTriggerBase, RuleId.DagobahTriggerSpread, Prng.Session, luke.Faction)
		print("[Force] %s will be called to Dagobah on day %d." % [luke.Name, _departs_on])

	if luke.AtDagobah:
		if day >= _returns_on:
			ConcludeDagobah(luke, day, true)
		return

	if day < _departs_on:
		return

	if luke.IsCaptured() or luke.Status == Enums.Status.Dead \
			or luke.Status == Enums.Status.Enroute or luke.Status == Enums.Status.OnMission \
			or MissionManager.IsOnMissionTeam(luke) or luke.Attached == null:
		return

	_return_to = luke.Attached
	_departed_on = day
	_returns_on = day + DagobahStayDays(null)

	luke.AtDagobah = true
	luke.Attached = null
	luke.Commanding = null
	luke.Rank = Enums.Rank.None

	print("[Force] %s has left for Dagobah, returning day %d." % [luke.Name, _returns_on])

	if not GameSettings.IsHuman(luke.Faction):
		return
	EventBus.Tell(luke.Faction, GameMessage.new("%s has gone" % luke.Name,
		"%s has left for the Dagobah system, alone and without orders, to seek training under a Jedi Master.\n\nHe cannot be located or given orders until he returns." % luke.Name,
		Enums.MessageCategory.Missions, day, _return_to if _return_to is Planet else null, luke))


## LEIA IS THE ONE EXCEPTION (manual p094; REBEXE.EXE 0x560BCF): no rank threshold.
static func LeiaLearnsFromLuke(roster: Array, day: int) -> void:
	var leia: Character = Lq.first_or_null(roster, func(c): return c.Name == HeirName)
	if leia == null or leia.KnowsHeritage:
		return
	if leia.Status == Enums.Status.Dead or leia.IsOffMap() or leia.Attached == null:
		return
	var luke: Character = Lq.first_or_null(roster, func(c): return c.Name == PilgrimName)
	if luke == null or not luke.KnowsHeritage:
		return
	if luke.Status == Enums.Status.Dead or luke.Attached != leia.Attached:
		return

	leia.KnowsHeritage = true
	leia.IsKnownJedi = true
	var rank_name := JsonUtil.enum_name(Enums.ForceRanking, leia.ForceRank())
	print("[Force] %s has told %s what she is (%s, level %d)." % [luke.Name, leia.Name, rank_name, leia.JediLevel])

	if not GameSettings.IsHuman(leia.Faction):
		return
	EventBus.Tell(leia.Faction, GameMessage.new("%s knows her heritage" % leia.Name,
		"%s has told %s the truth about their parentage.\n\nThe Force has been in her all along, and she stands at %s. Her abilities can be developed further with a Jedi Training mission led by a Jedi Master." % [luke.Name, leia.Name, rank_name],
		Enums.MessageCategory.Missions, day, leia.Attached if leia.Attached is Planet else null, leia))


static func ProcessDay(day: int) -> void:
	ProcessDagobah(day)
	var roster := GameState.ActiveRoster
	if roster == null:
		return
	LeiaLearnsFromLuke(roster, day)

	var detectors := Lq.where(roster, func(c):
		return c.IsKnownJedi and c.Status != Enums.Status.Dead and not c.IsCaptured() \
			and c.Attached != null and c.JediLevel >= RuleManager.Get(RuleId.DiscoverForceUserThresh, c.Faction))
	if detectors.is_empty():
		return

	for seer in detectors:
		for latent in roster:
			# ⛔ LEIA IS EXEMPT FROM THIS ENTIRE ROUTINE (p094).
			if latent.Name == HeirName:
				continue
			if latent.IsKnownJedi or latent.JediLevel <= 0:
				continue
			if latent.Status == Enums.Status.Dead or latent.IsCaptured():
				continue
			if latent.Faction != seer.Faction:
				continue
			if latent.Attached == null or latent.Attached != seer.Attached:
				continue

			latent.IsKnownJedi = true
			# ⚠ THE STAT BOOST IS NOT IMPLEMENTED - no magnitude in any source.
			var rank_name := JsonUtil.enum_name(Enums.ForceRanking, latent.ForceRank())
			print("[Force] %s has sensed the Force in %s (%s, level %d)." % [seer.Name, latent.Name, rank_name, latent.JediLevel])

			if not GameSettings.IsHuman(latent.Faction):
				continue
			EventBus.Tell(latent.Faction, GameMessage.new("%s: %s is strong in the Force" % [seer.Name, latent.Name],
				"%s has been unaware of it until now. They stand at %s.\n\nTheir abilities can be developed further with a Jedi Training mission led by a Jedi Master." % [latent.Name, rank_name],
				Enums.MessageCategory.Missions, day, latent.Attached if latent.Attached is Planet else null, latent))
