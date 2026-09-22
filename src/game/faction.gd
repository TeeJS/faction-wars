class_name Faction
extends RefCounted
## backend/Faction.cs - a side in the current match, built from pack data by
## FactionRegistry. No constants: the pack decides how many sides exist and what
## they are called. Identity is by reference - the registry owns one instance per
## id, so `==` works everywhere the C# `==` did.

var Id: String
var DisplayName: String
var FactionColor: Color

## Asymmetry knobs, straight from the pack. Engine systems branch on THESE,
## never on which faction it is.
var Hq: PackDefs.HqDef
var OccupationSupportPolicy: String
var LoyaltyLabel: String
var StartingPlanets: Array[PackDefs.StartingPlanetDef] = []
var Seed: PackDefs.FactionSeedDef
var Victory: PackDefs.VictoryDef
## The side's agent droid / adviser, as the pack names it (manual p030, Fig. 2.16).
var AgentName: String = ""


static func FromPack(def: PackDefs.FactionDef) -> Faction:
	var f := Faction.new()
	f.Id = def.Id
	f.DisplayName = def.DisplayName
	f.FactionColor = FactionRegistry.ParseColor(def.ColorHex)
	f.Hq = def.Hq
	f.OccupationSupportPolicy = def.OccupationSupportPolicy
	f.LoyaltyLabel = def.LoyaltyLabel
	f.StartingPlanets = def.StartingPlanets if def.StartingPlanets != null else []
	f.Seed = def.Seed
	f.Victory = def.Victory
	f.AgentName = def.AgentName
	return f


## For the non-playable sides (neutral, unknown): identity and colour only.
static func Simple(id: String, display_name: String, color: Color) -> Faction:
	var f := Faction.new()
	f.Id = id
	f.DisplayName = display_name
	f.FactionColor = color
	return f


## True when this faction's headquarters is concealed from other sides.
func HasHiddenHq() -> bool:
	return Hq != null and Hq.Kind == "hidden"


func _to_string() -> String:
	return DisplayName if DisplayName != "" else Id
