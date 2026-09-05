class_name StrategicTickManager
extends RefCounted
## backend/StrategicTickManager.cs - one strategic day, in the source's order.
## Every subsystem is live (step 2); the order is load-bearing because the PRNG
## stream depends on it.

var CurrentDay: int = 1
## The same day, reachable without a handle on the tick manager.
static var Today: int = 1
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
				character.Attached = destination
				character.Destination = null
				character.Status = Enums.Status.AwaitingOrders
				print("%s has arrived at %s!" % [character.Name, character.Attached.Name])
				var msg := GameMessage.new("%s Arrives" % character.Name,
					"%s has successfully completed transit and safely arrived at %s. They are currently awaiting new orders." % [character.Name, destination.Name],
					Enums.MessageCategory.Missions, CurrentDay, destination, character)
				msg.Type = Enums.MessageType.PersonnelArrive
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

	# --- PROCESS FLEET MOVEMENT ---
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
					print("%s has arrived at %s." % [fleet.Name, landing.Name])
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
