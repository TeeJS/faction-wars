class_name DayZeroGenerator
extends RefCounted
## backend/DayZeroGenerator.cs - the opening position. Pack-declared starting
## state, resource slots from GNPRTB, habitation, the political lottery (SDPRTB
## buckets), logistics tables, character stats and placement, the opening intel.
## THE ORDER OF EVERY RANDOM DRAW IS THE SOURCE'S, including LINQ's lazy
## evaluation order, because the replay hash depends on it.


static func InitializeGalaxyState(galaxy: Array, human_faction: Faction, difficulty: int, all_characters: Array) -> void:
	var rng := Prng.Session
	var all_planets: Array = []
	for s in galaxy:
		for p in s.Planets:
			all_planets.append(p)
	var rim_planets: Array = []
	for s in galaxy:
		if s.GalaxyRing > 1:
			for p in s.Planets:
				rim_planets.append(p)
	var hq_of: Dictionary = {}   # Faction -> Planet

	# --- PACK-DECLARED STARTING STATE ---
	for faction in FactionRegistry.Playable:
		for start in faction.StartingPlanets:
			var sp: Planet = Lq.first_or_null(all_planets, func(x): return x.Name == start.Planet)
			if sp == null:
				push_error("[Pack] %s: starting planet '%s' not in the map." % [faction.Id, start.Planet])
				continue
			sp.ControllingFaction = faction
			sp.SetSupportFor(faction, start.Support)
			sp.SetExploredForAll(start.Explored)   # the pack's charted start, the same one flag used to mean for everyone
			sp.StartsInhabited = true
			sp.IsInhabited = true

		var hq_def := faction.Hq
		if hq_def == null:
			continue
		var seat: Planet = null
		if hq_def.Kind == "hidden":
			if hq_def.Placement == "random_rim":
				var unclaimed := Lq.where(rim_planets, func(x): return x.ControllingFaction == null)
				var shuffled := Lq.order_by(unclaimed, func(_x): return rng.Next())
				seat = shuffled[0] if not shuffled.is_empty() else null
			else:
				seat = Lq.first_or_null(all_planets, func(x): return x.Name == hq_def.Placement)
		else:
			seat = Lq.first_or_null(all_planets, func(x): return x.Name == hq_def.Planet)
		if seat == null:
			push_error("[Pack] %s: could not place hq (kind '%s')." % [faction.Id, hq_def.Kind])
			continue
		seat.ControllingFaction = faction
		seat.AddFacility(Enums.FacilityType.Headquarters)
		seat.SetSupportFor(faction, 100)
		seat.StartsInhabited = true
		seat.IsInhabited = true
		# A side always knows its own seat; a HIDDEN seat is unknown to the others.
		for other in FactionRegistry.Playable:
			seat.SetExplored(other, other == faction or not faction.HasHiddenHq())
		hq_of[faction] = seat

	# --- HABITATION SEEDING ---
	for sector in galaxy:
		var is_core: bool = sector.GalaxyRing == 1
		for planet in sector.Planets:
			GenerateResources(planet, is_core)
			var pack_placed := planet.ControllingFaction != null
			if not planet.HasHeadquarters() and not pack_placed:
				var populated_pct := RuleManager.GetShared(RuleId.CorePopulatedPct if is_core else RuleId.RimPopulatedPct)
				planet.IsInhabited = planet.StartsInhabited or rng.NextRange(0, 100) < populated_pct
				planet.ControllingFaction = FactionRegistry.Neutral

	# --- POLITICAL LOTTERY: THE BUCKET MODEL (SDPRTB 30/31) ---
	var neutral_inhabited := Lq.where(all_planets, func(p): return p.IsInhabited and p.ControllingFaction == FactionRegistry.Neutral)

	var is_core_world := func(p: Planet) -> bool:
		for s in galaxy:
			if s.Planets.has(p):
				return s.GalaxyRing == 1
		return false

	var core_count := Lq.count(all_planets, func(p): return is_core_world.call(p) and p.IsInhabited)

	var bucket := func(entry_id: int, side: Faction) -> int:
		return core_count * SideLotteryManager.GetProbability(entry_id, human_faction, difficulty, side) / 100

	var strong: Dictionary = {}
	var weak: Dictionary = {}
	for f in FactionRegistry.Playable:
		# A pre-placed CORE world comes off its side's strong bucket; a rim seat
		# (Yavin, the hidden HQ) costs nothing - the original decrements only for
		# Coruscant (TheArchitect2018 seed.js: "_empire_strong -= 1").
		var already := Lq.count(all_planets, func(pl): return pl.ControllingFaction == f and is_core_world.call(pl))
		strong[f] = max(0, bucket.call(SideLotteryManager.CoreBucketStrong, f) - already)
		weak[f] = max(0, bucket.call(SideLotteryManager.CoreBucketWeak, f))

	print("[DayZero] %d populated core worlds. Buckets: %s" % [core_count, Lq.join(Lq.select(FactionRegistry.Playable, func(f): return "%s %d+%d" % [f.Id, strong[f], weak[f]]))])

	# The source enumerates Concat(core.OrderBy(rng), rim.OrderBy(rng)) lazily:
	# every core key is drawn, the core worlds are processed, THEN the rim keys
	# are drawn. Two passes reproduce that draw order exactly.
	var core_neutral := Lq.where(neutral_inhabited, func(p): return is_core_world.call(p))
	var rim_neutral := Lq.where(neutral_inhabited, func(p): return not is_core_world.call(p))
	var passes := [core_neutral, rim_neutral]
	for pass_list in passes:
		var ordered := Lq.order_by(pass_list, func(_p): return rng.Next())
		for p in ordered:
			var is_core: bool = is_core_world.call(p)

			var claimant: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f): return strong[f] > 0)
			var strong_slot := claimant != null
			if claimant == null:
				claimant = Lq.first_or_null(FactionRegistry.Playable, func(f): return weak[f] > 0)

			if claimant == null:
				p.ControllingFaction = FactionRegistry.Neutral
				var spread := RuleManager.GetShared(RuleId.NeutralCoreSupportSpread if is_core else RuleId.RimSupportSpread)
				var support := rng.NextRange(0, spread + 1) + (50 - spread / 2)
				var contested := FactionRegistry.Playable
				if contested.size() > 0:
					p.SetSupportFor(contested[rng.NextMax(contested.size())], support)
				p.SetExploredForAll(is_core)
				continue

			if strong_slot:
				strong[claimant] -= 1
			else:
				weak[claimant] -= 1

			p.ControllingFaction = claimant
			# Core worlds are charted for everyone; a rim claim only for its claimant.
			for other in FactionRegistry.Playable:
				p.SetExplored(other, is_core or claimant == other)

			var support_base := SideLotteryManager.GetProbability(SideLotteryManager.StrongSupportBase if strong_slot else SideLotteryManager.WeakSupportBase, human_faction, difficulty, claimant)
			var support_var := SideLotteryManager.GetProbability(SideLotteryManager.StrongSupportVar if strong_slot else SideLotteryManager.WeakSupportVar, human_faction, difficulty, claimant)
			p.SetSupportFor(claimant, support_base + rng.NextRange(0, max(1, support_var) + 1))

	var planets_of: Dictionary = {}
	for f in FactionRegistry.Playable:
		planets_of[f] = Lq.where(all_planets, func(p): return p.ControllingFaction == f)

	# --- POPULATION, ECONOMY & LOGISTICS ---
	for sector in galaxy:
		var is_core: bool = sector.GalaxyRing == 1
		for planet in sector.Planets:
			if not planet.IsInhabited:
				continue
			var owner: Faction = planet.ControllingFaction
			var seed: PackDefs.FactionSeedDef = owner.Seed if owner != null else null
			var start_def: PackDefs.StartingPlanetDef = null
			if owner != null:
				start_def = Lq.first_or_null(owner.StartingPlanets, func(s): return s.Planet == planet.Name)

			if planet.HasHeadquarters() and seed != null:
				ApplyLogistics(planet, SeedManager.Logistics[seed.HqFacilities], rng)
				ApplyLogistics(planet, SeedManager.Logistics[seed.HqGarrison], rng)
				ApplyLogistics(planet, SeedManager.Logistics[seed.Fleet], rng)
			elif start_def != null and not start_def.Garrison.is_empty() and seed != null:
				ApplyLogistics(planet, SeedManager.Logistics[start_def.Garrison], rng)
				ApplyLogistics(planet, SeedManager.Logistics[seed.Fleet], rng)
			elif seed != null and not seed.ProceduralFleet.is_empty():
				ApplyLogistics(planet, SeedManager.Logistics[seed.ProceduralFleet], rng)

			var syfc_file := "SYFCCRTB.DAT" if is_core else "SYFCRMTB.DAT"
			ApplyLogistics(planet, SeedManager.Logistics[syfc_file], rng, is_core)

	# --- CHARACTER SPAWNING ---
	for c in all_characters:
		GenerateCharacterStats(c, rng)

	var side_a: Faction = FactionRegistry.Playable[0] if FactionRegistry.Playable.size() > 0 else null
	var side_b: Faction = FactionRegistry.Playable[1] if FactionRegistry.Playable.size() > 1 else null
	var unassigned_alliance := Lq.where(all_characters, func(c): return c.Faction == side_a)
	var unassigned_empire := Lq.where(all_characters, func(c): return c.Faction == side_b)

	var side_a_start: Planet = null
	if side_a != null and not side_a.StartingPlanets.is_empty():
		var first_name: String = side_a.StartingPlanets[0].Planet
		side_a_start = Lq.first_or_null(all_planets, func(x): return x.Name == first_name)
	var side_a_hq: Planet = hq_of[side_a] if (side_a != null and hq_of.has(side_a)) else side_a_start
	var side_b_hq: Planet = hq_of[side_b] if (side_b != null and hq_of.has(side_b)) else null
	if side_a_start == null:
		side_a_start = side_a_hq

	for char_name in ["Luke Skywalker", "Leia Organa", "Han Solo", "Chewbacca", "Jan Dodonna", "Wedge Antilles"]:
		var c: Character = Lq.first_or_null(unassigned_alliance, func(x): return x.Name == char_name)
		if c != null:
			c.Attached = side_a_start
			c.Status = Enums.Status.AwaitingOrders
			unassigned_alliance.erase(c)

	var mothma: Character = Lq.first_or_null(unassigned_alliance, func(x): return x.Name == "Mon Mothma")
	if mothma != null:
		mothma.Attached = side_a_hq
		unassigned_alliance.erase(mothma)

	var palpatine: Character = Lq.first_or_null(unassigned_empire, func(x): return x.Name == "Emperor Palpatine")
	if palpatine != null:
		palpatine.Attached = side_b_hq
		unassigned_empire.erase(palpatine)

	# "located on a randomly selected Imperial-controlled system or fleet"
	var imperial_planets: Array = planets_of[side_b] if side_b != null else []
	var imperial_fleets: Array = []
	for p in imperial_planets:
		for f in p.OrbitingFleets:
			imperial_fleets.append(f)
	for char_name in ["Darth Vader", "Jerjerrod", "Ozzel", "Piett", "Veers", "Needa"]:
		var c: Character = Lq.first_or_null(unassigned_empire, func(x): return x.Name == char_name)
		if c != null and imperial_planets.size() > 0:
			if imperial_fleets.size() > 0 and rng.NextRange(0, 2) == 0:
				c.Attached = imperial_fleets[rng.NextMax(imperial_fleets.size())]
			else:
				c.Attached = imperial_planets[rng.NextMax(imperial_planets.size())]
			c.Status = Enums.Status.AwaitingOrders
			unassigned_empire.erase(c)

	var extra_characters: int
	match GameSettings.SelectedSize:
		Enums.GalaxySize.Standard: extra_characters = 1
		Enums.GalaxySize.Large:    extra_characters = 2
		Enums.GalaxySize.Huge:     extra_characters = 4
		_:                         extra_characters = 2

	for i in extra_characters:
		if unassigned_alliance.size() > 0:
			var extra_rebel: Character = unassigned_alliance[rng.NextMax(unassigned_alliance.size())]
			extra_rebel.Attached = side_a_hq
			unassigned_alliance.erase(extra_rebel)
		if unassigned_empire.size() > 0:
			var extra_imp: Character = unassigned_empire[rng.NextMax(unassigned_empire.size())]
			extra_imp.Attached = side_b_hq
			unassigned_empire.erase(extra_imp)

	# --- 6. DAY ZERO STATISTICAL REPORT ---
	var total := all_planets.size()
	var inhabited := Lq.count(all_planets, func(p): return p.IsInhabited)
	var explored_count := Lq.count(all_planets, func(p): return p.ExploredBy(human_faction))

	# THE OPENING SNAPSHOT: Reconnaissance's categories for every charted world
	# a side does not hold.
	for f in FactionRegistry.Playable:
		for p in all_planets:
			if p.ExploredBy(f) and p.ControllingFaction != f:
				IntelManager.Capture(f, p, 1, IntelManager.ReconnaissanceCategories)

	print("[INTEL] Playing as: %s" % str(GameSettings.PlayerFaction))
	for f in FactionRegistry.Playable:
		if not f.HasHiddenHq():
			continue
		var seat: Planet = hq_of.get(f)
		var visible := Lq.where(all_planets, func(p): return p.ControllingFaction == f and p.ExploredBy(human_faction))
		print("[INTEL] %s HQ: %s | visible to player=%s" % [f.Id, seat.Name if seat != null else "none", str(seat.ExploredBy(human_faction)) if seat != null else ""])
		print("[INTEL] %s worlds visible to player: %d -> %s" % [f.Id, visible.size(), Lq.join(Lq.select(visible, func(p): return p.Name))])

	var own := Lq.where(all_planets, func(p): return p.ControllingFaction == GameSettings.PlayerFaction)
	print("[INTEL] player worlds: %d -> %s" % [own.size(), Lq.join(Lq.select(own, func(p): return "%s(m%d/r%d/e%d)" % [p.Name, p.Mines(), p.Refineries(), p.BaseEnergy]))])
	var own_mines := Lq.sum(own, func(p): return p.Mines())
	var own_refineries := Lq.sum(own, func(p): return p.Refineries())
	print("[INTEL] player totals: %d mines, %d refineries, maintenance capacity %d" % [own_mines, own_refineries, min(own_mines, own_refineries) * Economy.MaintenancePerPair])

	var total_facilities := Lq.sum(all_planets, func(p): return p.Facilities.size())
	var total_fleets := Lq.sum(all_planets, func(p): return p.OrbitingFleets.size())
	var all_capital_ships: Array = []
	for p in all_planets:
		for f in p.OrbitingFleets:
			for s in f.Ships:
				all_capital_ships.append(s)
	var planetary_troops := Lq.sum(all_planets, func(p): return p.Garrison.size())
	var planetary_fighters := Lq.sum(all_planets, func(p): return p.FighterSquadrons.size())
	var hangar_troops := Lq.sum(all_capital_ships, func(s): return Lq.count(s.Hangar, func(u): return u.Type == Enums.UnitType.Troop or u.Type == Enums.UnitType.SpecForce))
	var hangar_fighters := Lq.sum(all_capital_ships, func(s): return Lq.count(s.Hangar, func(u): return u.Type == Enums.UnitType.Fighter))
	var characters_deployed := Lq.count(all_characters, func(c): return c.Attached != null)

	print("\n=== DAY ZERO GALAXY GENERATION REPORT ===")
	print("Planets:   %d (%d Inhabited | %d Barren)" % [total, inhabited, total - inhabited])
	print("Alignment: %s | %d %s" % [Lq.join(Lq.select(FactionRegistry.Playable, func(f): return "%d %s" % [Lq.count(all_planets, func(p): return p.ControllingFaction == f), f.DisplayName]), " | "),
		Lq.count(all_planets, func(p): return p.ControllingFaction == FactionRegistry.Neutral), FactionRegistry.Neutral.DisplayName])
	print("Intel:     %d Explored | %d Uncharted" % [explored_count, total - explored_count])
	print("Economy:   %d Facilities Seeded" % total_facilities)
	print("Navy:      %d Fleets containing %d Capital Ships" % [total_fleets, all_capital_ships.size()])
	print("Forces:    %d Regiments | %d Fighter Squadrons" % [planetary_troops + hangar_troops, planetary_fighters + hangar_fighters])
	print("Roster:    %d Characters Deployed (%d Undiscovered)" % [characters_deployed, all_characters.size() - characters_deployed])
	print("=========================================\n")


## Seven seed files are FIXED LISTS (GNPRTB 84-97 name the parent range); two,
## CMUNALTB and CMUNEMTB, are random band tables - the LAST entry the roll reached.
static func ApplyLogistics(planet: Planet, file: CatalogDtos.LogisticsFile, rng: Prng, is_core: bool = false) -> void:
	if file == null or file.Entries == null:
		return
	if file.Type.contains("SYFC"):
		SeedSystemFacilities(planet, file, rng, is_core)
		return

	var chosen: Array = []
	var range_ids := FixedListRange(file.Name)
	if range_ids[0] != 0:
		var first: int = maxi(1, RuleManager.GetShared(range_ids[0]))
		var max_v: int = maxi(first, RuleManager.GetShared(range_ids[1]))
		var i := first - 1
		while i < max_v and i < file.Entries.size():
			chosen.append(file.Entries[i])
			i += 1
		print("[Seed] %s: deploying parents %d..%d of %d on %s." % [file.Name, first, max_v, file.Entries.size(), planet.Name])
	else:
		var table_roll := rng.NextRange(1, 101)
		var band: CatalogDtos.LogisticsEntry = null
		for entry in file.Entries:
			if entry.ProbabilityThreshold <= table_roll:
				band = entry
		if band == null and not file.Entries.is_empty():
			band = file.Entries[0]
		if band != null:
			chosen.append(band)

	for selected_entry in chosen:
		if selected_entry == null or selected_entry.Assets == null or selected_entry.Assets.is_empty():
			continue
		for i in selected_entry.Multiplier:
			var carrier := DeployAsset(planet, selected_entry.Assets[0])
			for j in range(1, selected_entry.Assets.size()):
				var payload := DeployAsset(planet, selected_entry.Assets[j])
				if payload != null:
					if carrier != null and carrier.Type == Enums.UnitType.CapitalShip and payload.Type != Enums.UnitType.CapitalShip:
						carrier.Hangar.append(payload)
					else:
						AssignUnitToPlanet(planet, payload)
			if carrier != null:
				AssignUnitToPlanet(planet, carrier)


## Which GNPRTB first/max pair governs a seed file, or [0, 0] for a random table.
static func FixedListRange(type: String) -> Array:
	if type.contains("CMUNYVTB"): return [RuleId.SeedYavinFirst, RuleId.SeedYavinMax]
	if type.contains("CMUNHQTB"): return [RuleId.SeedAllianceHqFirst, RuleId.SeedAllianceHqMax]
	if type.contains("CMUNCRTB"): return [RuleId.SeedCoruscantFirst, RuleId.SeedCoruscantMax]
	if type.contains("CMUNAFTB"): return [RuleId.SeedAllianceFleetFirst, RuleId.SeedAllianceFleetMax]
	if type.contains("CMUNEFTB"): return [RuleId.SeedEmpireFleetFirst, RuleId.SeedEmpireFleetMax]
	if type.contains("FACLHQTB"): return [RuleId.SeedHqFacilitiesFirst, RuleId.SeedHqFacilitiesMax]
	if type.contains("FACLCRTB"): return [RuleId.SeedCoruscantFacilitiesFirst, RuleId.SeedCoruscantFacilitiesMax]
	return [0, 0]


static func AssignUnitToPlanet(planet: Planet, unit: Unit) -> void:
	if unit == null:
		return
	if unit.Type == Enums.UnitType.Troop or unit.Type == Enums.UnitType.SpecForce:
		planet.Garrison.append(unit)
	elif unit.Type == Enums.UnitType.Fighter:
		planet.FighterSquadrons.append(unit)
	elif unit.Type == Enums.UnitType.CapitalShip:
		print("Adding Capital ship!")
		planet.AddCapitalShip(unit)


## Mines first (entries 212/213: FreeSlots*X% per raw site), then the cumulative
## band table fills whatever energy is left, ONCE PER ENERGY SLOT.
static func SeedSystemFacilities(planet: Planet, file: CatalogDtos.LogisticsFile, rng: Prng, is_core: bool) -> void:
	var chance_per_slot := planet.FreeMineSlots() * RuleManager.Get(RuleId.CoreMineChancePerSlot if is_core else RuleId.RimMineChancePerSlot)
	for i in planet.BaseRawMaterials:
		if planet.FreeMineSlots() <= 0 or planet.FreeEnergySlots() <= 0:
			break
		if rng.NextRange(1, 101) > chance_per_slot:
			continue
		planet.AddFacility(Enums.FacilityType.Mine, 1)

	var energy_slots := planet.BaseEnergy
	for i in energy_slots:
		if planet.FreeEnergySlots() <= 0:
			break
		var roll := rng.NextRange(1, 101)
		var pick: CatalogDtos.LogisticsEntry = null
		for e in file.Entries:
			if roll >= e.ProbabilityThreshold:
				pick = e
		if pick != null and pick.Asset != null and pick.Asset.FamilyId != 0:
			DeployAsset(planet, pick.Asset)


static func DeployAsset(planet: Planet, asset: CatalogDtos.LogisticsAsset) -> Unit:
	if asset == null or asset.FamilyId == 0:
		return null
	var facility_type: Variant = null
	match asset.FamilyId:
		32: facility_type = Enums.FacilityType.Headquarters
		34: facility_type = Enums.FacilityType.IonCannon
		35: facility_type = Enums.FacilityType.TurbolaserBattery
		36: facility_type = Enums.FacilityType.PlanetaryShield
		40: facility_type = Enums.FacilityType.Shipyard
		41: facility_type = Enums.FacilityType.TrainingFacility
		42: facility_type = Enums.FacilityType.ConstructionYard
		44: facility_type = Enums.FacilityType.Mine
		45: facility_type = Enums.FacilityType.Refinery

	if facility_type != null:
		var is_hq: bool = facility_type == Enums.FacilityType.Headquarters
		if not is_hq and planet.FreeEnergySlots() <= 0:
			return null
		if facility_type == Enums.FacilityType.Mine and planet.FreeMineSlots() <= 0:
			return null
		planet.AddFacility(facility_type, 1)
		return null

	var unit_type: Variant = null
	match asset.FamilyId:
		16: unit_type = Enums.UnitType.Troop
		20: unit_type = Enums.UnitType.CapitalShip
		24: unit_type = Enums.UnitType.CapitalShip   # Death Star
		28: unit_type = Enums.UnitType.Fighter
		60: unit_type = Enums.UnitType.SpecForce
	if unit_type == null:
		return null

	var key := Vector2i(asset.FamilyId, asset.AssetId)
	if SeedManager.MilitaryStats.has(key):
		return MilitaryCatalog.Create(SeedManager.MilitaryStats[key], planet.ControllingFaction, planet)

	var u := Unit.new()
	u.Name = "%s (Model %d)" % [asset.FamilyName, asset.AssetId]
	u.Type = unit_type
	u.AssetId = asset.AssetId
	u.FamilyId = asset.FamilyId
	u.Faction = planet.ControllingFaction
	u.Attached = planet
	return u


## GNPRTB generation rules, read from the pack (entries 189-197, 180, 182).
static func GenerateResources(planet: Planet, is_core: bool) -> void:
	var rng := Prng.Session
	if is_core:
		planet.BaseEnergy = RuleManager.Roll(RuleId.CoreEnergySlotsBase, RuleId.CoreEnergySlotsSpread, rng)
		planet.BaseRawMaterials = RuleManager.Roll(RuleId.CoreMineSlotsBase, RuleId.CoreMineSlotsSpread, rng)
	else:
		# ⚠ The one unsourced step: the wider spread on a 1-in-5 "rich system" roll.
		var rich := rng.NextDouble() > 0.8
		var spread_id := RuleId.RimEnergySlotsSpread2 if rich else RuleId.RimEnergySlotsSpread1
		planet.BaseEnergy = RuleManager.Roll(RuleId.RimEnergySlotsBase, spread_id, rng)
		planet.BaseRawMaterials = RuleManager.Roll(RuleId.RimMineSlotsBase, RuleId.RimMineSlotsSpread, rng)
	planet.BaseEnergy = min(planet.BaseEnergy, RuleManager.Get(RuleId.EnergySlotsHardMax))
	planet.BaseRawMaterials = min(planet.BaseRawMaterials, RuleManager.Get(RuleId.MineSlotsHardMax))


static func GenerateCharacterStats(c: Character, rng: Prng) -> void:
	c.DiplomacyRating = c.DiplomacyBase + rng.NextRange(0, c.DiplomacyVar + 1)
	c.EspionageRating = c.EspionageBase + rng.NextRange(0, c.EspionageVar + 1)
	c.CombatRating = c.CombatBase + rng.NextRange(0, c.CombatVar + 1)
	c.LeadershipRating = c.LeadershipBase + rng.NextRange(0, c.LeadershipVar + 1)
	c.Loyalty = c.LoyaltyBase + rng.NextRange(0, c.LoyaltyVar + 1)
	c.ShipDesign = c.ShipResearchBase + rng.NextRange(0, c.ShipResearchVar + 1)
	c.FacilityDesign = c.FacilityResearchBase + rng.NextRange(0, c.FacilityResearchVar + 1)
	c.TroopTraining = c.TroopResearchBase + rng.NextRange(0, c.TroopResearchVar + 1)
	# LATENT FORCE POTENTIAL - rolled as a percentage; IsKnownJedi is the reveal.
	if c.JediProbability > 0 and rng.NextRange(1, 101) <= c.JediProbability:
		c.JediLevel = c.JediLevelBase + rng.NextRange(0, c.JediLevelVar + 1)
