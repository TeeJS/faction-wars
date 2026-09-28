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

## The battle or assault this message reports (a FleetBattleManager.BattleReport
## or an AssaultManager.AssaultReport). Opening the message opens its results
## window, as the original's Conflict messages do: the Assault Summary "also is
## available as a message when your opponent assaults one of your systems"
## (manual p123; TeeJ's screenshot of the original, 2026-09-26). Messages are
## not saved, so neither is this.
var Report: RefCounted = null

## WHAT THE DROIDS SAY ABOUT IT (docs/advisor-plan.md): the advisor event this
## news is for the side it is addressed to - the engine's names, which the pack's
## `advisor` maps to the droids' animations and lines ("" - nothing). A
## character's own event takes the character from AssociatedCharacter
## ("personnel_report" plays that character's report where the pack has one).
## Presentation only: the simulation never reads it.
var Advisor: String = ""
## The line AssociatedCharacter speaks with it (the pack's `voices`:
## "mission_success", "personnel_arrived", ...), or "".
var Voice: String = ""
## The picture it shows when read, as a pack reference ("<art set>:<path>"),
## or "" - the character's or the world's, as before. An agent advice
## message's is the agent's own (the pack's `advice`). Presentation only.
var Picture: String = ""
## A report's scene - the original's message picture, "message.<id>" - with the
## reporting character laid over it (the original's mission reports: STRATEGY
## 1044 for Diplomacy, the agent in front), or "". Presentation only.
var Scene: String = ""
## The original's message picture shown as it is, nobody laid over it -
## "message.<id>", windows/message.<id>.png (STRATEGY 1000-1075: "Chewbacca
## Escaped" is 1029) - or "". Presentation only.
var Still: String = ""
## The original's sound for it, played when the message is shown - STRATEGY's
## WAVE, "strategy/<id>" (1100-1152; the art set's sound/strategy/<id>.ogg),
## as REBEXE's builder for it sets one beside its picture - or "".
## Presentation only.
var Sound: String = ""
## Its own icon in the Message Index, in place of its category's, or "":
## "imported" - the cockpit's load disc (TeeJ, 2026-09-28, for Game imported).
## Presentation only.
var Icon: String = ""


func _init(title: String = "", body: String = "", category: int = Enums.MessageCategory.All,
		day: int = 0, planet: Location = null, character: Character = null) -> void:
	Serial = NextSerial()
	Title = title
	Body = body
	Category = category as Enums.MessageCategory
	DayReceived = day
	AssociatedLocation = planet
	AssociatedCharacter = character


## The same message for a second audience - its own serial, its own read flag.
func Copy() -> GameMessage:
	var c := GameMessage.new(Title, Body, Category, DayReceived, AssociatedLocation, AssociatedCharacter)
	c.Type = Type
	c.PendingMission = PendingMission
	c.Report = Report
	c.Advisor = Advisor
	c.Voice = Voice
	c.Picture = Picture
	c.Scene = Scene
	c.Still = Still
	c.Sound = Sound
	c.Icon = Icon
	return c


## The same message, tagged for the droids and the character's own line.
func With(advisor: String, voice: String = "") -> GameMessage:
	Advisor = advisor
	Voice = voice
	return self


## The same message, with the original's sound for it (Sound).
func Sounding(sound: String) -> GameMessage:
	Sound = sound
	return self


func AwaitsDecision() -> bool:
	return PendingMission != null and not PendingMission.Finished


static func _enum_fields() -> Dictionary:
	return { "Category": Enums.MessageCategory, "Type": Enums.MessageType }
