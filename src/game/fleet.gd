class_name Fleet
extends Location
## backend/Fleet.cs - a container of capital ships in orbit or in transit.

var ID: String = ""   # C# Guid, derived from the serial; never read by anything
var Ships: Array[Unit] = []
var Commander: String = ""

var Status: Enums.Status = Enums.Status.AwaitingOrders
var Destination: Planet
var Attached: Planet
var Hangar: Variant = null   # IEnumerable<object>, never populated by the source
var Faction: Faction
var DaysToDestination: int
## The day it last came into orbit where it is (-1: built there, or never
## moved). A battle's alert says which side moved in (manual p021 Fig. 2.1:
## "the Imperial fleet is threatening..."; p141 Fig. 4.1: "the Alliance fleet
## has entered the ... system") - the later arrival of the two.
var ArrivedDay: int = -1

## FLEET SERIALS ARE DETERMINISTIC (HANDOFF step 0b): a per-game counter gives the
## same "Fleet_0007" on every replay.
static var _next_serial: int = 0


static func ResetSerials() -> void:
	_next_serial = 0
	_numbers.clear()


## THE ORIGINAL'S NAMES: "Fleet 1", "Fleet 2", ... - each side numbering its
## own (TeeJ's screenshots: the Alliance's Fleet 1-5, the Empire's Fleet 1 at
## Chandrila; TeeJ, 2026-09-24: "switch to original"). A number is not reused
## when its fleet is gone (INFERRED - no source says either way). Both sides
## may hold a "Fleet 1", so orders name a fleet by its ID, never its name.
static var _numbers: Dictionary = {}   # faction id -> the last number given


static func NextName(side: Faction) -> String:
	var key: String = side.Id if side != null else ""
	_numbers[key] = int(_numbers.get(key, 0)) + 1
	return "Fleet %d" % _numbers[key]


## A loaded fleet's name: the side's numbering goes on past it.
static func NoteName(side: Faction, name: String) -> void:
	if not name.begins_with("Fleet "):
		return
	var tail: String = name.substr(6)
	if not tail.is_valid_int():
		return
	var key: String = side.Id if side != null else ""
	_numbers[key] = maxi(int(_numbers.get(key, 0)), int(tail))


static func NextSerial() -> int:
	_next_serial += 1
	return _next_serial


## The C# Guid(serial, 0, 0, new byte[8]) rendered as text: 8 hex digits of the
## serial and zeros. Excluded from snapshots on purpose.
static func IdFor(serial: int) -> String:
	return "%08x-0000-0000-0000-000000000000" % serial


func AddShip(unit: Unit) -> void:
	if unit == null:
		return
	Ships.append(unit)


func IsEmpty() -> bool:
	return Ships.size() <= 0


## THE SLOWEST SHIP GOVERNS: the HIGHEST hyperdrive number, because the rating is
## a time multiplier. Rating 0 = no hyperdrive at all, ignored (manual p055).
func HyperdriveRating() -> int:
	var worst := 0
	for s in Ships:
		if s.Hyperdrive > worst:
			worst = s.Hyperdrive
	return worst


## C# has no ToString override, so a fleet prints as its type name - and
## GameSignature.For(Character) relies on exactly that.
func _to_string() -> String:
	return "Fleet"


static func _enum_fields() -> Dictionary:
	return { "Status": Enums.Status }
