class_name PackDefs
extends RefCounted
## backend/Packs/PackLoader.cs - the plain data shapes read from a faction pack.
## The pack files are snake_case (JsonNamingPolicy.SnakeCaseLower on the C# side),
## so every hydrator here reads the snake_case key into the PascalCase field.


class HqDef:
	var Kind: String          # "fixed" | "hidden"
	var Planet: String        # fixed: the planet it sits on
	var Placement: String     # hidden: "random_rim", or a planet name
	var Movable: bool

	static func from_dict(d: Variant) -> HqDef:
		if d == null:
			return null
		var o := HqDef.new()
		o.Kind = JsonUtil.str_or(d, "kind", "")
		o.Planet = JsonUtil.str_or(d, "planet", "")
		o.Placement = JsonUtil.str_or(d, "placement", "")
		o.Movable = JsonUtil.bool_or(d, "movable")
		return o


class StartingPlanetDef:
	var Planet: String
	var Support: int          # percent loyal to THIS faction
	var Explored: bool
	var Garrison: String      # optional logistics table

	static func from_dict(d: Dictionary) -> StartingPlanetDef:
		var o := StartingPlanetDef.new()
		o.Planet = JsonUtil.str_or(d, "planet", "")
		o.Support = JsonUtil.int_or(d, "support")
		o.Explored = JsonUtil.bool_or(d, "explored")
		o.Garrison = JsonUtil.str_or(d, "garrison", "")
		return o


class FactionSeedDef:
	var HqFacilities: String
	var HqGarrison: String
	var Fleet: String
	var ProceduralFleet: String

	static func from_dict(d: Variant) -> FactionSeedDef:
		if d == null:
			return null
		var o := FactionSeedDef.new()
		o.HqFacilities = JsonUtil.str_or(d, "hq_facilities", "")
		o.HqGarrison = JsonUtil.str_or(d, "hq_garrison", "")
		o.Fleet = JsonUtil.str_or(d, "fleet", "")
		o.ProceduralFleet = JsonUtil.str_or(d, "procedural_fleet", "")
		return o


## WHAT THIS SIDE MUST ACHIEVE TO WIN - manual p011 and p162. Only the character
## list lives here; the headquarters half is derived from the opponent's HqDef.
class VictoryDef:
	var CaptureCharacters: Array[String] = []

	static func from_dict(d: Variant) -> VictoryDef:
		if d == null:
			return null
		var o := VictoryDef.new()
		o.CaptureCharacters = JsonUtil.str_list(d, "capture_characters", [])
		return o


class FactionDef:
	var Id: String
	var DisplayName: String
	var ColorHex: String        # C# ColorHex, JSON "color" - Color is a builtin type name
	var LoyaltyLabel: String
	var Hq: HqDef
	var OccupationSupportPolicy: String
	var StartingPlanets: Array[StartingPlanetDef] = []
	var Seed: FactionSeedDef
	var Victory: VictoryDef

	static func from_dict(d: Dictionary) -> FactionDef:
		var o := FactionDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.ColorHex = JsonUtil.str_or(d, "color", "")
		o.LoyaltyLabel = JsonUtil.str_or(d, "loyalty_label", "")
		o.Hq = HqDef.from_dict(JsonUtil.get_ci(d, "hq"))
		o.OccupationSupportPolicy = JsonUtil.str_or(d, "occupation_support_policy", "")
		var sp: Variant = JsonUtil.get_ci(d, "starting_planets")
		if sp != null:
			for e in sp:
				o.StartingPlanets.append(StartingPlanetDef.from_dict(e))
		o.Seed = FactionSeedDef.from_dict(JsonUtil.get_ci(d, "seed"))
		o.Victory = VictoryDef.from_dict(JsonUtil.get_ci(d, "victory"))
		return o


class NeutralDef:
	var Id: String
	var DisplayName: String
	var ColorHex: String

	static func from_dict(d: Variant) -> NeutralDef:
		if d == null:
			return null
		var o := NeutralDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.ColorHex = JsonUtil.str_or(d, "color", "")
		return o


class PackSetupDef:
	var DifficultyDefault: String
	var GalaxySizes: Array[String] = []

	static func from_dict(d: Variant) -> PackSetupDef:
		if d == null:
			return null
		var o := PackSetupDef.new()
		o.DifficultyDefault = JsonUtil.str_or(d, "difficulty_default", "")
		o.GalaxySizes = JsonUtil.str_list(d, "galaxy_sizes", [])
		return o


class PackManifest:
	var Id: String
	var DisplayName: String
	var SchemaVersion: int
	var FactionCount: int
	var Neutral: NeutralDef
	var UnexploredColor: String
	## SCHEMA.md section 2 (Q3, decided): the galaxy backdrop, relative to the
	## pack folder. Declared here so the engine never assumes a filename.
	var MapImage: String
	var Setup: PackSetupDef

	static func from_dict(d: Dictionary) -> PackManifest:
		var o := PackManifest.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.SchemaVersion = JsonUtil.int_or(d, "schema_version")
		o.FactionCount = JsonUtil.int_or(d, "faction_count")
		o.Neutral = NeutralDef.from_dict(JsonUtil.get_ci(d, "neutral"))
		o.UnexploredColor = JsonUtil.str_or(d, "unexplored_color", "")
		o.MapImage = JsonUtil.str_or(d, "map_image", "")
		o.Setup = PackSetupDef.from_dict(JsonUtil.get_ci(d, "setup"))
		return o


class FactionsFile:
	var Factions: Array[FactionDef] = []

	static func from_dict(d: Dictionary) -> FactionsFile:
		var o := FactionsFile.new()
		var list: Variant = JsonUtil.get_ci(d, "factions")
		if list != null:
			for e in list:
				o.Factions.append(FactionDef.from_dict(e))
		return o


## SCHEMA.md section 4. Generated by tools/build-map-json.py from the two data/
## files - never hand-edited, or the next regeneration reverts it.
## ORDER IS LOAD-BEARING: GalaxyFactory builds sectors in file order and appends
## each planet to its sector in file order, and day zero consumes the PRNG in
## that order. Both lists stay in the order the file declares them.
class SectorDef:
	var Id: String
	var DisplayName: String
	var Ring: int             # 1 = Core, >1 = Rim
	var StartsNeutral: bool
	var MapX: int
	var MapY: int
	## The SMALLEST galaxy size this sector appears in; sizes are cumulative.
	## Replaces the twenty literal sector names GalaxyFactory used to hold.
	var MinSize: String
	var IntelTier: String     # [later] - nothing reads this yet
	var SourceId: int         # the original SectorId, for traceability

	static func from_dict(d: Dictionary) -> SectorDef:
		var o := SectorDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.Ring = JsonUtil.int_or(d, "ring")
		o.StartsNeutral = JsonUtil.bool_or(d, "starts_neutral")
		var m: Variant = JsonUtil.get_ci(d, "map")
		if m is Dictionary:
			o.MapX = JsonUtil.int_or(m, "x")
			o.MapY = JsonUtil.int_or(m, "y")
		o.MinSize = JsonUtil.str_or(d, "min_size", "")
		o.IntelTier = JsonUtil.str_or(d, "intel_tier", "")
		o.SourceId = JsonUtil.int_or(d, "source_id")
		return o


class PlanetDef:
	var Id: String
	var DisplayName: String
	var Sector: String        # a SectorDef id
	var StartsInhabited: bool
	var MapX: int
	var MapY: int
	var ArtworkId: int        # not read by the engine today; pack content
	var SourceId: int

	static func from_dict(d: Dictionary) -> PlanetDef:
		var o := PlanetDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.Sector = JsonUtil.str_or(d, "sector", "")
		o.StartsInhabited = JsonUtil.bool_or(d, "starts_inhabited")
		var m: Variant = JsonUtil.get_ci(d, "map")
		if m is Dictionary:
			o.MapX = JsonUtil.int_or(m, "x")
			o.MapY = JsonUtil.int_or(m, "y")
		o.ArtworkId = JsonUtil.int_or(d, "artwork_id")
		o.SourceId = JsonUtil.int_or(d, "source_id")
		return o


class MapFile:
	var Sectors: Array[SectorDef] = []
	var Planets: Array[PlanetDef] = []

	static func from_dict(d: Dictionary) -> MapFile:
		var o := MapFile.new()
		var secs: Variant = JsonUtil.get_ci(d, "sectors")
		if secs != null:
			for e in secs:
				o.Sectors.append(SectorDef.from_dict(e))
		var plts: Variant = JsonUtil.get_ci(d, "planets")
		if plts != null:
			for e in plts:
				o.Planets.append(PlanetDef.from_dict(e))
		return o


## SCHEMA.md section 7. Generated by tools/build-characters-json.py from the two
## data/ tables. ORDER IS LOAD-BEARING: majors first, then minors, because day
## zero walks the roster in that order consuming the PRNG as it goes.
class RatingDef:
	var Base: int
	var Var: int

	static func from_dict(d: Variant) -> RatingDef:
		var o := RatingDef.new()
		if d is Dictionary:
			o.Base = JsonUtil.int_or(d, "base")
			o.Var = JsonUtil.int_or(d, "var")
		return o


## The hidden, trainable aptitude - "the Force" in this pack (SCHEMA section 12
## Q5). The engine holds the ranked bands and their thresholds; what the bands
## are CALLED is pack display content.
class SpecialPowerDef:
	var Probability: int
	var IsKnownUser: bool
	var LevelBase: int
	var LevelVar: int
	var CanTrain: bool

	static func from_dict(d: Variant) -> SpecialPowerDef:
		var o := SpecialPowerDef.new()
		if d is Dictionary:
			o.Probability = JsonUtil.int_or(d, "probability")
			o.IsKnownUser = JsonUtil.bool_or(d, "is_known_user")
			o.CanTrain = JsonUtil.bool_or(d, "can_train")
			var lvl: Variant = JsonUtil.get_ci(d, "level")
			if lvl is Dictionary:
				o.LevelBase = JsonUtil.int_or(lvl, "base")
				o.LevelVar = JsonUtil.int_or(lvl, "var")
		return o


class CharacterDef:
	var Id: String
	var DisplayName: String
	var FactionId: String
	var IsMajor: bool
	var Ratings: Dictionary = {}      # rating id -> RatingDef
	var CanCommand: Array[String] = []
	var WontBetray: bool
	var SpecialPower: SpecialPowerDef
	var SourceId: int
	var StringId: int

	static func from_dict(d: Dictionary) -> CharacterDef:
		var o := CharacterDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.FactionId = JsonUtil.str_or(d, "faction", "")
		o.IsMajor = JsonUtil.bool_or(d, "is_major")
		var r: Variant = JsonUtil.get_ci(d, "ratings")
		if r is Dictionary:
			for k in r.keys():
				o.Ratings[str(k)] = RatingDef.from_dict(r[k])
		o.CanCommand = JsonUtil.str_list(d, "can_command", [])
		o.WontBetray = JsonUtil.bool_or(d, "wont_betray")
		o.SpecialPower = SpecialPowerDef.from_dict(JsonUtil.get_ci(d, "special_power"))
		o.SourceId = JsonUtil.int_or(d, "source_id")
		o.StringId = JsonUtil.int_or(d, "string_id")
		return o

	## A rating's base/var, or a zeroed one when the pack does not declare it.
	func rating(id: String) -> RatingDef:
		return Ratings[id] if Ratings.has(id) else RatingDef.new()


class CharactersFile:
	var Characters: Array[CharacterDef] = []

	static func from_dict(d: Dictionary) -> CharactersFile:
		var o := CharactersFile.new()
		var list: Variant = JsonUtil.get_ci(d, "characters")
		if list != null:
			for e in list:
				o.Characters.append(CharacterDef.from_dict(e))
		return o


## SCHEMA.md section 5. Generated by tools/build-facilities-json.py.
## THIS FILE REPLACES Enums.FacilityType. The engine selects on ROLES - it asks
## what a facility does, never what it is called.
class FacilityDef:
	var Id: String
	var DisplayName: String
	## Tiers are variants of ONE family: Shipyard and Advanced Shipyard share the
	## family "shipyard" at tiers 1 and 2, and the catalog indexes on the pair.
	var Family: String
	var Tier: int
	var Roles: Array[String] = []
	var BuildableBy: Array[String] = []
	var ConstructionCost: int
	var MaintenanceCost: int
	var ResearchOrder: int
	var ResearchCost: int
	## Open map - the engine has no built-in stat vocabulary. Absorbs the
	## production/defensive column split (processing_rate vs weapon_rating).
	var Stats: Dictionary = {}
	var SourceFamilyId: int

	static func from_dict(d: Dictionary) -> FacilityDef:
		var o := FacilityDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.Family = JsonUtil.str_or(d, "family", "")
		o.Tier = JsonUtil.int_or(d, "tier", 1)
		o.Roles = JsonUtil.str_list(d, "roles", [])
		o.BuildableBy = JsonUtil.str_list(d, "buildable_by", [])
		o.ConstructionCost = JsonUtil.int_or(d, "construction_cost")
		o.MaintenanceCost = JsonUtil.int_or(d, "maintenance_cost")
		o.ResearchOrder = JsonUtil.int_or(d, "research_order")
		o.ResearchCost = JsonUtil.int_or(d, "research_cost")
		var st: Variant = JsonUtil.get_ci(d, "stats")
		if st is Dictionary:
			for k in st.keys():
				o.Stats[str(k)] = st[k]
		o.SourceFamilyId = JsonUtil.int_or(d, "source_family_id")
		return o

	func HasRole(role: String) -> bool:
		return Roles.has(role)

	## An absent buildable_by means every side may build it (SCHEMA.md section 5).
	func CanBeBuiltBy(f: Faction) -> bool:
		return f != null and (BuildableBy.is_empty() or BuildableBy.has(f.Id))

	## A named stat, or `fallback` when this pack does not declare it. Absence is
	## the encoding - the tables omit inapplicable stats rather than writing null.
	func stat(name: String, fallback: int = 0) -> int:
		return int(Stats[name]) if Stats.has(name) else fallback


class FacilitiesFile:
	var Facilities: Array[FacilityDef] = []

	static func from_dict(d: Dictionary) -> FacilitiesFile:
		var o := FacilitiesFile.new()
		var list: Variant = JsonUtil.get_ci(d, "facilities")
		if list != null:
			for e in list:
				o.Facilities.append(FacilityDef.from_dict(e))
		return o


## SCHEMA.md section 6 and its weapons subsection. Generated by
## tools/build-units-json.py. WEAPON CLASSES ARE PACK DATA - the engine asks
## what a weapon DOES (its roles), never whether it is a turbolaser.
class WeaponDef:
	var Id: String
	var DisplayName: String
	var Roles: Array[String] = []
	## Whether this weapon fires per firing arc. A torpedo does not.
	var HasArcs: bool

	static func from_dict(d: Dictionary) -> WeaponDef:
		var o := WeaponDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.Roles = JsonUtil.str_list(d, "roles", [])
		o.HasArcs = JsonUtil.bool_or(d, "arcs")
		return o

	func HasRole(role: String) -> bool:
		return Roles.has(role)


class WeaponsFile:
	var Weapons: Array[WeaponDef] = []

	static func from_dict(d: Dictionary) -> WeaponsFile:
		var o := WeaponsFile.new()
		var list: Variant = JsonUtil.get_ci(d, "weapons")
		if list != null:
			for e in list:
				o.Weapons.append(WeaponDef.from_dict(e))
		return o


## One weapon fitted to one unit: how much it throws, and how far.
class UnitWeaponDef:
	## Indexed by Enums.ShipArc - Fore, Aft, Starboard, Port. Empty for a
	## weapon the pack declares as arc-less.
	var Arcs: Array[int] = []
	## For an arc-less weapon (torpedoes), the whole payload.
	var Amount: int
	## How far it reaches. Named Reach, not Range: `Range` is a native Godot
	## class and a member of that name shadows it.
	var Reach: int

	static func from_dict(d: Variant) -> UnitWeaponDef:
		var o := UnitWeaponDef.new()
		if d is Dictionary:
			var a: Variant = JsonUtil.get_ci(d, "arcs")
			if a is Dictionary:
				o.Arcs = [JsonUtil.int_or(a, "fore"), JsonUtil.int_or(a, "aft"),
					JsonUtil.int_or(a, "starboard"), JsonUtil.int_or(a, "port")]
			o.Amount = JsonUtil.int_or(d, "amount")
			o.Reach = JsonUtil.int_or(d, "range")
		return o

	## This weapon's throw in one arc. An ARC-LESS weapon contributes NOTHING
	## here - a torpedo is not part of a broadside, and counting its payload as
	## arc firepower both inflates the shot and skews the divisor it is averaged
	## by. Read arc-less payloads with total().
	func in_arc(arc: int) -> int:
		if Arcs.is_empty():
			return 0
		return Arcs[arc] if arc >= 0 and arc < Arcs.size() else 0

	## Every arc summed - the "Turbolaser"/"IonCannon"/"LaserRating" columns the
	## original table carried, which were exactly this and are no longer stored.
	func total() -> int:
		if Arcs.is_empty():
			return Amount
		var n := 0
		for v in Arcs:
			n += v
		return n


class UnitDef:
	var Id: String
	var DisplayName: String
	## "capital_ship" | "fighter" | "troop" | "spec_force". Which producer and
	## which queue a unit uses is engine structure, so this stays a small set.
	var Kind: String
	var BuildableBy: Array[String] = []
	var ConstructionCost: int
	var MaintenanceCost: int
	var ResearchOrder: int
	var ResearchCost: int
	var Weapons: Dictionary = {}      # weapon id -> UnitWeaponDef
	var Stats: Dictionary = {}
	var SourceFamilyId: int
	var SourceId: int
	var StringId: int

	static func from_dict(d: Dictionary) -> UnitDef:
		var o := UnitDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.Kind = JsonUtil.str_or(d, "kind", "")
		o.BuildableBy = JsonUtil.str_list(d, "buildable_by", [])
		o.ConstructionCost = JsonUtil.int_or(d, "construction_cost")
		o.MaintenanceCost = JsonUtil.int_or(d, "maintenance_cost")
		o.ResearchOrder = JsonUtil.int_or(d, "research_order")
		o.ResearchCost = JsonUtil.int_or(d, "research_cost")
		var w: Variant = JsonUtil.get_ci(d, "weapons")
		if w is Dictionary:
			for k in w.keys():
				o.Weapons[str(k)] = UnitWeaponDef.from_dict(w[k])
		var st: Variant = JsonUtil.get_ci(d, "stats")
		if st is Dictionary:
			for k in st.keys():
				o.Stats[str(k)] = st[k]
		o.SourceFamilyId = JsonUtil.int_or(d, "source_family_id")
		o.SourceId = JsonUtil.int_or(d, "source_id")
		o.StringId = JsonUtil.int_or(d, "string_id")
		return o

	func CanBeBuiltBy(f: Faction) -> bool:
		return f != null and (BuildableBy.is_empty() or BuildableBy.has(f.Id))

	## A named stat, or `fallback` where this pack declares none. Absence is the
	## encoding: the tables omit inapplicable stats rather than writing null.
	func stat(name: String, fallback: int = 0) -> int:
		return int(Stats[name]) if Stats.has(name) else fallback

	func weapon(id: String) -> UnitWeaponDef:
		return Weapons.get(id)


class UnitsFile:
	var Units: Array[UnitDef] = []

	static func from_dict(d: Dictionary) -> UnitsFile:
		var o := UnitsFile.new()
		var list: Variant = JsonUtil.get_ci(d, "units")
		if list != null:
			for e in list:
				o.Units.append(UnitDef.from_dict(e))
		return o


## SCHEMA.md section 9. Generated by tools/build-missions-json.py.
class MissionDefPack:
	var Id: String
	var DisplayName: String
	## Replaces the raw table's `Alliance` / `Empire` integer pair - the exact
	## pattern the charter forbids, and the last instance of it.
	var AvailableTo: Array[String] = []
	## Unit ids (SCHEMA section 12 Q1); the raw table lists display names.
	var SpecForces: Array[String] = []
	var LengthBase: int
	var LengthSpread: int
	var Flags: Dictionary = {}
	var Targets: Dictionary = {}
	var SourceId: int

	static func from_dict(d: Dictionary) -> MissionDefPack:
		var o := MissionDefPack.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.AvailableTo = JsonUtil.str_list(d, "available_to", [])
		o.SpecForces = JsonUtil.str_list(d, "spec_forces", [])
		var l: Variant = JsonUtil.get_ci(d, "length")
		if l is Dictionary:
			o.LengthBase = JsonUtil.int_or(l, "base")
			o.LengthSpread = JsonUtil.int_or(l, "spread")
		var fl: Variant = JsonUtil.get_ci(d, "flags")
		if fl is Dictionary:
			for k in fl.keys():
				o.Flags[str(k)] = bool(fl[k])
		var tg: Variant = JsonUtil.get_ci(d, "targets")
		if tg is Dictionary:
			for k in tg.keys():
				o.Targets[str(k)] = bool(tg[k])
		o.SourceId = JsonUtil.int_or(d, "source_id")
		return o

	func AvailableToFaction(f: Faction) -> bool:
		return f != null and (AvailableTo.is_empty() or AvailableTo.has(f.Id))

	func flag(name: String) -> bool:
		return Flags.get(name, false)

	func targets(kind: String) -> bool:
		return Targets.get(kind, false)


class MissionsFile:
	var Missions: Array[MissionDefPack] = []

	static func from_dict(d: Dictionary) -> MissionsFile:
		var o := MissionsFile.new()
		var list: Variant = JsonUtil.get_ci(d, "missions")
		if list != null:
			for e in list:
				o.Missions.append(MissionDefPack.from_dict(e))
		return o
