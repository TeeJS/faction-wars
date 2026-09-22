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
	"mines":                "extractors",
	"refineries":           "refineries",
	# unit kinds, singular and plural
	"fighter_squadron":     "Fighter Squadron",
	"fighter_squadrons":    "Fighter Squadrons",
	"trooper_regiment":     "Ground Regiment",
	"trooper_regiments":    "Ground Regiments",
	# movement between systems
	"in_transit":           "in transit",
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
