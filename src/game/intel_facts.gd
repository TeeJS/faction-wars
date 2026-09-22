class_name IntelFacts
extends RefCounted
## WHAT ONE SIDE KNOWS OF ONE WORLD, AS DATA - for a planner (the built-in AI's
## stages, docs/ai-framework). Built only from IntelManager.Sighting: live for a
## world we hold, the dated snapshot for one we have seen, nothing for one we have
## not. Every group of fields carries the day it was seen (-1 = never), because
## categories are seen on different days: Reconnaissance never shows who is standing
## on a world.
##
## THE FAIRNESS RULE BY CONSTRUCTION: code that takes an IntelFacts instead of a
## Planet cannot read an enemy world's live state, because there is none in here.
## `world` is kept for identity and for map facts both sides share (its name, its
## sector, the distance to it) - never read its garrison, facilities or fleets.

var world: Planet
var viewer: Faction
var ours: bool = false            ## we hold it: every group below is live and as of today
var explored: bool = false

var status_day: int = -1          ## SystemStatus
var owner_id: String = ""         ## "" = nobody
var support: Dictionary = {}      ## faction id -> percent
var garrison_requirement: int = 0
var uprising: bool = false

var troops_day: int = -1          ## Troopers
var regiments: Array = []         ## [{name, attack, defense}]

var fighters_day: int = -1
var squadrons: int = 0

var ships_day: int = -1           ## OrbitingShips - includes fleets still inbound, as the text does
var fleets: Array = []            ## [{name, faction, ships, strength}]

var defences_day: int = -1        ## DefensiveFacilities
var shields: int = 0
var shield_strength: int = 0
var batteries: Array = []         ## weapon ratings of the turbolaser batteries
var ion_cannons: int = 0
var guns: Array = []              ## weapon ratings of EVERY defence that fires on a landing (AssaultManager.Estimate's `batteries`)

var production_day: int = -1      ## ProductionFacilities
var facility_counts: Dictionary = {}   ## facility family id -> count (the headquarters building is one)

var people_day: int = -1          ## Characters - everybody standing there, either side's, EXCEPT an agent on a mission (hidden)
var people: Array = []            ## [{name, rank}]


static func of(viewer_: Faction, planet: Planet) -> IntelFacts:
	var f := IntelFacts.new()
	f.world = planet
	f.viewer = viewer_
	if viewer_ == null or planet == null:
		return f
	f.ours = planet.ControllingFaction == viewer_
	f.explored = planet.ExploredBy(viewer_)

	var s := IntelManager.Sighting(viewer_, planet, Enums.IntelSection.SystemStatus)
	if s["known"]:
		f.status_day = s["day"]
		f.owner_id = str(s["data"].get("owner", ""))
		f.support = s["data"].get("support", {})
		f.garrison_requirement = int(s["data"].get("garrison_requirement", 0))
		f.uprising = bool(s["data"].get("uprising", false))
	s = IntelManager.Sighting(viewer_, planet, Enums.IntelSection.Troopers)
	if s["known"]:
		f.troops_day = s["day"]
		f.regiments = s["data"].get("regiments", [])
	s = IntelManager.Sighting(viewer_, planet, Enums.IntelSection.Fighters)
	if s["known"]:
		f.fighters_day = s["day"]
		f.squadrons = int(s["data"].get("squadrons", 0))
	s = IntelManager.Sighting(viewer_, planet, Enums.IntelSection.OrbitingShips)
	if s["known"]:
		f.ships_day = s["day"]
		f.fleets = s["data"].get("fleets", [])
	s = IntelManager.Sighting(viewer_, planet, Enums.IntelSection.DefensiveFacilities)
	if s["known"]:
		f.defences_day = s["day"]
		f.shields = int(s["data"].get("shields", 0))
		f.shield_strength = int(s["data"].get("shield_strength", 0))
		f.batteries = s["data"].get("battery_ratings", [])
		f.ion_cannons = int(s["data"].get("ion_cannons", 0))
		f.guns = s["data"].get("guns", [])
	s = IntelManager.Sighting(viewer_, planet, Enums.IntelSection.ProductionFacilities)
	if s["known"]:
		f.production_day = s["day"]
		f.facility_counts = s["data"].get("counts", {})
	s = IntelManager.Sighting(viewer_, planet, Enums.IntelSection.Characters)
	if s["known"]:
		f.people_day = s["day"]
		f.people = s["data"].get("people", [])
	return f


## Days since a group was seen; a very large number when it never was.
func age(day_seen: int, today: int) -> int:
	return today - day_seen if day_seen >= 0 else 1 << 30


func count_of(family: String) -> int:
	return int(facility_counts.get(family, 0))


## How many facilities of `family` we saw there, whichever sighting holds that
## kind: the three defences are seen with DefensiveFacilities (by ROLE - the
## family is looked up in the catalog, never named here), everything else with
## ProductionFacilities (IntelManager.IsDefensive).
func facilities_of(family: String) -> int:
	var def := FacilityCatalog.Get(family)
	if def != null:
		if def.HasRole("shield"):
			return shields
		if def.HasRole("anti_ship"):
			return batteries.size()
		if def.HasRole("disable"):
			return ion_cannons
	return count_of(family)


func has_headquarters() -> bool:
	return count_of("headquarters") > 0


## Combined strength of the fleets seen there that are NOT `side`'s.
func hostile_strength(side: Faction) -> int:
	var total := 0
	for fl: Dictionary in fleets:
		if str(fl.get("faction", "")) != side.Id:
			total += int(fl.get("strength", 0))
	return total


func hostile_ships(side: Faction) -> int:
	var total := 0
	for fl: Dictionary in fleets:
		if str(fl.get("faction", "")) != side.Id:
			total += int(fl.get("ships", 0))
	return total


func support_for(side: Faction) -> int:
	return int(support.get(side.Id, 0))


func names_present() -> Array:
	return Lq.select(people, func(p: Dictionary) -> String: return str(p.get("name", "")))
