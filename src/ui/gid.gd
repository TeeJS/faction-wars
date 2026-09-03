class_name Gid
extends RefCounted
## frontend/Gid.cs - the Galactic Information Display catalog: categories, modes
## and per-mode tier thresholds, all taken from the original game's own key
## windows (manual p066, p069-p072).


## One magnitude bucket within a GID mode. Thresholds are ABSOLUTE, so a world's
## marker only changes when that world changes.
class GidTier:
	var Min: float          # inclusive lower bound on the mode's magnitude
	var LabelText: String   # C# Label - key row text, verbatim from the original (Label shadows the Control class)
	var FlareSize: int      # font size of the "+" flare; 0 = bare dot, no flare

	func _init(min_: float, label: String, flareSize: int) -> void:
		Min = min_
		LabelText = label
		FlareSize = flareSize


## One selectable GID mode. Magnitude sorts a planet into one of Tiers; the
## planet's faction color drives the dot and the flare.
class GidMode:
	var LabelText: String        # C# Label - selector-menu text
	var Title: String            # key-panel title
	var Magnitude: Callable      # Func<Planet, float>
	var Reveal: Callable         # Func<Planet, bool> - does the player have knowledge here?
	var Tiers: Array             # Array[GidTier], descending

	func _init(label: String, magnitude: Callable, reveal: Callable, tiers: Array, title: String = "") -> void:
		LabelText = label
		Magnitude = magnitude
		Reveal = reveal
		Tiers = tiers
		Title = title if not title.is_empty() else label

	## Largest tier whose threshold the magnitude meets. Tiers are ordered
	## descending, so the last one (Min 0) always matches.
	func TierFor(magnitude: float) -> GidTier:
		for t in Tiers:
			if magnitude >= t.Min:
				return t
		return Tiers[Tiers.size() - 1]


class GidCategory:
	var Name: String
	var Modes: Array   # Array[GidMode]

	func _init(name: String, modes: Array) -> void:
		Name = name
		Modes = modes


# --- Marker geometry -------------------------------------------------
const FlareBig := 46
const FlareMid := 32
const FlareLow := 22
const DotSize := 15
# HQ highlight - DRAWN as geometry rather than set as a glyph in a Label.
const HaloSpan := 52.0        # tip-to-tip of the straight rays
const HaloThickness := 2.0    # ray width
const HaloDiagonal := 0.62    # diagonal rays, as a fraction of span

const CHighlight := Color(1.0, 1.0, 1.0)

# Sector planets are 32px artwork, so the galaxy flare sizes would swamp them.
const SectorFlareScale := 0.45
const SectorFlareMin := 9


## Your own HQ is marked - but only if it is the CONCEALED kind (manual,
## Headquarters). Driven by the pack's hq.kind rather than by which faction it is.
static func ShowHqHighlight(p: Planet) -> bool:
	return p.HasHeadquarters() \
		and p.IsExplored \
		and p.ControllingFaction == GameSettings.PlayerFaction \
		and GameSettings.PlayerFaction != null and GameSettings.PlayerFaction.HasHiddenHq()


# --- Faction colors --------------------------------------------------
# One source of truth: the pack, via FactionRegistry. C# properties -> funcs.
static func CNeutral() -> Color:
	return FactionRegistry.Neutral.FactionColor


static func CUnexplored() -> Color:
	return FactionRegistry.Unknown.FactionColor


static func FactionColor(p: Planet) -> Color:
	return p.GetFactionColor()


static func _Owned(p: Planet) -> bool:
	return p.ControllingFaction == GameSettings.PlayerFaction


## Knowledge gate: the player sees detail for any explored world. Right for
## Resources and Manufacturing, WRONG for Defense (needs an intel model) - see
## the source's GID-NOTES.md.
static func _Known(p: Planet) -> bool:
	return p.IsExplored


static func _PlayerSupport(p: Planet) -> float:
	return p.SupportFor(GameSettings.PlayerFaction)


# --- Tier builders ---------------------------------------------------

## The original's recurring 4-bucket count pattern: "{hi}+", mid..hi-1, 1..mid-1, none.
static func _Counts(hi: int, mid: int, noun: String, noneLabel: String = "") -> Array:
	var band := func(lo: int, high: int) -> String:
		return str(lo) if lo == high else "%d-%d" % [lo, high]
	return [
		GidTier.new(hi, "%d+ %s" % [hi, noun], FlareBig),
		GidTier.new(mid, "%s %s" % [band.call(mid, hi - 1), noun], FlareMid),
		GidTier.new(1, "%s %s" % [band.call(1, mid - 1), noun], FlareLow),
		GidTier.new(0, noneLabel if not noneLabel.is_empty() else "No %s" % noun, 0),
	]


## Two-state modes (present / absent).
static func _Binary(yes: String, no: String) -> Array:
	return [GidTier.new(1, yes, FlareBig), GidTier.new(0, no, 0)]


static var DisplayOff: GidMode = GidMode.new("Display Off", func(_p: Planet) -> float: return 0.0, _Known, [GidTier.new(0, "", 0)])


## Loyalty is titled for whichever side the player is on: pack data (factions.json loyalty_label).
static func _LoyaltyTitle() -> String:
	return GameSettings.PlayerFaction.LoyaltyLabel if GameSettings.PlayerFaction != null else "Loyalty"


## Present and usable here. UNIT, not Character - "your personnel" is characters
## AND Special Forces (manual p126). SystemOf, NOT `Attached == p`: a character
## riding a fleet has the FLEET as their Attached (manual p072, p100, p037).
static func _IsHere(u: Unit, p: Planet) -> bool:
	return u.Faction == GameSettings.PlayerFaction \
		and OrderManager.SystemOf(u.Attached) == p \
		and u.Status != Enums.Status.Enroute


## Command rank is a character's; a SpecForce is busy purely by being on a mission.
static func _IsBusy(u: Unit) -> bool:
	return u.Status == Enums.Status.OnMission or (u is Character and u.Rank != Enums.Rank.None)


## "Idle Personnel ... personnel AVAILABLE FOR ASSIGNMENTS" (manual p100); the
## injured and the captured are not idle (p096).
static func _IsAvailable(u: Unit) -> bool:
	return not (u is Character) or u.CanTakeOrders()


static func _CountUnits(units: Array, p: Planet, busy: bool, requireAvailable: bool) -> int:
	var n := 0
	for u in units:
		if not _IsHere(u, p):
			continue
		if _IsBusy(u) != busy:
			continue
		if requireAvailable and not _IsAvailable(u):
			continue
		n += 1
	return n


static var Categories: Array = _BuildCategories()


static func _BuildCategories() -> Array:
	return [
		GidCategory.new("Loyalty", [
			GidMode.new("Popular Support", _PlayerSupport, _Known, [
				GidTier.new(75, "Loyal", FlareBig),
				GidTier.new(50, "Obedient", FlareMid),
				GidTier.new(25, "Disloyal", FlareLow),
				GidTier.new(0, "Hostile", 0),
			], "Loyalty to the Alliance"),
			# "You can also select Uprisings from this menu to see systems in
			# uprisings" (manual p091). Binary: "a large star icon indicates the
			# system is in uprising".
			GidMode.new("Uprisings", func(p: Planet) -> float: return 1.0 if p.IsInUprising else 0.0, _Known,
				_Binary("Currently in Uprising", "Not in Uprising"), "Worlds in Uprising"),
		]),
		GidCategory.new("Fleets", [
			# The original counts FLEETS, not ships.
			GidMode.new("Idle Fleets",
				func(p: Planet) -> float: return Lq.count(p.OrbitingFleets, func(f: Fleet) -> bool: return f.Status == Enums.Status.AwaitingOrders),
				_Known, [
					GidTier.new(3, "3+ fleets", FlareBig),
					GidTier.new(2, "2 fleets", FlareMid),
					GidTier.new(1, "1 fleet", FlareLow),
					GidTier.new(0, "No fleets", 0),
				]),
			GidMode.new("Fleets Enroute",
				func(p: Planet) -> float: return Lq.count(p.OrbitingFleets, func(f: Fleet) -> bool: return f.Status == Enums.Status.Enroute),
				_Known, [
					GidTier.new(3, "3+ fleets", FlareBig),
					GidTier.new(2, "2 fleets", FlareMid),
					GidTier.new(1, "1 fleet", FlareLow),
					GidTier.new(0, "No fleets", 0),
				]),
		]),
		GidCategory.new("Personnel", [
			# Both modes show YOUR people only (manual p100), split by MISSION OR
			# COMMAND, and "personnel" is characters PLUS Special Forces (p126).
			GidMode.new("Idle Personnel",
				func(p: Planet) -> float: return _CountUnits(GameState.ActiveRoster, p, false, true) + _CountUnits(p.SpecForces(), p, false, true),
				_Known, _Binary("Idle", "None")),
			GidMode.new("Active Personnel",
				func(p: Planet) -> float: return _CountUnits(GameState.ActiveRoster, p, true, false) + _CountUnits(p.SpecForces(), p, true, false),
				_Known, _Binary("Active", "None")),
		]),
		GidCategory.new("Resources", [
			GidMode.new("Available Energy", func(p: Planet) -> float: return p.BaseEnergy, _Known,
				_Counts(6, 3, "Points Available", "0 Points Available")),
			GidMode.new("Available Raw Materials", func(p: Planet) -> float: return p.BaseRawMaterials, _Known,
				_Counts(3, 2, "Points Available", "0 Points Available")),
			GidMode.new("Mines", func(p: Planet) -> float: return p.Mines(), _Known, _Counts(6, 3, "Mines")),
			GidMode.new("Refineries", func(p: Planet) -> float: return p.Refineries(), _Known, _Counts(6, 3, "Refineries")),
		]),
		GidCategory.new("Manufacturing", [
			GidMode.new("Shipyards", func(p: Planet) -> float: return p.Shipyards(), _Known, _Counts(5, 2, "Shipyards")),
			GidMode.new("Idle Shipyards",
				func(p: Planet) -> float: return 1.0 if (_Owned(p) and p.HasIdleShipyards()) else 0.0, _Known, _Binary("Idle", "Active")),
			GidMode.new("Training Facilities", func(p: Planet) -> float: return p.TrainingFacilities(), _Known,
				_Counts(5, 2, "Training Facilities")),
			GidMode.new("Idle Training Facilities",
				func(p: Planet) -> float: return 1.0 if (_Owned(p) and p.HasIdleTroopTraining()) else 0.0, _Known, _Binary("Idle", "Active")),
			GidMode.new("Construction Yards", func(p: Planet) -> float: return p.ConstructionYards(), _Known,
				_Counts(5, 2, "Construction Yards")),
			GidMode.new("Idle Construction Yards",
				func(p: Planet) -> float: return 1.0 if (_Owned(p) and p.HasIdleConstructionYards()) else 0.0, _Known, _Binary("Idle", "Active")),
		]),
		GidCategory.new("Defense", [
			GidMode.new("Defense Batteries", func(p: Planet) -> float: return p.TurbolaserBatteries() + p.IonCannons(), _Known,
				_Counts(6, 3, "Batteries"), "Defense Batteries"),
			GidMode.new("Shield Generators", func(p: Planet) -> float: return p.PlanetaryShields(), _Known,
				_Counts(6, 3, "Generators")),
			GidMode.new("Fighter Squadrons", func(p: Planet) -> float: return p.FighterSquadrons.size(), _Known,
				_Counts(6, 3, "Fighter Squadrons")),
			GidMode.new("Trooper Regiments", func(p: Planet) -> float: return p.Garrison.size(), _Known,
				_Counts(6, 3, "Trooper Regiments")),
			# Death Star shields aren't modeled yet; option present to match the original.
			GidMode.new("Death Star Shields", func(_p: Planet) -> float: return 0.0, _Known,
				_Binary("Death Star Shield", "No Death Star Shield")),
		]),
	]


static func Default() -> GidMode:
	return Categories[0].Modes[0]


## The mode the player has selected, held here rather than inside GalaxyMap
## because THE SECTOR WINDOW MIRRORS THE SAME STARS (manual Fig 2.8).
## C#: static property ActiveMode { get; set; } -> ActiveMode() / SetActiveMode().
static var _activeMode: GidMode = null


static func ActiveMode() -> GidMode:
	if _activeMode == null:
		_activeMode = Default()
	return _activeMode


static func SetActiveMode(mode: GidMode) -> void:
	_activeMode = mode


## The loyalty title depends on the player's faction, which isn't known at
## static-init time; patch it when the key is shown.
static func TitleFor(mode: GidMode) -> String:
	return _LoyaltyTitle() if mode.LabelText == "Popular Support" else mode.Title
