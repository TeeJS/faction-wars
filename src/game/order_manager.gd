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
	var falcon := Lq.any(characters, func(c): return c.HasRole("smuggler")) \
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
	# A unit already standing on the destination needs nothing: a regiment
	# landed a moment ago can still be among those picked, and it must not turn
	# the rest's landing into "Already at" (TeeJ, 2026-09-27, the Coruscant
	# fleet's troops). Only when nothing is left to move is that the answer.
	if units != null and destination != null:
		var needed: Array = Lq.where(units, func(u): return not (u.Attached == destination and CarrierOf(u) == null))
		if needed.is_empty() and not units.is_empty():
			return Result.fail("Already at %s." % destination.Name, 0)
		units = needed
	var free: Unit = Lq.first_or_null(units, func(u): return u.Status != Enums.Status.Enroute) if units != null else null
	var from: Location = free.Attached if free != null else null
	if from == null:
		return Result.fail("Nothing here is free to move.", 0)
	if destination == null:
		return Result.fail("No destination.", 0)

	# SPECFORCES ARE PERSONNEL AND CARRY THE SAME RESTRICTION as characters (p126).
	var blocked: Unit = Lq.first_or_null(units, func(u): return u.Type == Enums.UnitType.SpecForce and destination.ControllingFaction != u.Faction)
	if blocked != null:
		return Result.fail("%s is not under your control - personnel can only be moved to worlds your side holds." % destination.Name, 0).coded("not_controlled")

	# A UNIT RIDING A FLEET COMES OFF IT FIRST - dropped on the world below, it
	# lands there ("drag them onto the system, or right-click -> Move", manual
	# p120). Found by the hangar it is in, not by its Attached (CarrierOf).
	var carrier: Fleet = CarrierOf(free)
	if carrier != null:
		var orbit := SystemOf(carrier)
		if orbit == null:
			return Result.fail("%s is not in orbit anywhere." % carrier.Name, 0)
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


## WHICH FLEET IS CARRYING THIS UNIT? The one with it in a ship's hangar. A
## payload's Attached names the fleet only after LoadAboard: at day zero and
## after its fleet has moved it names the SYSTEM (DayZeroGenerator,
## CascadeFleetPayloads), so the hangars of the fleets there are searched, as
## MissionManager does for a team leaving a fleet. Null when not aboard.
static func CarrierOf(u: Unit) -> Fleet:
	if u == null:
		return null
	if u.Attached is Fleet:
		return u.Attached
	var orbit := SystemOf(u.Attached)
	if orbit == null:
		return null
	for f in orbit.OrbitingFleets:
		for ship in f.Ships:
			if ship.Hangar.has(u):
				return f
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
		return Result.fail("%s is not under your control - personnel can only be moved to worlds your side holds." % destination.Name, 0).coded("not_controlled")

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
		return Result.fail("%s is not under your control - the headquarters can only move to a world your side holds." % destination.Name).coded("not_controlled")
	if BlockadeManager.IsBlockaded(seat):
		return Result.fail("%s is blockaded - the headquarters cannot relocate until the blockade is broken." % seat.Name)

	for i in range(seat.Facilities.size() - 1, -1, -1):
		if seat.Facilities[i].HasRole("headquarters"):
			seat.Facilities.remove_at(i)
	destination.AddFacility("headquarters")
	# The new seat is concealed from other sides for a hidden HQ; a side always knows its own.
	for other in FactionRegistry.Playable:
		destination.SetExplored(other, other == faction or not faction.HasHiddenHq())
	# A small loyalty drop on the world it left (manual p090).
	seat.ShiftSupport(faction, -RuleManager.Get(RuleId.HiddenHqSupportShift, faction))
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
		return Result.fail("%s is %s." % [fleet.Name, Terms.label("in_transit")]).coded("in_transit")
	var orbit: Planet = fleet.Attached
	if orbit == null:
		return Result.fail("%s is not in orbit anywhere." % fleet.Name)
	var boarding := Lq.where(characters, func(c): return c.Status != Enums.Status.Enroute and not c.IsCaptured() and not c.IsOffMap())
	if boarding.is_empty():
		return Result.fail("Nobody here is free to move.")
	for c in boarding:
		if c.Faction != fleet.Faction:
			return Result.fail("%s cannot board another side's fleet." % c.Name)
		if c.Attached != fleet and SystemOf(c.Attached) == null:
			return Result.fail("%s is nowhere to leave from." % c.Name)
	# FROM ANOTHER SYSTEM THEY TRAVEL TO IT: "move that character onto the fleet
	# as well. It will take the characters some time to get to the fleet, and
	# significantly longer if they are traveling between sectors" (manual
	# p046). Together, as a move is (the Millennium Falcon effect with it);
	# aboard - Attached to it - on the way, and there on arrival (the day's
	# tick); a fleet gone by then, they fall back to a world their side holds.
	var far: Array = Lq.where(boarding, func(c): return c.Attached != fleet and SystemOf(c.Attached) != orbit)
	var by_origin := {}
	for c in far:
		var from: Planet = SystemOf(c.Attached)
		if not by_origin.has(from):
			by_origin[from] = []
		by_origin[from].append(c)
	for from in by_origin:
		var group: Array = by_origin[from]
		var days: int = maxi(1, CharacterTravelDays(group, from, orbit))
		for c in group:
			c.Attached = fleet
			c.Destination = fleet
			c.DaysToDestination = days
			c.Status = Enums.Status.Enroute
			print("%s leaves %s to join %s at %s. ETA: %d days." % [c.Name, from.Name, fleet.Name, orbit.Name, days])
	for c in boarding:
		if far.has(c):
			continue
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
		return Result.fail("%s is %s." % [fleet.Name, Terms.label("in_transit")], 0).coded("in_transit")
	if not (fleet.Attached is Planet):
		return Result.fail("%s is not in orbit." % fleet.Name, 0)
	var orbit: Planet = fleet.Attached
	if units == null or units.is_empty():
		return Result.fail("Nothing selected.", 0)

	# CAPITAL SHIPS JOIN THE FLEET ITSELF, not a hangar: "Drag ships or troops
	# between fleets in the open Fleet display" (manual p120), and from
	# another system p122 (MoveShipsToFleet).
	var ships: Array = Lq.where(units, func(u): return u.Type == Enums.UnitType.CapitalShip)
	if not ships.is_empty():
		var moved: Result = MoveShipsToFleet(ships, fleet)
		units = Lq.where(units, func(u): return u.Type != Enums.UnitType.CapitalShip)
		if units.is_empty():
			return moved

	# Troops leaving a blockaded world for a fleet elsewhere run the blockade,
	# as any evacuation does ("Troops attempting to move MAY BE KILLED",
	# manual p124; the player is asked first, UIManager.ExecuteLoadAboard).
	var going: Array = []
	var by_origin := {}
	for u in units:
		var here: Planet = _SystemOfUnit(u)
		if here != null and here != orbit and u.Status != Enums.Status.Enroute and MustRunBlockade(here, [u]):
			if not by_origin.has(here):
				by_origin[here] = []
			by_origin[here].append(u)
		else:
			going.append(u)
	for here in by_origin:
		going.append_array(RunBlockade(by_origin[here], here, Prng.Session))

	var loaded := 0
	var error := ""
	for u in going:
		if u.Type != Enums.UnitType.Troop and u.Type != Enums.UnitType.Fighter:
			continue
		if u.Faction != fleet.Faction:
			continue
		if u.Status == Enums.Status.Enroute:
			continue
		# From the world below, or from another fleet in the same orbit:
		# "Drag ships or troops between fleets" (manual p120).
		var carrier: Fleet = CarrierOf(u)
		if carrier == fleet:
			continue   # already aboard this one
		if carrier != null and carrier.Status == Enums.Status.Enroute:
			continue
		var here: Planet = _SystemOfUnit(u)
		if here == null:
			continue
		var berth: Unit = Lq.first_or_null(fleet.Ships, func(s): return HasRoomFor(s, u.Type))
		if berth == null:
			error = "%s has no room left." % fleet.Name
			break
		if carrier != null:
			for ship in carrier.Ships:
				ship.Hangar.erase(u)
		here.Garrison.erase(u)
		here.FighterSquadrons.erase(u)
		berth.Hangar.append(u)
		u.Attached = fleet
		if here != orbit:
			# FROM ANOTHER SYSTEM: "If you move a ship onto a fleet in a different
			# sector, that ship will immediately be considered a member of the
			# fleet but will still be in hyperspace for several days until it
			# arrives" (manual p122) - a regiment or squadron the same way (TeeJ,
			# 2026-09-27: the fleet "is not taking troops, even though it can hold
			# 2"). Its berth is taken at once; it is not there - to land, fight
			# or blockade - until it arrives (Inbound; the day's tick).
			u.Destination = fleet
			u.DaysToDestination = maxi(1, UnitTravelDays([u], here, orbit))
			u.Status = Enums.Status.Enroute
			print("%s leaves %s to join %s at %s. ETA: %d days." % [u.Name, here.Name, fleet.Name, orbit.Name, u.DaysToDestination])
		loaded += 1

	if loaded > 0:
		print("%d unit(s) loaded aboard %s at %s." % [loaded, fleet.Name, orbit.Name])
		EventBus.BroadcastChanged()
	elif error.is_empty():
		error = "Nothing there could be loaded."
	return Result.success(loaded) if error.is_empty() else Result.fail(error, loaded)


## THE FLEET A CAPITAL SHIP BELONGS TO, wherever it orbits; null if none.
static func FleetOfShip(ship: Unit) -> Fleet:
	if ship == null:
		return null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if f.Ships.has(ship):
				return f
	return null


## SHIPS INTO A NEW FLEET where they orbit (all at one system, free to
## move): out of their fleets, a fleet left with no ship disbanded ("If you
## move all the ships out of a fleet, the fleet is automatically disbanded",
## manual p120) and the people aboard it going with the ships. The whole of
## one fleet is that fleet. `name` names it (a transit fleet takes its
## target's); a new name otherwise.
static func _ShipsIntoFleetHere(ships: Array, name: String = "") -> Fleet:
	var sources: Array = []
	for s in ships:
		var f: Fleet = FleetOfShip(s)
		if f == null or f.Status == Enums.Status.Enroute or s.Status == Enums.Status.Enroute:
			return null
		if not sources.has(f):
			sources.append(f)
	var orbit: Planet = sources[0].Attached if not sources.is_empty() else null
	if orbit == null or Lq.any(sources, func(f: Fleet) -> bool: return f.Attached != orbit):
		return null
	if sources.size() == 1 and sources[0].Ships.size() == ships.size() and name.is_empty():
		return sources[0]
	var fleet := Fleet.new()
	fleet.ID = Fleet.IdFor(Fleet.NextSerial())
	fleet.Faction = sources[0].Faction
	fleet.Name = name if not name.is_empty() else Fleet.NextName(fleet.Faction)
	fleet.Attached = orbit
	fleet.Status = Enums.Status.AwaitingOrders
	orbit.OrbitingFleets.append(fleet)
	for s in ships:
		FleetOfShip(s).Ships.erase(s)
		fleet.AddShip(s)
	_Disband(sources, fleet)
	return fleet


## Fleets left with no ship go, the people aboard moving to `heir` - those on
## their way to them too.
static func _Disband(fleets: Array, heir: Fleet) -> void:
	for f in fleets:
		if not f.Ships.is_empty():
			continue
		for c in GameState.ActiveRoster:
			if c.Attached == f:
				c.Attached = heir
			if c.Destination == f:
				c.Destination = heir
		if f.Attached != null:
			f.Attached.OrbitingFleets.erase(f)
		print("%s disbanded: its ships have gone to other fleets." % f.Name)


## CREATE FLEET (a ship's menu, manual p115; "Ctrl-select several first for a
## bigger one", p120): the ships picked, a new fleet where they are.
static func CreateFleet(ships: Array) -> Result:
	if ships == null or ships.is_empty():
		return Result.fail("Nothing selected.")
	var f: Fleet = _ShipsIntoFleetHere(ships)
	if f == null:
		return Result.fail("Those ships are not together and free to move.")
	EventBus.BroadcastChanged()
	return Result.success(f.Ships.size())


## A SHIP'S MOVE TO A SYSTEM (manual p115): the ships picked leave their fleet
## as a fleet of their own and go - the whole fleet when all of it is picked.
static func MoveShips(ships: Array, destination: Planet) -> Result:
	if ships == null or ships.is_empty():
		return Result.fail("Nothing selected.", 0)
	var f: Fleet = _ShipsIntoFleetHere(ships)
	if f == null:
		return Result.fail("Those ships are not together and free to move.", 0)
	return MoveFleets([f], destination)


## SHIPS ONTO ANOTHER FLEET. In the same orbit they join it at once ("Drag
## ships or troops between fleets", manual p120). From another system: "If you
## move a ship onto a fleet in a different sector, that ship will immediately
## be considered a member of the fleet but will still be in hyperspace for
## several days until it arrives" (p122) - they travel as a fleet named for
## it (JoinFleet) and fold into it on arrival. value = how many.
static func MoveShipsToFleet(ships: Array, fleet: Fleet) -> Result:
	if fleet == null:
		return Result.fail("No fleet.", 0)
	if fleet.Status == Enums.Status.Enroute:
		return Result.fail("%s is %s." % [fleet.Name, Terms.label("in_transit")], 0).coded("in_transit")
	var going: Array = Lq.where(ships, func(s): return s.Faction == fleet.Faction and s.Status != Enums.Status.Enroute \
		and not fleet.Ships.has(s) and FleetOfShip(s) != null and FleetOfShip(s).Status != Enums.Status.Enroute)
	if going.is_empty():
		return Result.fail("Nothing there could join %s." % fleet.Name, 0)
	var moved := 0
	var by_orbit := {}
	for s in going:
		var at: Planet = FleetOfShip(s).Attached
		if not by_orbit.has(at):
			by_orbit[at] = []
		by_orbit[at].append(s)
	for at in by_orbit:
		var group: Array = by_orbit[at]
		if at == fleet.Attached:
			var sources: Array = []
			for s in group:
				var f: Fleet = FleetOfShip(s)
				if not sources.has(f):
					sources.append(f)
				f.Ships.erase(s)
				fleet.AddShip(s)
			_Disband(sources, fleet)
			print("%d ship(s) join %s at %s." % [group.size(), fleet.Name, at.Name])
			moved += group.size()
			continue
		var transit: Fleet = _ShipsIntoFleetHere(group, fleet.Name)
		if transit == null:
			continue
		transit.JoinFleet = fleet
		var r: Result = MoveFleets([transit], fleet.Attached)
		if r.ok:
			print("%d ship(s) leave %s to join %s at %s. ETA: %d days." % [group.size(), at.Name, fleet.Name, fleet.Attached.Name, int(r.value)])
			moved += group.size()
	if moved > 0:
		EventBus.BroadcastChanged()
	return Result.success(moved) if moved > 0 else Result.fail("Nothing there could join %s." % fleet.Name, 0)


## The system a unit stands at: its carrier's orbit, or its own world.
static func _SystemOfUnit(u: Unit) -> Planet:
	var carrier: Fleet = CarrierOf(u)
	if carrier != null:
		return SystemOf(carrier)
	return u.Attached as Planet if u.Attached is Planet else null


## ON ITS WAY TO JOIN A FLEET: a member already, in hyperspace until it arrives
## (manual p122; LoadAboard). Not there to land, fight, blockade or bombard.
static func Inbound(u: Unit) -> bool:
	return u != null and u.Status == Enums.Status.Enroute and u.Destination is Fleet


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
			if Inbound(u):
				continue   # not here yet
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
	var riding := Lq.where(units, func(u): return CarrierOf(u) != null and not Inbound(u)) if units != null else []
	if riding.is_empty():
		return Result.fail("Nothing is aboard a fleet.")
	for u in riding:
		var fleet: Fleet = CarrierOf(u)
		if fleet.Status == Enums.Status.Enroute:
			return Result.fail("%s is %s." % [fleet.Name, Terms.label("in_transit")]).coded("in_transit")
		if not (fleet.Attached is Planet):
			return Result.fail("%s is not in orbit anywhere." % fleet.Name)
		var orbit: Planet = fleet.Attached
		for ship in fleet.Ships:
			ship.Hangar.erase(u)
		u.Attached = orbit
		u.Status = Enums.Status.AwaitingOrders
		var into: Array = orbit.FighterSquadrons if u.Type == Enums.UnitType.Fighter else orbit.Garrison
		if not into.has(u):
			into.append(u)
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
			return Result.fail("%s is %s." % [from.Name, Terms.label("in_transit")]).coded("in_transit")
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
		var carrier: Fleet = CarrierOf(u)   # lost off a ship as well as off the world
		if carrier != null:
			for ship in carrier.Ships:
				ship.Hangar.erase(u)
		from.Garrison.erase(u)
		from.FighterSquadrons.erase(u)
	if not lost.is_empty():
		var msg := GameMessage.new("Evacuation Losses",
			"The following units were lost running an enemy blockade of %s:\n\n  %s" % [from.Name, "\n  ".join(lost)],
			Enums.MessageCategory.Missions, StrategicTickManager.Today, from)
		msg.Type = Enums.MessageType.EvacuationLosses
		EventBus.Tell(units[0].Faction, msg)   # own-side only, not broadcast
	return survivors


static func MustRunBlockade(from: Location, units: Array) -> bool:
	return from is Planet and BlockadeManager.IsBlockaded(from) \
		and Lq.any(units, func(u): return u.Type == Enums.UnitType.Troop)
