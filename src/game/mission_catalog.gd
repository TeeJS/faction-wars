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
## WHAT EACH SPECFORCE MAY BE SENT TO DO (manual p098): unit pack id -> the
## engine behaviours whose pack mission lists it under `spec_forces`. This is
## the pack's own roster read the other way round; nothing here names a unit.
static var _spec_force_missions: Dictionary = {}   # unit id -> Array[int]


## THE ENGINE'S NAMES FOR ITS BEHAVIOURS: Enums.MissionType members in
## snake_case, plus the two scripted stays the engine drives without a
## MissionType (Dagobah and Jabba's palace). missions.json joins its rows to
## these with `behaviour`; nothing here names a pack mission.
const EXTRA_BEHAVIOURS := ["dagobah", "palace"]
static var _by_behaviour: Dictionary = {}   # behaviour -> PackDefs.MissionDefPack


static func BehaviourName(type: int) -> String:
	return _snake(JsonUtil.enum_name(Enums.MissionType, type))


static func KnownBehaviours() -> Array:
	var out: Array = []
	for member in Enums.MissionType.keys():
		out.append(_snake(member))
	out.append_array(EXTRA_BEHAVIOURS)
	return out


static func _snake(camel: String) -> String:
	var out := ""
	for i in camel.length():
		var ch := camel[i]
		if i > 0 and ch == ch.to_upper() and ch != ch.to_lower():
			out += "_"
		out += ch.to_lower()
	return out


## The pack mission implementing a behaviour the engine has no MissionType for.
static func ByBehaviour(behaviour: String) -> PackDefs.MissionDefPack:
	return _by_behaviour.get(behaviour)


## The pack's mission for an engine behaviour, or null when this pack offers none.
static func DefFor(type: int) -> PackDefs.MissionDefPack:
	return _by_behaviour.get(BehaviourName(type))


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
	var d := DefFor(type)
	return fallback if d == null else RollLengthById(d.Id, rng, fallback)


## "Do you wish the mission to continue?" Null when the pack declares no such
## mission, so the caller can fall back rather than read a missing table as
## "nothing is persistent".
static func CanContinue(type: int) -> Variant:
	var d := DefFor(type)
	return null if d == null else d.flag("can_continue")


static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_by_id.clear()
	_by_pack_id.clear()
	_by_behaviour.clear()
	if pack == null:
		push_error("[MissionCatalog] no pack loaded!")
		return
	for d in pack.Missions:
		_by_id[d.SourceId] = d
		_by_pack_id[d.Id] = d
		if not d.Behaviour.is_empty():
			_by_behaviour[d.Behaviour] = d
	_spec_force_missions.clear()
	for type in Enums.MissionType.values():
		var d: PackDefs.MissionDefPack = DefFor(type)
		if d == null:
			continue
		for unit_id in d.SpecForces:
			if not _spec_force_missions.has(unit_id):
				_spec_force_missions[unit_id] = []
			_spec_force_missions[unit_id].append(type)
	print("Successfully loaded %d mission definitions from the pack." % _by_id.size())


## The engine behaviours this SpecForce unit (by pack id) may be sent on.
static func SpecForceMissions(unit_pack_id: String) -> Array:
	return _spec_force_missions.get(unit_pack_id, [])


static func SpecForceCanRun(unit_pack_id: String, type: int) -> bool:
	return SpecForceMissions(unit_pack_id).has(type)


## May this side run this mission at all? `available_to` in missions.json; a
## mission the pack does not declare is available to nobody.
static func AvailableTo(type: int, f: Faction) -> bool:
	var d := DefFor(type)
	return d != null and f != null and d.AvailableTo.has(f.Id)


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
