class_name Unit
extends RefCounted
## backend/Unit.cs. Field names are the C# names, deliberately: the port is a
## straight translation of ~25k lines that reference them, and the parity dump
## compares them by name.

var Name: String
var Type: Enums.UnitType = Enums.UnitType.Troop

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

var AssetId: int
var FamilyId: int

var Faction: Faction
## VIRTUAL in C#: a Character reacts to being moved (leaving the fleet or system it
## commands relieves it of the rank). Character overrides set_Attached.
var Attached: Location:
	set(value):
		set_Attached(value)
	get:
		return _attached
var _attached: Location
var Destination: Location
var Status: Enums.Status = Enums.Status.AwaitingOrders
var DaysToDestination: int

# --- COMBAT STATS ---
var ConstructionCost: int
var MaintenanceCost: int
var Detection: int

## MISSION RATINGS, held once for everything that can go on a mission (manual p101).
var DiplomacyRating: int
var EspionageRating: int
var CombatRating: int
var LeadershipRating: int

# Fleet Stats
var Hull: int
var Shield: int
var Sublight: int
var Hyperdrive: int
var Bombardment: int
var Turbolaser: int
var LaserRating: int
var IonCannon: int
var Torpedoes: int

# --- THE REST OF THE COMBAT BLOCK (CAPSHPSD/FIGHTSD; PDF p114) ---
var Maneuverability: int
var HyperdriveDamaged: int
var DamageControl: int
var WeaponRecharge: int
var ShieldRecharge: int
var TractorPower: int
var TractorRange: int
var GravityWell: int
var InterdictionStrength: int
var SquadronSize: int

var TurbolaserRange: int
var IonCannonRange: int
var LaserRange: int
var TorpedoRange: int

## Per-arc, indexed by ShipArc (PDF p138).
var TurbolaserArc: Array[int] = [0, 0, 0, 0]
var IonCannonArc: Array[int] = [0, 0, 0, 0]
var LaserArc: Array[int] = [0, 0, 0, 0]

# --- DAMAGE STATE (PDF p114) --- null means undamaged.
var Damage: ShipDamage = null

# Ground Stats
var Attack: int
var Defense: int
var BombardmentDefense: int

# Carrier Capabilities
var FighterCapacity: int
var TroopCapacity: int

## The units currently housed inside this ship.
var Hangar: Array[Unit] = []


func set_Attached(value: Location) -> void:
	_attached = value


## "Ship Damaged: Yes/No" (PDF p114). Null Damage means undamaged - the current
## value is the design value - so the state object is built on first demand.
func DamageState() -> ShipDamage:
	if Damage == null:
		Damage = ShipDamage.For(self)
	return Damage


func IsDamaged() -> bool:
	return Damage != null and Damage.IsDamaged()


## Which vars are enums, for hydration and the canonical dump.
static func _enum_fields() -> Dictionary:
	return { "Type": Enums.UnitType, "Status": Enums.Status }
