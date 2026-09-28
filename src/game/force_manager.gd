class_name ForceManager
extends RefCounted
## backend/ForceManager.cs - DISCOVERING LATENT FORCE POTENTIAL (manual p094-p095)
## and Luke's Dagobah pilgrimage (entries 101/102, 129, 130; MISSNSD 0x43).
## The discovery threshold (entry 41) is OURS in the sense the source records:
## it reproduces the manual's asymmetry and nothing in REBEXE.EXE reads it.

## The pilgrim and the heir are ROLES in characters.json (SCHEMA.md section 7),
## not names: Luke and Leia in the Star Wars pack.

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
	var d := MissionCatalog.ByBehaviour("dagobah")
	return MissionCatalog.RollLengthById(d.Id, rng, 100) if d != null else 100


## Called by StoryManager when the hunters take Han. Ends the course there and then.
static func InterruptDagobah() -> void:
	if _completed:
		return
	var luke: Character = Lq.first_or_null(GameState.ActiveRoster, func(c): return c.HasRole("pilgrim"))
	if luke == null or not luke.AtDagobah:
		return
	ConcludeDagobah(luke, StrategicTickManager.Today, false)


## REBEXE.EXE 0x575216: completed -> rank + pct(rank, entry 129); interrupted ->
## rank + pct(rank, daysTrained / entry 130).
static func ConcludeDagobah(luke: Character, day: int, completed: bool) -> void:
	var before := luke.SpecialPowerLevel
	var percent: int
	if completed:
		percent = RuleManager.Get(RuleId.PilgrimageBonusPercent, luke.Faction)
	else:
		percent = max(0, day - _departed_on) / max(1, RuleManager.Get(RuleId.PilgrimagePartialDivisor, luke.Faction))
	luke.SpecialPowerLevel = before + before * percent / 100

	luke.AtDagobah = false
	luke.Attached = _return_to
	luke.Status = Enums.Status.AwaitingOrders
	_completed = true

	var served: int = maxi(0, day - _departed_on)
	var rank_name := Character.RankLabel(luke.SpecialPowerRankOf())
	print("[Force] %s has returned from Dagobah after %d day(s) (%s, +%d%%): Force %d -> %d (%s)." % [
		luke.Name, served, "completed" if completed else "interrupted", percent, before, luke.SpecialPowerLevel, rank_name])

	if not GameSettings.IsHuman(luke.Faction):
		return
	# The original's words and picture (TEXTSTRA 29114 / 29115, STRATEGY 1042):
	# "Luke Leaves Dagobah" / "I have finished my training with Yoda."
	var back := GameMessage.new("%s Leaves Dagobah" % FirstName(luke), "I have finished my training with Yoda.",
		Enums.MessageCategory.Missions, day, _return_to if _return_to is Planet else null, luke).With("", "dagobah_completed" if completed else "")
	back.Still = "message.1042"
	EventBus.Tell(luke.Faction, back)


## How the original names its story characters in its messages: "Luke", "Leia".
static func FirstName(c: Character) -> String:
	return c.Name.get_slice(" ", 0)


static func ProcessDagobah(day: int) -> void:
	if _completed:
		return
	var roster := GameState.ActiveRoster
	if roster == null:
		return
	var luke: Character = Lq.first_or_null(roster, func(c): return c.HasRole("pilgrim"))
	if luke == null:
		return

	if _departs_on < 0:
		_departs_on = day + RuleManager.Roll(RuleId.PilgrimageTriggerBase, RuleId.PilgrimageTriggerSpread, Prng.Session, luke.Faction)
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
	# TEXTSTRA 29112 / 29113, STRATEGY 1057.
	var gone := GameMessage.new("%s Goes to Dagobah" % FirstName(luke),
		"%s has been sent to Dagobah to be trained by Yoda." % FirstName(luke),
		Enums.MessageCategory.Missions, day, _return_to if _return_to is Planet else null, luke)
	gone.Still = "message.1057"
	gone.Sound = "strategy/1132"
	EventBus.Tell(luke.Faction, gone)


## LEIA IS THE ONE EXCEPTION (manual p094; REBEXE.EXE 0x560BCF): no rank threshold.
static func LeiaLearnsFromLuke(roster: Array, day: int) -> void:
	var leia: Character = Lq.first_or_null(roster, func(c): return c.HasRole("heir"))
	if leia == null or leia.KnowsHeritage:
		return
	if leia.Status == Enums.Status.Dead or leia.IsOffMap() or leia.Attached == null:
		return
	var luke: Character = Lq.first_or_null(roster, func(c): return c.HasRole("pilgrim"))
	if luke == null or not luke.KnowsHeritage:
		return
	if luke.Status == Enums.Status.Dead or luke.Attached != leia.Attached:
		return

	leia.KnowsHeritage = true
	leia.IsKnownSpecialPowerUser = true
	var rank_name := Character.RankLabel(leia.SpecialPowerRankOf())
	print("[Force] %s has told %s what she is (%s, level %d)." % [luke.Name, leia.Name, rank_name, leia.SpecialPowerLevel])

	if not GameSettings.IsHuman(leia.Faction):
		return
	# TEXTSTRA 29144 / 29145, in her own voice.
	EventBus.Tell(leia.Faction, GameMessage.new("%s Uses Force" % FirstName(leia),
		"My heritage as a member of the Skywalker family has given me the ability to use the Force, as it has my brother and father.",
		Enums.MessageCategory.Missions, day, leia.Attached if leia.Attached is Planet else null, leia).With("", "force_ability_revealed"))


static func ProcessDay(day: int) -> void:
	ProcessDagobah(day)
	var roster := GameState.ActiveRoster
	if roster == null:
		return
	LeiaLearnsFromLuke(roster, day)

	var detectors := Lq.where(roster, func(c):
		return c.IsKnownSpecialPowerUser and c.Status != Enums.Status.Dead and not c.IsCaptured() \
			and c.Attached != null and c.SpecialPowerLevel >= RuleManager.Get(RuleId.DiscoverForceUserThresh, c.Faction))
	if detectors.is_empty():
		return

	for seer in detectors:
		for latent in roster:
			# ⛔ LEIA IS EXEMPT FROM THIS ENTIRE ROUTINE (p094).
			if latent.HasRole("heir"):
				continue
			if latent.IsKnownSpecialPowerUser or latent.SpecialPowerLevel <= 0:
				continue
			if latent.Status == Enums.Status.Dead or latent.IsCaptured():
				continue
			if latent.Faction != seer.Faction:
				continue
			if latent.Attached == null or latent.Attached != seer.Attached:
				continue

			latent.IsKnownSpecialPowerUser = true
			# ⚠ THE STAT BOOST IS NOT IMPLEMENTED - no magnitude in any source.
			var rank_name := Character.RankLabel(latent.SpecialPowerRankOf())
			print("[Force] %s has sensed the Force in %s (%s, level %d)." % [seer.Name, latent.Name, rank_name, latent.SpecialPowerLevel])

			if not GameSettings.IsHuman(latent.Faction):
				continue
			# TEXTSTRA 29048-29050, in the seer's voice: he can train them now, or
			# once he is a Jedi Knight.
			var can_train: bool = MissionManager.CanTeachSpecialPower(seer)
			EventBus.Tell(latent.Faction, GameMessage.new("Future Jedi Discovered",
				("I have detected that %s has the ability to use the Force.  We should consider allowing me to conduct training in the way of the Force." if can_train
					else "I have detected that %s has the ability to use the Force.  Once I reach the rank of Jedi Knight, I should conduct training in the use of the Force.") % latent.Name,
				Enums.MessageCategory.Missions, day, latent.Attached if latent.Attached is Planet else null, seer))
