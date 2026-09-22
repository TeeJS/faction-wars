class_name IntelManager
extends RefCounted
## backend/IntelManager.cs - WHAT YOU KNOW ABOUT A SYSTEM YOU DO NOT HOLD (manual
## p104, p106, p107). THE MODEL IS STALENESS, NOT CONCEALMENT: an enemy system
## shows you what you last saw, undated, however wrong that has since become.
## The categories are the original's (REBEXE.EXE 0x50E18C family ranges).


## A named group inside a snapshot - a fleet, and the ships it held when seen.
class IntelGroup:
	var Name: String
	var Lines: Array[String] = []


## One category of one system, as it was on the day it was seen. Rendered at
## capture time on purpose.
class IntelSnapshot:
	var Day: int
	var Lines: Array[String] = []
	var Groups: Array[IntelGroup] = []
	## The same sighting as DATA (Collect) - a structured twin taken at the same
	## moment as Lines, of the same things, so it reveals nothing the text does not.
	## Read by the windows and the GID (fogged, via the Seen* readers) and by code
	## that must reason about a world it does not hold without reading its live
	## state (the built-in AI, via Sighting/IntelFacts).
	var Data: Dictionary = {}


## What the viewer may show for one category right now.
class IntelView:
	var Known: bool
	var Live: bool
	var Day: int
	var Lines: Array[String] = []
	var Groups: Array[IntelGroup] = []

	static func Nothing() -> IntelView:
		return IntelView.new()

	static func make(known: bool, live: bool, day: int, lines: Array, groups: Array) -> IntelView:
		var v := IntelView.new()
		v.Known = known
		v.Live = live
		v.Day = day
		for l in lines:
			v.Lines.append(l)
		for g in groups:
			v.Groups.append(g)
		return v


## "factionId|planetName|section" -> IntelSnapshot
static var _known: Dictionary = {}

## planet instance id -> galaxy ring. A game's galaxy never re-sectors, so the
## lookup is cached; cleared with the snapshots on Reset().
static var _ring_cache: Dictionary = {}


static func Reset() -> void:
	_known.clear()
	_ring_cache.clear()


static func _key(viewer: Faction, planet: Planet, section: int) -> String:
	return "%s|%s|%d" % [viewer.Id, planet.Name, section]


## THE MANUAL'S CORE EXCEPTION (p069). "One exception is who controls core systems,
## and the level of popular support on core systems. These are always up to date."
## Everything else - resources, production, defences, troops, personnel, ships - is
## only what you last saw, however stale. Core == GalaxyRing 1 (a map fact both
## sides share). Applied inside the Seen* accessors so the UI and the GID inherit it.
static func IsCore(planet: Planet) -> bool:
	return _RingOf(planet) == 1


## The world's galaxy ring, resolved by SECTOR MEMBERSHIP. Planet.SectorId is NOT
## populated on the new-game path (galaxy_factory.gd:50, mirrored from the source),
## so a sector's own Planets list is the only reliable authority.
static func _RingOf(planet: Planet) -> int:
	if planet == null:
		return 0
	var id := planet.get_instance_id()
	if _ring_cache.has(id):
		return _ring_cache[id]
	var ring := 0
	for s in GameState.ActiveGalaxy:
		if s.Planets.has(planet):
			ring = s.GalaxyRing
			break
	_ring_cache[id] = ring
	return ring


## Which category gates each panel.
static func CategoryOf(s: int) -> int:
	match s:
		Enums.IntelSection.SystemStatus:         return Enums.IntelCategory.SystemStatus
		Enums.IntelSection.Troopers:             return Enums.IntelCategory.MilitaryUnits
		Enums.IntelSection.Fighters:             return Enums.IntelCategory.MilitaryUnits
		Enums.IntelSection.OrbitingShips:        return Enums.IntelCategory.MilitaryUnits
		Enums.IntelSection.DefensiveFacilities:  return Enums.IntelCategory.DefensiveFacilities
		Enums.IntelSection.ProductionFacilities: return Enums.IntelCategory.ProductionFacilities
		Enums.IntelSection.SpecForces:           return Enums.IntelCategory.SpecForces
		Enums.IntelSection.Characters:           return Enums.IntelCategory.Characters
	return Enums.IntelCategory.Manufacturing


const AllSections := [
	Enums.IntelSection.SystemStatus, Enums.IntelSection.Troopers, Enums.IntelSection.Fighters,
	Enums.IntelSection.OrbitingShips, Enums.IntelSection.DefensiveFacilities,
	Enums.IntelSection.ProductionFacilities, Enums.IntelSection.SpecForces,
	Enums.IntelSection.Characters, Enums.IntelSection.Manufacturing,
]

## The categories each source hands over - all three are the manual's.
const EspionageCategories := [
	Enums.IntelCategory.SystemStatus, Enums.IntelCategory.MilitaryUnits,
	Enums.IntelCategory.DefensiveFacilities, Enums.IntelCategory.ProductionFacilities,
	Enums.IntelCategory.SpecForces, Enums.IntelCategory.Characters,
	Enums.IntelCategory.Manufacturing,
]

## Reconnaissance is the manual's own list minus its own two exclusions.
const ReconnaissanceCategories := [
	Enums.IntelCategory.SystemStatus, Enums.IntelCategory.MilitaryUnits,
	Enums.IntelCategory.DefensiveFacilities, Enums.IntelCategory.ProductionFacilities,
]


static func Capture(viewer: Faction, planet: Planet, day: int, categories: Array) -> void:
	if viewer == null or planet == null or categories == null:
		return
	for section in AllSections:
		if not categories.has(CategoryOf(section)):
			continue
		var snap := IntelSnapshot.new()
		snap.Day = day
		for l in Render(planet, section):
			snap.Lines.append(l)
		for g in RenderGroups(planet, section):
			snap.Groups.append(g)
		snap.Data = Collect(planet, section)
		_known[_key(viewer, planet, section)] = snap
	# Anything at all charts the system.
	planet.SetExplored(viewer, true)


## A system you hold reports itself, always and accurately. Everything else is
## whatever you last saw.
static func View(viewer: Faction, planet: Planet, section: int) -> IntelView:
	if viewer == null or planet == null:
		return IntelView.Nothing()
	if planet.ControllingFaction == viewer:
		return IntelView.make(true, true, StrategicTickManager.Today, Render(planet, section), RenderGroups(planet, section))
	var k := _key(viewer, planet, section)
	if _known.has(k):
		var s: IntelSnapshot = _known[k]
		return IntelView.make(true, false, s.Day, s.Lines, s.Groups)
	return IntelView.Nothing()


static func Knows(viewer: Faction, planet: Planet, section: int) -> bool:
	return View(viewer, planet, section).Known


static func IsLive(viewer: Faction, planet: Planet) -> bool:
	return viewer != null and planet != null and planet.ControllingFaction == viewer


# ---------------------------------------------------------------------------
# THE SAME INTELLIGENCE, AS DATA. Render() is what was on the screen; Collect()
# is the same sighting in a form code can reason about. Both are taken by
# Capture() at the same moment, so a side never knows more through one than
# through the other. Two readers sit on top:
#   - the Seen* readers below hand it to the UI and the GID with the manual's
#     Core exception applied, so they read fogged numbers, not the live world;
#   - Sighting()/Facts() hand it to the built-in AI, which reads ONLY these and so
#     never reads an enemy world's live state (the fairness rule,
#     docs/ai-framework/10 section 3).
# ---------------------------------------------------------------------------

## { known, live, day, data } for one category - the structured twin of View().
static func Sighting(viewer: Faction, planet: Planet, section: int) -> Dictionary:
	if viewer == null or planet == null:
		return { "known": false, "live": false, "day": 0, "data": {} }
	if planet.ControllingFaction == viewer:
		return { "known": true, "live": true, "day": StrategicTickManager.Today, "data": Collect(planet, section) }
	var k := _key(viewer, planet, section)
	if _known.has(k):
		var s: IntelSnapshot = _known[k]
		return { "known": true, "live": false, "day": s.Day, "data": s.Data }
	return { "known": false, "live": false, "day": 0, "data": {} }


## Everything `viewer` knows of `planet`, gathered for a planner (IntelFacts).
static func Facts(viewer: Faction, planet: Planet) -> IntelFacts:
	return IntelFacts.of(viewer, planet)


## One category of one system as data. Mirrors Render() line for line: the same
## lists, the same filters (so a fleet still in hyperspace TO this world is listed,
## exactly as the text lists it).
static func Collect(p: Planet, section: int) -> Dictionary:
	match section:
		Enums.IntelSection.SystemStatus:
			var support: Dictionary = {}
			for f in FactionRegistry.Playable:
				support[f.Id] = p.SupportFor(f)
			return {
				"owner": p.ControllingFaction.Id if p.ControllingFaction != null else "",
				"support": support,
				"garrison_requirement": p.GarrisonRequirement(),
				"uprising": p.IsInUprising,
				"energy": p.BaseEnergy,
				"materials": p.BaseRawMaterials,
			}
		Enums.IntelSection.Troopers:
			var regiments: Array = []
			for u in p.Troopers():
				regiments.append({ "id": u.PackId, "name": u.Name, "attack": u.Attack, "defense": u.Defense })
			return { "regiments": regiments }
		Enums.IntelSection.Fighters:
			return { "squadrons": p.FighterSquadrons.size() }
		Enums.IntelSection.OrbitingShips:
			var fleets: Array = []
			for f in p.OrbitingFleets:
				fleets.append({
					"name": f.Name,
					"faction": f.Faction.Id if f.Faction != null else "",
					"ships": f.Ships.size(),
					"strength": FleetBattleManager.StrengthOf(f),
				})
			return { "fleets": fleets }
		Enums.IntelSection.DefensiveFacilities:
			var shields := 0
			var shield_strength := 0
			var battery_ratings: Array = []   # turbolaser batteries only, one WeaponRating each (the AI's read)
			var ion_cannons := 0
			var guns: Array = []   # every defensive facility that fires on a landing (AssaultManager.Resolve: WeaponRating > 0)
			for f in p.Facilities:
				if IsDefensive(f) and f.WeaponRating > 0:
					guns.append(f.WeaponRating)
				match f.Family():
					"planetary_shield":
						shields += 1
						var rule := FacilityCatalog.Get(f.Family(), f.Tier)
						shield_strength += rule.stat("shield_strength") if rule != null else 0
					"turbolaser_battery":
						battery_ratings.append(f.WeaponRating)
					"ion_cannon":
						ion_cannons += 1
			return {
				"shields": shields,
				"shield_strength": shield_strength,
				# "batteries" is a COUNT (turbolaser + ion), as the GID's "Defense Batteries" reads it.
				"batteries": battery_ratings.size() + ion_cannons,
				"battery_ratings": battery_ratings,
				"ion_cannons": ion_cannons,
				"guns": guns,
			}
		Enums.IntelSection.ProductionFacilities:
			var counts: Dictionary = {}
			for f in p.Facilities:
				if not IsDefensive(f):
					counts[f.Family()] = int(counts.get(f.Family(), 0)) + 1
			return { "counts": counts }
		Enums.IntelSection.SpecForces:
			return { "units": p.SpecForces().size() }
		Enums.IntelSection.Characters:
			# ONE DELIBERATE DIFFERENCE FROM Render(): an agent ON A MISSION is not listed.
			# Such an agent is hiding - the Personnel tab already refuses to show one
			# standing on a world we hold (issue #2a, tests/onmission_fog.gd) - and a
			# planner that saw them could abduct a spy it has not detected. The built-in
			# AI does exactly that; a brain reading these facts cannot.
			var people: Array = []
			for c in GameState.ActiveRoster:
				if c.IsOffMap() or c.Attached != p or c.Status == Enums.Status.Dead or c.Status == Enums.Status.OnMission:
					continue
				people.append({ "name": c.Name, "rank": c.Rank })
			return { "people": people }
	return {}


## The stored data twin for a section, or the live twin for a world we hold, or {}
## for one never seen. No Core exception here - that is owner/support only, in
## StatusSeen.
static func SeenData(viewer: Faction, planet: Planet, section: int) -> Dictionary:
	if viewer == null or planet == null:
		return {}
	if planet.ControllingFaction == viewer:
		return Collect(planet, section)
	var k := _key(viewer, planet, section)
	return _known[k].Data if _known.has(k) else {}


## SystemStatus as the viewer may see it: the snapshot, with owner and support
## overwritten LIVE on a Core world (p069). Live throughout for a world we hold.
## {} when never charted and not Core.
static func StatusSeen(viewer: Faction, planet: Planet) -> Dictionary:
	if viewer == null or planet == null:
		return {}
	if planet.ControllingFaction == viewer:
		return Collect(planet, Enums.IntelSection.SystemStatus)
	var k := _key(viewer, planet, Enums.IntelSection.SystemStatus)
	var d: Dictionary = _known[k].Data.duplicate(true) if _known.has(k) else {}
	if IsCore(planet):
		d["owner"] = planet.ControllingFaction.Id if planet.ControllingFaction != null else ""
		var support: Dictionary = {}
		for f in FactionRegistry.Playable:
			support[f.Id] = planet.SupportFor(f)
		d["support"] = support
	return d


## Who `viewer` believes controls `planet`: the live holder for a world we hold or
## any Core world (p069), else whoever we last saw, else null when never charted.
## The one owner-of-record read; GetFactionColor and the maps go through it.
static func OwnerSeen(viewer: Faction, planet: Planet) -> Faction:
	var d := StatusSeen(viewer, planet)
	if d.is_empty():
		return null
	var owner_id := str(d.get("owner", ""))
	return FactionRegistry.Neutral if owner_id.is_empty() else FactionRegistry.ById(owner_id)


## Support for `faction` on `planet` as `viewer` may see it - live on a Core world
## or one we hold, else the last sighting, else 0.
static func SupportSeen(viewer: Faction, planet: Planet, faction: Faction) -> int:
	if faction == null:
		return 0
	var support: Dictionary = StatusSeen(viewer, planet).get("support", {})
	return int(support.get(faction.Id, 0))


## Uprising as last seen (NOT a Core-live datum - the exception is owner + support
## only). Live for a world we hold.
static func UprisingSeen(viewer: Faction, planet: Planet) -> bool:
	return bool(StatusSeen(viewer, planet).get("uprising", false))


static func RenderGroups(p: Planet, section: int) -> Array:
	var groups := []
	if section != Enums.IntelSection.OrbitingShips:
		return groups
	for f in p.OrbitingFleets:
		var g := IntelGroup.new()
		g.Name = f.Name
		for s in f.Ships:
			g.Lines.append(s.Name)
		groups.append(g)
	return groups


## One category of one system, as text - a copy of what was on the screen.
static func Render(p: Planet, section: int) -> Array:
	var lines: Array = []
	match section:
		Enums.IntelSection.SystemStatus:
			lines.append("Controlled by: %s" % (p.ControllingFaction.DisplayName if p.ControllingFaction != null else "nobody"))
			for f in FactionRegistry.Playable:
				lines.append("Support for the %s: %d%%" % [f.DisplayName, p.SupportFor(f)])
			lines.append("Garrison requirement: %d" % p.GarrisonRequirement())
			if p.IsInUprising:
				lines.append("The system is in open revolt.")
			lines.append("Energy: %d   Raw materials: %d" % [p.BaseEnergy, p.BaseRawMaterials])
		Enums.IntelSection.Troopers:
			for u in p.Troopers():
				lines.append(u.Name)
		Enums.IntelSection.Fighters:
			for u in p.FighterSquadrons:
				lines.append(u.Name)
		Enums.IntelSection.OrbitingShips:
			for f in p.OrbitingFleets:
				for s in f.Ships:
					lines.append("%s (%s)" % [s.Name, f.Name])
		Enums.IntelSection.DefensiveFacilities:
			for f in p.Facilities:
				if IsDefensive(f):
					lines.append(Describe(f))
		Enums.IntelSection.ProductionFacilities:
			for f in p.Facilities:
				if not IsDefensive(f):
					lines.append(Describe(f))
		Enums.IntelSection.SpecForces:
			for u in p.SpecForces():
				lines.append(u.Name)
		Enums.IntelSection.Characters:
			for c in GameState.ActiveRoster:
				if c.IsOffMap() or c.Attached != p or c.Status == Enums.Status.Dead:
					continue
				lines.append(c.Name if c.Rank == Enums.Rank.None else "%s %s" % [JsonUtil.enum_name(Enums.Rank, c.Rank), c.Name])
		Enums.IntelSection.Manufacturing:
			for t in p.BuildingQueue:
				lines.append(DescribeTask(t, "construction", p))
			for t in p.ShipyardQueue:
				lines.append(DescribeTask(t, "shipyard", p))
			for t in p.TrainingQueue:
				lines.append(DescribeTask(t, "training", p))
	return lines


static func IsDefensive(f: Facility) -> bool:
	return f.HasRole("shield") \
		or f.HasRole("anti_ship") \
		or f.HasRole("disable")


static func Describe(f: Facility) -> String:
	return "Advanced %s" % f.Name() if f.Tier > 1 else f.Name()


static func DescribeTask(t: ConstructionTask, where: String, home: Planet = null) -> String:
	var pct := 0 if t.TotalWork <= 0 else clampi(t.Progress * 100 / t.TotalWork, 0, 100)
	var what: String
	if t.UnitRule != null:
		what = t.UnitRule.DisplayName
	else:
		var type_name := Facility.NameOf(t.Family, t.Tier)
		what = "Advanced %s" % type_name if t.Tier > 1 else type_name
	# Espionage reveals where production is headed (manual/guide; the Empire's only
	# documented HQ-finding method). Show the destination only when the order ships
	# elsewhere - a build-in-place order (Destination null or the producing world
	# itself) has no shipping leg to betray.
	if t.Destination != null and t.Destination != home:
		return "%s (%s -> %s, %d%% complete)" % [what, where, t.Destination.Name, pct]
	return "%s (%s, %d%% complete)" % [what, where, pct]
