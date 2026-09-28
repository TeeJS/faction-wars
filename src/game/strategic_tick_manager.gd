class_name StrategicTickManager
extends RefCounted
## backend/StrategicTickManager.cs - one strategic day, in the source's order.
## Every subsystem is live (step 2); the order is load-bearing because the PRNG
## stream depends on it.

var CurrentDay: int = 1
## The same day, reachable without a handle on the tick manager.
static var Today: int = 1


## A day AS THE PLAYER SEES IT: the original's counter is "a number indicating
## how many days have passed since the game began" (manual p033) - 0 on the
## first day, as TeeJ saw it (2026-09-27). The game counts its first day 1
## (day 0 is the setup before it), so every day shown - the counter, a
## message's date, an arrival, a sighting, a save - is this, never the raw one.
static func Shown(day: int) -> int:
	return maxi(0, day - 1)
var _galaxy: Array[Sector]


func _init(galaxy_data: Array[Sector]) -> void:
	_galaxy = galaxy_data
	CurrentDay = 1
	Today = 1


## "Resting on a system OR FLEET you control" (manual p096).
static func RestingSomewhereFriendly(c: Character) -> bool:
	if c.Attached is Planet:
		return (c.Attached as Planet).ControllingFaction == c.Faction
	if c.Attached is Fleet:
		var f := c.Attached as Fleet
		return f.Faction == c.Faction or f.Faction == null
	return false


func AdvanceDay() -> void:
	CurrentDay += 1
	Today = CurrentDay
	var rng := Prng.Session

	# --- PROCESS CHARACTER MOVEMENT ---
	for character in GameState.ActiveRoster:
		# "HEALING REQUIRES RESTING ON A SYSTEM OR FLEET YOU CONTROL. CAPTURED
		# CHARACTERS DO NOT HEAL." (manual p096). A tick is treated as a day.
		if character.IsInjured() and not character.IsCaptured() \
				and character.Status != Enums.Status.Enroute \
				and character.Status != Enums.Status.OnMission \
				and character.Status != Enums.Status.Dead \
				and RestingSomewhereFriendly(character):
			var per_day := RuleManager.Get(RuleId.FastHealReductionPerTick, character.Faction) if character.HealsFast() else 1
			character.DaysResting += 1
			character.Injury = max(0, character.Injury - max(1, per_day))
			if not character.IsInjured():
				character.DaysResting = 0
				print("%s has recovered." % character.Name)
				var msg := GameMessage.new("%s has recovered" % character.Name,
					"%s is fit again and ready for assignment." % character.Name,
					Enums.MessageCategory.Missions, CurrentDay,
					character.Attached if character.Attached is Planet else null, character)
				msg.Type = Enums.MessageType.CharacterHealth
				msg.Voice = "recovered"
				EventBus.Tell(character.Faction, msg)   # own-side only, not broadcast
		elif not character.IsInjured():
			character.DaysResting = 0

		# A mission owns its team's travel and lands them itself.
		if MissionManager.IsOnMissionTeam(character):
			continue

		if character.Status == Enums.Status.Enroute and character.Destination != null:
			character.DaysToDestination -= 1
			if character.DaysToDestination <= 0:
				var destination := character.Destination
				# Bound for a fleet no longer in orbit anywhere (lost, or merged
				# away): the world it was over if their side holds it, else the
				# nearest that it does - where personnel stand (GAMEPLAY.md, the
				# measured rule; the refuge "NEAREST", manual p111).
				if destination is Fleet and ((destination as Fleet).Attached == null \
						or not (destination as Fleet).Attached.OrbitingFleets.has(destination)):
					var over: Planet = (destination as Fleet).Attached
					destination = over if over != null and over.ControllingFaction == character.Faction \
						else MilitaryCatalog.NearestHeldBy(character.Faction, over)
					if destination == null:
						character.DaysToDestination = 1
						continue
				character.Attached = destination
				character.Destination = null
				character.Status = Enums.Status.AwaitingOrders
				print("%s has arrived at %s!" % [character.Name, character.Attached.Name])
				var msg := GameMessage.new("%s Arrives" % character.Name,
					"%s has successfully completed transit and safely arrived at %s. They are currently awaiting new orders." % [character.Name, destination.Name],
					Enums.MessageCategory.Missions, CurrentDay, destination, character)
				msg.Type = Enums.MessageType.PersonnelArrive
				msg.Advisor = "personnel_report"
				msg.Voice = "personnel_arrived"
				EventBus.Tell(character.Faction, msg)   # own-side only, not broadcast

	# --- PROCESS UNIT MOVEMENT --- collected first and moved after.
	var arriving: Array[Unit] = []
	for sector in _galaxy:
		for planet in sector.Planets:
			for u in planet.Garrison:
				if u.Status == Enums.Status.Enroute and u.Destination != null and not MissionManager.IsOnMissionTeam(u):
					u.DaysToDestination -= 1
					if u.DaysToDestination <= 0:
						arriving.append(u)
			for u in planet.FighterSquadrons:
				if u.Status == Enums.Status.Enroute and u.Destination != null and not MissionManager.IsOnMissionTeam(u):
					u.DaysToDestination -= 1
					if u.DaysToDestination <= 0:
						arriving.append(u)

	for u in arriving:
		var destination := u.Destination
		u.Destination = null
		u.DaysToDestination = 0
		u.Status = Enums.Status.AwaitingOrders
		if destination is Planet:
			MilitaryCatalog.Relocate(u, destination)
		else:
			u.Attached = destination
		print("%s has arrived at %s." % [u.Name, destination.Name])

	# --- UNITS ON THEIR WAY TO A FLEET: "a member of the fleet but ... still in
	# hyperspace for several days until it arrives" (manual p122;
	# OrderManager.LoadAboard). A fleet that moves takes them along
	# (CascadeFleetPayloads) and they arrive with it.
	for sector in _galaxy:
		for planet in sector.Planets:
			for fleet in planet.OrbitingFleets:
				if fleet.Status == Enums.Status.Enroute:
					continue
				for ship in fleet.Ships:
					for cargo in ship.Hangar:
						if not OrderManager.Inbound(cargo):
							continue
						cargo.DaysToDestination -= 1
						if cargo.DaysToDestination <= 0:
							cargo.DaysToDestination = 0
							cargo.Destination = null
							cargo.Status = Enums.Status.AwaitingOrders
							print("%s has joined %s at %s." % [cargo.Name, fleet.Name, planet.Name])

	# --- PROCESS FLEET MOVEMENT ---
	var charted := false
	var joining: Array[Fleet] = []
	for sector in _galaxy:
		for planet in sector.Planets:
			for fleet in planet.OrbitingFleets:
				if fleet.Status != Enums.Status.Enroute or fleet.Destination == null:
					continue
				fleet.DaysToDestination -= 1
				var arrived := fleet.DaysToDestination <= 0
				var landing := fleet.Destination
				if arrived:
					fleet.Attached = landing
					fleet.Destination = null
					fleet.DaysToDestination = 0
					fleet.Status = Enums.Status.AwaitingOrders
					fleet.ArrivedDay = Today
					print("%s has arrived at %s." % [fleet.Name, landing.Name])
					# "A FLEET CAN EXPLORE AN UNEXPLORED SYSTEM ... WHEN THE FLEET ARRIVES YOU
					# LEARN THE SAME INFORMATION ABOUT THE SYSTEM THAT YOU DO FROM A RECON
					# MISSION ... EXCEPT ANY CHARACTERS OR SPECFORCES THAT MAY BE PRESENT AND
					# INFORMATION CONCERNING CURRENT MANUFACTURING" (manual p121); a charted
					# system is updated the same way - "IF YOU SEND A FLEET OR A MISSION TO A
					# SYSTEM TO INVESTIGATE" (manual p069). ON ARRIVAL ONLY: no source says a
					# fleet that stays keeps the sighting fresh (GAMEPLAY.md section 13).
					if fleet.Faction != null and landing.ControllingFaction != fleet.Faction:
						IntelManager.Capture(fleet.Faction, landing, CurrentDay, IntelManager.ReconnaissanceCategories)
						charted = true
					if fleet.IsTransit():
						joining.append(fleet)
				for ship in fleet.Ships:
					ship.DaysToDestination = fleet.DaysToDestination
					if arrived:
						ship.Attached = landing
						ship.Destination = null
						ship.Status = Enums.Status.AwaitingOrders
					if ship.Hangar == null:
						continue
					for cargo in ship.Hangar:
						cargo.DaysToDestination = fleet.DaysToDestination
						if not arrived:
							continue
						cargo.Attached = landing
						cargo.Destination = null
						cargo.Status = Enums.Status.AwaitingOrders
				for rider in GameState.ActiveRoster:
					if rider.Attached != fleet:
						continue
					rider.DaysToDestination = fleet.DaysToDestination
					if arrived:
						rider.Status = Enums.Status.AwaitingOrders
	# Ships that went to join a fleet fold into it on arriving, if it is still
	# there and free (manual p122); otherwise they stay a fleet of their own.
	for transit in joining:
		var target: Fleet = transit.JoinFleet
		transit.JoinFleet = null
		var here: Planet = transit.Attached
		if target == null or here == null or not here.OrbitingFleets.has(target) \
				or target.Status == Enums.Status.Enroute or target.Faction != transit.Faction:
			print("%s arrives at %s; the fleet it was joining is not there." % [transit.Name, here.Name if here != null else "?"])
			if target != null and transit.Name == target.Name:
				transit.Name = Fleet.NextName(transit.Faction)
			continue
		for ship in transit.Ships.duplicate():
			transit.Ships.erase(ship)
			target.AddShip(ship)
		for rider in GameState.ActiveRoster:
			if rider.Attached == transit:
				rider.Attached = target
			if rider.Destination == transit:
				rider.Destination = target
		here.OrbitingFleets.erase(transit)
		print("Ships arriving at %s join %s." % [here.Name, target.Name])
	if charted:
		EventBus.BroadcastChanged()   # the map recolours, as it does after a Reconnaissance report

	# Per-planet work: construction queues only.
	for sector in _galaxy:
		for planet in sector.Planets:
			planet.ProcessDailyTick()

	# Mine -> raw -> refine -> refined, once per faction.
	for faction in FactionRegistry.Playable:
		Economy.ProcessDay(faction)

	LoyaltyManager.ProcessDay(_galaxy)
	ForceManager.ProcessDay(CurrentDay)
	StoryManager.ProcessDay(CurrentDay, rng)
	CaptivityManager.ProcessDay(_galaxy, CurrentDay, rng)
	InformantManager.ProcessDay(_galaxy, CurrentDay, rng)
	AgentDroid.ProcessDay(_galaxy, CurrentDay)
	AiManager.ProcessDay(_galaxy, CurrentDay, rng)
	FleetBattleManager.ProcessDay(_galaxy, CurrentDay, rng)
	BlockadeManager.ProcessDay(_galaxy, CurrentDay, rng)
	SmugglingManager.ProcessDay(_galaxy, CurrentDay, rng)
	RepairManager.ProcessDay(_galaxy, CurrentDay)
	VictoryManager.ProcessDay(_galaxy, CurrentDay)
	ResearchManager.ProcessDay(_galaxy, CurrentDay)

	MissionManager.ProcessDay(rng, CurrentDay)

	EventBus.BroadcastDayAdvanced(CurrentDay)
