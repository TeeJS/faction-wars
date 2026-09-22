class_name LoyaltyManager
extends RefCounted
## backend/LoyaltyManager.cs - CHARACTER LOYALTY AND TREACHERY, manual p094.
## Loyalty is pulled each day toward how the war is going; a bad stretch turns
## people and a recovery brings them back. Key characters and anyone holding a
## command are immune.

## ⚠ fitted, no entry exists - calibrated against tens of thousands of hours of
## play in which a character turned traitor exactly once.
const TraitorThreshold := 15

## The shocks p094 lists by name. ⚠ fitted.
const ShockCapitalChangedHands := 25
const ShockRebelHqDestroyed := 40
const ShockCombatLosses := 5

## Who held each capital last time we looked: planet pack id -> Faction (or
## null for nobody). A capital is a world some faction's FIXED headquarters
## sits on (factions.json `hq.kind: fixed`) - Coruscant in the Star Wars pack.
## MissionManager.LeakExtraSystems defines "capital" the same way.
static var _capital_held_by: Dictionary = {}


static func Reset() -> void:
	_capital_held_by.clear()


## Entries 48 and 47: base 0, spread -5, magnitude only.
static func DriftStep(f: Faction, rng: Prng) -> int:
	var b := RuleManager.Get(RuleId.LoyaltyShiftBase, f)
	var spread := RuleManager.Get(RuleId.LoyaltyShiftSpread, f)
	var roll := b + rng.NextRange(0, abs(spread) + 1)
	return max(1, abs(roll))


static func ProcessDay(galaxy: Array) -> void:
	if GameState.ActiveRoster == null or galaxy == null:
		return
	WatchCapitals(galaxy)
	var rng := Prng.Session
	for f in FactionRegistry.Playable:
		var target := GalaxySupportFor(f, galaxy)
		for c in GameState.ActiveRoster:
			if c.Faction != f or c.Status == Enums.Status.Dead:
				continue
			if not c.CanTurnTraitor():
				c.Loyalty = 100
				c.TraitorRevealed = false
				continue
			var step := DriftStep(f, rng)
			if c.Loyalty < target:
				c.Loyalty = min(c.Loyalty + step, target)
			elif c.Loyalty > target:
				c.Loyalty = max(c.Loyalty - step, target)
			if not c.IsTraitorous():
				c.TraitorRevealed = false


## HOW THE WAR IS GOING, RELATIVE TO THE OTHER SIDE: level pegging is 50.
static func GalaxySupportFor(f: Faction, galaxy: Array) -> int:
	var mine := AverageSupport(f, galaxy)
	var theirs := 0
	for other in FactionRegistry.Playable:
		if other != f:
			theirs = max(theirs, AverageSupport(other, galaxy))
	return clampi(50 + (mine - theirs), 0, 100)


## Explored worlds only.
static func AverageSupport(f: Faction, galaxy: Array) -> int:
	var total := 0
	var count := 0
	for s in galaxy:
		for p in s.Planets:
			if not p.ExploredBy(f):   # each side's galaxy-wide support is over ITS chart
				continue
			total += p.SupportFor(f)
			count += 1
	return 50 if count == 0 else total / count


## "The Empire GAINING OR LOSING CONTROL OF CORUSCANT" (p094) - either direction,
## both sides. Generalised to every capital the pack declares (a fixed HQ world);
## the Star Wars pack has exactly one, so this is the same rule.
static func WatchCapitals(galaxy: Array) -> void:
	for f in FactionRegistry.Playable:
		if f.Hq == null or f.Hq.Kind != "fixed" or f.Hq.Planet.is_empty():
			continue
		var capital: Planet = null
		for s in galaxy:
			for p in s.Planets:
				if p.PackId == f.Hq.Planet:
					capital = p
					break
			if capital != null:
				break
		if capital == null:
			continue
		if not _capital_held_by.has(capital.PackId):
			_capital_held_by[capital.PackId] = capital.ControllingFaction
			continue
		var last: Faction = _capital_held_by[capital.PackId]
		if capital.ControllingFaction == last:
			continue
		var gained := capital.ControllingFaction
		var lost := last
		_capital_held_by[capital.PackId] = gained
		print("[Loyalty] %s changed hands: %s -> %s." % [capital.Name, lost.DisplayName if lost != null else "nobody", gained.DisplayName if gained != null else "nobody"])
		Shock(lost, -ShockCapitalChangedHands)
		Shock(gained, ShockCapitalChangedHands)


static func RebelHeadquartersDestroyed(owner: Faction) -> void:
	Shock(owner, -ShockRebelHqDestroyed)


## "DESTROYING CIVILIAN FACILITIES HURTS LOYALTY" (manual p122).
static func CivilianFacilitiesDestroyed(attacker: Faction, amount: int) -> void:
	Shock(attacker, -amount)


static func LostUnitsInCombat(owner: Faction, units_lost: int) -> void:
	Shock(owner, -ShockCombatLosses * max(1, units_lost))


static func Shock(f: Faction, delta: int) -> void:
	if f == null or GameState.ActiveRoster == null:
		return
	for c in GameState.ActiveRoster:
		if c.Faction != f or not c.CanTurnTraitor() or c.Status == Enums.Status.Dead:
			continue
		c.Loyalty = clampi(c.Loyalty + delta, 0, 100)


## "CHARACTERS STRONG IN THE FORCE CAN ALSO FERRET OUT TRAITORS IN A PARTY."
static func FerretOutTraitors(team: Array) -> Array:
	var found: Array = []
	if team == null:
		return found
	var people := Lq.of_type_character(team)
	var strong := Lq.any(people, func(c): return c.SpecialPowerRankOf() == Enums.SpecialPowerRank.Knight or c.SpecialPowerRankOf() == Enums.SpecialPowerRank.Master)
	if not strong:
		return found
	for c in people:
		if not c.IsTraitorous() or c.TraitorRevealed:
			continue
		c.TraitorRevealed = true
		found.append(c)
	return found
