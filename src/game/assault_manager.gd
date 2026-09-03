class_name AssaultManager
extends RefCounted
## backend/AssaultManager.cs - PLANETARY ASSAULT, manual p122-p123, p127, and the
## step loop read out of REBEXE.EXE 0x58C120. Phase 4 (entry 7's repeat trial)
## is NOT implemented, exactly as the source says.


class AssaultReport:
	var Target: Planet
	var Captured: bool
	var Steps: int
	var AttackerLost: Array = []
	var DefenderLost: Array = []
	var LostToBatteries: Array = []
	var AttackersRemaining: int
	var DefendersRemaining: int


## "...at least two planetary shields" greys the option out (p123; entry 151).
static func CanAssault(fleet: Fleet, target: Planet) -> Result:
	if fleet == null or target == null:
		return Result.fail("Nothing to assault.")
	if fleet.Status == Enums.Status.Enroute:
		return Result.fail("The fleet is in hyperspace.")
	if fleet.Attached != target:
		return Result.fail("The fleet is not in orbit above %s." % target.Name)
	if target.ControllingFaction == fleet.Faction:
		return Result.fail("%s is already ours." % target.Name)
	if LandingForce(fleet).is_empty():
		return Result.fail("The fleet carries no trooper regiments.")
	var shields := target.CountOf(Enums.FacilityType.PlanetaryShield)
	var needed := RuleManager.Get(RuleId.ShieldsToPreventAssault, fleet.Faction)
	if needed > 0 and shields >= needed:
		return Result.fail("%s is defended by %d planetary shields. Bombard or sabotage them first." % [target.Name, shields])
	return Result.success()


## Only trooper regiments land - riding INSIDE a hangar or as bare entries in the
## fleet's list; Distinct keeps first occurrence.
static func LandingForce(fleet: Fleet) -> Array:
	var out := []
	for s in fleet.Ships:
		for u in s.Hangar:
			if u != null and u.Type == Enums.UnitType.Troop and not out.has(u):
				out.append(u)
	for u in fleet.Ships:
		if u != null and u.Type == Enums.UnitType.Troop and not out.has(u):
			out.append(u)
	return out


static func RemoveFromFleet(fleet: Fleet, u: Unit) -> void:
	fleet.Ships.erase(u)
	for ship in fleet.Ships:
		ship.Hangar.erase(u)


## The commanding General, per side: attacker's on the FLEET, defender's on the SYSTEM.
static func GeneralLeadership(post: Location, side: Faction) -> int:
	var g: Character = Lq.first_or_null(GameState.ActiveRoster, func(c): return c.Commanding == post and c.Faction == side and c.Rank == Enums.Rank.General)
	return g.LeadershipRating if g != null else 0


static func Resolve(fleet: Fleet, target: Planet, rng: Prng, day: int) -> AssaultReport:
	var report := AssaultReport.new()
	report.Target = target

	var attackers := LandingForce(fleet)
	var defenders := Lq.where(target.Garrison, func(u): return u.Type == Enums.UnitType.Troop)

	var attacker := fleet.Faction
	var defender: Faction = target.ControllingFaction

	var att_gen := GeneralLeadership(fleet, attacker)
	var def_gen := GeneralLeadership(target, defender)

	var gen_div: int = maxi(1, RuleManager.Get(RuleId.TroopContestGeneralDiv, attacker))
	var width := RuleManager.Get(RuleId.TroopContestRandomWidth, attacker)
	var defender_max := RuleManager.Get(RuleId.TroopContestDefenderMax, attacker)
	var attacker_min := RuleManager.Get(RuleId.TroopContestAttackerMin, attacker)
	var battery_div: int = maxi(1, RuleManager.Get(RuleId.BatteryResponseDivisor, attacker))

	var attacker_slots := attackers.size()
	var defender_slots := defenders.size()
	var attacker_alive := attackers.duplicate()
	var defender_alive := defenders.duplicate()

	var guard := (attacker_slots + defender_slots) * 20 + 50

	while attacker_alive.size() > 0 and defender_alive.size() > 0 and report.Steps < guard:
		report.Steps += 1

		# --- PHASE 2: the batteries fire at whoever just landed ---
		for f in target.Facilities.duplicate():
			if attacker_alive.is_empty():
				break
			var rating: int = f.WeaponRating
			if rating <= 0:
				continue
			if rng.NextRange(1, 101) > rating / battery_div:
				continue
			var hit: Unit = attacker_alive[rng.NextRange(0, attacker_alive.size())]
			attacker_alive.erase(hit)
			report.LostToBatteries.append(hit.Name)
			report.AttackerLost.append(hit.Name)

		if attacker_alive.is_empty() or defender_alive.is_empty():
			break

		# --- PHASE 3: the troop kill contest, once per landed regiment ---
		for att in attacker_alive.duplicate():
			if defender_alive.is_empty():
				break
			if not attacker_alive.has(att):
				continue
			var slot := rng.NextRange(0, max(1, defender_slots))
			if slot >= defender_alive.size():
				continue
			var def: Unit = defender_alive[slot]
			var score: int = rng.NextRange(0, width + 1) + att.Attack + att_gen / gen_div - def.Defense - def_gen / gen_div
			if score <= defender_max:
				attacker_alive.erase(att)
				report.AttackerLost.append(att.Name)
			elif score >= attacker_min:
				defender_alive.erase(def)
				report.DefenderLost.append(def.Name)

	report.AttackersRemaining = attacker_alive.size()
	report.DefendersRemaining = defender_alive.size()
	report.Captured = attacker_alive.size() > 0 and defender_alive.is_empty()

	for lost in attackers:
		if not attacker_alive.has(lost):
			RemoveFromFleet(fleet, lost)
	for lost in defenders:
		if not defender_alive.has(lost):
			target.Garrison.erase(lost)

	if not report.AttackerLost.is_empty():
		LoyaltyManager.LostUnitsInCombat(attacker, report.AttackerLost.size())
	if not report.DefenderLost.is_empty():
		LoyaltyManager.LostUnitsInCombat(defender, report.DefenderLost.size())

	if report.Captured:
		for survivor in attacker_alive:
			RemoveFromFleet(fleet, survivor)
			survivor.Attached = target
			survivor.Status = Enums.Status.AwaitingOrders
			target.Garrison.append(survivor)

		var previous: Faction = target.ControllingFaction
		target.ControllingFaction = attacker
		target.SetExplored(attacker, true)
		MilitaryCatalog.OnControlChanged(target, previous)
		print("[Assault] %s taken by %s after %d rounds (%d regiments hold it)." % [target.Name, attacker.DisplayName, report.Steps, report.AttackersRemaining])

		if previous != null and target.CountOf(Enums.FacilityType.Headquarters) > 0:
			for i in range(target.Facilities.size() - 1, -1, -1):
				if target.Facilities[i].Type == Enums.FacilityType.Headquarters:
					target.Facilities.remove_at(i)
			VictoryManager.HeadquartersDestroyed(previous)
	else:
		print("[Assault] %s held after %d rounds (%d regiments remain)." % [target.Name, report.Steps, report.DefendersRemaining])

	Announce(report, fleet, attacker, defender, day)
	EventBus.BroadcastChanged()
	return report


## "An Assault Summary window ... also available as a message when your opponent
## assaults one of your systems" (manual p123).
static func Announce(r: AssaultReport, _fleet: Fleet, attacker: Faction, defender: Faction, day: int) -> void:
	var body := "Assault on %s - %d rounds.\n\nAttacking regiments lost: %d%s\nDefending regiments lost: %d\n\n%s" % [
		r.Target.Name, r.Steps, r.AttackerLost.size(),
		(" (%d to defensive batteries)" % r.LostToBatteries.size()) if not r.LostToBatteries.is_empty() else "",
		r.DefenderLost.size(),
		("%s has fallen. %d regiments hold it." % [r.Target.Name, r.AttackersRemaining]) if r.Captured
		else ("The assault was thrown back. %d defending regiments remain." % r.DefendersRemaining)]
	for side in [attacker, defender]:
		if side == null or not GameSettings.IsHuman(side):
			continue
		var ours: bool = side == attacker
		var title: String
		if r.Captured:
			title = ("%s captured" % r.Target.Name) if ours else ("%s lost" % r.Target.Name)
		else:
			title = ("Assault on %s failed" % r.Target.Name) if ours else ("%s held" % r.Target.Name)
		EventBus.Tell(side, GameMessage.new(title, body, Enums.MessageCategory.Conflict, day, r.Target))
