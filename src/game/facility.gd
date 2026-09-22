class_name Facility
extends RefCounted
## backend/Facility.cs - a facility standing on a world.

var Attached: Planet

## A DETERMINISTIC SERIAL, assigned at creation from a per-game counter (the
## fleet's NextSerial is the precedent). Commands name entities by it in
## head-to-head play (docs/m0-audit.md section 4). Not hashed, not snapshotted.
var Serial: int = 0
static var _next_serial: int = 0


static func ResetSerials() -> void:
	_next_serial = 0


static func NextSerial() -> int:
	_next_serial += 1
	return _next_serial


func _init() -> void:
	Serial = NextSerial()


## WHAT THIS IS, from the pack (SCHEMA.md section 5). Replaces the old
## `Type: Enums.FacilityType`. The engine asks Def.HasRole(...), never which
## facility it is.
var Def: PackDefs.FacilityDef
var Tier: int = 1
var IsDamaged: bool = false
var IsSelected: bool = false

# --- COMBAT STATS ---
var ConstructionCost: int
var MaintenanceCost: int
var WeaponRating: int
var ShieldStrength: int

## "BOMBARDMENT VALUE" - what a bombarding fleet must spend to destroy this
## (manual p085 fig 3.28, p122).
var BombardmentDefense: int


func Name() -> String:
	return Def.DisplayName if Def != null else ""


## The pack id, e.g. "advanced_shipyard". Data, never a code constant.
func TypeId() -> String:
	return Def.Id if Def != null else ""


## The family this is a tier of, e.g. "shipyard".
func Family() -> String:
	return Def.Family if Def != null else ""


## THE ONLY WAY ENGINE CODE MAY SELECT A FACILITY (charter question 3).
func HasRole(role: String) -> bool:
	return Def != null and Def.HasRole(role)


## The producer role this facility carries, if any - the key to the queue it
## feeds (Planet.QueueFor). "" for a facility that produces nothing.
func ProducerRole() -> String:
	for role in ["produces_facility", "produces_unit", "produces_troop"]:
		if HasRole(role):
			return role
	return ""


## The display name for a family/tier nobody has built yet.
static func NameOf(family: String, tier: int = 1) -> String:
	var d := FacilityCatalog.Get(family, tier)
	return d.DisplayName if d != null else family


static func Make(family: String, tier: int = 1) -> Facility:
	var f := Facility.new()
	f.Def = FacilityCatalog.Get(family, tier)
	f.Tier = tier
	return f


static func FromDef(def: PackDefs.FacilityDef) -> Facility:
	var f := Facility.new()
	f.Def = def
	f.Tier = def.Tier if def != null else 1
	return f


static func _enum_fields() -> Dictionary:
	return {}
