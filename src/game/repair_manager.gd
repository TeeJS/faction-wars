class_name RepairManager
extends RefCounted
## backend/RepairManager.cs - REPAIR AND SQUADRON REPLENISHMENT, manual p116 and
## entries 19/20/72/73. Capital ships mend one system at a time in ticks (73 to
## the day); squadrons recover one aircraft at a time in days. Free.

static var _next: Dictionary = {}   # Unit -> day (keyed by object)

const TicksPerDay := 73


static func Reset() -> void:
	_next.clear()


static func ProcessDay(galaxy: Array, day: int) -> void:
	if galaxy == null:
		return
	for s in galaxy:
		for world in s.Planets:
			var yard := Lq.any(world.Facilities, func(f): return f.Type == Enums.FacilityType.Shipyard)
			for fleet in world.OrbitingFleets.duplicate():
				if fleet.Status == Enums.Status.Enroute:
					continue
				for ship in fleet.Ships.duplicate():
					Mend(ship, fleet, world, yard, day)
					for carried in ship.Hangar.duplicate():
						Mend(carried, fleet, world, yard, day)
			for squadron in world.FighterSquadrons.duplicate():
				Mend(squadron, null, world, yard, day)


static func Mend(u: Unit, fleet: Fleet, where: Planet, yard: bool, day: int) -> void:
	if u == null or u.Status == Enums.Status.Enroute:
		return
	var d: ShipDamage = u.Damage
	if d == null or not NeedsWork(u, d):
		_next.erase(u)
		return

	var squadron := u.Type == Enums.UnitType.Fighter
	if squadron:
		var days: int = maxi(1, RuleManager.Get(RuleId.SquadronRecoverWithYard if yard else RuleId.SquadronRecoverNoYard, u.Faction))
		if not _next.has(u):
			_next[u] = day + days
			return
		if day < _next[u]:
			return
		_next[u] = day + days

	var whole := RecoverFighter(d) if squadron else RepairSystem(d, PointsPerDay(u, yard))
	if not whole:
		return
	_next.erase(u)
	Announce(u, fleet, where, day)


static func PointsPerDay(u: Unit, yard: bool) -> int:
	var delay: int = maxi(1, RuleManager.Get(RuleId.CapitalFastRepairDelay if yard else RuleId.CapitalNormalRepairDelay, u.Faction))
	return max(1, TicksPerDay / delay)


static func NeedsWork(u: Unit, d: ShipDamage) -> bool:
	if u.Type == Enums.UnitType.Fighter:
		return d.MaxAircraft > 0 and d.Aircraft < d.MaxAircraft
	return d.Hull < d.MaxHull or d.IsDamaged()


static func RecoverFighter(d: ShipDamage) -> bool:
	d.Aircraft = min(d.MaxAircraft, d.Aircraft + 1)
	return d.Aircraft >= d.MaxAircraft


## ONE SYSTEM AT A TIME (p147); hull last. Shields are a charge, not a repair job.
static func RepairSystem(d: ShipDamage, points: int) -> bool:
	if d.Shield < d.MaxShield:
		d.Shield = d.MaxShield
	for i in points:
		if d.ShieldRecharge < d.MaxShieldRecharge:
			d.ShieldRecharge += 1
			continue
		if d.WeaponRecharge < d.MaxWeaponRecharge:
			d.WeaponRecharge += 1
			continue
		if d.Sublight < d.MaxSublight:
			d.Sublight += 1
			continue
		if d.Hyperdrive < d.MaxHyperdrive:
			d.Hyperdrive += 1
			continue
		if d.TractorPower < d.MaxTractorPower:
			d.TractorPower += 1
			continue
		if d.Hull < d.MaxHull:
			d.Hull += 1
			continue
		return true
	return d.Hull >= d.MaxHull and not d.IsDamaged()


static func Announce(u: Unit, fleet: Fleet, where: Planet, day: int) -> void:
	var at: String = fleet.Name if fleet != null else (where.Name if where != null else "our forces")
	print("[Repair] %s attached to %s is fully operational again." % [u.Name, at])
	if not GameSettings.IsHuman(u.Faction):
		return
	var squadron := u.Type == Enums.UnitType.Fighter
	var msg := GameMessage.new("Squadron at Full Strength" if squadron else "Capital Ship Repaired",
		("The %s Squadron attached to %s has replaced all fighters lost in combat." % [u.Name, at]) if squadron
		else ("%s attached to %s has repaired all battle damage and is fully operational." % [u.Name, at]),
		Enums.MessageCategory.Missions, day, where)
	msg.Type = Enums.MessageType.Repair
	EventBus.Tell(u.Faction, msg)
