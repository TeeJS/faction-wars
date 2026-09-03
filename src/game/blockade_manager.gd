class_name BlockadeManager
extends RefCounted
## backend/BlockadeManager.cs - BLOCKADES, manual p124, p090; REBEXE.EXE 0x50B310
## (withdraw percentage) and 0x50CB20 (support drift). Derived, never latched.

static var _next_drift: Dictionary = {}   # planet name -> day
static var _announced: Dictionary = {}    # planet name -> true


static func Reset() -> void:
	_next_drift.clear()
	_announced.clear()


## Which side, if any, is blockading this world right now. Null when it is not
## blockaded. If both sides are present this is a battle, not a blockade.
static func BlockaderOf(p: Planet) -> Faction:
	if p == null or p.ControllingFaction == null:
		return null
	var neutral := p.ControllingFaction == FactionRegistry.Neutral
	if neutral and not p.IsInhabited:
		return null
	var in_orbit := p.FleetsInOrbit()
	var present := func(f: Faction) -> bool:
		return Lq.any(in_orbit, func(x): return x.Faction == f and not x.IsEmpty()) \
			or Lq.any(p.FighterSquadrons, func(u): return u.Faction == f)
	var sides := 0
	for f in FactionRegistry.Playable:
		if present.call(f):
			sides += 1
	if sides > 1:
		return null
	for x in in_orbit:
		if not x.IsEmpty() and x.Faction != null and x.Faction != p.ControllingFaction:
			return x.Faction
	return null


static func IsBlockaded(p: Planet) -> bool:
	return BlockaderOf(p) != null


## SystemTroopRegWithdrawPercent (0x50B310): 100, or max(0, 100 - 5*capitals -
## 2*fighters) over the blockading force when there is no KDY v-150. THE ION
## CANNON IS ABSOLUTE.
static func WithdrawPercent(p: Planet) -> int:
	if not IsBlockaded(p):
		return 100
	if Lq.any(p.Facilities, func(f): return f.Type == Enums.FacilityType.IonCannon):
		return 100
	var blockader := BlockaderOf(p)
	var capitals := 0
	var fighters := 0
	for f in p.FleetsInOrbit():
		if f.Faction != blockader:
			continue
		capitals += Lq.count(f.Ships, func(s): return s.Type == Enums.UnitType.CapitalShip)
		fighters += Lq.count(f.Ships, func(s): return s.Type == Enums.UnitType.Fighter)
		for s in f.Ships:
			fighters += Lq.count(s.Hangar, func(h): return h.Type == Enums.UnitType.Fighter)
	var per_capital := RuleManager.Get(RuleId.BlockadeCapitalShipPenalty, blockader)
	var per_fighter := RuleManager.Get(RuleId.BlockadeFighterPenalty, blockader)
	return max(0, 100 - per_capital * capitals - per_fighter * fighters)


## "Troops attempting to move MAY BE KILLED" (p124) - trooper regiments only; the
## shipped game does not implement the character rule (see the source).
static func SurvivesLeaving(from: Planet, unit: Unit, rng: Prng) -> bool:
	if unit == null or unit.Type != Enums.UnitType.Troop:
		return true
	if not IsBlockaded(from):
		return true
	var pct := WithdrawPercent(from)
	if rng.NextRange(1, 101) <= pct:
		return true
	print("[Blockade] %s was destroyed running the blockade of %s (%d%% to get clear)." % [unit.Name, from.Name, pct])
	return false


## A blockade AMPLIFIES whichever way the world already leans (p090; 0x50CB20).
static func ProcessDay(galaxy: Array, day: int, _rng: Prng) -> void:
	if galaxy == null:
		return
	for s in galaxy:
		for p in s.Planets:
			var blockader := BlockaderOf(p)
			if blockader == null:
				if _announced.erase(p.Name):
					Broke(p, day)
				continue
			if not _announced.has(p.Name):
				_announced[p.Name] = true
				Begun(p, blockader, day)

			if not _next_drift.has(p.Name):
				_next_drift[p.Name] = day + RuleManager.Get(RuleId.BlockadeDriftDelayMatching, blockader)
				continue
			if day < _next_drift[p.Name]:
				continue

			var by_support := Lq.order_by(FactionRegistry.Playable, func(f): return p.SupportFor(f), true)
			var leading: Faction = by_support[0] if not by_support.is_empty() else null

			# 0x509930 returns Neutral on an exact tie, so a tie is always mismatched.
			var distinct := {}
			for f in FactionRegistry.Playable:
				distinct[p.SupportFor(f)] = true
			var tie := distinct.size() == 1
			var matching := not tie and leading == blockader

			var shift := RuleManager.Get(RuleId.BlockadeSupportShiftMatching if matching else RuleId.BlockadeSupportShiftMismatched, blockader)
			p.ShiftSupport(blockader, shift)
			_next_drift[p.Name] = day + RuleManager.Get(RuleId.BlockadeDriftDelayMatching if matching else RuleId.BlockadeDriftDelayMismatched, blockader)


## The original's own strings: "Fleet Initiates Blockade of |" / "| has initiated a blockade of |".
static func Begun(p: Planet, blockader: Faction, day: int) -> void:
	print("[Blockade] %s is blockading %s (units get out at %d%%)." % [blockader.DisplayName, p.Name, WithdrawPercent(p)])
	var audiences: Array = Lq.where([p.ControllingFaction, blockader], func(f: Faction) -> bool: return GameSettings.IsHuman(f))
	if audiences.is_empty():
		return
	var fleet: Fleet = Lq.first_or_null(p.FleetsInOrbit(), func(f): return f.Faction == blockader)
	var ion := Lq.any(p.Facilities, func(f): return f.Type == Enums.FacilityType.IonCannon)
	var msg := GameMessage.new("Fleet Initiates Blockade of %s" % p.Name,
		"%s has initiated a blockade of %s.\n\nProduction is halted and the system's facilities cannot be used while it lasts. Units leaving have a %d%% chance of getting clear.%s" % [
			fleet.Name if fleet != null else blockader.DisplayName, p.Name, WithdrawPercent(p),
			"\n\nThe ion cannon on the system is letting units through unharmed." if ion else ""],
		Enums.MessageCategory.Missions, day, p)
	msg.Type = Enums.MessageType.Blockade
	for k in audiences.size():
		EventBus.Tell(audiences[k], msg if k == 0 else msg.Copy())


static func Broke(p: Planet, day: int) -> void:
	_next_drift.erase(p.Name)
	print("[Blockade] The blockade of %s has been broken." % p.Name)
	if not GameSettings.IsHuman(p.ControllingFaction):
		return
	var msg := GameMessage.new("Blockade of %s broken" % p.Name,
		"The blockade of %s has been lifted. Production may resume." % p.Name,
		Enums.MessageCategory.Missions, day, p)
	msg.Type = Enums.MessageType.Blockade
	EventBus.Tell(p.ControllingFaction, msg)
