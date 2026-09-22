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
	var Id: String               # the pack's mode id (display.json)
	var TitleFrom: String        # "loyalty_label" -> resolved per player faction
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
	var Id: String     # the pack's category id
	var Name: String
	var Modes: Array   # Array[GidMode]

	func _init(name: String, modes: Array, id: String = "") -> void:
		Name = name
		Modes = modes
		Id = id


# --- Marker geometry -------------------------------------------------
const FlareBig := 46
const FlareMid := 32
const FlareLow := 22
const DotSize := 15
## The pack names a tier's flare; the SIZE is engine presentation.
const FlareByName := { "big": FlareBig, "mid": FlareMid, "low": FlareLow, "none": 0 }
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


## Knowledge gate: does the player have ANY chart of this world (drives the grey
## "unexplored" marker). What is shown for a charted world is then FOGGED per datum
## by the readers below - owner/support live on the Core, everything else as last
## seen (manual p069). This closes the old "WRONG for Defense" gap noted here: the
## modes now read IntelManager sightings, not the live world.
static func _Known(p: Planet) -> bool:
	return p.IsExplored


# --- Fogged magnitude readers -------------------------------------------------
# Every mode below reads what the player KNOWS, not the live world: live on a world
# we hold, live owner/support on the Core, else the last sighting (IntelManager).

static func _player() -> Faction:
	return GameSettings.PlayerFaction


static func _PlayerSupport(p: Planet) -> float:
	return float(IntelManager.SupportSeen(_player(), p, _player()))


static func _StatusFig(p: Planet, key: String) -> float:
	return float(int(IntelManager.StatusSeen(_player(), p).get(key, 0)))


## Count of one production facility type as last seen (live for a world we hold).
static func _ProdCount(p: Planet, family: String) -> float:
	var counts: Dictionary = IntelManager.SeenData(_player(), p, Enums.IntelSection.ProductionFacilities).get("counts", {})
	return float(int(counts.get(family, 0)))


static func _DefFig(p: Planet, key: String) -> float:
	return float(int(IntelManager.SeenData(_player(), p, Enums.IntelSection.DefensiveFacilities).get(key, 0)))


## Unit counts fall straight out of the section's line list - no data twin needed.
static func _LineCount(p: Planet, section: int) -> float:
	return float(IntelManager.View(_player(), p, section).Lines.size())


## Fleet ORDERS (idle / moving) are knowable only for OUR OWN fleets; an enemy's are
## not, so these count ours alone - the same our-own rule the Idle Shipyards modes use.
static func _MyFleets(p: Planet, status: int) -> float:
	return float(Lq.count(p.OrbitingFleets, func(f: Fleet) -> bool: return f.Status == status and f.Faction == GameSettings.PlayerFaction))


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


## THE CATALOG IS PACK DATA (SCHEMA.md section 10, display.json). It used to be
## a literal table here - every label, threshold and flare in engine code. Now
## the pack declares the modes and the engine computes each `quantity.kind`.
## Populated by LoadFromPack from GameSession.load_catalogs; lazily built from
## the loaded pack if something asks first.
static var Categories: Array = []
static var _by_id: Dictionary = {}
## Which pack the catalog was built from, so a pack switch (the picker, after
## the Cockpit exits) rebuilds it instead of serving the old pack's modes.
static var _built_for: String = ""


static func LoadFromPack(pack: PackLoader.LoadedPack) -> void:
	Categories.clear()
	_by_id.clear()
	_activeMode = null
	if pack == null or pack.Display == null:
		push_error("[GID] no pack display catalog loaded!")
		return
	for cd in pack.Display.Categories:
		var modes := []
		for md in cd.Modes:
			var tiers := []
			for td in md.Tiers:
				tiers.append(GidTier.new(td.Min, td.LabelText, FlareByName.get(td.Flare, 0)))
			var title := md.Title
			if md.TitleFrom == "loyalty_label":
				# Resolved per player faction; stored here so the key-panel title
				# is right from the first frame and dynamic via TitleFor after.
				title = _LoyaltyTitle()
			var m := GidMode.new(md.LabelText, _magnitude_for(md.Kind, md.Args), _Known, tiers, title)
			m.Id = md.Id
			m.TitleFrom = md.TitleFrom
			modes.append(m)
			_by_id[md.Id] = m
		Categories.append(GidCategory.new(cd.DisplayName, modes, cd.Id))
	_built_for = pack.Manifest.Id
	print("[GID] catalog from the pack: %d categories, %d modes." % [Categories.size(), _by_id.size()])


static func _EnsureBuilt() -> void:
	if FactionRegistry.Pack != null and (Categories.is_empty() or _built_for != FactionRegistry.Pack.Manifest.Id):
		LoadFromPack(FactionRegistry.Pack)


static func ModeById(id: String) -> GidMode:
	_EnsureBuilt()
	return _by_id.get(id)


## THE ENGINE'S HALF OF THE CONTRACT: one magnitude reader per kind. Measured
## from the catalog this replaced - each kind is one of its former lambdas.
static func _magnitude_for(kind: String, args: Dictionary) -> Callable:
	match kind:
		"support":
			return _PlayerSupport
		"uprising":
			return func(p: Planet) -> float: return 1.0 if IntelManager.UprisingSeen(GameSettings.PlayerFaction, p) else 0.0
		"my_fleets":
			var status: int = Enums.Status.Enroute if str(args.get("status", "")) == "enroute" else Enums.Status.AwaitingOrders
			return func(p: Planet) -> float: return _MyFleets(p, status)
		"personnel":
			var busy: bool = bool(args.get("busy", false))
			# Idle counts only the AVAILABLE (not injured, not captured - manual p096).
			var require_available: bool = not busy
			return func(p: Planet) -> float: return _CountUnits(GameState.ActiveRoster, p, busy, require_available) + _CountUnits(p.SpecForces(), p, busy, require_available)
		"status_figure":
			var key: String = str(args.get("key", ""))
			return func(p: Planet) -> float: return _StatusFig(p, key)
		"facility_count":
			var family: String = str(args.get("family", ""))
			return func(p: Planet) -> float: return _ProdCount(p, family)
		"idle_producer":
			var role: String = str(args.get("role", ""))
			return func(p: Planet) -> float: return 1.0 if (_Owned(p) and p.CountByRole(role) > 0 and p.QueueFor(role) != null and (p.QueueFor(role) as Array).is_empty()) else 0.0
		"defence_figure":
			var key: String = str(args.get("key", ""))
			return func(p: Planet) -> float: return _DefFig(p, key)
		"intel_line_count":
			var section: int = Enums.IntelSection.Troopers if str(args.get("section", "")) == "troopers" else Enums.IntelSection.Fighters
			return func(p: Planet) -> float: return _LineCount(p, section)
		"constant_zero":
			return func(_p: Planet) -> float: return 0.0
	push_error("[GID] unknown quantity kind '%s' - the loader should have refused it." % kind)
	return func(_p: Planet) -> float: return 0.0


static func Default() -> GidMode:
	_EnsureBuilt()
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


## The Galaxy Display modes in the original's Alt+1..9 order (Steam guide),
## as the PACK lists them (display.json galaxy_display_modes). Index 0 = Alt+1.
## An entry is null if the pack names a mode it does not declare - the loader
## refuses that, so in practice every slot resolves.
static func GalaxyDisplayModes() -> Array:
	_EnsureBuilt()
	var out := []
	var pack := FactionRegistry.Pack
	if pack != null and pack.Display != null:
		for id in pack.Display.GalaxyDisplayModes:
			out.append(_by_id.get(id))
	return out


## The loyalty title depends on the player's faction, which isn't known at
## static-init time; patch it when the key is shown.
static func TitleFor(mode: GidMode) -> String:
	return _LoyaltyTitle() if mode.TitleFrom == "loyalty_label" else mode.Title
