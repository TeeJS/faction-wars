class_name GameMessage
extends RefCounted
## backend/GameMessage.cs - one entry in the message log.

var Title: String

## A DETERMINISTIC SERIAL, assigned at creation from a per-game counter (the
## fleet's NextSerial is the precedent). Delete Messages names a message by it
## in head-to-head play (docs/m0-audit.md section 4). Not hashed, not snapshotted.
var Serial: int = 0
static var _next_serial: int = 0


static func ResetSerials() -> void:
	_next_serial = 0


static func NextSerial() -> int:
	_next_serial += 1
	return _next_serial

## THE FACTION THIS MESSAGE IS ADDRESSED TO. Null means everybody (a chat line,
## a system notice). In lockstep both clients hold the same log and each shows
## its own faction's messages (docs/m0-audit.md section 1).
var For: Faction = null
var Body: String
var Category: Enums.MessageCategory
## The original's finer-grained kind. Optional - None rather than guessed.
var Type: Enums.MessageType = Enums.MessageType.None
var DayReceived: int
var AssociatedLocation: Location
var AssociatedCharacter: Character
var IsRead: bool = false

## Set when the message asks a question the player can answer from the message
## itself ("Do you wish the mission to continue?", manual p110).
var PendingMission: Mission


func _init(title: String = "", body: String = "", category: int = Enums.MessageCategory.All,
		day: int = 0, planet: Location = null, character: Character = null) -> void:
	Serial = NextSerial()
	Title = title
	Body = body
	Category = category as Enums.MessageCategory
	DayReceived = day
	AssociatedLocation = planet
	AssociatedCharacter = character


func AwaitsDecision() -> bool:
	return PendingMission != null and not PendingMission.Finished


static func _enum_fields() -> Dictionary:
	return { "Category": Enums.MessageCategory, "Type": Enums.MessageType }
