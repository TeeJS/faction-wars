class_name Character
extends Unit
## backend/Character.cs - a named person. The stat block is JSON; ratings are
## rolled at day zero; injury, capture, command and the Force are rules of the
## manual quoted at each function in the source.

## Major or minor - set from which file the character was loaded out of, not JSON.
var IsMajor: bool

var Rank: Enums.Rank = Enums.Rank.None
var Commanding: Location   # a planet or a fleet

## CAPTURED: who is holding them. Null means free.
var CapturedBy: Faction
## AWAY AT DAGOBAH / AT JABBA'S PALACE - off the map entirely (manual p100).
var AtDagobah: bool
var AtJabbasPalace: bool

# --- STORY FLAGS --- real fields on the original's character object.
var KnowsHeritage: bool
var CanEscape: bool = true
var BountyAttack: bool
var CapturedByBountyHunters: bool
var FinalBattleReady: bool
var NextEscapeAttemptOn: int

## Days spent convalescing somewhere friendly.
var DaysResting: int
## INJURY IS A MAGNITUDE, NOT A FLAG (rules table entries 22-37).
var Injury: int

# --- RAW JSON DATA BOUNDS ---
var DiplomacyBase: int
var DiplomacyVar: int
var EspionageBase: int
var EspionageVar: int
var CombatBase: int
var CombatVar: int
var LeadershipBase: int
var LeadershipVar: int
var LoyaltyBase: int
var LoyaltyVar: int
var JediLevelBase: int
var JediLevelVar: int
var ShipResearchBase: int
var ShipResearchVar: int
var TroopResearchBase: int
var TroopResearchVar: int
var FacilityResearchBase: int
var FacilityResearchVar: int

## POSSIBLE COMMAND RANKS (manual p101, Fig 3.46).
var CanBeAdmiral: bool
var CanBeCommander: bool
var CanBeGeneral: bool

var JediProbability: int
var JediLevel: int
var IsKnownJedi: bool
var CanTrainJedi: bool

## Loyalty drifts toward galaxy-wide support (manual p094; LoyaltyManager).
var Loyalty: int
var TraitorRevealed: bool
var WontBetray: bool

var ShipDesign: int
var TroopTraining: int
var FacilityDesign: int


func IsInjured() -> bool:
	return Injury > 0


func IsCaptured() -> bool:
	return CapturedBy != null


## Can this character be given orders at all?
func CanTakeOrders() -> bool:
	return not IsCaptured() and not IsInjured() and not AtDagobah and not AtJabbasPalace and Status != Enums.Status.Dead


## "You cannot locate..." (manual p100).
func IsOffMap() -> bool:
	return AtDagobah or AtJabbasPalace


func CanHold(rank: int) -> bool:
	match rank:
		Enums.Rank.Admiral:   return CanBeAdmiral
		Enums.Rank.General:   return CanBeGeneral
		Enums.Rank.Commander: return CanBeCommander
		Enums.Rank.None:      return true
	return false


func CanHoldAnyRank() -> bool:
	return CanBeAdmiral or CanBeGeneral or CanBeCommander


## TAKING A COMMAND is a SEPARATE ACT from being there (manual p056, p101, p129).
func TryTakeCommand(rank: int) -> Result:
	if IsCaptured():
		return Result.fail("%s is a prisoner and answers to the other side." % Name)
	if Status == Enums.Status.Enroute:
		return Result.fail("%s is in hyperspace." % Name)
	if rank == Enums.Rank.None:
		Rank = Enums.Rank.None
		Commanding = null
		return Result.success()
	if Attached == null:
		return Result.fail("%s is not stationed anywhere to command." % Name)
	if not CanHold(rank):
		return Result.fail("%s cannot hold the rank of %s." % [Name, JsonUtil.enum_name(Enums.Rank, rank)])
	if not RankFitsLocation(rank, Attached):
		if rank == Enums.Rank.Admiral:
			return Result.fail("An Admiral commands the ships of a fleet, and %s is not with one." % Name)
		return Result.fail("%s cannot hold the rank of %s here." % [Name, JsonUtil.enum_name(Enums.Rank, rank)])
	Rank = rank
	Commanding = Attached
	return Result.success()


## WHERE EACH RANK CAN BE HELD (manual p095): an Admiral needs a fleet.
static func RankFitsLocation(rank: int, where: Location) -> bool:
	match rank:
		Enums.Rank.None:    return true
		Enums.Rank.Admiral: return where is Fleet
	return where is Fleet or where is Planet


## "KEY CHARACTERS HAVE STRONG LOYALTY THAT WON'T WAVER ... CHARACTERS IN COMMAND
## ROLES WILL NOT BETRAY YOU" (manual p094).
func CanTurnTraitor() -> bool:
	return not IsMajor and Rank == Enums.Rank.None


func IsTraitorous() -> bool:
	return CanTurnTraitor() and Loyalty < LoyaltyManager.TraitorThreshold


## The five bands: Novice 10 · Trainee 20 · Jedi Student 80 · Jedi Knight 100 ·
## Master 120 (recovered; see the source for the corroboration).
func ForceRank() -> int:
	if JediLevel >= 120: return Enums.ForceRanking.JediMaster
	if JediLevel >= 100: return Enums.ForceRanking.JediKnight
	if JediLevel >= 80:  return Enums.ForceRanking.JediStudent
	if JediLevel >= 20:  return Enums.ForceRanking.Trainee
	if JediLevel >= 10:  return Enums.ForceRanking.Novice
	return Enums.ForceRanking.None


## "Strong enough" is entry 21, "Fast Heal: Force Rank Threshold" = 80.
func HealsFast() -> bool:
	return JediLevel >= RuleManager.Get(RuleId.FastHealForceRankThresh, Faction)


## ★ LEAVING THE THING YOU COMMAND RELIEVES YOU OF THE COMMAND (measured). One
## choke point for every way of leaving a post.
func set_Attached(value: Location) -> void:
	_attached = value
	if Rank == Enums.Rank.None or Commanding == null:
		return
	if Commanding == value:
		return
	var relieved := Rank
	var post := Commanding
	Rank = Enums.Rank.None
	Commanding = null
	print("[Command] %s is no longer %s of %s - left the post." % [Name, JsonUtil.enum_name(Enums.Rank, relieved), post.Name])
	# Day zero moves people into place before anyone holds a rank; and the
	# opponent's chain of command is not the player's business.
	if not GameSettings.IsHuman(Faction) or StrategicTickManager.Today <= 0:
		return
	EventBus.Tell(Faction, GameMessage.new(
		"%s relieved of command" % Name,
		"%s has left %s and is no longer its %s. Assign the rank again if %s is to command where they are now." % [Name, post.Name, JsonUtil.enum_name(Enums.Rank, relieved), Name],
		Enums.MessageCategory.Defense, StrategicTickManager.Today, OrderManager.SystemOf(value), self))


static func _enum_fields() -> Dictionary:
	return { "Type": Enums.UnitType, "Status": Enums.Status, "Rank": Enums.Rank }


## The C# deserialisation: case-insensitive keys, JsonStringEnumConverter for
## enums, FactionConverter for Faction.
static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	JsonUtil.hydrate(c, d, _enum_fields(), {
		"Faction": func(id: String) -> Faction: return FactionRegistry.ById(id),
		"CapturedBy": func(id: String) -> Faction: return FactionRegistry.ById(id),
	})
	return c
