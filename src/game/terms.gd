class_name Terms
extends RefCounted
## WHAT THE SCREEN CALLS THE ENGINE'S CONCEPTS. The engine reads stats and
## resources by key (shield, hull, hyperdrive, ...); the words a player sees
## for them are the PACK's - display.json `terms` (SCHEMA.md section 10) - and
## a key the pack leaves out gets the neutral default below. UI code asks
## Terms.label("hyperdrive"), never writes the word.
##
## The two speeds are distinct concepts: `hyperdrive` is movement BETWEEN
## systems (a time multiplier, lower is faster, 0 = cannot), `sublight` is
## speed IN a battle. The defaults keep that apart.

## The engine's neutral label per concept. The key set IS the vocabulary:
## PackLoader.KNOWN_TERMS must equal these keys (tests/terms.gd checks).
const DEFAULTS := {
	# unit stats
	"hyperdrive":           "Transit Rating",
	"sublight":             "Combat Speed",
	"shield":               "Shielding",
	"hull":                 "Structure",
	"detection":            "Detection Rating",
	"weapons":              "Weapons Rating",
	"bombardment":          "Bombardment Value",
	"bombardment_defense":  "Bombardment Defense",
	"bombardment_modifier": "Bombardment Modifier",
	"maintenance":          "Maintenance Cost",
	"squadron_size":        "Squadron Size",
	"fighter_capacity":     "Fighter Capacity",
	"troop_capacity":       "Troop Capacity",
	# the economy
	"energy":               "Energy",
	"raw_materials":        "Raw Materials",
	"refined_materials":    "Refined Materials",
	"mine":                 "extractor",
	"mines":                "extractors",
	"refinery":             "refinery",
	"refineries":           "refineries",
	# the two defence kinds, as prose plurals
	"planetary_shields":    "shield sites",
	"orbital_batteries":    "gun batteries",
	# unit kinds, singular and plural
	"fighter_squadron":     "Fighter Squadron",
	"fighter_squadrons":    "Fighter Squadrons",
	"trooper_regiment":     "Ground Regiment",
	"trooper_regiments":    "Ground Regiments",
	# movement between systems
	"in_transit":           "in transit",
	# a fleet held at a system, not moving (TeeJ, 2026-09-30: "I don't think WW2
	# fleets were 'in orbit'"); a pack sets its own - the Star Wars pack's
	# "in orbit", the WWII pack's "on station"
	"in_orbit":             "on station",
	# the five ship systems tactical damage tracks (manual p128: shield recharge,
	# weapon recharge, tractor beam power, sub-light engines, hyperdrive)
	"system_shield_recharge": "Shielding Recharge",
	"system_weapon_recharge": "Weapon Recharge",
	"system_tractor":         "Tractor Power",
	"system_engines":         "Combat Engines",
	"system_hyperdrive":      "Transit Drive",
	# a standing defence's state tag in the Defenses window
	"shield_active":          "Shielding Up",
	"weapon_armed":           "Armed",
	# the System Finder's search field, before anything is typed
	"search_systems":         "Search galaxy...",
	# the word under a sector's name on the map, in the original's look
	# ("Calaron" / "Sector")
	"sector":                 "Sector",
	# the Cockpit's size choice (manual p021, Fig. 2.2: "galaxy size")
	"galaxy_size":            "Galaxy Size",
	# the window counting every type the sides have (manual p030, "Galaxy
	# Overview"): its title and its menu item; a pack sets its own (TeeJ,
	# 2026-09-30, of the WWII menu: "galaxy is the wrong term here!")
	"galaxy_overview":        "Galaxy Overview",
	# the System Finder's title (manual p075, Fig 3.12: "Planetary System
	# Finder"); a pack sets its own (TeeJ, 2026-09-30: "Planetary system
	# finder is wrong for WWII as well")
	"system_finder":          "Planetary System Finder",
	# the Encyclopedia's name: its title bar and its close button's hint
	# (manual p073-p074: "Galactic Encyclopedia"); a pack sets its own (TeeJ,
	# 2026-09-30: "Galactic encyclopedia is also wrong")
	"encyclopedia":           "Galactic Encyclopedia",
	# a message category with nothing in it
	"no_messages":            "No transmissions.",
}


## The pack's word for a concept, or the neutral default. An unknown key is an
## engine bug (the vocabulary is closed); it is reported once and shown raw so
## it is visible rather than blank.
static var _warned: Dictionary = {}

static func label(key: String) -> String:
	var pack := FactionRegistry.Pack
	if pack != null and pack.Display != null and pack.Display.Terms.has(key):
		return str(pack.Display.Terms[key])
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	if not _warned.has(key):
		_warned[key] = true
		push_error("[Terms] no such concept '%s' - add it to Terms.DEFAULTS and PackLoader.KNOWN_TERMS." % key)
	return key


## "Label:" - the common form in the status windows.
static func field(key: String) -> String:
	return label(key) + ":"


## The word in running prose ("carries no trooper regiments").
static func lower(key: String) -> String:
	return label(key).to_lower()


## The word starting a sentence ("In hyperspace - 3d out"): first letter up,
## the rest as the pack wrote it.
static func cap(key: String) -> String:
	var s := label(key)
	return s if s.is_empty() else s[0].to_upper() + s.substr(1)
