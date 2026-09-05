class_name OrderManager
extends RefCounted
## backend/OrderManager.cs - ISSUING A MOVE ORDER. The whole cascade - fleet to
## its ships, ships to their hangar payloads, and the personnel riding the fleet -
## plus the slowest-hyperdrive calculation and the blockade-running losses. Game
## state only; confirmation dialogs stay in the UI.


# --- TRAVEL TIME ---

## Slowest ship governs, and slowest is the HIGHEST rating; 0 = unshipped.
static func SlowestHyperdrive(units: Array) -> int:
	var slowest := 0
	for u in units:
		if u.Hyperdrive > slowest:
			slowest = u.Hyperdrive
	return slowest


static func FleetTravelDays(fleets: Array, from: Planet, to: Planet) -> int:
	var ships := []
	for f in fleets:
		if f.Status != Enums.Status.Enroute:
			for s in f.Ships:
				ships.append(s)
	return from.TravelDaysTo(to, SlowestHyperdrive(ships))


static func UnitTravelDays(units: Array, from: Location, to: Planet) -> int:
	if from is Planet:
		return (from as Planet).TravelDaysTo(to, SlowestHyperdrive(units))
	return 1


## "MILLENNIUM FALCON EFFECT: Han travelling alone or with characters, not aboard
## a ship - travels twice as fast" (manual p094).
static func CharacterTravelDays(characters: Array, from: Planet, to: Planet) -> int:
	var falcon := Lq.any(characters, func(c): return c.Name == "Han Solo") \
		and Lq.all(characters, func(c): return c is Character)
	var travelling: Faction = characters[0].Faction if not characters.is_empty() else null
	var speed := Planet.HanSoloTravelSpeed(travelling) if falcon else Planet.StandardTravelSpeed(travelling)
	return from.TravelDaysTo(to, 0, speed)


# --- THE ORDERS --- each returns a Result; value = days where C# had `out days`.

static func MoveFleets(fleets: Array, destination: Planet) -> Result:
	var free: Fleet = Lq.first_or_null(fleets, func(f): return f.Status != Enums.Status.Enroute) if fleets != null else null
	var from: Planet = free.Attached if free != null else null
	if from == null:
		return Result.fail("Nothing here is free to move.", 0)
	if destination == null:
		return Result.fail("No destination.", 0)
	if from == destination:
		return Result.fail("Already at %s." % destination.Name, 0)
	var days := FleetTravelDays(fleets, from, destination)
	var ok := Transit(fleets, from, destination, days, CascadeFleetPayloads(destination))
	return Result.success(days) if ok else Result.fail("", days)


static func MoveUnits(units: Array, destination: Planet) -> Result:
	var free: Unit = Lq.first_or_null(units, func(u): return u.Status != Enums.Status.Enroute) if units != null else null
	var from: Location = free.Attached if free != null else null
	if from == null:
		return Result.fail("Nothing here is free to move.", 0)
	if destination == null:
		return Result.fail("No destination.", 0)

	# SPECFORCES ARE PERSONNEL AND CARRY THE SAME RESTRICTION as characters (p126).
	var blocked: Unit = Lq.first_or_null(units, func(u): return u.Type == Enums.UnitType.SpecForce and destination.ControllingFaction != u.Faction)
	if blocked != null:
		return Result.fail("%s is not under your control - personnel can only be moved to worlds your side holds." % destination.Name, 0)

	# A UNIT RIDING A FLEET COMES OFF IT FIRST.
	if from is Fleet:
		var riding := from as Fleet
		var orbit := SystemOf(riding)
		if orbit == null:
			return Result.fail("%s is not in orbit anywhere." % riding.Name, 0)
		var unloaded := UnloadUnits(units)
		if not unloaded.ok:
			return Result.fail(unloaded.error, 0)
		if orbit == destination:
			return Result.success(0)
		from = orbit

	if from == destination:
		return Result.fail("Already at %s." % destination.Name, 0)

	var days := UnitTravelDays(units, from, destination)
	var ok := Transit(units, from, destination, days)
	return Result.success(days) if ok else Result.fail("", days)


## WHICH SYSTEM IS THIS THING AT? A planet is its own answer; a fleet is at the
## world it orbits.
static func SystemOf(where: Location) -> Planet:
	if where is Planet:
		return where
	if where is Fleet:
		return (where as Fleet).Attached
	return null


## WHICH FLEET DID THE PLAYER MEAN? A fleet, or any capital ship in it.
static func FleetOf(picked: Variant) -> Fleet:
	if picked is Fleet:
		return picked
	if picked is Unit and (picked as Unit).Attached is Planet:
		var orbit: Planet = (picked as Unit).Attached
		return Lq.first_or_null(orbit.OrbitingFleets, func(fl): return fl.Ships.has(picked))
	return null


static func MoveCharacters(characters: Array, destination: Planet) -> Result:
	var lead: Character = Lq.first_or_null(characters, func(c): return c.Status != Enums.Status.Enroute) if characters != null else null
	var from := SystemOf(lead.Attached) if lead != null else null
	if from == null:
		return Result.fail("Nobody here is free to move.", 0)
	if destination == null:
		return Result.fail("No destination.", 0)

	# ★ A MOVE ONLY EVER GOES TO A WORLD YOUR SIDE CONTROLS (measured).
	if destination.ControllingFaction != lead.Faction:
		return Result.fail("%s is not under your control - personnel can only be moved to worlds your side holds." % destination.Name, 0)

	# ALREADY IN THAT ORBIT MEANS WALK OFF THE SHIP.
	if from == destination:
		if lead.Attached is Fleet:
			var d := Disembark(characters)
			return Result.success(0) if d.ok else Result.fail(d.error, 0)
		return Result.fail("Already at %s." % destination.Name, 0)

	var days := CharacterTravelDays(characters, from, destination)
	var ok := Transit(characters, from, destination, days)
	return Result.success(days) if ok else Result.fail("", days)


## HQ RELOCATION — the Alliance may move its headquarters to another world it holds
## (manual p090 / GAMEPLAY.md:2996-2998, Fig 3.82; guide Ch2/4/9/11/10). A blockade on
## the current seat PINS it — the Imperial kill chain's whole point (GAMEPLAY.md:3078-3087).
## It costs a small loyalty drop on the world it leaves (manual p090): the system loses
## the HQ's support magnitude (entry 174). Only a faction whose HqDef is Movable (the
## Alliance's hidden HQ) may relocate; the Empire's fixed Coruscant seat cannot.
static func MoveHeadquarters(faction: Faction, destination: Planet) -> Result:
	if faction == null or faction.Hq == null or not faction.Hq.Movable:
		return Result.fail("This headquarters cannot be relocated.")
	if destination == null:
		return Result.fail("No destination.")
	var seat: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p): return p.HasHeadquarters() and p.ControllingFaction == faction)
	if seat == null:
		return Result.fail("There is no headquarters to move.")
	if seat == destination:
		return Result.fail("The headquarters is already at %s." % destination.Name)
	if destination.ControllingFaction != faction:
		return Result.fail("%s is not under your control - the headquarters can only move to a world your side holds." % destination.Name)
	if BlockadeManager.IsBlockaded(seat):
		return Result.fail("%s is blockaded - the headquarters cannot relocate until the blockade is broken." % seat.Name)

	for i in range(seat.Facilities.size() - 1, -1, -1):
		if seat.Facilities[i].Type == Enums.FacilityType.Headquarters:
			seat.Facilities.remove_at(i)
	destination.AddFacility(Enums.FacilityType.Headquarters)
	# The new seat is concealed from other sides for a hidden HQ; a side always knows its own.
	for other in FactionRegistry.Playable:
		destination.SetExplored(other, other == faction or not faction.HasHiddenHq())
	# A small loyalty drop on the world it left (manual p090).
	seat.ShiftSupport(faction, -RuleManager.Get(RuleId.AllianceHqSupportShift, faction))
	print("[HQ] %s relocated its headquarters from %s to %s." % [faction.DisplayName, seat.Name, destination.Name])
	EventBus.BroadcastChanged()
	return Result.success()


## BOARDING A FLEET. "A CHARACTER ON A SHIP HAS THAT SHIP AS THEIR BASE" (p115).
static func BoardFleet(characters: Array, fleet: Fleet) -> Result:
	if fleet == null:
		return Result.fail("No fleet.")
	if characters == null or characters.is_empty():
		return Result.fail("Nobody selected.")
	if fleet.Status == Enums.Status.Enroute:
		return Result.fail("%s is in hyperspace." % fleet.Name)
	var orbit: Planet = fleet.Attached
	if orbit == null:
		return Result.fail("%s is not in orbit anywhere." % fleet.Name)
	var boarding := Lq.where(characters, func(c): return c.Status != Enums.Status.Enroute and not c.IsCaptured() and not c.IsOffMap())
	if boarding.is_empty():
		return Result.fail("Nobody here is free to move.")
	for c in boarding:
		if c.Faction != fleet.Faction:
			return Result.fail("%s cannot board another side's fleet." % c.Name)
		if c.Attached != orbit and c.Attached != fleet:
			return Result.fail("%s is not at %s." % [c.Name, orbit.Name])
	for c in boarding:
		c.Attached = fleet
		c.Destination = null
		c.DaysToDestination = 0
		c.Status = Enums.Status.AwaitingOrders
		print("%s boards %s at %s." % [c.Name, fleet.Name, orbit.Name])
	EventBus.BroadcastChanged()
	return Result.success()


## LOADING TROOPS AND FIGHTERS ABOARD. value = how many went aboard.
static func LoadAboard(units: Array, fleet: Fleet) -> Result:
	if fleet == null:
		return Result.fail("No fleet.", 0)
	if fleet.Status == Enums.Status.Enroute:
		return Result.fail("%s is in hyperspace." % fleet.Name, 0)
	if not (fleet.Attached is Planet):
		return Result.fail("%s is not in orbit." % fleet.Name, 0)
	var orbit: Planet = fleet.Attached
	if units == null or units.is_empty():
		return Result.fail("Nothing selected.", 0)

	var loaded := 0
	var error := ""
	for u in units:
		if u.Type != Enums.UnitType.Troop and u.Type != Enums.UnitType.Fighter:
			continue
		if u.Faction != fleet.Faction:
			continue
		if u.Status == Enums.Status.Enroute:
			continue
		if u.Attached != orbit:
			continue
		var berth: Unit = Lq.first_or_null(fleet.Ships, func(s): return HasRoomFor(s, u.Type))
		if berth == null:
			error = "%s has no room left." % fleet.Name
			break
		orbit.Garrison.erase(u)
		orbit.FighterSquadrons.erase(u)
		berth.Hangar.append(u)
		u.Attached = fleet
		loaded += 1

	if loaded > 0:
		print("%d unit(s) loaded aboard %s at %s." % [loaded, fleet.Name, orbit.Name])
		EventBus.BroadcastChanged()
	elif error.is_empty():
		error = "Nothing there could be loaded."
	return Result.success(loaded) if error.is_empty() else Result.fail(error, loaded)


static func HasRoomFor(ship: Unit, kind: int) -> bool:
	var cap := ship.FighterCapacity if kind == Enums.UnitType.Fighter else ship.TroopCapacity
	var aboard := Lq.count(ship.Hangar, func(h): return h.Type == kind)
	return aboard < cap


## Put them back on the world the fleet is orbiting. value = how many came off.
static func Unload(fleet: Fleet) -> Result:
	if fleet == null:
		return Result.fail("No fleet.", 0)
	if not (fleet.Attached is Planet):
		return Result.fail("%s is not in orbit." % fleet.Name, 0)
	var orbit: Planet = fleet.Attached
	var off := 0
	for ship in fleet.Ships:
		for u in ship.Hangar.duplicate():
			ship.Hangar.erase(u)
			u.Attached = orbit
			if u.Type == Enums.UnitType.Fighter:
				orbit.FighterSquadrons.append(u)
			else:
				orbit.Garrison.append(u)
			off += 1
	if off > 0:
		EventBus.BroadcastChanged()
	return Result.success(off)


## NAMED UNITS OFF THE SHIPS CARRYING THEM.
static func UnloadUnits(units: Array) -> Result:
	var riding := Lq.where(units, func(u): return u.Attached is Fleet) if units != null else []
	if riding.is_empty():
		return Result.fail("Nothing is aboard a fleet.")
	for u in riding:
		var fleet: Fleet = u.Attached
		if fleet.Status == Enums.Status.Enroute:
			return Result.fail("%s is in hyperspace." % fleet.Name)
		if not (fleet.Attached is Planet):
			return Result.fail("%s is not in orbit anywhere." % fleet.Name)
		var orbit: Planet = fleet.Attached
		for ship in fleet.Ships:
			ship.Hangar.erase(u)
		u.Attached = orbit
		u.Status = Enums.Status.AwaitingOrders
		if u.Type == Enums.UnitType.Fighter:
			orbit.FighterSquadrons.append(u)
		else:
			orbit.Garrison.append(u)
		print("%s unloads from %s at %s." % [u.Name, fleet.Name, orbit.Name])
	EventBus.BroadcastChanged()
	return Result.success()


## And back off again, onto the world the fleet is orbiting.
static func Disembark(characters: Array) -> Result:
	var leaving := Lq.where(characters, func(c): return c.Attached is Fleet) if characters != null else []
	if leaving.is_empty():
		return Result.fail("Nobody is aboard a fleet.")
	for c in leaving:
		var from: Fleet = c.Attached
		if from.Status == Enums.Status.Enroute:
			return Result.fail("%s is in hyperspace." % from.Name)
		if not (from.Attached is Planet):
			return Result.fail("%s is not in orbit anywhere." % from.Name)
		var orbit: Planet = from.Attached
		c.Attached = orbit
		c.Status = Enums.Status.AwaitingOrders
		print("%s disembarks from %s at %s." % [c.Name, from.Name, orbit.Name])
	EventBus.BroadcastChanged()
	return Result.success()


# --- THE CASCADE ---

## Moves the entities (fleets, units or characters) and everything riding on them.
static func Transit(entities: Array, from: Location, to: Location, days: int, cascade: Callable = Callable()) -> bool:
	if entities == null or entities.is_empty():
		return false
	var moving := Lq.where(entities, func(e): return e.Status != Enums.Status.Enroute)
	if moving.is_empty() or from == null or from == to:
		return false

	var dep_planet: Planet = from if from is Planet else null
	var dest_planet: Planet = to if to is Planet else null

	for entity in moving:
		entity.Destination = dest_planet
		entity.DaysToDestination = max(1, days)
		entity.Status = Enums.Status.Enroute

		if entity is Fleet and dep_planet != null and dest_planet != null:
			var f := entity as Fleet
			dep_planet.OrbitingFleets.erase(f)
			dest_planet.OrbitingFleets.append(f)
			f.Attached = dest_planet
		elif entity is Unit and not (entity is Character) and dep_planet != null and dest_planet != null:
			var u := entity as Unit
			if u.Type == Enums.UnitType.Troop or u.Type == Enums.UnitType.SpecForce:
				dep_planet.Garrison.erase(u)
				dest_planet.Garrison.append(u)
			elif u.Type == Enums.UnitType.Fighter:
				dep_planet.FighterSquadrons.erase(u)
				dest_planet.FighterSquadrons.append(u)
			u.Attached = dest_planet
		elif entity is Character and dest_planet != null:
			(entity as Character).Attached = dest_planet

		print("%s departs for %s. ETA: %d days." % [entity.Name, to.Name, entity.DaysToDestination])

	if cascade.is_valid():
		cascade.call(moving)
	return true


## A fleet carries its ships, their hangar payloads, and its personnel.
static func CascadeFleetPayloads(destination: Location) -> Callable:
	return func(fleets: Array) -> void:
		for fleet in fleets:
			for ship in fleet.Ships:
				ship.Status = Enums.Status.Enroute
				ship.Destination = destination
				ship.DaysToDestination = fleet.DaysToDestination
				ship.Attached = destination
				for payload in ship.Hangar:
					payload.Status = Enums.Status.Enroute
					payload.Destination = destination
					payload.DaysToDestination = fleet.DaysToDestination
					payload.Attached = destination
			# Riders keep the FLEET as their anchor; Destination stays null.
			for p in GameState.ActiveRoster:
				if p.Attached != fleet:
					continue
				p.Status = Enums.Status.Enroute
				p.Destination = null
				p.DaysToDestination = fleet.DaysToDestination


# --- RUNNING A BLOCKADE --- "Troops attempting to move MAY BE KILLED" (p124).

## Returns the survivors, having already removed the losses and filed the report.
static func RunBlockade(units: Array, from: Planet, rng: Prng) -> Array:
	var survivors := []
	var lost := []
	for u in units:
		if BlockadeManager.SurvivesLeaving(from, u, rng):
			survivors.append(u)
			continue
		lost.append(u.Name)
		from.Garrison.erase(u)
		from.FighterSquadrons.erase(u)
	if not lost.is_empty():
		var msg := GameMessage.new("Evacuation Losses",
			"The following units were lost running an enemy blockade of %s:\n\n  %s" % [from.Name, "\n  ".join(lost)],
			Enums.MessageCategory.Missions, StrategicTickManager.Today, from)
		msg.Type = Enums.MessageType.EvacuationLosses
		EventBus.BroadcastMessage(msg)
	return survivors


static func MustRunBlockade(from: Location, units: Array) -> bool:
	return from is Planet and BlockadeManager.IsBlockaded(from) \
		and Lq.any(units, func(u): return u.Type == Enums.UnitType.Troop)
