class_name PackDefs
extends RefCounted
## backend/Packs/PackLoader.cs - the plain data shapes read from a faction pack.
## The pack files are snake_case (JsonNamingPolicy.SnakeCaseLower on the C# side),
## so every hydrator here reads the snake_case key into the PascalCase field.


class HqDef:
	var Kind: String          # "fixed" | "hidden"
	var Planet: String        # fixed: the planet it sits on
	var Placement: String     # hidden: "random_rim", or a planet id
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
	var AgentName: String
	## SCHEMA.md section 14: which of the art set's side looks this faction
	## wears ("alliance" / "empire" for swr-original). Blank = its own id.
	var ArtSkin: String
	## The side's name as an adjective in the game's own sentences ("the
	## Imperial fleet", "Alliance forces" - TEXTSTRA's battle block). Blank =
	## the display name.
	var Adjective: String

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
		o.AgentName = JsonUtil.str_or(d, "agent_name", "")
		o.ArtSkin = JsonUtil.str_or(d, "skin", "")
		o.Adjective = JsonUtil.str_or(d, "adjective", "")
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
	## The size pre-selected on the Cockpit (manual p021: "default is standard").
	## Optional; the first entry of galaxy_sizes when absent.
	var GalaxySizeDefault: String

	static func from_dict(d: Variant) -> PackSetupDef:
		if d == null:
			return null
		var o := PackSetupDef.new()
		o.DifficultyDefault = JsonUtil.str_or(d, "difficulty_default", "")
		o.GalaxySizes = JsonUtil.str_list(d, "galaxy_sizes", [])
		o.GalaxySizeDefault = JsonUtil.str_or(d, "galaxy_size_default", "")
		return o


## ONE CLICKABLE AREA OF THE COCKPIT PICTURE - manual p021, Fig. 2.2. `rect` is
## [x, y, w, h] in the picture's own pixels; the engine scales it with the
## picture. `action` is the engine's menu vocabulary (PackLoader.KNOWN_MENU_ACTIONS);
## `value` names WHICH difficulty / galaxy size / faction for the three actions
## that take one.
class MenuRegionDef:
	var Action: String
	var Value: String
	var Rect: Array = []       # [x, y, w, h]
	var Tooltip: String
	## Optional: this region's bracket colour when chosen (the original marks
	## difficulty in red and galaxy size in yellow). Empty = menu.selected_color.
	var SelectedColorHex: String
	## Optional: the screen this region shows, as its four corners in the
	## picture's pixels - top-left, top-right, bottom-right, bottom-left - so
	## the selection brackets lie on a screen seen at an angle (TeeJ,
	## 2026-09-24: the Cockpit's difficulty monitors lean). Empty = the rect's
	## corners. QuadGiven: the key was there (validation checks its shape).
	var Quad: PackedVector2Array = PackedVector2Array()
	var QuadGiven: bool = false

	static func from_dict(d: Dictionary) -> MenuRegionDef:
		var o := MenuRegionDef.new()
		o.Action = JsonUtil.str_or(d, "action", "")
		o.Value = JsonUtil.str_or(d, "value", "")
		var r: Variant = JsonUtil.get_ci(d, "rect")
		if r is Array:
			for v in r:
				o.Rect.append(int(v))
		o.Tooltip = JsonUtil.str_or(d, "tooltip", "")
		o.SelectedColorHex = JsonUtil.str_or(d, "selected_color", "")
		var q: Variant = JsonUtil.get_ci(d, "quad")
		if q != null:
			o.QuadGiven = true
			var pts := PackedVector2Array()
			if q is Array and q.size() == 4:
				for p in q:
					if p is Array and p.size() == 2:
						pts.append(Vector2(float(p[0]), float(p[1])))
			if pts.size() == 4:
				o.Quad = pts
		return o

	func rect2() -> Rect2:
		if Rect.size() != 4:
			return Rect2()
		return Rect2(Rect[0], Rect[1], Rect[2], Rect[3])


## The text panel under the victory-condition screen (the screenshot's
## "Standard Game"). The engine paints `standard` or `hq_only` over `rect`.
class MenuReadoutDef:
	var Rect: Array = []
	var Standard: String
	var HqOnly: String
	var ColorHex: String

	static func from_dict(d: Variant) -> MenuReadoutDef:
		if d == null:
			return null
		var o := MenuReadoutDef.new()
		var r: Variant = JsonUtil.get_ci(d, "rect")
		if r is Array:
			for v in r:
				o.Rect.append(int(v))
		o.Standard = JsonUtil.str_or(d, "standard", "")
		o.HqOnly = JsonUtil.str_or(d, "hq_only", "")
		o.ColorHex = JsonUtil.str_or(d, "color", "#40ff40")
		return o

	func rect2() -> Rect2:
		if Rect.size() != 4:
			return Rect2()
		return Rect2(Rect[0], Rect[1], Rect[2], Rect[3])


## A MONITOR ON THE COCKPIT (manual p021, Fig. 2.2: "the rotating red Alliance
## icon"): `image` is a strip of `frames` equal frames side by side, played in a
## loop at menu.monitor_fps with its top-left at `at` ([x, y], the picture's
## own pixels). With `region` (a region's "action" or "action:value") and
## `selected_image`, that picture shows instead while the region is chosen.
## With `still` (a frame, from 0) it holds that frame and does not move.
class MenuMonitorDef:
	var ImageFile: String
	var At: Array = []         # [x, y]
	var Frames: int = 1
	var Still: int = -1
	var Region: String
	var SelectedImageFile: String

	static func from_dict(d: Dictionary) -> MenuMonitorDef:
		var o := MenuMonitorDef.new()
		o.ImageFile = JsonUtil.str_or(d, "image", "")
		var a: Variant = JsonUtil.get_ci(d, "at")
		if a is Array:
			for v in a:
				o.At.append(int(v))
		o.Frames = int(JsonUtil.get_ci(d, "frames") if JsonUtil.get_ci(d, "frames") != null else 1)
		o.Still = int(JsonUtil.get_ci(d, "still") if JsonUtil.get_ci(d, "still") != null else -1)
		o.Region = JsonUtil.str_or(d, "region", "")
		o.SelectedImageFile = JsonUtil.str_or(d, "selected_image", "")
		return o


## THE SHUTTLE COCKPIT AS A PICTURE (manual p021, Fig. 2.2): the pack's own
## image with a clickable region per menu function. Optional - a pack without
## one gets the labelled-button menu.
class MenuDef:
	var ImageFile: String   # "Image" would shadow the native class
	var SelectedColorHex: String
	var Regions: Array[MenuRegionDef] = []
	var Readout: MenuReadoutDef
	var Credits: Array[String] = []
	var Monitors: Array[MenuMonitorDef] = []
	var MonitorFps: float = 10.0

	static func from_dict(d: Variant) -> MenuDef:
		if d == null:
			return null
		var o := MenuDef.new()
		o.ImageFile = JsonUtil.str_or(d, "image", "")
		o.SelectedColorHex = JsonUtil.str_or(d, "selected_color", "#ffd23c")
		var rs: Variant = JsonUtil.get_ci(d, "regions")
		if rs is Array:
			for e in rs:
				o.Regions.append(MenuRegionDef.from_dict(e))
		o.Readout = MenuReadoutDef.from_dict(JsonUtil.get_ci(d, "readout"))
		o.Credits = JsonUtil.str_list(d, "credits", [])
		var ms: Variant = JsonUtil.get_ci(d, "monitors")
		if ms is Array:
			for e in ms:
				o.Monitors.append(MenuMonitorDef.from_dict(e))
		var fps: Variant = JsonUtil.get_ci(d, "monitor_fps")
		if fps != null:
			o.MonitorFps = float(fps)
		return o


## The win-condition tooltips on the Multiplayer Options screen (manual p162):
## the pack's own wording, per victory mode.
class VictoryTipsDef:
	var Standard: String
	var HqOnly: String

	static func from_dict(d: Variant) -> VictoryTipsDef:
		if d == null:
			return null
		var o := VictoryTipsDef.new()
		o.Standard = JsonUtil.str_or(d, "standard", "")
		o.HqOnly = JsonUtil.str_or(d, "hq_only", "")
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
	## SCHEMA.md section 4: where the picture sits in the pack's map coordinate
	## space, [x, y, w, h]. Zero-sized when absent: the picture's own pixels.
	var MapImageRect: Rect2 = Rect2()
	## SCHEMA.md section 2: one sentence on what the setting is, for the pack
	## picker's card. Optional; blank when absent.
	var Summary: String
	var Setup: PackSetupDef
	## SCHEMA.md section 2: the Cockpit picture and its regions. Null = button menu.
	var Menu: MenuDef
	## SCHEMA.md section 2: the p162 win-condition tooltips. Null = no tooltip.
	var VictoryTips: VictoryTipsDef
	## SCHEMA.md section 14: the art sets this pack's original look comes from
	## (the player's own, imported - never shipped). Empty = the engine's own art.
	var ArtSets: Array[String] = []
	## SCHEMA.md section 2: who made the setting - "View credits" shows them.
	## A pack without a Cockpit picture has them here (the WWII pack's were
	## never shown, the editor handoff, 2026-09-23); `menu.credits` wins when
	## the picture has its own.
	var Credits: Array[String] = []

	static func from_dict(d: Dictionary) -> PackManifest:
		var o := PackManifest.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.SchemaVersion = JsonUtil.int_or(d, "schema_version")
		o.FactionCount = JsonUtil.int_or(d, "faction_count")
		o.Neutral = NeutralDef.from_dict(JsonUtil.get_ci(d, "neutral"))
		o.UnexploredColor = JsonUtil.str_or(d, "unexplored_color", "")
		o.MapImage = JsonUtil.str_or(d, "map_image", "")
		var r: Variant = JsonUtil.get_ci(d, "map_image_rect")
		if r is Array and r.size() == 4:
			o.MapImageRect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		o.Summary = JsonUtil.str_or(d, "summary", "")
		o.Setup = PackSetupDef.from_dict(JsonUtil.get_ci(d, "setup"))
		o.Menu = MenuDef.from_dict(JsonUtil.get_ci(d, "menu"))
		o.VictoryTips = VictoryTipsDef.from_dict(JsonUtil.get_ci(d, "victory_tips"))
		o.ArtSets = JsonUtil.str_list(d, "art_sets", [])
		o.Credits = JsonUtil.str_list(d, "credits", [])
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


## SCHEMA.md section 4. Built once from the original tables, hand-edited since
## (the generators are retired; `source_id` keeps the trail).
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
	## SCHEMA.md section 14: this row's pictures come from another row of an
	## art set, "[set:]<kind>/<id>". Blank = the row's own id.
	var Art: String = ""
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
		o.Art = JsonUtil.str_or(d, "art", "")
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


## SCHEMA.md section 7. Built once from the original tables, hand-edited since.
## ORDER IS LOAD-BEARING: majors first, then minors, because day
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
	## SCHEMA.md section 14: this row's pictures come from another row of an
	## art set, "[set:]<kind>/<id>". Blank = the row's own id.
	var Art: String = ""
	var Id: String
	var DisplayName: String
	var FactionId: String
	var IsMajor: bool
	## SCHEMA.md section 7: the planet id this character opens on. Optional;
	## when set it wins over the placement roles. Must be a world the
	## character's side holds at day zero (validation rule 15).
	var StartsAt: String = ""
	var Ratings: Dictionary = {}      # rating id -> RatingDef
	var CanCommand: Array[String] = []
	var WontBetray: bool
	var SpecialPower: SpecialPowerDef
	## SCHEMA.md section 7, roles: day-zero placement (starts_at_first_world,
	## starts_at_hq, starts_at_random_holding) and the story parts (pilgrim,
	## heir, dark_lord, dark_master, smuggler, companion). Engine code selects
	## on these; it never names a character.
	var Roles: Array[String] = []
	var SourceId: int
	var StringId: int

	static func from_dict(d: Dictionary) -> CharacterDef:
		var o := CharacterDef.new()
		o.Art = JsonUtil.str_or(d, "art", "")
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.FactionId = JsonUtil.str_or(d, "faction", "")
		o.IsMajor = JsonUtil.bool_or(d, "is_major")
		var r: Variant = JsonUtil.get_ci(d, "ratings")
		if r is Dictionary:
			for k in JsonUtil.data_keys(r):
				o.Ratings[str(k)] = RatingDef.from_dict(r[k])
		o.CanCommand = JsonUtil.str_list(d, "can_command", [])
		o.WontBetray = JsonUtil.bool_or(d, "wont_betray")
		o.SpecialPower = SpecialPowerDef.from_dict(JsonUtil.get_ci(d, "special_power"))
		o.Roles = JsonUtil.str_list(d, "roles", [])
		o.StartsAt = JsonUtil.str_or(d, "starts_at", "")
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


## SCHEMA.md section 5. Built once from the original tables, hand-edited since.
## THIS FILE REPLACES Enums.FacilityType. The engine selects on ROLES - it asks
## what a facility does, never what it is called.
class FacilityDef:
	## SCHEMA.md section 14: this row's pictures come from another row of an
	## art set, "[set:]<kind>/<id>". Blank = the row's own id.
	var Art: String = ""
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
		o.Art = JsonUtil.str_or(d, "art", "")
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
			for k in JsonUtil.data_keys(st):
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


## SCHEMA.md section 6 and its weapons subsection. Built once from the original
## tables, hand-edited since. WEAPON CLASSES ARE PACK DATA - the engine asks
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
	## SCHEMA.md section 14: this row's pictures come from another row of an
	## art set, "[set:]<kind>/<id>". Blank = the row's own id.
	var Art: String = ""
	var Id: String
	var DisplayName: String
	## "capital_ship" | "fighter" | "troop" | "spec_force". Which producer and
	## which queue a unit uses is engine structure, so this stays a small set.
	var Kind: String
	## SCHEMA.md section 6, roles: superweapon, garrison_troop. What a unit IS
	## to the engine's special cases, so no rule names a unit.
	var Roles: Array[String] = []
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
		o.Art = JsonUtil.str_or(d, "art", "")
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.Kind = JsonUtil.str_or(d, "kind", "")
		o.Roles = JsonUtil.str_list(d, "roles", [])
		o.BuildableBy = JsonUtil.str_list(d, "buildable_by", [])
		o.ConstructionCost = JsonUtil.int_or(d, "construction_cost")
		o.MaintenanceCost = JsonUtil.int_or(d, "maintenance_cost")
		o.ResearchOrder = JsonUtil.int_or(d, "research_order")
		o.ResearchCost = JsonUtil.int_or(d, "research_cost")
		var w: Variant = JsonUtil.get_ci(d, "weapons")
		if w is Dictionary:
			for k in JsonUtil.data_keys(w):
				o.Weapons[str(k)] = UnitWeaponDef.from_dict(w[k])
		var st: Variant = JsonUtil.get_ci(d, "stats")
		if st is Dictionary:
			for k in JsonUtil.data_keys(st):
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


## SCHEMA.md section 9. Built once from the original tables, hand-edited since.
class MissionDefPack:
	## SCHEMA.md section 14: this row's pictures come from another row of an
	## art set, "[set:]<kind>/<id>". Blank = the row's own id.
	var Art: String = ""
	var Id: String
	var DisplayName: String
	## Replaces the raw table's `Alliance` / `Empire` integer pair - the exact
	## pattern the charter forbids, and the last instance of it.
	var AvailableTo: Array[String] = []
	## SCHEMA.md section 9: the ENGINE behaviour this mission is the pack's
	## flavour of (MissionCatalog.KnownBehaviours()). Empty for a mission the
	## engine has no behaviour for (the unnamed rows).
	var Behaviour: String
	## Unit ids (SCHEMA section 12 Q1); the raw table lists display names.
	var SpecForces: Array[String] = []
	var LengthBase: int
	var LengthSpread: int
	var Flags: Dictionary = {}
	var Targets: Dictionary = {}
	var SourceId: int

	static func from_dict(d: Dictionary) -> MissionDefPack:
		var o := MissionDefPack.new()
		o.Art = JsonUtil.str_or(d, "art", "")
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		o.AvailableTo = JsonUtil.str_list(d, "available_to", [])
		o.Behaviour = JsonUtil.str_or(d, "behaviour", "")
		o.SpecForces = JsonUtil.str_list(d, "spec_forces", [])
		var l: Variant = JsonUtil.get_ci(d, "length")
		if l is Dictionary:
			o.LengthBase = JsonUtil.int_or(l, "base")
			o.LengthSpread = JsonUtil.int_or(l, "spread")
		var fl: Variant = JsonUtil.get_ci(d, "flags")
		if fl is Dictionary:
			for k in JsonUtil.data_keys(fl):
				o.Flags[str(k)] = bool(fl[k])
		var tg: Variant = JsonUtil.get_ci(d, "targets")
		if tg is Dictionary:
			for k in JsonUtil.data_keys(tg):
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


## SCHEMA.md section 9. A mission outcome table: an ascending STEP FUNCTION.
class MissionTableEntryDef:
	var Threshold: int
	var Value: int

	static func from_dict(d: Dictionary) -> MissionTableEntryDef:
		var o := MissionTableEntryDef.new()
		o.Threshold = JsonUtil.int_or(d, "Threshold")
		o.Value = JsonUtil.int_or(d, "Value")
		return o


class MissionTableDef:
	var Id: String
	## The original .DAT this came from - traceability only, never load-bearing
	## (SCHEMA section 12 Q2).
	var SourceFile: String
	var Description: String
	var Entries: Array[MissionTableEntryDef] = []

	static func from_dict(id: String, d: Dictionary) -> MissionTableDef:
		var o := MissionTableDef.new()
		o.Id = id
		o.SourceFile = JsonUtil.str_or(d, "source_file", "")
		o.Description = JsonUtil.str_or(d, "description", "")
		var list: Variant = JsonUtil.get_ci(d, "entries")
		if list != null:
			for e in list:
				o.Entries.append(MissionTableEntryDef.from_dict(e))
		return o


class MissionTablesFile:
	## table id -> MissionTableDef
	var Tables: Dictionary = {}

	static func from_dict(d: Dictionary) -> MissionTablesFile:
		var o := MissionTablesFile.new()
		var t: Variant = JsonUtil.get_ci(d, "tables")
		if t is Dictionary:
			for k in JsonUtil.data_keys(t):
				o.Tables[str(k)] = MissionTableDef.from_dict(str(k), t[k])
		return o


## SCHEMA.md section 8. rules.json and setup.json are carried as RAW rows: the
## engine's own catalogs (RuleManager, SideLotteryManager, SeedManager) already
## hydrate these shapes, and Q6 kept the integer EntryId, so re-typing them here
## would buy nothing and risk a transcription error.
class SetupFile:
	## The raw side-lottery rows, as SideLotteryManager reads them.
	var SideLottery: Array = []
	## logistics table id -> the raw table, with `source_file` alongside.
	var Logistics: Dictionary = {}

	static func from_dict(d: Dictionary) -> SetupFile:
		var o := SetupFile.new()
		var sl: Variant = JsonUtil.get_ci(d, "side_lottery")
		if sl is Array:
			o.SideLottery = sl
		var lg: Variant = JsonUtil.get_ci(d, "logistics")
		if lg is Dictionary:
			for k in JsonUtil.data_keys(lg):
				o.Logistics[str(k)] = lg[k]
		return o


## SCHEMA.md section 10 - the Galactic Information Display catalog. The ENGINE
## implements each quantity kind (Gid._magnitude_for); the PACK decides which
## modes exist, what they are called, and how a magnitude buckets into tiers.
class GidTierDef:
	var Min: float
	var LabelText: String   # "Label" would shadow the native Control class
	var Flare: String   # "big" | "mid" | "low" | "none" - sizes are engine constants

	static func from_dict(d: Dictionary) -> GidTierDef:
		var o := GidTierDef.new()
		o.Min = JsonUtil.float_or(d, "min")
		o.LabelText = JsonUtil.str_or(d, "label", "")
		o.Flare = JsonUtil.str_or(d, "flare", "none")
		return o


class GidModeDef:
	var Id: String
	var LabelText: String   # "Label" would shadow the native Control class
	var Title: String          # explicit key-panel title; empty -> the label
	var TitleFrom: String      # "loyalty_label" -> the player's faction's loyalty label
	var Kind: String           # quantity.kind
	var Args: Dictionary = {}  # the rest of quantity
	var Tiers: Array[GidTierDef] = []

	static func from_dict(d: Dictionary) -> GidModeDef:
		var o := GidModeDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.LabelText = JsonUtil.str_or(d, "label", "")
		o.Title = JsonUtil.str_or(d, "title", "")
		o.TitleFrom = JsonUtil.str_or(d, "title_from", "")
		var q: Variant = JsonUtil.get_ci(d, "quantity")
		if q is Dictionary:
			o.Kind = JsonUtil.str_or(q, "kind", "")
			for k in JsonUtil.data_keys(q):
				if str(k) != "kind":
					o.Args[str(k)] = q[k]
		var t: Variant = JsonUtil.get_ci(d, "tiers")
		if t != null:
			for e in t:
				o.Tiers.append(GidTierDef.from_dict(e))
		return o


class GidCategoryDef:
	var Id: String
	var DisplayName: String
	var Modes: Array[GidModeDef] = []

	static func from_dict(d: Dictionary) -> GidCategoryDef:
		var o := GidCategoryDef.new()
		o.Id = JsonUtil.str_or(d, "id", "")
		o.DisplayName = JsonUtil.str_or(d, "display_name", "")
		var m: Variant = JsonUtil.get_ci(d, "modes")
		if m != null:
			for e in m:
				o.Modes.append(GidModeDef.from_dict(e))
		return o


class DisplayDef:
	var Categories: Array[GidCategoryDef] = []
	## Mode ids in the original's Alt+1..9 order.
	var GalaxyDisplayModes: Array[String] = []
	## The five special-power bands' PLAYER-FACING labels (SCHEMA section 12 Q5):
	## none, novice, trainee, student, knight, master. The engine holds the
	## thresholds; what a band is CALLED is this pack's business.
	var SpecialPowerRanks: Dictionary = {}
	## SCHEMA.md section 10, `terms`: what the pack calls the engine's concepts on
	## screen - a stat, a resource, a unit kind. Keys are PackLoader.KNOWN_TERMS;
	## a key the pack leaves out gets the engine's neutral default (Terms.gd).
	var Terms: Dictionary = {}
	## SCHEMA.md section 10, `loyalty_bar`: the sides left to right on the sector
	## window's loyalty bar (manual p025 Fig 2.9 has the Empire on the left).
	## Optional; empty = the pack's faction order. Validation rule 16.
	var LoyaltyBar: Array[String] = []
	## SCHEMA.md section 10, `icons`: the pack's own picture for a sector-window
	## corner glyph (manufacturing, defenses, fleet, mission, uprising), a file in
	## the pack folder. Optional per key; the engine's assets/icons/ otherwise.
	## Validation rule 17.
	var Icons: Dictionary = {}

	static func from_dict(d: Dictionary) -> DisplayDef:
		var o := DisplayDef.new()
		o.LoyaltyBar = JsonUtil.str_list(d, "loyalty_bar", [])
		var ic: Variant = JsonUtil.get_ci(d, "icons")
		if ic is Dictionary:
			for k in JsonUtil.data_keys(ic):
				o.Icons[str(k)] = str(ic[k])
		var c: Variant = JsonUtil.get_ci(d, "categories")
		if c != null:
			for e in c:
				o.Categories.append(GidCategoryDef.from_dict(e))
		o.GalaxyDisplayModes = JsonUtil.str_list(d, "galaxy_display_modes", [])
		var r: Variant = JsonUtil.get_ci(d, "special_power_ranks")
		if r is Dictionary:
			for k in JsonUtil.data_keys(r):
				o.SpecialPowerRanks[str(k)] = str(r[k])
		var t: Variant = JsonUtil.get_ci(d, "terms")
		if t is Dictionary:
			for k in JsonUtil.data_keys(t):
				o.Terms[str(k)] = str(t[k])
		return o

	## The label for a band key; the key itself when the pack names none, so a
	## missing label is visible rather than blank.
	func RankLabel(key: String) -> String:
		return SpecialPowerRanks.get(key, key)
