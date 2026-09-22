class_name MissionCatalog
extends RefCounted
## backend/MissionCatalog.cs - the mission catalog, now from the pack
## (SCHEMA.md section 9, packs/<pack>/missions.json).
##
## ⚠ MISSION BEHAVIOUR IS ENGINE, NOT PACK. Unlike facilities - whose behaviour
## reduced entirely to role tags - each mission kind is a block of bespoke code
## in MissionManager: its own scoring terms, its own rating gains, its own
## resolution. A pack cannot add a mission kind without code, and Enums
## .MissionType is the engine's list of behaviours it implements, not a
## vocabulary of content. What IS content - which of them this setting offers,
## what they are called, who may run them, their lengths, flags, teams and
## outcome tables - lives in the pack.
##
## This map is the JOIN between the two: an engine behaviour and the pack
## mission it is implemented for. The pack side is an id, so the hardcoded
## MISSNSD numbers (0x10, 0x41, ...) are gone.

static var _by_id: Dictionary = {}          # source id -> PackDefs.MissionDefPack
static var _by_pack_id: Dictionary = {}     # pack id   -> PackDefs.MissionDefPack

## Pack mission ids this codebase needs by name but has no MissionType for.
const DagobahId := "dagobah"
const PalaceId := "palace"

const _pack_ids := {
	Enums.MissionType.Diplomacy:              "diplomacy",
	Enums.MissionType.Rescue:                 "rescue",
	Enums.MissionType.Sabotage:               "sabotage",
	Enums.MissionType.Espionage:              "espionage",
	Enums.MissionType.Reconnaissance:         "reconnaissance",
	Enums.MissionType.Recruitment:            "recruitment",
	Enums.MissionType.Abduction:              "abduction",
	Enums.MissionType.ShipDesignResearch:     "ship_design_research",
	Enums.MissionType.FacilityDesignResearch: "facility_design_research",
	Enums.MissionType.TroopTrainingResearch:  "troop_training_research",
	Enums.MissionType.InciteUprising:         "incite_uprising",
	# The engine behaviour is generic; the PACK names its own flavour of it.
	Enums.MissionType.SuperweaponSabotage:    "death_star_sabotage",
	Enums.MissionType.SpecialPowerTraining:   "jedi_training",
	Enums.MissionType.SubdueUprising:         "subdue_uprising",
	Enums.MissionType.Assassination:          "assassination",
}


## The pack's mission for an engine behaviour, or null when this pack offers none.
static func DefFor(type: int) -> PackDefs.MissionDefPack:
	var pid: Variant = _pack_ids.get(type)
	return null if pid == null else _by_pack_id.get(pid)


static func ById(pack_id: String) -> PackDefs.MissionDefPack:
	return _by_pack_id.get(pack_id)


## What the player calls this mission - the PACK's wording, not the enum's.
static func DisplayNameFor(type: int) -> String:
	var d := DefFor(type)
	return d.DisplayName if d != null else JsonUtil.enum_name(Enums.MissionType, type)


static func IdFor(type: int) -> int:
	var d := DefFor(type)
	return d.SourceId if d != null else -1


static func RollLength(type: int, rng: Prng, fallback: int) -> int:
	var pid: Variant = _pack_ids.get(type)
	return fallback if pid == null else RollLengthById(str(pid), rng, fallback)


## "Do you wish the mission to continue?" Null when the pack declares no such
## mission, so the caller can fall back rather than read a missing table as
## "nothing is persistent".
static func CanContinue(type: int) -> Variant:
	var d := DefFor(type)
	return null if d == null else d.flag("can_continue")


static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_by_id.clear()
	_by_pack_id.clear()
	if pack == null:
		push_error("[MissionCatalog] no pack loaded!")
		return
	for d in pack.Missions:
		_by_id[d.SourceId] = d
		_by_pack_id[d.Id] = d
	print("Successfully loaded %d mission definitions from the pack." % _by_id.size())


static func Get(mission_id: int) -> PackDefs.MissionDefPack:
	return _by_id.get(mission_id)


## base + rand(0..spread), inclusive at both ends, matching RuleManager.Roll.
## Falls back to the supplied default when the pack declares no such mission.
static func RollLengthById(pack_id: String, rng: Prng, fallback: int) -> int:
	var d := ById(pack_id)
	if d == null or d.LengthBase <= 0:
		return fallback
	var extra := 0
	if d.LengthSpread > 0:
		assert(rng != null, "MissionCatalog.RollLength: null rng")   # fails loudly on purpose
		extra = rng.NextRange(0, d.LengthSpread + 1)
	return d.LengthBase + extra
