class_name CatalogDtos
extends RefCounted
## The shipped-table DTOs, one inner class per C# class, each with the exact
## defaults and nullability of its C# declaration. Where C# says `int?`, the
## field here is Variant and stays null (HANDOFF risk 8).


## backend/GalaxyFactory.cs - sectors_data.json
class SectorJsonData:
	var SectorId: int
	var Name: String
	var GalaxyRing: int
	var StartsNeutral: bool
	var MapCenterX: int
	var MapCenterY: int

	static func from_dict(d: Dictionary) -> SectorJsonData:
		var o := SectorJsonData.new()
		o.SectorId = JsonUtil.int_or(d, "SectorId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.GalaxyRing = JsonUtil.int_or(d, "GalaxyRing")
		o.StartsNeutral = JsonUtil.bool_or(d, "StartsNeutral")
		o.MapCenterX = JsonUtil.int_or(d, "MapCenterX")
		o.MapCenterY = JsonUtil.int_or(d, "MapCenterY")
		return o


## backend/GalaxyFactory.cs - planets_data.json. No energy/materials: rolled per game.
class PlanetJsonData:
	var Name: String
	var PlanetId: int
	var SectorId: int
	var MapX: int
	var MapY: int
	var StartsInhabited: bool

	static func from_dict(d: Dictionary) -> PlanetJsonData:
		var o := PlanetJsonData.new()
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.PlanetId = JsonUtil.int_or(d, "PlanetId")
		o.SectorId = JsonUtil.int_or(d, "SectorId")
		o.MapX = JsonUtil.int_or(d, "MapX")
		o.MapY = JsonUtil.int_or(d, "MapY")
		o.StartsInhabited = JsonUtil.bool_or(d, "StartsInhabited")
		return o


## backend/MissionCatalog.cs - missions.json (MISSNSD.DAT as data)
class MissionDef:
	var MissionId: int
	var Name: String
	var StringId: int
	var Alliance: int
	var Empire: int
	var SpecForceMask: int
	var SpecForces: Array[String] = []
	var LengthBase: int
	var LengthSpread: int
	var CanContinue: int
	var Scripted: int
	var TargetFriendly: int
	var TargetNeutral: int
	var TargetHostile: int
	var AbortOnBlockade: int
	var CanEscape: int
	var CanKill: int

	static func from_dict(d: Dictionary) -> MissionDef:
		var o := MissionDef.new()
		o.MissionId = JsonUtil.int_or(d, "MissionId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.StringId = JsonUtil.int_or(d, "StringId")
		o.Alliance = JsonUtil.int_or(d, "Alliance")
		o.Empire = JsonUtil.int_or(d, "Empire")
		o.SpecForceMask = JsonUtil.int_or(d, "SpecForceMask")
		o.SpecForces = JsonUtil.str_list(d, "SpecForces", [])
		o.LengthBase = JsonUtil.int_or(d, "LengthBase")
		o.LengthSpread = JsonUtil.int_or(d, "LengthSpread")
		o.CanContinue = JsonUtil.int_or(d, "CanContinue")
		o.Scripted = JsonUtil.int_or(d, "Scripted")
		o.TargetFriendly = JsonUtil.int_or(d, "TargetFriendly")
		o.TargetNeutral = JsonUtil.int_or(d, "TargetNeutral")
		o.TargetHostile = JsonUtil.int_or(d, "TargetHostile")
		o.AbortOnBlockade = JsonUtil.int_or(d, "AbortOnBlockade")
		o.CanEscape = JsonUtil.int_or(d, "CanEscape")
		o.CanKill = JsonUtil.int_or(d, "CanKill")
		return o


## backend/RuleManager.cs - game_rules.json (GNPRTB.DAT's 213 constants).
## By_Faction: faction id -> difficulty -> value. The JSON key is "by_faction";
## the C# property is By_Faction and the loader is case-insensitive.
class GameRuleData:
	var EntryId: int
	var Name: String
	var ParameterId: int
	var Development: int
	var Multiplayer: int
	var By_Faction: Dictionary = {}

	static func from_dict(d: Dictionary) -> GameRuleData:
		var o := GameRuleData.new()
		o.EntryId = JsonUtil.int_or(d, "EntryId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.ParameterId = JsonUtil.int_or(d, "ParameterId")
		o.Development = JsonUtil.int_or(d, "Development")
		o.Multiplayer = JsonUtil.int_or(d, "Multiplayer")
		var bf: Variant = JsonUtil.get_ci(d, "By_Faction")
		if bf != null:
			for faction_id in bf.keys():
				o.By_Faction[str(faction_id)] = JsonUtil.str_int_dict(bf, str(faction_id))
		return o


## backend/SideLotteryManager.cs - side_lottery.json (SDPRTB).
## By_Faction: faction id -> difficulty -> {faction id -> value}.
class SideRuleData:
	var EntryId: int
	var Name: String
	var GroupId: int
	## Easy / Medium / Hard per player side (manual p067: the three campaigns).
	var By_Faction: Dictionary = {}
	## The two pairs the binary carries beyond the three difficulties. The manual
	## has no fourth difficulty; open-rebellion's dumper labels slots 3-4 dev and
	## slots 17-18 multiplayer, the same reading the rules parser chose for
	## GNPRTB. Unsettled at the source (docs/m0-audit.md question 2).
	var Dev: Dictionary = {}
	var Mp: Dictionary = {}

	static func from_dict(d: Dictionary) -> SideRuleData:
		var o := SideRuleData.new()
		o.EntryId = JsonUtil.int_or(d, "EntryId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.GroupId = JsonUtil.int_or(d, "GroupId")
		var bf: Variant = JsonUtil.get_ci(d, "By_Faction")
		if bf != null:
			for faction_id in bf.keys():
				var by_diff := {}
				var inner: Variant = bf[faction_id]
				if inner != null:
					for diff in inner.keys():
						by_diff[str(diff)] = JsonUtil.str_int_dict(inner, str(diff))
				o.By_Faction[str(faction_id)] = by_diff
		o.Dev = JsonUtil.str_int_dict(d, "dev")
		o.Mp = JsonUtil.str_int_dict(d, "mp")
		return o


## backend/FacilityCatalog.cs - production_facilities.json + defensive_facilities.json
class FacilityStatRule:
	var Id: int
	var FamilyId: int
	var Name: String
	var Tier: int = 1
	var BuildableBy: Array[String] = []
	var ConstructionCost: int
	var MaintenanceCost: int
	var ResearchOrder: int
	var ResearchCost: int
	var BombardmentDefense: int
	var ProcessingRate: int
	var ShieldStrength: int
	var WeaponRating: int

	static func from_dict(d: Dictionary) -> FacilityStatRule:
		var o := FacilityStatRule.new()
		o.Id = JsonUtil.int_or(d, "Id")
		o.FamilyId = JsonUtil.int_or(d, "FamilyId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.Tier = JsonUtil.int_or(d, "Tier", 1)
		o.BuildableBy = JsonUtil.str_list(d, "BuildableBy", [])
		o.ConstructionCost = JsonUtil.int_or(d, "ConstructionCost")
		o.MaintenanceCost = JsonUtil.int_or(d, "MaintenanceCost")
		o.ResearchOrder = JsonUtil.int_or(d, "ResearchOrder")
		o.ResearchCost = JsonUtil.int_or(d, "ResearchCost")
		o.BombardmentDefense = JsonUtil.int_or(d, "BombardmentDefense")
		o.ProcessingRate = JsonUtil.int_or(d, "ProcessingRate")
		o.ShieldStrength = JsonUtil.int_or(d, "ShieldStrength")
		o.WeaponRating = JsonUtil.int_or(d, "WeaponRating")
		return o

	## A facility nobody can build is not offered.
	func CanBeBuiltBy(f: Faction) -> bool:
		return f != null and BuildableBy != null and BuildableBy.has(f.Id)


## backend/Facility.cs - defensive_facilities.json as SeedManager reads it
class DefenseStatRule:
	var FamilyId: int
	var Tier: int
	var ConstructionCost: int
	var MaintenanceCost: int
	var WeaponRating: int
	var ShieldStrength: int

	static func from_dict(d: Dictionary) -> DefenseStatRule:
		var o := DefenseStatRule.new()
		o.FamilyId = JsonUtil.int_or(d, "FamilyId")
		o.Tier = JsonUtil.int_or(d, "Tier")
		o.ConstructionCost = JsonUtil.int_or(d, "ConstructionCost")
		o.MaintenanceCost = JsonUtil.int_or(d, "MaintenanceCost")
		o.WeaponRating = JsonUtil.int_or(d, "WeaponRating")
		o.ShieldStrength = JsonUtil.int_or(d, "ShieldStrength")
		return o


## backend/SeedManager.cs - military_units.json. Stat fields are NULLABLE because
## the file omits stats that do not apply to a unit class; consumers coalesce to
## 0 at the point of use, never here.
class UnitStatRule:
	var Id: int
	var FamilyId: int
	var Name: String
	var Type: String              # "CapitalShip" | "Fighter" | "Troop" | "SpecForce"
	var BuildableBy: Array[String] = []
	var ConstructionCost: int
	var MaintenanceCost: int
	var Detection: int
	var ResearchOrder: int
	var ResearchCost: int
	var DiplomacyRating: Variant = null
	var EspionageRating: Variant = null
	var CombatRating: Variant = null
	var LeadershipRating: Variant = null
	var Shield: Variant = null
	var Sublight: Variant = null
	var Hyperdrive: Variant = null
	var Hull: Variant = null
	var Attack: Variant = null
	var Defense: Variant = null
	var Bombardment: Variant = null
	var BombardmentDefense: Variant = null
	var FighterCapacity: Variant = null
	var TroopCapacity: Variant = null
	var Turbolaser: Variant = null
	var LaserRating: Variant = null
	var IonCannon: Variant = null
	var Torpedoes: Variant = null
	var Maneuverability: Variant = null
	var HyperdriveDamaged: Variant = null
	var TurbolaserFore: Variant = null
	var TurbolaserAft: Variant = null
	var TurbolaserStarboard: Variant = null
	var TurbolaserPort: Variant = null
	var IonCannonFore: Variant = null
	var IonCannonAft: Variant = null
	var IonCannonStarboard: Variant = null
	var IonCannonPort: Variant = null
	var LaserFore: Variant = null
	var LaserAft: Variant = null
	var LaserStarboard: Variant = null
	var LaserPort: Variant = null
	var TurbolaserRange: Variant = null
	var IonCannonRange: Variant = null
	var LaserRange: Variant = null
	var TorpedoRange: Variant = null
	var TractorPower: Variant = null
	var TractorRange: Variant = null
	var GravityWell: Variant = null
	var InterdictionStrength: Variant = null
	var DamageControl: Variant = null
	var WeaponRecharge: Variant = null
	var ShieldRecharge: Variant = null
	var SquadronSize: Variant = null

	const NULLABLE := [
		"DiplomacyRating", "EspionageRating", "CombatRating", "LeadershipRating",
		"Shield", "Sublight", "Hyperdrive", "Hull", "Attack", "Defense", "Bombardment",
		"BombardmentDefense", "FighterCapacity", "TroopCapacity", "Turbolaser", "LaserRating",
		"IonCannon", "Torpedoes", "Maneuverability", "HyperdriveDamaged",
		"TurbolaserFore", "TurbolaserAft", "TurbolaserStarboard", "TurbolaserPort",
		"IonCannonFore", "IonCannonAft", "IonCannonStarboard", "IonCannonPort",
		"LaserFore", "LaserAft", "LaserStarboard", "LaserPort",
		"TurbolaserRange", "IonCannonRange", "LaserRange", "TorpedoRange",
		"TractorPower", "TractorRange", "GravityWell", "InterdictionStrength",
		"DamageControl", "WeaponRecharge", "ShieldRecharge", "SquadronSize",
	]

	static func from_dict(d: Dictionary) -> UnitStatRule:
		var o := UnitStatRule.new()
		o.Id = JsonUtil.int_or(d, "Id")
		o.FamilyId = JsonUtil.int_or(d, "FamilyId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.Type = JsonUtil.str_or(d, "Type", "")
		o.BuildableBy = JsonUtil.str_list(d, "BuildableBy", [])
		o.ConstructionCost = JsonUtil.int_or(d, "ConstructionCost")
		o.MaintenanceCost = JsonUtil.int_or(d, "MaintenanceCost")
		o.Detection = JsonUtil.int_or(d, "Detection")
		o.ResearchOrder = JsonUtil.int_or(d, "ResearchOrder")
		o.ResearchCost = JsonUtil.int_or(d, "ResearchCost")
		for f in NULLABLE:
			o.set(f, JsonUtil.int_or_null(d, f))
		return o


## frontend/MilitaryDataEditor.cs - the editor's own view of military_units.json,
## explicit [JsonPropertyName] on every field, all stats nullable.
class MilitaryUnit:
	var Id: int
	var FamilyId: int
	var StringId: int
	var Name: String
	var Type: String
	var BuildableBy: Array[String] = []
	var ConstructionCost: int
	var MaintenanceCost: int
	var Detection: int
	var Shield: Variant = null
	var Sublight: Variant = null
	var Hyperdrive: Variant = null
	var Turbolaser: Variant = null
	var IonCannon: Variant = null
	var LaserRating: Variant = null
	var Hull: Variant = null
	var Bombardment: Variant = null
	var FighterCapacity: Variant = null
	var TroopCapacity: Variant = null
	var Torpedoes: Variant = null
	var BombardmentDefense: Variant = null
	var Attack: Variant = null
	var Defense: Variant = null

	const NULLABLE := [
		"Shield", "Sublight", "Hyperdrive", "Turbolaser", "IonCannon", "LaserRating", "Hull",
		"Bombardment", "FighterCapacity", "TroopCapacity", "Torpedoes", "BombardmentDefense",
		"Attack", "Defense",
	]

	static func from_dict(d: Dictionary) -> MilitaryUnit:
		var o := MilitaryUnit.new()
		o.Id = JsonUtil.int_or(d, "Id")
		o.FamilyId = JsonUtil.int_or(d, "FamilyId")
		o.StringId = JsonUtil.int_or(d, "StringId")
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.Type = JsonUtil.str_or(d, "Type", "")
		o.BuildableBy = JsonUtil.str_list(d, "BuildableBy", [])
		o.ConstructionCost = JsonUtil.int_or(d, "ConstructionCost")
		o.MaintenanceCost = JsonUtil.int_or(d, "MaintenanceCost")
		o.Detection = JsonUtil.int_or(d, "Detection")
		for f in NULLABLE:
			o.set(f, JsonUtil.int_or_null(d, f))
		return o


## backend/LogisticsModels.cs - day_zero_logistics.json
class LogisticsAsset:
	var FamilyId: int
	var FamilyName: String
	var AssetId: int

	static func from_dict(d: Dictionary) -> LogisticsAsset:
		var o := LogisticsAsset.new()
		o.FamilyId = JsonUtil.int_or(d, "FamilyId")
		o.FamilyName = JsonUtil.str_or(d, "FamilyName", "")
		o.AssetId = JsonUtil.int_or(d, "AssetId")
		return o


class LogisticsEntry:
	var ParentId: int
	var ProbabilityThreshold: int
	var SpawnChancePercent: int          # SYFC files
	var Asset: LogisticsAsset            # SYFC files
	var Multiplier: int = 1              # CMUN / FACL files
	var Assets: Variant = null           # List<LogisticsAsset>, no initialiser -> null

	static func from_dict(d: Dictionary) -> LogisticsEntry:
		var o := LogisticsEntry.new()
		o.ParentId = JsonUtil.int_or(d, "ParentId")
		o.ProbabilityThreshold = JsonUtil.int_or(d, "ProbabilityThreshold")
		o.SpawnChancePercent = JsonUtil.int_or(d, "SpawnChancePercent")
		var a: Variant = JsonUtil.get_ci(d, "Asset")
		o.Asset = LogisticsAsset.from_dict(a) if a != null else null
		o.Multiplier = JsonUtil.int_or(d, "Multiplier", 1)
		var list: Variant = JsonUtil.get_ci(d, "Assets")
		if list != null:
			var assets: Array[LogisticsAsset] = []
			for e in list:
				assets.append(LogisticsAsset.from_dict(e))
			o.Assets = assets
		return o


class LogisticsFile:
	var Name: String                     # stamped from the dictionary key at load
	var Type: String                     # a CATEGORY, not a name
	var Description: String
	var Entries: Variant = null          # List<LogisticsEntry>, no initialiser -> null

	static func from_dict(d: Dictionary) -> LogisticsFile:
		var o := LogisticsFile.new()
		o.Name = JsonUtil.str_or(d, "Name", "")
		o.Type = JsonUtil.str_or(d, "Type", "")
		o.Description = JsonUtil.str_or(d, "Description", "")
		var list: Variant = JsonUtil.get_ci(d, "Entries")
		if list != null:
			var entries: Array[LogisticsEntry] = []
			for e in list:
				entries.append(LogisticsEntry.from_dict(e))
			o.Entries = entries
		return o


## backend/MissionTableManager.cs - mission_tables.json (the *MSTB step tables)
class MissionTableEntry:
	var Id: int
	var Field2: int
	var Threshold: int
	var Value: int

	static func from_dict(d: Dictionary) -> MissionTableEntry:
		var o := MissionTableEntry.new()
		o.Id = JsonUtil.int_or(d, "Id")
		o.Field2 = JsonUtil.int_or(d, "Field2")
		o.Threshold = JsonUtil.int_or(d, "Threshold")
		o.Value = JsonUtil.int_or(d, "Value")
		return o


class MissionTableData:
	var Entries_Count: int
	var Info: String
	var Description: String
	var Entries: Array[MissionTableEntry] = []

	static func from_dict(d: Dictionary) -> MissionTableData:
		var o := MissionTableData.new()
		o.Entries_Count = JsonUtil.int_or(d, "Entries_Count")
		o.Info = JsonUtil.str_or(d, "Info", "")
		o.Description = JsonUtil.str_or(d, "Description", "")
		var list: Variant = JsonUtil.get_ci(d, "Entries")
		if list != null:
			for e in list:
				o.Entries.append(MissionTableEntry.from_dict(e))
		return o


## backend/UprisingTable.cs - uprising_start.json / uprising_end.json
class IntTableEntry:
	var Id: int
	var Threshold: int
	var Value: int

	static func from_dict(d: Dictionary) -> IntTableEntry:
		var o := IntTableEntry.new()
		o.Id = JsonUtil.int_or(d, "Id")
		o.Threshold = JsonUtil.int_or(d, "Threshold")
		o.Value = JsonUtil.int_or(d, "Value")
		return o


class IntTable:
	var Entries: Variant = null          # List<IntTableEntry>, no initialiser -> null

	static func from_dict(d: Dictionary) -> IntTable:
		var o := IntTable.new()
		var list: Variant = JsonUtil.get_ci(d, "Entries")
		if list != null:
			var entries: Array[IntTableEntry] = []
			for e in list:
				entries.append(IntTableEntry.from_dict(e))
			o.Entries = entries
		return o
