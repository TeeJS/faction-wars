class_name Mission
extends RefCounted
## backend/Mission.cs Mission - one mission in flight. The manager is MissionManager.

var Type: Enums.MissionType = Enums.MissionType.Diplomacy

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

var Faction: Faction
var Target: Planet
var HomeBase: Planet

## THE PARTICULAR PERSON this mission is aimed at (Abduction, Assassination, Rescue).
var TargetCharacter: Character
## What Sabotage is aimed at - one of these, never both.
var TargetFacility: Facility
var TargetUnit: Unit

## The whole team travels together (manual p102). UNITS, not just people.
var Team: Array[Unit] = []
## Decoys are full team members whose job is to be noticed (manual p102-p103).
var Decoys: Array[Unit] = []

var DaysToTarget: int
var Finished: bool = false
## Has the team's arrival been reported yet? Keeps arrival and the first attempt
## on SEPARATE DAYS.
var Announced: bool = false

## DAYS OF WORK LEFT BEFORE THIS ATTEMPT RESOLVES - MISSNSD.DAT cols 10/11.
## Re-rolled per attempt.
var DaysOnStation: int

var Attempts: int
## Who was spotted, for the report a foiled team files.
var FoiledBy: Unit

## What a pack shipping no MISSNSD gets: the one day this engine used to take.
const DefaultWorkDays := 1


func TargetObjectName() -> Variant:
	if TargetCharacter != null:
		return TargetCharacter.Name
	if TargetFacility != null:
		return TargetFacility.Name()
	if TargetUnit != null:
		return TargetUnit.Name
	return null


func Arrived() -> bool:
	return DaysToTarget <= 0


func RollWorkDays(rng: Prng) -> int:
	return MissionCatalog.RollLength(Type, rng, DefaultWorkDays)


## "Characters will try to continue until the mission is 100 percent successful"
## (manual p110) - the table's CanContinue column, with the manual's four as the
## fallback for a pack that ships no MISSNSD.
func IsPersistent() -> bool:
	var cc: Variant = MissionCatalog.CanContinue(Type)
	if cc != null:
		return cc
	return Type == Enums.MissionType.Diplomacy \
		or Type == Enums.MissionType.InciteUprising \
		or Type == Enums.MissionType.SubdueUprising \
		or IsResearch()


func IsResearch() -> bool:
	return Type == Enums.MissionType.ShipDesignResearch \
		or Type == Enums.MissionType.TroopTrainingResearch \
		or Type == Enums.MissionType.FacilityDesignResearch


func ResearchTrack() -> int:
	match Type:
		Enums.MissionType.ShipDesignResearch:    return Enums.ResearchTrackKind.ShipDesign
		Enums.MissionType.TroopTrainingResearch: return Enums.ResearchTrackKind.TroopTraining
	return Enums.ResearchTrackKind.FacilityDesign


func DisplayName() -> String:
	return JsonUtil.enum_name(Enums.MissionType, Type)


static func _enum_fields() -> Dictionary:
	return { "Type": Enums.MissionType }
