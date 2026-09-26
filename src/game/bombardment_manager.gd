class_name BombardmentManager
extends RefCounted
## backend/BombardmentManager.cs - ORBITAL BOMBARDMENT, manual p122, and the
## resolution path at REBEXE.EXE 0x58DC00-0x58E2E0: defenders shoot first, the
## fleet's combined modifier (fighters and Admiral included) is pitted against
## the shields, and what gets through is a NUMBER OF SHOTS.

## "Use your ships' firepower to..." - the four options (p122).
enum BombardmentMode { MilitaryFacilities, CivilianFacilities, General, DestroySystem }


class BombardmentReport:
	var Target: Planet
	var Blocked: bool
	var ShipsDisabled: int
	var Firepower: int
	var ShieldStrength: int
	var Through: int
	var Destroyed: Array = []
	var ShipsLost: Array = []
	var Damaged: Array = []
	var CivilianLoss: bool


## ⚠ FITTED.
const CollateralPercent := 25
## ⚠ STILL FITTED.
const CivilianLoyaltyHit := 6


## Entry 173 "Orbital Strike Selected Side Support Shift" = -20, stored negative.
static func CivilianSectorSupportShift(f: Faction) -> int:
	return RuleManager.Get(RuleId.OrbitalStrikeSupportShift, f)


static func CanBombard(fleet: Fleet, target: Planet) -> bool:
	return fleet != null and target != null and fleet.Status != Enums.Status.Enroute \
		and fleet.Ships.size() > 0 and target.ControllingFaction != fleet.Faction


## "...have the DEATH STAR IN YOUR FLEET" (p122) - the unit the pack marks
## `superweapon` (units.json roles).
static func CanDestroySystem(fleet: Fleet) -> bool:
	return fleet != null and Lq.any(fleet.Ships, func(s): return s.HasRole("superweapon"))


static func Bombard(fleet: Fleet, target: Planet, mode: int, rng: Prng, day: int) -> BombardmentReport:
	var report := BombardmentReport.new()
	report.Target = target
	if not CanBombard(fleet, target):
		return report

	var ships := fleet.Ships.duplicate()

	# 1. THE DEFENDERS SHOOT FIRST.
	var disabled: Array = []
	for f in target.Facilities:
		if not f.HasRole("disable"):
			continue
		var victim: Unit = Lq.first_or_null(ships, func(s): return not disabled.has(s))
		if victim == null:
			break
		disabled.append(victim)
		report.ShipsDisabled += 1

	for bat in target.Facilities:
		if not bat.HasRole("anti_ship"):
			continue
		var victim: Unit = ships[rng.NextMax(ships.size())] if ships.size() > 0 else null
		if victim == null:
			break
		var hit: int = bat.WeaponRating
		var on_shield: int = min(victim.Shield, hit)
		victim.Shield -= on_shield
		hit -= on_shield
		victim.Hull -= hit
		if victim.Hull <= 0:
			report.ShipsLost.append(victim.Name)
			ships.erase(victim)
			disabled.erase(victim)
			target.DestroyUnit(victim)
			fleet.Ships.erase(victim)
		elif hit > 0:
			report.Damaged.append(victim.Name)

	var able := Lq.where(ships, func(s): return not disabled.has(s))
	if able.is_empty():
		report.Blocked = true
		Announce(report, fleet, mode, day)
		return report

	# 2. COMBINE THE BOMBARDMENT MODIFIERS, PIT THEM AGAINST THE SHIELDS.
	var admiral := 0
	for c in GameState.ActiveRoster:
		if c.Commanding == fleet and c.Rank == Enums.Rank.Admiral:
			admiral = max(admiral, c.LeadershipRating)

	var raw := Lq.sum(able, func(s): return s.Bombardment) \
		+ Lq.sum(able, func(s): return Lq.sum(Lq.where(s.Hangar, func(h): return h.Type == Enums.UnitType.Fighter), func(h): return h.Bombardment))

	var officer_div: int = maxi(1, RuleManager.Get(RuleId.ShipBombardOfficerDiv, fleet.Faction))
	report.Firepower = raw + raw * admiral / officer_div

	report.ShieldStrength = 0
	for f in target.Facilities:
		if f.HasRole("shield"):
			var rule := FacilityCatalog.Get(f.Family(), f.Tier)
			report.ShieldStrength += rule.stat("shield_strength") if rule != null else 0

	report.Through = max(0, report.Firepower - report.ShieldStrength)
	if report.Through <= 0:
		Announce(report, fleet, mode, day)
		return report

	# 3. WHAT GETS PAST IS SPENT ON THE GROUND, by the chosen mode.
	var budget := report.Through

	if mode == BombardmentMode.DestroySystem and CanDestroySystem(fleet):
		var owner: Faction = target.ControllingFaction
		DestroyEverything(target, report)
		Announce(report, fleet, mode, day)
		# The Death Star's work (manual p124; the original's movie 101), for
		# the side that did it and the side that held the system.
		EventBus.Cue("system_destroyed", [fleet.Faction, owner])
		return report

	var military := Lq.where(target.Facilities, IsMilitary)
	var civilian := Lq.where(target.Facilities, func(f): return not IsMilitary(f) and not f.HasRole("headquarters"))

	match mode:
		BombardmentMode.MilitaryFacilities:
			budget = SpendOn(military, budget, rng, report)
			if budget > 0 and rng.NextRange(1, 101) <= CollateralPercent:
				budget = SpendOn(civilian, budget, rng, report)
		BombardmentMode.CivilianFacilities:
			budget = SpendOn(civilian, budget, rng, report)
		BombardmentMode.General:
			budget = SpendOnTroops(target, budget, rng, report)
			var everything := Lq.order_by(military + civilian, func(_f): return rng.Next())
			budget = SpendOn(everything, budget, rng, report)

	Announce(report, fleet, mode, day)
	return report


## The four defensive families (the original's 34 to 37), by role.
static func IsMilitary(f: Facility) -> bool:
	return f.HasRole("shield") or f.HasRole("anti_ship") \
		or f.HasRole("disable") or f.HasRole("superweapon_shield")


## 0x58E186: `through` shots, each a random surviving target against
## randRange(entry 10, entry 11) vs its resistance (read as BombardmentDefense).
static func SpendOn(pool: Array, shots: int, rng: Prng, r: BombardmentReport) -> int:
	var alive := pool.duplicate()
	var lo := RuleManager.Get(RuleId.StrikePermissionMin, r.Target.ControllingFaction)
	var hi := RuleManager.Get(RuleId.StrikePermissionMax, r.Target.ControllingFaction)
	if hi < lo:
		hi = lo
	while shots > 0 and alive.size() > 0:
		shots -= 1
		var f: Facility = alive[rng.NextMax(alive.size())]
		var rule := FacilityCatalog.Get(f.Family(), f.Tier)
		var resistance: int = maxi(0, rule.stat("bombardment_defense") if rule != null else 0)
		if rng.NextRange(lo, hi + 1) <= resistance:
			continue
		alive.erase(f)
		if not r.Target.DestroyFacility(f):
			continue
		r.Destroyed.append(f.Name())
		if not IsMilitary(f):
			r.CivilianLoss = true
	return shots


static func SpendOnTroops(target: Planet, budget: int, rng: Prng, r: BombardmentReport) -> int:
	var alive := target.Troopers()
	var lo := RuleManager.Get(RuleId.StrikePermissionMin, target.ControllingFaction)
	var hi := RuleManager.Get(RuleId.StrikePermissionMax, target.ControllingFaction)
	if hi < lo:
		hi = lo
	while budget > 0 and alive.size() > 0:
		budget -= 1
		var t: Unit = alive[rng.NextMax(alive.size())]
		if rng.NextRange(lo, hi + 1) <= max(0, t.BombardmentDefense):
			continue
		alive.erase(t)
		if target.DestroyUnit(t):
			r.Destroyed.append(t.Name)
	return budget


## A HEADQUARTERS DESTROYED WITH THE SYSTEM STILL COUNTS (manual p136).
static func DestroyEverything(target: Planet, r: BombardmentReport) -> void:
	var hq_owner: Faction = target.ControllingFaction if Lq.any(target.Facilities, func(f): return f.HasRole("headquarters")) else null
	for f in target.Facilities.duplicate():
		if target.DestroyFacility(f):
			r.Destroyed.append(f.Name())
	if hq_owner != null:
		VictoryManager.HeadquartersDestroyed(hq_owner)
	for u in target.Garrison.duplicate():
		if target.DestroyUnit(u):
			r.Destroyed.append(u.Name)
	for u in target.FighterSquadrons.duplicate():
		if target.DestroyUnit(u):
			r.Destroyed.append(u.Name)
	r.CivilianLoss = true


## "After bombardment, a window will display the bombardment effects" (p122).
static func Announce(r: BombardmentReport, fleet: Fleet, mode: int, day: int) -> void:
	var t := r.Target
	var attacker := fleet.Faction
	if r.CivilianLoss:
		LoyaltyManager.CivilianFacilitiesDestroyed(attacker, CivilianLoyaltyHit)
		var shift := CivilianSectorSupportShift(attacker)
		for p in SectorPeers(t):
			p.ShiftSupport(attacker, shift)

	var lines := []
	if r.ShipsDisabled > 0:
		lines.append("%d ship(s) had their guns robbed of power by ion cannon fire." % r.ShipsDisabled)
	if not r.ShipsLost.is_empty():
		lines.append("Lost to defensive batteries: %s." % Lq.join(r.ShipsLost))
	if not r.Damaged.is_empty():
		lines.append("Damaged: %s." % Lq.join(r.Damaged))
	if r.Blocked:
		lines.append("The fleet could not bring its guns to bear at all.")
	else:
		lines.append("Firepower %d against %s %d - %d reached the surface." % [r.Firepower, Terms.lower("planetary_shields"), r.ShieldStrength, r.Through])
		lines.append(("Destroyed: %s." % Lq.join(r.Destroyed)) if not r.Destroyed.is_empty() else "Nothing on the surface was destroyed.")
	if r.CivilianLoss:
		lines.append("Civilian losses have hurt our standing across the sector.")

	var body := "\n".join(lines)
	print("[Bombardment] %s (%s): %s" % [t.Name, JsonUtil.enum_name(BombardmentMode, mode), body.replace("\n", " ")])
	EventBus.BroadcastMessage(GameMessage.new("Bombardment of %s" % t.Name, body, Enums.MessageCategory.Conflict, day, t))
	EventBus.BroadcastChanged()


static func SectorPeers(p: Planet) -> Array:
	var out := []
	for s in GameState.ActiveGalaxy:
		for q in s.Planets:
			if q.SectorId == p.SectorId:
				out.append(q)
	return out
