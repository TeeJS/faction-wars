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


var Type: Enums.FacilityType = Enums.FacilityType.Headquarters
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
	return NameOf(Type)


## Static so code holding only a TYPE names it the same way a live facility does.
static func NameOf(type: int) -> String:
	return JsonUtil.enum_name(Enums.FacilityType, type) \
		.replace("ConstructionYard", "Construction Yard") \
		.replace("TrainingFacility", "Training Facility") \
		.replace("PlanetaryShield", "Planetary Shield") \
		.replace("TurbolaserBattery", "Turbolaser Battery") \
		.replace("DeathStarShield", "Death Star Shield") \
		.replace("IonCannon", "Ion Cannon")


static func _enum_fields() -> Dictionary:
	return { "Type": Enums.FacilityType }
