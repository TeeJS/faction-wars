class_name FacilityCatalog
extends RefCounted
## backend/FacilityCatalog.cs - what a facility costs and how it behaves.
##
## THE PACK IS THE CATALOG NOW (SCHEMA.md section 5). This class used to hold
## `Families`, a map from the original binary's family numbers to members of
## Enums.FacilityType - a closed vocabulary that a pack could not add to. It is
## gone: facilities are whatever `facilities.json` declares, selected by ROLE.

## facility id -> PackDefs.FacilityDef
static var _by_id: Dictionary = {}
## "family|tier" -> PackDefs.FacilityDef. Tiers are variants of one family.
static var _by_family_tier: Dictionary = {}
## role -> Array[PackDefs.FacilityDef], in pack order.
static var _by_role: Dictionary = {}


static func _key(family: String, tier: int) -> String:
	return "%s|%d" % [family, tier]


static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	_by_id.clear()
	_by_family_tier.clear()
	_by_role.clear()
	if pack == null:
		push_error("[FacilityCatalog] no pack loaded!")
		return
	for def in pack.Facilities:
		_by_id[def.Id] = def
		_by_family_tier[_key(def.Family, def.Tier)] = def
		for role in def.Roles:
			if not _by_role.has(role):
				_by_role[role] = []
			_by_role[role].append(def)
	print("[FacilityCatalog] Loaded %d facility profiles from the pack." % _by_id.size())


static func ById(id: String) -> PackDefs.FacilityDef:
	return _by_id.get(id)


static func Get(family: String, tier: int = 1) -> PackDefs.FacilityDef:
	return _by_family_tier.get(_key(family, tier))


## Every facility carrying `role`, in pack order.
static func WithRole(role: String) -> Array:
	return _by_role.get(role, [])


## The one facility carrying `role` at tier 1 - for roles a pack declares once,
## such as the headquarters. Null when the pack declares none.
static func FirstWithRole(role: String) -> PackDefs.FacilityDef:
	for def in WithRole(role):
		if def.Tier == 1:
			return def
	return null


static func ConstructionCost(family: String, tier: int = 1) -> int:
	var r := Get(family, tier)
	return r.ConstructionCost if r != null else 0


static func MaintenanceCost(family: String, tier: int = 1) -> int:
	var r := Get(family, tier)
	return r.MaintenanceCost if r != null else 0


## Days of work per unit of cost. Base facilities are 4, the R&D-gated Advanced
## variants 2 (manual p104). The pack carries it as a stat; 4 is the fallback
## for a facility that declares none.
static func ProcessingRate(family: String, tier: int = 1) -> int:
	var r := Get(family, tier)
	return max(1, r.stat("processing_rate", 4) if r != null else 4)


## Every profile, for the research tree to walk.
static func All() -> Array:
	return _by_id.values()


## What a given faction may place on a world it controls. Excludes anything with
## the headquarters role; Advanced variants are R&D-gated (manual p104).
static func BuildableBy(faction: Faction) -> Array:
	var out := []
	for r in _by_id.values():
		if not ResearchManager.IsUnlockedFacility(faction, r):
			continue
		if r.Tier != 1:
			continue
		if r.HasRole("headquarters"):
			continue
		if not r.CanBeBuiltBy(faction):
			continue
		out.append(r)
	return Lq.order_by(out, func(r): return r.ConstructionCost)
