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


static func Reset() -> void:
	_known.clear()


static func _key(viewer: Faction, planet: Planet, section: int) -> String:
	return "%s|%s|%d" % [viewer.Id, planet.Name, section]


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
				lines.append(DescribeTask(t, "construction"))
			for t in p.ShipyardQueue:
				lines.append(DescribeTask(t, "shipyard"))
			for t in p.TrainingQueue:
				lines.append(DescribeTask(t, "training"))
	return lines


static func IsDefensive(f: Facility) -> bool:
	return f.Type == Enums.FacilityType.PlanetaryShield \
		or f.Type == Enums.FacilityType.TurbolaserBattery \
		or f.Type == Enums.FacilityType.IonCannon


static func Describe(f: Facility) -> String:
	return "Advanced %s" % f.Name() if f.Tier > 1 else f.Name()


static func DescribeTask(t: ConstructionTask, where: String) -> String:
	var pct := 0 if t.TotalWork <= 0 else clampi(t.Progress * 100 / t.TotalWork, 0, 100)
	var what: String
	if t.UnitRule != null:
		what = t.UnitRule.Name
	else:
		var type_name := JsonUtil.enum_name(Enums.FacilityType, t.Type)
		what = "Advanced %s" % type_name if t.Tier > 1 else type_name
	return "%s (%s, %d%% complete)" % [what, where, pct]
