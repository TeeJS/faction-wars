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
	## Who fought, for the Assault Summary window (manual p123, Figs 3.66-3.67):
	## the sides (Defender null for a neutral system), the fleet, and each
	## side's forces by the window's six tabs.
	var Attacker: Faction
	var Defender: Faction
	var Fleet: Fleet
	var AttackerForces := FleetBattleManager.Casualties.new()
	var DefenderForces := FleetBattleManager.Casualties.new()


## "...at least two planetary shields" greys the option out (p123; entry 151).
static func CanAssault(fleet: Fleet, target: Planet) -> Result:
	if fleet == null or target == null:
		return Result.fail("Nothing to assault.")
	if fleet.Status == Enums.Status.Enroute:
		return Result.fail("The fleet is %s." % Terms.label("in_transit"))
	if fleet.Attached != target:
		return Result.fail("The fleet is not in orbit above %s." % target.Name)
	if target.ControllingFaction == fleet.Faction:
		return Result.fail("%s is already ours." % target.Name)
	if LandingForce(fleet).is_empty():
		return Result.fail("The fleet carries no %s." % Terms.lower("trooper_regiments"))
	var shields := target.CountByRole("shield")
	var needed := RuleManager.Get(RuleId.ShieldsToPreventAssault, fleet.Faction)
	if needed > 0 and shields >= needed:
		return Result.fail("%s is defended by %d %s. Bombard or sabotage them first." % [target.Name, shields, Terms.lower("planetary_shields")])
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
	report.Attacker = attacker
	report.Defender = defender
	report.Fleet = fleet
	Forces(report, fleet, target, attackers, attacker_alive, defenders, defender_alive)

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

		if previous != null and target.CountOf("headquarters") > 0:
			for i in range(target.Facilities.size() - 1, -1, -1):
				if target.Facilities[i].HasRole("headquarters"):
					target.Facilities.remove_at(i)
			VictoryManager.HeadquartersDestroyed(previous)
	else:
		print("[Assault] %s held after %d rounds (%d regiments remain)." % [target.Name, report.Steps, report.DefendersRemaining])

	Announce(report, fleet, attacker, defender, day)
	# The side that ordered it sees the Assault Summary at once (manual p123);
	# UIManager shows it only to that side's own client.
	if attacker != null and GameSettings.IsHuman(attacker):
		FleetBattleManager.AddUnreported(report)
	EventBus.BroadcastChanged()
	return report


## Each side's forces by the Assault Summary's tabs. The fleet's ships and
## fighters are only in orbit - the batteries fire at the troops landing, so
## they stay operational; the regiments as the contest left them; the world's
## facilities, manufacturing or defensive by their roles (as Planet sorts a new
## one's message); everyone aboard the fleet or on the world, alive.
static func Forces(r: AssaultReport, fleet: Fleet, target: Planet, attackers: Array, attacker_alive: Array,
		defenders: Array, defender_alive: Array) -> void:
	var a := r.AttackerForces
	for s in fleet.Ships:
		if s == null:
			continue
		if s.Type == Enums.UnitType.CapitalShip:
			a.add("CapitalShipsOperational", s.Name, "units", s.PackId, false)
		for h in s.Hangar:
			if h != null and h.Type == Enums.UnitType.Fighter:
				a.add("SquadronsOperational", h.Name, "units", h.PackId, false)
	for u in attackers:
		a.add("TroopsOperational" if attacker_alive.has(u) else "TroopsDestroyed", u.Name, "units", u.PackId, false)
	var d := r.DefenderForces
	for u in target.Garrison:
		if u == null or defenders.has(u):
			continue
		if u.Type == Enums.UnitType.CapitalShip:
			d.add("CapitalShipsOperational", u.Name, "units", u.PackId, false)
		elif u.Type == Enums.UnitType.Fighter:
			d.add("SquadronsOperational", u.Name, "units", u.PackId, false)
	for f in target.Facilities:
		var defensive: bool = f.HasRole("planet_defense") or f.HasRole("shield") or f.HasRole("anti_ship") or f.HasRole("disable")
		# A captured world's headquarters is destroyed (Resolve removes it).
		var lost: bool = r.Captured and r.Defender != null and f.HasRole("headquarters")
		d.add(("Defense" if defensive else "Manufacturing") + ("Destroyed" if lost else "Operational"), f.Name(), "facilities", f.TypeId(), f.IsDamaged)
	for u in defenders:
		d.add("TroopsOperational" if defender_alive.has(u) else "TroopsDestroyed", u.Name, "units", u.PackId, false)
	for c in GameState.ActiveRoster:
		if c.Status == Enums.Status.Dead:
			continue
		var into: FleetBattleManager.Casualties = null
		if c.Attached == fleet:
			into = a
		elif c.Attached == target and c.Faction == r.Defender:
			into = d
		if into != null:
			into.add("PersonnelSurvivors", c.Name if c.Rank == Enums.Rank.None else "%s %s" % [JsonUtil.enum_name(Enums.Rank, c.Rank), c.Name],
				"characters", c.PackId, false)


## The Assault Summary's sentence, in the original's words (TEXTSTRA.DLL
## 0xF67E-0xF76E): "Imperial troops have taken control of the Alliance system
## Ghorman" (TeeJ's screenshot and manual p123 Fig 3.66, matched to the pixel),
## "<side> Troops have defended <system> from an <side> assault.", and the
## neutral system's two. The original's "from an" is for its two sides, both
## vowels; another pack's side gets "a" before a consonant.
static func Sentence(r: AssaultReport) -> String:
	var world: String = r.Target.Name
	var att: String = Adjective(r.Attacker)
	if r.Defender == null:
		if r.Captured:
			return "%s troops have seized control of the neutral system %s" % [att, world]
		return "The neutral system %s has repulsed an attack by %s troops." % [world, att]
	if r.Captured:
		return "%s troops have taken control of the %s system %s" % [att, Adjective(r.Defender), world]
	var article: String = "an" if "AEIOUaeiou".contains(att.left(1)) else "a"
	return "%s Troops have defended %s from %s %s assault." % [Adjective(r.Defender), world, article, att]


static func Adjective(f: Faction) -> String:
	if f == null:
		return "Neutral"
	return f.Adjective if not f.Adjective.is_empty() else f.DisplayName


## "An Assault Summary window ... also available as a message when your opponent
## assaults one of your systems" (manual p123). The message is titled as the
## window ("Assault on |", TEXTSTRA.DLL 0xF664; TeeJ's screenshot of the
## original's Conflict Messages, 2026-09-26) and opening it opens the window.
static func Announce(r: AssaultReport, _fleet: Fleet, attacker: Faction, defender: Faction, day: int) -> void:
	var body := "%s\n\n%d rounds.\nAttacking regiments lost: %d%s\nDefending regiments lost: %d" % [
		Sentence(r), r.Steps, r.AttackerLost.size(),
		(" (%d to defensive batteries)" % r.LostToBatteries.size()) if not r.LostToBatteries.is_empty() else "",
		r.DefenderLost.size()]
	for side in [attacker, defender]:
		if side == null or not GameSettings.IsHuman(side):
			continue
		var msg := GameMessage.new("Assault on %s" % r.Target.Name, body, Enums.MessageCategory.Conflict, day, r.Target)
		msg.Report = r
		EventBus.Tell(side, msg)
