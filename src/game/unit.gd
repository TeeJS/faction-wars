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
	_class_numbers.clear()


## A capital ship's number within its class and side ("Corellian Corvette 1",
## "Corellian Corvette 2" - TeeJ's screenshots of the original's Ship Finder;
## fighters and regiments carry none). Never reused (INFERRED).
static var _class_numbers: Dictionary = {}   # "faction|unit id" -> the last number


static func NextClassNumber(side: Faction, unit_id: String) -> int:
	var key: String = "%s|%s" % [side.Id if side != null else "", unit_id]
	_class_numbers[key] = int(_class_numbers.get(key, 0)) + 1
	return _class_numbers[key]


## A loaded ship's name: its class's numbering goes on past it.
static func NoteClassName(side: Faction, unit_id: String, class_name_: String, name: String) -> void:
	if not name.begins_with(class_name_ + " "):
		return
	var tail: String = name.substr(class_name_.length() + 1)
	if not tail.is_valid_int():
		return
	var key: String = "%s|%s" % [side.Id if side != null else "", unit_id]
	_class_numbers[key] = maxi(int(_class_numbers.get(key, 0)), int(tail))


static func NextSerial() -> int:
	_next_serial += 1
	return _next_serial


func _init() -> void:
	Serial = NextSerial()

var AssetId: int
var FamilyId: int
## The pack's id for this unit (units.json; for a Character, characters.json).
## Engine code that must know WHICH unit this is compares this, never Name -
## names are display strings (SCHEMA.md section 12 Q1).
var PackId: String = ""


## Does the pack give this unit the role? The engine's special cases ask this
## (SCHEMA.md section 6); a Character answers from characters.json instead.
func HasRole(role: String) -> bool:
	return MilitaryCatalog.RolesOf(PackId).has(role)

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
## WEAPONS ARE PACK DATA (SCHEMA.md section 6). This used to be four named
## fields plus four ranges plus three per-arc arrays - "turbolaser", "ion cannon"
## and "laser" written into the engine. The pack declares the classes; the engine
## asks what each one DOES through its roles.
## weapon id -> PackDefs.UnitWeaponDef
var Weapons: Dictionary = {}

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


# --- WEAPONS, asked by ROLE (SCHEMA.md section 6) ---

## This unit's fitting of `id`, or null when it carries none.
func Weapon(id: String) -> PackDefs.UnitWeaponDef:
	return Weapons.get(id)


## Every weapon this unit carries that has `role`, as [id, UnitWeaponDef] pairs,
## in the pack's declared order so the sum is deterministic.
func WeaponsWithRole(role: String) -> Array:
	var out := []
	for w in MilitaryCatalog.WeaponOrder():
		if Weapons.has(w.Id) and w.HasRole(role):
			out.append([w.Id, Weapons[w.Id]])
	return out


## What this unit throws in `arc`, counting only weapons that do NOT have
## `excluded_role`. The engine's one question of a weapon.
func FirepowerInArc(arc: int, excluded_role: String = "") -> int:
	var n := 0
	for w in MilitaryCatalog.WeaponOrder():
		if not Weapons.has(w.Id):
			continue
		if not excluded_role.is_empty() and w.HasRole(excluded_role):
			continue
		n += (Weapons[w.Id] as PackDefs.UnitWeaponDef).in_arc(arc)
	return n


## The longest reach of any weapon this unit carries.
func MaxWeaponReach() -> int:
	var best := 0
	for id in Weapons:
		best = max(best, (Weapons[id] as PackDefs.UnitWeaponDef).Reach)
	return best
