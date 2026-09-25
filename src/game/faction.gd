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
## Which of the art set's side looks this faction wears (factions.json `skin`,
## docs/original-art-plan.md): the original's pictures are keyed by it, never
## by the id, so a Separatist side can wear the Empire's. Defaults to the id.
var ArtSkin: String = ""
## "The Imperial fleet", "Alliance forces": factions.json `adjective`, else the
## display name.
var Adjective: String = ""
## "Alliance", "Empire": factions.json `short_name`, where room is short (the
## map key's legend); else the display name.
var ShortName: String = ""
## "Loyalty to Alliance": factions.json `loyalty_label_short`, where room is
## short (the Command Center's left-hand menu); else the loyalty label.
var LoyaltyLabelShort: String = ""


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
	f.ArtSkin = def.ArtSkin if not def.ArtSkin.is_empty() else def.Id
	f.Adjective = def.Adjective if not def.Adjective.is_empty() else def.DisplayName
	f.ShortName = def.ShortName if not def.ShortName.is_empty() else def.DisplayName
	f.LoyaltyLabelShort = def.LoyaltyLabelShort if not def.LoyaltyLabelShort.is_empty() else def.LoyaltyLabel
	return f


## For the non-playable sides (neutral, unknown): identity and colour only.
static func Simple(id: String, display_name: String, color: Color) -> Faction:
	var f := Faction.new()
	f.Id = id
	f.DisplayName = display_name
	f.FactionColor = color
	f.ArtSkin = id
	f.Adjective = display_name
	f.ShortName = display_name
	return f


## The skin for a faction id - the loaded side's ArtSkin, or the id itself for a
## name that is no side ("unexplored", or "").
static func SkinOf(faction_id: String) -> String:
	var f: Faction = FactionRegistry.ById(faction_id) if not faction_id.is_empty() else null
	return f.ArtSkin if f != null and f.Id == faction_id else faction_id


## True when this faction's headquarters is concealed from other sides.
func HasHiddenHq() -> bool:
	return Hq != null and Hq.Kind == "hidden"


func _to_string() -> String:
	return DisplayName if DisplayName != "" else Id
