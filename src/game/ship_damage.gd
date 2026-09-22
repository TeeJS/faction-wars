class_name ShipDamage
extends RefCounted
## backend/ShipDamage.cs - A CAPITAL SHIP'S CURRENT CONDITION, system by system
## (PDF p114, p144). A state container and a set of sourced RULES about that
## state; it invents no numbers.

# Capacities, copied from the design record.
var MaxHull: int
var MaxShield: int
var MaxShieldRecharge: int
var MaxWeaponRecharge: int
var MaxTractorPower: int
var MaxSublight: int
var MaxHyperdrive: int

# Current levels.
var Hull: int
var Shield: int
var ShieldRecharge: int
var WeaponRecharge: int
var TractorPower: int
var Sublight: int
var Hyperdrive: int

## A fighter squadron takes casualties in whole aircraft out of twelve.
var Aircraft: int
var MaxAircraft: int

## The manual's order in the sentence that names them; the Shield Recharger
## first because it can be hit while shields still hold.
const RepairOrder := [
	Enums.ShipSystem.ShieldRecharge,
	Enums.ShipSystem.WeaponRecharge,
	Enums.ShipSystem.TractorPower,
	Enums.ShipSystem.Engines,
	Enums.ShipSystem.Hyperdrive,
]


static func For(u: Unit) -> ShipDamage:
	var d := ShipDamage.new()
	d.MaxHull = u.Hull
	d.MaxShield = u.Shield
	d.MaxShieldRecharge = u.ShieldRecharge
	d.MaxWeaponRecharge = u.WeaponRecharge
	d.MaxTractorPower = u.TractorPower
	d.MaxSublight = u.Sublight
	d.MaxHyperdrive = u.Hyperdrive
	d.MaxAircraft = u.SquadronSize
	d.Reset()
	return d


func Reset() -> void:
	Hull = MaxHull
	Shield = MaxShield
	ShieldRecharge = MaxShieldRecharge
	WeaponRecharge = MaxWeaponRecharge
	TractorPower = MaxTractorPower
	Sublight = MaxSublight
	Hyperdrive = MaxHyperdrive
	Aircraft = MaxAircraft


func ShieldsUp() -> bool:
	return Shield > 0


func Destroyed() -> bool:
	return Aircraft <= 0 if MaxAircraft > 0 else Hull <= 0


## "Ship Damaged: Yes / No" - one line on the Capital Ship Status window.
func IsDamaged() -> bool:
	return Hull < MaxHull or Shield < MaxShield or ShieldRecharge < MaxShieldRecharge \
		or WeaponRecharge < MaxWeaponRecharge or TractorPower < MaxTractorPower \
		or Sublight < MaxSublight or Hyperdrive < MaxHyperdrive \
		or Aircraft < MaxAircraft


func CanJumpToHyperspace() -> bool:
	return MaxHyperdrive > 0 and Hyperdrive > 0


func CanFire() -> bool:
	return MaxWeaponRecharge == 0 or WeaponRecharge > 0


## "Unlike other ship systems, the Shield Recharger may be damaged before your
## shields are knocked out."
func IsVulnerable(sys: int) -> bool:
	return sys == Enums.ShipSystem.ShieldRecharge or not ShieldsUp()


func Current(sys: int) -> int:
	match sys:
		Enums.ShipSystem.ShieldRecharge: return ShieldRecharge
		Enums.ShipSystem.WeaponRecharge: return WeaponRecharge
		Enums.ShipSystem.TractorPower:   return TractorPower
		Enums.ShipSystem.Engines:        return Sublight
		Enums.ShipSystem.Hyperdrive:     return Hyperdrive
	return 0


func Capacity(sys: int) -> int:
	match sys:
		Enums.ShipSystem.ShieldRecharge: return MaxShieldRecharge
		Enums.ShipSystem.WeaponRecharge: return MaxWeaponRecharge
		Enums.ShipSystem.TractorPower:   return MaxTractorPower
		Enums.ShipSystem.Engines:        return MaxSublight
		Enums.ShipSystem.Hyperdrive:     return MaxHyperdrive
	return 0


func SetCurrent(sys: int, value: int) -> void:
	value = clampi(value, 0, Capacity(sys))
	match sys:
		Enums.ShipSystem.ShieldRecharge: ShieldRecharge = value
		Enums.ShipSystem.WeaponRecharge: WeaponRecharge = value
		Enums.ShipSystem.TractorPower:   TractorPower = value
		Enums.ShipSystem.Engines:        Sublight = value
		Enums.ShipSystem.Hyperdrive:     Hyperdrive = value


## "ONLY ONE SYSTEM AT A TIME": the first damaged system in the manual's order,
## or null when whole.
func SystemUnderRepair() -> Variant:
	for s in RepairOrder:
		if Current(s) < Capacity(s):
			return s
	return null


## The pack's words for the five systems (display.json terms, SCHEMA.md
## section 10); the manual's are the Star Wars pack's.
static func DisplayName(s: int) -> String:
	match s:
		Enums.ShipSystem.ShieldRecharge: return Terms.label("system_shield_recharge")
		Enums.ShipSystem.WeaponRecharge: return Terms.label("system_weapon_recharge")
		Enums.ShipSystem.TractorPower:   return Terms.label("system_tractor")
		Enums.ShipSystem.Engines:        return Terms.label("system_engines")
		Enums.ShipSystem.Hyperdrive:     return Terms.label("system_hyperdrive")
	return JsonUtil.enum_name(Enums.ShipSystem, s)
