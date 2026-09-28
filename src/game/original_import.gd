extends RefCounted
## A Star Wars: Rebellion saved game, made a game of this engine (PROJECT.md,
## "Import Game"). The reader (src/data/original_save.gd) gives the original's
## objects; this puts each one where this engine keeps the same thing, and
## lists what it cannot - never a guessed value (CLAUDE.md rule 2). Every
## object in the save is either carried or named in the report: Unaccounted()
## is empty, and tests/original_import.gd holds it to that.
##
## Only the Star Wars pack: the original's .DAT ids ARE that pack's source ids
## (units and facilities by source_family_id + source_id - the save's class
## code is the family - planets, characters and missions by source_id).
##
## THE DAY. The original counts its first day 0 (manual p033); this engine
## counts it 1 and shows day - 1 (StrategicTickManager.Shown). So the
## original's day D is Today = D + 1, the player sees "Day D", and every
## absolute day the save holds (an ETA, a timer's fire day, both in the
## original's days) leaves `that day - D` days to go.
##
## Build() needs a fresh game state (GameSession.start_from_original resets it
## first). Plan() reads nothing but the pack, so an import can check a file
## while another game is being played.
##
## Preloaded by path (as OriginalImport): a new script can lag the editor's
## class cache.

const OriginalSave := preload("res://src/data/original_save.gd")

const PACK_ID := "star-wars-rebellion"

## The GNPRTB column the galaxy object keeps at +0x64 (its saved word x[2]):
## REBEXE 0x518dc0 -> 0x513f70 -> 0x53e0a0 stores it, 0x585840 reads column c
## (0..7) of each rules entry. The column order is GNPRTB.DAT's (community
## editor, GNPRTB.cs): Development, Alliance Easy / Medium / Hard, Empire
## Easy / Medium / Hard, Multiplayer. Both of TeeJ's saves agree with their own
## side word (1 = Alliance -> column 1, 2 = Empire -> column 4).
const COLUMNS := {
	1: ["alliance", Enums.Difficulty.Easy], 2: ["alliance", Enums.Difficulty.Medium], 3: ["alliance", Enums.Difficulty.Hard],
	4: ["empire", Enums.Difficulty.Easy], 5: ["empire", Enums.Difficulty.Medium], 6: ["empire", Enums.Difficulty.Hard],
}
const SIDES := {1: "alliance", 2: "empire"}
## A galaxy's size by its number of systems (pack.json setup.galaxy_sizes).
const SIZES := {100: Enums.GalaxySize.Standard, 150: Enums.GalaxySize.Large, 200: Enums.GalaxySize.Huge}

const SYSTEM := [0x90, 0x92]
const FACILITY_CLASSES := [0x20, 0x22, 0x23, 0x24, 0x25, 0x28, 0x29, 0x2a, 0x2c, 0x2d]
const UNIT_CLASSES := [0x10, 0x14, 0x18, 0x1c, 0x3c]
const CHARACTER_CLASSES := [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x38]
## The build managers and the queue each feeds (0xA0 builds facilities,
## 0xA2 ships and fighters, 0xA4 troops and Special Forces - by what they hold
## in both saves).
const MANAGER_ROLE := {0xa0: "produces_facility", 0xa2: "produces_unit", 0xa4: "produces_troop"}
## The original's own "move this person" missions: the pack's unnamed_01..04,
## scripted, carrying a character or Special Force to a system. The person
## carries its own ETA; this engine keeps that movement on the person.
const MOVEMENT_MISSIONS := [0x41, 0x42, 0x43, 0x44]
## A key that names nothing.
const NO_KEY := [0, 2]
## Mission phases seen in the saves: 4 travelling, 8 at work (open-rebellion
## timer-scheduler.md: timer 0x38b acts at phase 8, 0x38c at phase 11).
const PHASE_TRAVEL := 4
const PHASE_WORK := 8

## Scheduler timers by what they do (open-rebellion ghidra/notes/
## timer-scheduler.md, the same build). Those this engine arms by its own rules
## are listed so the report can say so.
const TIMER_NAMES := {
	0x380: "capital ship timers", 0x381: "each side's periodic totals", 0x382: "each side's lock checks",
	0x383: "system flag timers", 0x384: "system support timers", 0x385: "system support timers",
	0x386: "system support timers", 0x387: "arrivals", 0x388: "injury recovery", 0x389: "character timers",
	0x38a: "escape attempts", 0x38b: "missions' next attempts", 0x38c: "missions' next phases",
	0x38d: "uprising incidents", 0x38e: "informant incidents", 0x38f: "disasters", 0x390: "resource incidents",
	0x392: "story events", 0x393: "story events", 0x394: "mine and refinery output",
}

## The last Build's report, as lines (also sent to the player as a message).
static var LastReport: Array[String] = []

var _g: Dictionary
var _day: int = 0                  # the original's day
var _pack: PackLoader.LoadedPack
var _alliance: Faction
var _empire: Faction

var _objs: Dictionary = {}         # key -> {o, parent}, the master copy
var _views: Array = [{}, {}, {}]   # key -> object, each copy
var _accounted: Dictionary = {}    # key -> how
var _carried: Dictionary = {}      # what -> count
var _left: Dictionary = {}         # why -> [names]
var _notes: Array[String] = []     # carried, but not exactly as the original had it

var _planets: Dictionary = {}      # system key -> Planet
var _fleets: Dictionary = {}       # fleet key -> Fleet
var _units: Dictionary = {}        # unit or character key -> Unit
var _facilities: Dictionary = {}   # facility key -> Facility
var _roster: Dictionary = {}       # character pack id -> Character
var _owed: Dictionary = {}         # faction id -> refined the imported orders would still draw


# ---- entry points ------------------------------------------------------------------

## What an original save would import as, from the pack alone: {ok, error,
## name, day (this engine's), side (faction id), difficulty, size}. Touches no
## game state.
static func Plan(g: Dictionary) -> Dictionary:
	var out := {"ok": false, "error": "", "name": str(g.get("name", "")), "day": 0, "side": "", "difficulty": 0, "size": 0}
	if not g.get("ok", false):
		out["error"] = "That file is not a saved game this can read (%s)." % g.get("error", "")
		return out
	if not FactionRegistry.EnsureLoaded() or FactionRegistry.LoadedId() != PACK_ID:
		out["error"] = "Star Wars: Rebellion games import into the Star Wars game pack only."
		return out
	var side: String = SIDES.get(int(g["header"]["side"]), "")
	var galaxy: Dictionary = g["views"][0]
	var column: int = int(galaxy.get("x", [0, 0, 0])[2])
	# The rules column says head-to-head (7) for certain; the header's
	# single/multi word is not confirmed, so it is not what decides.
	if column == 7:
		out["error"] = "That is a head-to-head game; only single-player games can be imported."
		return out
	if side.is_empty() or not COLUMNS.has(column) or COLUMNS[column][0] != side:
		out["error"] = "That game's side or difficulty is not one this can read (side %d, rules column %d)." % [int(g["header"]["side"]), column]
		return out
	var systems := 0
	for e: Dictionary in OriginalSave.Walk(galaxy):
		if int(e["o"]["class"]) in SYSTEM:
			systems += 1
	if not SIZES.has(systems):
		out["error"] = "That galaxy has %d systems, which is not one of the pack's sizes." % systems
		return out
	var pack := FactionRegistry.Pack
	var planet_ids := {}
	for pd in pack.Map.Planets:
		planet_ids[pd.SourceId] = true
	var character_ids := {}
	for cd in pack.Characters:
		character_ids[cd.SourceId] = true
	for e: Dictionary in OriginalSave.Walk(galaxy):
		var o: Dictionary = e["o"]
		var c: int = int(o["class"])
		var t: int = int(o["template"])
		if c in SYSTEM and not planet_ids.has(t):
			out["error"] = "That game has a system (%d) the pack does not." % t
			return out
		if c in CHARACTER_CLASSES and not character_ids.has(t):
			out["error"] = "That game has a character (%d) the pack does not." % t
			return out
		if c in UNIT_CLASSES and not MilitaryCatalog.HasSource(Vector2i(c, t)) and _unit_def(pack, c, t) == null:
			out["error"] = "That game has a unit (%d/%d) the pack does not." % [c, t]
			return out
	out["ok"] = true
	out["day"] = int(g["game"]["day"]) + 1
	out["side"] = side
	out["difficulty"] = COLUMNS[column][1]
	out["size"] = SIZES[systems]
	return out


## THE ORIGINAL'S FILE RIDES IN THE SAVE. A saved game here is its command log,
## rebuilt on load from its header; nothing but the original's own bytes can
## rebuild an imported game, so the header carries them ("origin") -
## compressed, as the file is mostly runs of small numbers.
static func OriginOf(bytes: PackedByteArray) -> Dictionary:
	return {"format": "swr-savegame", "size": bytes.size(),
		"deflate": Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))}


static func BytesOf(origin: Dictionary) -> PackedByteArray:
	if str(origin.get("format", "")) != "swr-savegame":
		return PackedByteArray()
	return Marshalls.base64_to_raw(str(origin.get("deflate", ""))).decompress(int(origin.get("size", 0)), FileAccess.COMPRESSION_DEFLATE)


## An imported game's seed: from the file itself, so importing the same file
## twice gives the same game.
static func SeedOf(bytes: PackedByteArray) -> int:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().decode_u32(0)


static func _unit_def(pack: PackLoader.LoadedPack, family: int, source_id: int) -> PackDefs.UnitDef:
	for u in pack.Units:
		if u.SourceFamilyId == family and u.SourceId == source_id:
			return u
	return null


## Build the imported game into a freshly reset game state; the catalogs must
## be loaded and GameSettings set from Plan. Returns the tick manager, on the
## imported day.
static func Build(g: Dictionary) -> StrategicTickManager:
	var b = load("res://src/game/original_import.gd").new()
	return b._build(g)


## Every object of the last Build that was neither carried nor reported (empty
## when the import is complete).
static var LastUnaccounted: Array = []
var Unaccounted: Array = []


# ---- the build ------------------------------------------------------------------------

func _build(g: Dictionary) -> StrategicTickManager:
	_g = g
	_day = int(g["game"]["day"])
	_pack = FactionRegistry.Pack
	_alliance = FactionRegistry.ById("alliance")
	_empire = FactionRegistry.ById("empire")
	for v in 3:
		for e: Dictionary in OriginalSave.Walk(g["views"][v]):
			var o: Dictionary = e["o"]
			_views[v][OriginalSave.Key(o)] = o
			if v == 0:
				_objs[OriginalSave.Key(o)] = e

	var galaxy := GalaxyFactory.LoadFromPack(_pack, GameSettings.SelectedSize)
	var by_pack_id := {}
	for s in galaxy:
		for p in s.Planets:
			by_pack_id[p.PackId] = p
	var roster := GameSession.load_roster()
	for c in roster:
		_roster[c.PackId] = c
	GameState.ActiveRoster = roster
	GameState.ActiveGalaxy = galaxy
	StrategicTickManager.Today = _day + 1

	var planet_of_source := {}
	for pd in _pack.Map.Planets:
		if by_pack_id.has(pd.Id):
			planet_of_source[pd.SourceId] = by_pack_id[pd.Id]

	# In the save's order, so the build (and every serial it hands out) is the
	# same on every load.
	for key in _objs:
		var o: Dictionary = _objs[key]["o"]
		if int(o["class"]) in SYSTEM:
			_system(key, o, planet_of_source.get(int(o["template"])))
	for p: Planet in GameState.AllPlanets():
		if not _planets.values().has(p):
			p.ControllingFaction = FactionRegistry.Neutral
			_leave(0, "systems of this galaxy size the save does not have (left neutral)", p.Name)
	for key in _objs:
		var o: Dictionary = _objs[key]["o"]
		var c: int = int(o["class"])
		if c in FACILITY_CLASSES:
			_facility(key, o)
		elif c == 0x08:
			_fleet(key, o)
	for key in _objs:
		var o: Dictionary = _objs[key]["o"]
		if int(o["class"]) in UNIT_CLASSES:
			_unit(key, o)
	for key in _objs:
		var o: Dictionary = _objs[key]["o"]
		if int(o["class"]) in CHARACTER_CLASSES:
			_character(key, o)
	for key in _objs:
		var o: Dictionary = _objs[key]["o"]
		var c: int = int(o["class"])
		if MANAGER_ROLE.has(c):
			_manager(key, o)
		elif c >= 0x41 and c <= 0x73:
			_mission(key, o)
	for key in _objs:
		var o: Dictionary = _objs[key]["o"]
		var c: int = int(o["class"])
		if c == 0xf3:
			_side(key, o)
		elif c in [0xf1, 0x80, 0x98, 0xf2, 0xf8, 0xf9, 0xfa]:
			_account(key, "structure")
	_timers()
	_economy()
	_intel()
	_messages()

	for key in _objs:
		if not _accounted.has(key):
			var o: Dictionary = _objs[key]["o"]
			Unaccounted.append("%s (0x%x/%d)" % [_label(o), int(o["class"]), int(o["template"])])

	LastUnaccounted = Unaccounted
	var engine := StrategicTickManager.new(galaxy)
	engine.CurrentDay = _day + 1
	StrategicTickManager.Today = _day + 1
	LastReport = _report(0)
	for line in LastReport:
		print("[Import] %s" % line)
	_tell_player()
	return engine


# ---- bookkeeping ----------------------------------------------------------------------

func _account(key: int, how: String) -> void:
	if _accounted.has(key):
		push_error("[Import] %s accounted twice (%s, then %s)." % [_label(_objs[key]["o"]), _accounted[key], how])
	_accounted[key] = how


func _carry(key: int, what: String) -> void:
	_account(key, "carried")
	_carried[what] = int(_carried.get(what, 0)) + 1


func _leave(key: int, why: String, name: String = "") -> void:
	if key != 0:
		_account(key, "reported")
	if not _left.has(why):
		_left[why] = []
	if not name.is_empty():
		_left[why].append(name)


func _note(line: String) -> void:
	_notes.append(line)


func _status(o: Dictionary, bit: String) -> bool:
	return OriginalSave.Has(int(o["status"]), OriginalSave.BASE_STATUS, bit)


func _owner(o: Dictionary) -> Faction:
	match OriginalSave.Owner(int(o["control_kind"])):
		"alliance": return _alliance
		"empire":   return _empire
		"neutral":  return FactionRegistry.Neutral
	return null


func _parent(key: int) -> Dictionary:
	return _objs[key]["parent"] if _objs.has(key) else {}


## The system an object is in or under (itself if it is one); {} if none.
func _system_of(key: int) -> Dictionary:
	var o: Dictionary = _objs[key]["o"] if _objs.has(key) else {}
	while not o.is_empty() and not (int(o["class"]) in SYSTEM):
		o = _objs[OriginalSave.Key(o)]["parent"]
	return o


func _planet_of(key: int) -> Planet:
	var s := _system_of(key)
	return _planets.get(OriginalSave.Key(s)) if not s.is_empty() else null


func _planet_at(key: int) -> Planet:
	if key in NO_KEY or not _objs.has(key):
		return null
	return _planet_of(key)


## Days to go until the original's day `day` (0 when it is today or past).
func _days_to(day: int) -> int:
	return maxi(0, day - _day)


func _label(o: Dictionary) -> String:
	var c: int = int(o["class"])
	var t: int = int(o["template"])
	if c in SYSTEM:
		for pd in _pack.Map.Planets:
			if pd.SourceId == t:
				return pd.DisplayName
	if c in CHARACTER_CLASSES:
		for cd in _pack.Characters:
			if cd.SourceId == t:
				return cd.DisplayName
	if o.has("name"):
		return str(o["name"])
	var def := _unit_def(_pack, c, t)
	if def != null:
		return def.DisplayName
	var fac := _facility_def(c, t)
	if fac != null:
		return fac.DisplayName
	return "0x%x/%d" % [c, t]


func _facility_def(family: int, source_id: int) -> PackDefs.FacilityDef:
	for d in FacilityCatalog.All():
		if d.SourceFamilyId == family and d.SourceId == source_id:
			return d
	return null


# ---- systems --------------------------------------------------------------------------

func _system(key: int, o: Dictionary, p: Planet) -> void:
	if p == null:
		_leave(key, "systems the chosen galaxy size does not have", _label(o))
		return
	_planets[key] = p
	var owner := _owner(o)
	p.ControllingFaction = owner if owner != null else FactionRegistry.Neutral
	var flags: int = int(o["system_flags"])
	p.IsInhabited = OriginalSave.Has(flags, OriginalSave.SYSTEM_FLAGS, "populated")
	p.IsInUprising = OriginalSave.Has(flags, OriginalSave.SYSTEM_FLAGS, "uprising")
	# Loyalty is the Alliance's support, in percent (SAVEGAME-FORMAT.md, confirmed).
	p.SetSupportFor(_alliance, int(o["loyalty"]))
	# Each side's chart is its own copy of the galaxy.
	for side in [[1, _alliance], [2, _empire]]:
		var copy: Dictionary = _views[side[0]].get(key, {})
		p.SetExplored(side[1], not copy.is_empty() and OriginalSave.Has(int(copy["system_flags"]), OriginalSave.SYSTEM_FLAGS, "explored"))
	if p.IsInUprising:
		_uprising(key, o, p)
	p.BaseEnergy = int(o["energy"])
	p.BaseRawMaterials = int(o["raw_material"])
	_carry(key, "systems")
	if int(o["smuggling_percent"]) != 0:
		_leave(0, "smuggling percent (a system's own figure; this engine works smuggling out itself)", "%s %d" % [p.Name, _signed(int(o["smuggling_percent"]))])
	if int(o["production_modifier"]) != 100:
		_leave(0, "a system's production modifier (%)", "%s %d" % [p.Name, int(o["production_modifier"])])
	if int(o["troop_reg_withdraw_percent"]) != 100:
		_leave(0, "a system's troop withdrawal percent", "%s %d" % [p.Name, int(o["troop_reg_withdraw_percent"])])
	if OriginalSave.Has(flags, OriginalSave.SYSTEM_FLAGS, "never_been_controlled"):
		_leave(0, "\"never been controlled\" (not kept by this engine)", p.Name)


## A system in uprising: when it ends (timer 0x383 clears the Uprising bit) and
## when it next costs its holder support (0x384; timer-scheduler.md). Either
## missing is armed as this engine arms a new uprising.
func _uprising(key: int, o: Dictionary, p: Planet) -> void:
	var ends := _live_fire_day(key, o, 0x383)
	var drift := _live_fire_day(key, o, 0x384)
	var rng := Prng.Session
	var f := p.ControllingFaction
	if ends >= 0:
		p._uprising_ends = ends + 1
	else:
		p._uprising_ends = _day + 1 + RuleManager.Roll(RuleId.UprisingClearBase, RuleId.UprisingClearSpread, rng, f)
		_note("%s: the uprising's end was not in the save; it was rolled as a new one's is." % p.Name)
	if drift >= 0:
		p._next_support_drift = drift + 1
	else:
		p._next_support_drift = _day + 1 + maxi(1, RuleManager.Get(RuleId.UprisingSupportDriftDelay, f))


static func _signed(v: int) -> int:
	return v - 0x100000000 if v >= 0x80000000 else v


# ---- facilities -----------------------------------------------------------------------

func _facility(key: int, o: Dictionary) -> void:
	var def := _facility_def(int(o["class"]), int(o["template"]))
	if _status(o, "destroyed"):
		_leave(key, "destroyed facilities (the original keeps their remains)", _label(o))
		return
	if not _status(o, "completed"):
		return   # under construction: its build manager carries it (_manager)
	if _status(o, "enroute") and not _status(o, "deployed"):
		_in_transit(key, o, null, def)
		return
	var p := _planet_of(key)
	if def == null or p == null:
		_leave(key, "facilities with no place in this game", _label(o))
		return
	p.AddFacility(def.Family, def.Tier)
	p.Facilities[-1].IsDamaged = _status(o, "damaged")
	_facilities[key] = p.Facilities[-1]
	_carry(key, "facilities")


## Built, and still being shipped to where it was ordered (manual p114): a
## finished order in transit, held by the producer.
func _in_transit(key: int, o: Dictionary, unit: PackDefs.UnitDef, fac: PackDefs.FacilityDef) -> void:
	var to := _planet_of(key)
	var from := _planet_at(int(o["builder"]))
	if from == null:
		from = to
	if to == null or (unit == null and fac == null):
		_leave(key, "built items in transit with no destination here", _label(o))
		return
	var t := ConstructionTask.new()
	if unit != null:
		t.UnitRule = unit
		t.RefinedCost = unit.ConstructionCost
		t.MaintenanceCost = unit.MaintenanceCost
	else:
		t.Family = fac.Family
		t.Tier = fac.Tier
		t.RefinedCost = fac.ConstructionCost
		t.MaintenanceCost = fac.MaintenanceCost
	t.TotalWork = t.RefinedCost
	t.Progress = t.TotalWork
	t.Destination = to
	t.TransportDays = maxi(1, _days_to(int(o["eta"])))
	from._in_transit.append(t)
	_carry(key, "finished items in transit")


# ---- fleets and units -------------------------------------------------------------------

## A fleet is carried when it holds a finished ship; the original also keeps
## four empty fleet objects per system as containers, and a fleet made for a
## ship still being built.
func _fleet(key: int, o: Dictionary) -> void:
	var ships := Lq.where(o["children"], func(k): return int(k["class"]) in [0x14, 0x18] and _status(k, "completed"))
	if ships.is_empty():
		if o["children"].is_empty():
			_account(key, "structure")
		else:
			_leave(key, "fleets waiting for a ship still being built (the ship joins its system's fleets when done)", str(o.get("name", "")))
		return
	var at := _planet_of(key)
	if at == null:
		_leave(key, "fleets with no system here", str(o.get("name", "")))
		return
	var f := Fleet.new()
	f.ID = Fleet.IdFor(Fleet.NextSerial())
	f.Faction = _owner(o)
	f.Name = str(o.get("name", ""))
	if f.Name.is_empty():
		f.Name = Fleet.NextName(f.Faction)
	Fleet.NoteName(f.Faction, f.Name)
	f.Attached = at
	if _status(o, "enroute"):
		f.Status = Enums.Status.Enroute
		f.Destination = at
		f.DaysToDestination = maxi(1, _days_to(int(o["eta"])))
	at.OrbitingFleets.append(f)
	_fleets[key] = f
	_carry(key, "fleets")
	var flags: int = int(o["fleet_flags"])
	for bit in ["battle", "blockade", "bombard", "assault"]:
		if OriginalSave.Has(flags, OriginalSave.FLEET_FLAGS, bit):
			_note("%s was in a %s; this engine decides that again on the next day." % [f.Name, bit])


func _unit(key: int, o: Dictionary) -> void:
	var c: int = int(o["class"])
	var def: PackDefs.UnitDef = MilitaryCatalog.BySource(Vector2i(c, int(o["template"])))
	if def == null:
		def = _unit_def(_pack, c, int(o["template"]))
	if not _status(o, "completed"):
		return   # still being built: its build manager carries it
	if _status(o, "enroute") and not _status(o, "deployed"):
		_in_transit(key, o, def, null)
		return
	var parent: Dictionary = _parent(key)
	var pc: int = int(parent.get("class", 0))
	var p := _planet_of(key)
	if def == null or p == null:
		_leave(key, "units with no place in this game", _label(o))
		return
	var owner := _owner(o)
	var u := MilitaryCatalog.Create(def, owner, p)
	if o.has("name"):
		u.Name = str(o["name"])
		if u.Type == Enums.UnitType.CapitalShip:
			Unit.NoteClassName(owner, def.Id, def.DisplayName, u.Name)
	_units[key] = u
	var moving := _status(o, "enroute")
	var own_move := _status(o, "enroute_active")
	match u.Type:
		Enums.UnitType.CapitalShip:
			var f: Fleet = _fleets.get(OriginalSave.Key(parent))
			if f == null:
				_units.erase(key)
				_leave(key, "ships outside any fleet", u.Name)
				return
			f.AddShip(u)
			if f.Status == Enums.Status.Enroute:
				u.Status = Enums.Status.Enroute
				u.Destination = p
				u.DaysToDestination = f.DaysToDestination
			if int(o["hull_damage"]) > 0:
				u.DamageState().Hull = maxi(0, u.Hull - int(o["hull_damage"]))
			if int(o["allocations"]) != 0:
				_leave(0, "a ship's power allocations (not kept by this engine)", u.Name)
			_carry(key, "capital ships")
		_:
			if pc in [0x14, 0x18]:
				var ship: Unit = _units.get(OriginalSave.Key(parent))
				if ship == null:
					_units.erase(key)
					_leave(key, "units aboard a ship that is not here", u.Name)
					return
				ship.Hangar.append(u)
				var fleet: Fleet = _fleets.get(OriginalSave.Key(_parent(OriginalSave.Key(parent))))
				if fleet != null and fleet.Status == Enums.Status.Enroute:
					u.Status = Enums.Status.Enroute
					u.Destination = p
					u.DaysToDestination = fleet.DaysToDestination
					if own_move and _days_to(int(o["eta"])) != fleet.DaysToDestination:
						_note("%s, on its way to join %s, arrives with it on day %d instead of day %d." % [u.Name, fleet.Name, _day + fleet.DaysToDestination, int(o["eta"])])
				elif own_move and fleet != null:
					# On its way to join the fleet (manual p122; OrderManager.Inbound).
					u.Status = Enums.Status.Enroute
					u.Destination = fleet
					u.DaysToDestination = maxi(1, _days_to(int(o["eta"])))
				_carry(key, "units aboard ships")
			else:
				MilitaryCatalog.Relocate(u, p)
				if moving and own_move:
					u.Status = Enums.Status.Enroute
					u.Destination = p
					u.DaysToDestination = maxi(1, _days_to(int(o["eta"])))
				_carry(key, {Enums.UnitType.Fighter: "fighter squadrons", Enums.UnitType.Troop: "troop regiments"}.get(u.Type, "Special Forces"))
			if u.Type == Enums.UnitType.Fighter and int(o["squad_size_damage"]) > 0:
				u.DamageState().Aircraft = maxi(0, u.SquadronSize - int(o["squad_size_damage"]))


# ---- characters ---------------------------------------------------------------------------

func _character(key: int, o: Dictionary) -> void:
	var def_id := ""
	for cd in _pack.Characters:
		if cd.SourceId == int(o["template"]):
			def_id = cd.Id
	var c: Character = _roster.get(def_id)
	if c == null:
		_leave(key, "characters the pack does not have", _label(o))
		return
	_units[key] = c
	var parent: Dictionary = _parent(key)
	var pc: int = int(parent.get("class", 0))
	if pc == 0xf2:
		# Not yet on the map: the original has not rolled their ratings (all
		# zero), so they are rolled from the pack as a new game does.
		DayZeroGenerator.GenerateCharacterStats(c, Prng.Session)
		_carry(key, "characters not yet recruited")
		return
	var owner := _owner(o)
	var cflags: int = int(o["character_flags"])
	c.DiplomacyRating = int(o["base_diplomacy"])
	c.EspionageRating = int(o["base_espionage"])
	c.CombatRating = int(o["base_combat"])
	c.LeadershipRating = int(o["base_leadership"])
	c.Loyalty = int(o["base_loyalty"])
	c.ShipDesign = int(o["base_shipyard_rd"])
	c.TroopTraining = int(o["base_training_facil_rd"])
	c.FacilityDesign = int(o["base_construction_yard_rd"])
	for r in ["diplomacy", "espionage", "combat", "leadership", "loyalty"]:
		if int(o["enhanced_" + r]) != int(o["base_" + r]):
			_leave(0, "a rating's boosted value (the original's Force and leadership bonuses; the base rating is carried)", "%s %s %d->%d" % [c.Name, r, int(o["base_" + r]), int(o["enhanced_" + r])])
	if int(o["leadership_adjustment"]) != 0:
		_leave(0, "a leadership adjustment (not kept by this engine)", "%s %d" % [c.Name, int(o["leadership_adjustment"])])
	# THE FORCE: the level, and whether the side knows it. A latent user the
	# original has not measured yet (potential, level 0) gets this engine's
	# latent roll, as a new game gives them.
	var aware := OriginalSave.Has(cflags, OriginalSave.CHARACTER_FLAGS, "force_aware")
	var potential := OriginalSave.Has(cflags, OriginalSave.CHARACTER_FLAGS, "force_potential")
	c.IsKnownSpecialPowerUser = aware
	if int(o["force"]) > 0:
		c.SpecialPowerLevel = int(o["force"])
	elif potential and c.SpecialPowerLevelBase + c.SpecialPowerLevelVar > 0:
		c.SpecialPowerLevel = c.SpecialPowerLevelBase + Prng.Session.NextRange(0, c.SpecialPowerLevelVar + 1)
		_note("%s has the Force but the original had not measured it yet; its level was rolled from the pack (%d)." % [c.Name, c.SpecialPowerLevel])
	else:
		c.SpecialPowerLevel = 0
	c.Injury = int(o["injury"])
	c.TraitorRevealed = not (int(o["traitor_discovered"]) in NO_KEY)
	c.CanEscape = OriginalSave.Has(cflags, OriginalSave.CHARACTER_FLAGS, "can_escape")

	# Where: a system, or aboard a ship (so its fleet).
	var at: Location = null
	if pc in SYSTEM:
		at = _planets.get(OriginalSave.Key(parent))
	elif pc in [0x14, 0x18]:
		at = _fleets.get(OriginalSave.Key(_parent(OriginalSave.Key(parent))))
	elif pc == 0x08:
		at = _fleets.get(OriginalSave.Key(parent))
	if at == null:
		_leave(key, "characters somewhere this game has no place for", c.Name)
		return
	c.Attached = at
	c.Status = Enums.Status.AwaitingOrders
	if OriginalSave.Has(cflags, OriginalSave.CHARACTER_FLAGS, "captured"):
		c.CapturedBy = owner
		c.Status = Enums.Status.Kidnapped
	elif owner != null and owner != FactionRegistry.Neutral:
		c.Faction = owner
	if _status(o, "enroute") and _status(o, "enroute_active"):
		c.Status = Enums.Status.Enroute
		c.Destination = at
		c.DaysToDestination = maxi(1, _days_to(int(o["eta"])))
	elif at is Fleet and (at as Fleet).Status == Enums.Status.Enroute:
		c.Status = Enums.Status.Enroute
		c.DaysToDestination = (at as Fleet).DaysToDestination

	# Command: 3 General, 2 Admiral - the save's own names say so ("General
	# Drayson" 3, "Admiral Screed" 2). A third kind has not been seen.
	var kind: int = int(o["command_kind"])
	var post: Variant = _planets.get(int(o["commanding"]), _fleets.get(int(o["commanding"])))
	if kind == 3 and post != null:
		c.Rank = Enums.Rank.General
		c.Commanding = post
	elif kind == 2 and post != null:
		c.Rank = Enums.Rank.Admiral
		c.Commanding = post
	elif kind != 0:
		_leave(0, "a command this reader cannot name", "%s (kind %d)" % [c.Name, kind])
	_carry(key, "characters")


# ---- production -----------------------------------------------------------------------------

## A build manager with work: the rest of its order, as this engine's queue on
## the same world. The item under way keeps its share done (the original's
## points are the item's refined cost, so the fraction carries exactly).
func _manager(key: int, o: Dictionary) -> void:
	var n: int = int(o["remaining_count"])
	if n <= 0:
		_account(key, "structure")
		return
	var at := _planet_of(key)
	var type_key: int = int(o["seed_key"])
	var family: int = type_key >> 24
	var source: int = type_key & 0xffffff
	var unit: PackDefs.UnitDef = MilitaryCatalog.BySource(Vector2i(family, source))
	var fac: PackDefs.FacilityDef = _facility_def(family, source) if unit == null else null
	var to := _planet_at(int(o["deployment_key"]))
	if at == null or to == null or (unit == null and fac == null):
		_leave(key, "orders this game cannot place", str(o["product_name"]))
		for ref: Array in o["state"]["refs"]:
			_leave_product(int(ref[0]))
		return
	var dk: int = int(o["deployment_key"])
	if not (_objs[dk]["o"]["class"] in SYSTEM):
		_note("%s ordered at %s goes to %s itself; the original delivers it into %s." % [str(o["product_name"]), at.Name, to.Name, _label(_objs[dk]["o"])])
	var role: String = MANAGER_ROLE[int(o["class"])]
	var queue: Array = at.QueueFor(role)
	for i in n:
		var t := ConstructionTask.new()
		if unit != null:
			t.UnitRule = unit
			t.RefinedCost = unit.ConstructionCost
			t.MaintenanceCost = unit.MaintenanceCost
		else:
			t.Family = fac.Family
			t.Tier = fac.Tier
			t.RefinedCost = fac.ConstructionCost
			t.MaintenanceCost = fac.MaintenanceCost
		t.TotalWork = t.RefinedCost * at.BestProducerRate(role)
		if i == 0 and int(o["required_points"]) > 0:
			t.Progress = t.TotalWork * int(o["completed_points"]) / int(o["required_points"])
		t.Destination = to
		t.TransportDays = at.DeploymentDaysTo(to)
		queue.append(t)
		var f: Faction = at.ControllingFaction
		if f != null:
			var left: int = t.RefinedCost - (int(o["completed_points"]) if i == 0 else 0)
			_owed[f.Id] = int(_owed.get(f.Id, 0)) + maxi(0, left)
	_carry(key, "orders being built")
	# The objects the original made for the items on order.
	for ref: Array in o["state"]["refs"]:
		var k: int = int(ref[0])
		if _objs.has(k) and not _accounted.has(k):
			_account(k, "carried")
	if int(o["overflow_points"]) != 0:
		_leave(0, "points carried over between orders", "%s %d" % [str(o["product_name"]), int(o["overflow_points"])])


func _leave_product(k: int) -> void:
	if _objs.has(k) and not _accounted.has(k):
		_leave(k, "items on an order this game cannot place", _label(_objs[k]["o"]))


# ---- missions ---------------------------------------------------------------------------------

func _mission(key: int, o: Dictionary) -> void:
	var c: int = int(o["class"])
	if c in MOVEMENT_MISSIONS:
		_carry(key, "journeys (kept on the person travelling)")
		return
	var def: PackDefs.MissionDefPack = MissionCatalog.Get(int(o["template"]))
	var type: int = -1
	if def != null:
		for member in Enums.MissionType.keys():
			if MissionCatalog.BehaviourName(Enums.MissionType[member]) == def.Behaviour:
				type = Enums.MissionType[member]
	var target := _planet_at(int(o["target"]))
	var team: Array = []
	for ref: Array in o["team"]:
		var u: Unit = _units.get(int(ref[0]))
		if u != null:
			team.append(u)
	var decoys: Array = []
	for ref: Array in o["decoys"]:
		var u: Unit = _units.get(int(ref[0]))
		if u != null:
			decoys.append(u)
	if type < 0 or target == null or team.is_empty():
		_leave(key, "missions this game does not run", "%s at %s" % [def.DisplayName if def != null else "0x%x" % c, target.Name if target != null else "?"])
		return
	var m := Mission.new()
	m.Type = type
	m.Faction = _owner(o)
	m.Target = target
	m.HomeBase = _planet_at(int(o["origin_location"]))
	if m.HomeBase == null:
		m.HomeBase = target
	var objective: Variant = _units.get(int(o["objective"]), _facilities.get(int(o["objective"])))
	if objective is Character:
		m.TargetCharacter = objective
	elif objective is Unit:
		m.TargetUnit = objective
	elif objective is Facility:
		m.TargetFacility = objective
	# Decoys are team members here (MissionManager: agents = Team - Decoys);
	# the original lists them apart.
	for u in team + decoys:
		m.Team.append(u)
	for u in decoys:
		m.Decoys.append(u)
	var phase: int = int(o["phase"])
	if phase == PHASE_TRAVEL:
		var eta: int = 0
		for ref: Array in o["team"]:
			if _objs.has(int(ref[0])):
				eta = maxi(eta, int(_objs[int(ref[0])]["o"]["eta"]))
		m.DaysToTarget = maxi(1, _days_to(eta))
		# Where Launch leaves a team in transit: at the system it set out from.
		for u in m.Team:
			MilitaryCatalog.Relocate(u, m.HomeBase)
			u.Status = Enums.Status.Enroute
			u.Destination = target
			u.DaysToDestination = m.DaysToTarget
	elif phase == PHASE_WORK:
		m.DaysToTarget = 0
		m.Announced = true
		# MissionManager resolves on the tick that finds DaysOnStation at 0 -
		# it checks before counting down, where travel counts down first - so
		# a next attempt on the original's day F leaves F - D - 1.
		var fire := _live_fire_day(key, o, 0x38b)
		if fire >= 0:
			m.DaysOnStation = maxi(0, fire - _day - 1)
		else:
			m.DaysOnStation = m.RollWorkDays(Prng.Session)
			_note("%s at %s: its next attempt was not in the save; rolled as a new one's is." % [m.DisplayName(), target.Name])
		for u in m.Team:
			u.Status = Enums.Status.OnMission
			u.Destination = null
			u.DaysToDestination = 0
	else:
		_leave(key, "missions at a stage this reader cannot name", "%s (phase %d)" % [def.DisplayName, phase])
		return
	MissionManager._active.append(m)
	_carry(key, "missions")
	_leave(0, "how many attempts each mission had made (this engine counts afresh)", "")


## The fire day of the live timer `code` on object `key`: the one whose copy
## of a timer record still matches one of the object's own (timer-scheduler.md:
## a timer whose target's record has moved on is dead). -1 if none.
func _live_fire_day(key: int, o: Dictionary, code: int) -> int:
	var own: Array = []
	var state: Dictionary = o.get("state", {})
	for k in state:
		if str(k).begins_with("rec"):
			own.append(state[k])
	for e: Dictionary in _g["queue_a8"]:
		if int(e["code"]) != code or int(e["target"]) != key:
			continue
		for r: Array in own:
			if int(r[0]) == int(e["record"][0]) and int(r[1]) == int(e["record"][1]):
				return int(e["fire_day"])
	return -1


# ---- sides --------------------------------------------------------------------------------------

## Research: each track's order reached (ShipyardRdOrder and its two
## siblings, exe names), as this engine's bank - the cost of the dearest design
## at or below that order, so everything up to it is built.
func _side(key: int, o: Dictionary) -> void:
	var f := _owner(o)
	if f == null or f == FactionRegistry.Neutral:
		_account(key, "structure")
		return
	var tracks := [
		[Enums.ResearchTrackKind.ShipDesign, int(o["shipyard_rd_order"])],
		[Enums.ResearchTrackKind.TroopTraining, int(o["training_facil_rd_order"])],
		[Enums.ResearchTrackKind.FacilityDesign, int(o["construction_yard_rd_order"])],
	]
	for tr in tracks:
		var track: int = tr[0]
		var order: int = tr[1]
		var bank := 0
		var designs: Array = FacilityCatalog.All() if track == Enums.ResearchTrackKind.FacilityDesign else Lq.where(MilitaryCatalog.All(), func(d): return ResearchManager.TrackFor(d) == track)
		for d in designs:
			if d.CanBeBuiltBy(f) and d.ResearchOrder > 0 and d.ResearchOrder <= order:
				bank = maxi(bank, d.ResearchCost)
		ResearchManager.Bank(f)[track] = bank
		for d in designs:
			if d.CanBeBuiltBy(f) and d.ResearchOrder > order and d.ResearchCost <= bank:
				_note("%s: %s comes with research order %d here (this engine unlocks by cost)." % [f.DisplayName, d.DisplayName, order])
	# The original's own numbering: the side's count per kind ("Fleet 9",
	# "Imperial Star Destroyer 2"), so new ones go on from it.
	for node: Array in o["lc8"][1]:
		var type_key: int = int(node[2])
		var count: int = int(node[1])
		var family: int = type_key >> 24
		if family == 0x08:
			Fleet.NoteName(f, "Fleet %d" % count)
		else:
			var def: PackDefs.UnitDef = MilitaryCatalog.BySource(Vector2i(family, type_key & 0xffffff))
			if def != null:
				Unit.NoteClassName(f, def.Id, def.DisplayName, "%s %d" % [def.DisplayName, count])
	if int(o["victory_conditions"]) != 0:
		_leave(0, "victory conditions this reader cannot name", "%s %d" % [f.DisplayName, int(o["victory_conditions"])])
	# Material on hand: the side's raw and refined words (REBEXE: mines add to
	# the one, refineries to the other; original_save.gd). One unit is one
	# unit of this engine's: an item's points are its refined cost.
	var e := Economy.For(f)
	e.RawMaterials = int(o["raw_material"])
	e.RefinedMaterials = int(o["refined_material"])
	if int(o["raw_waiting"]) + int(o["refined_waiting"]) > 0:
		_leave(0, "facilities queued for material (this engine feeds them each day by its own rule)",
			"%s: %d refineries waiting for raw, %d factories for refined" % [f.DisplayName, int(o["raw_waiting"]), int(o["refined_waiting"])])
	_carry(key, "sides")


# ---- what the scheduler held -------------------------------------------------------------------

## Arrivals and missions' next attempts are carried on their objects above.
## Escape attempts: the live one's day. The rest this engine arms by its own
## rules on the next day; listed.
func _timers() -> void:
	var others := {}
	for e: Dictionary in _g["queue_a8"]:
		var code: int = int(e["code"])
		var target: int = int(e["target"])
		if code == 0x387 or code == 0x38b or (code in [0x383, 0x384] and _planets.has(target) and (_planets[target] as Planet).IsInUprising):
			continue
		if code == 0x38a and _units.has(target) and _units[target] is Character:
			var o: Dictionary = _objs[target]["o"]
			var live := _live_fire_day(target, o, 0x38a)
			if live >= 0:
				(_units[target] as Character).NextEscapeAttemptOn = live + 1
			continue
		var what: String = TIMER_NAMES.get(code, "0x%x" % code)
		others[what] = int(others.get(what, 0)) + 1
	for what in others:
		_leave(0, "scheduled events this engine times by its own rules", "%s %d" % [what, others[what]])
	for q in ["queue_ac", "queue_b0"]:
		if not (_g[q] as Array).is_empty():
			_leave(0, "queued game events waiting to run", "%s %d" % [q, (_g[q] as Array).size()])


## Orders under way. The original draws an order's refined material a unit
## per point as it builds (manual p047: short of it, "construction will take
## longer"); this engine charges the whole cost when the order is placed. The
## imported orders were placed in the original, so they come across paid for,
## the material on hand is the original's, and what they would still have
## drawn is said.
func _economy() -> void:
	for f in [_alliance, _empire]:
		var owed: int = int(_owed.get(f.Id, 0))
		if owed > 0:
			_note("%s's orders under way are carried as paid for; the original would still draw %d refined for them as they build (it had %d on hand)." % [f.DisplayName, owed, Economy.For(f).RefinedMaterials])


## What each side knows of the worlds it does not hold: this engine's own
## opening sighting, dated the import day (the original's older sightings are
## its sides' copies of the galaxy, which it does not keep as dated reports).
func _intel() -> void:
	for f in [_alliance, _empire]:
		for p: Planet in GameState.AllPlanets():
			if p.ExploredBy(f) and p.ControllingFaction != f:
				IntelManager.Capture(f, p, _day + 1, IntelManager.ReconnaissanceCategories)
	_leave(0, "when each side last saw each enemy world (sightings are dated the import day)", "")


## THE ORIGINAL'S MESSAGES: the player's message windows, kept in the human
## player's block after the game (SAVEGAME-FORMAT.md, "The players"), each with
## its own title and words - carried as this engine's messages, in the
## original's order, on the day each was posted. A mission report that asks
## "Do you wish the mission to continue?" gets its Continue / Abort (manual
## p110), for the mission it is about.
func _messages() -> void:
	var human: Dictionary = _g.get("human", {})
	var f: Faction = GameSettings.PlayerFaction
	if human.is_empty() or f == null:
		_leave(0, "the original's messages (its players' part could not be read: %s)" % str(_g.get("tail_error", "")), "")
		return
	var wordless := 0
	for list in ["windows", "windows2", "windows3"]:
		for w: Dictionary in human.get(list, []):
			var title := ""
			var text := ""
			if w.has("title"):
				title = str(w["title"])
				text = str(w["text"])
			elif w.has("strings") and not (w["strings"] as Array).is_empty():
				title = str(w["strings"][0])
				text = "\n".join((w["strings"] as Array).slice(1))
			if title.strip_edges().is_empty() and text.strip_edges().is_empty():
				wordless += 1
				continue
			var about: Variant = _units.get(int(w.get("keys", [0])[0]))
			var mission: Mission = null
			if about is Unit:
				mission = Lq.first_or_null(MissionManager._active, func(m): return m.Team.has(about))
			var where: Location = mission.Target if mission != null else (about.Attached if about is Unit and about.Attached is Planet else null)
			var msg := GameMessage.new(title, text, _category(w, about, mission), _posted_day(w) + 1, where, about as Character if about is Character else null)
			if mission != null:
				msg.Type = Enums.MessageType.MissionReport
				msg.Advisor = "personnel_report"
				if text.strip_edges().ends_with("continue?"):
					msg.PendingMission = mission
			elif about is Unit:
				msg.Type = Enums.MessageType.UnitDeployment
				msg.Advisor = "production"
			EventBus.Tell(f, msg)
			_carried["messages"] = int(_carried.get("messages", 0)) + 1
	if wordless > 0:
		_leave(0, "open windows with no words of their own (the original's screens)", "%d" % wordless)
	var queued := 0
	for g: Dictionary in human.get("log", []):
		queued += (g["items"] as Array).size()
	if queued > 0:
		_leave(0, "messages the original had queued but not yet shown (it words them when it shows them)", "%d" % queued)


## The message's category, as this engine files the same news: a mission's
## report under Missions; a unit delivered under Defense for troops and
## Special Forces, Manufacturing for the rest (Planet.Deliver).
func _category(w: Dictionary, about: Variant, mission: Mission) -> int:
	if mission != null:
		return Enums.MessageCategory.Missions
	if about is Unit and not (about is Character):
		var t: int = (about as Unit).Type
		return Enums.MessageCategory.Defense if (t == Enums.UnitType.Troop or t == Enums.UnitType.SpecForce) else Enums.MessageCategory.Manufacturing
	return Enums.MessageCategory.All


## The original's day a window was posted: the window keeps the tick (its
## base's third word); a tick of today is today, earlier ones count back by the
## day's length in ticks (taken as today's - the game's speed setting sets it).
func _posted_day(w: Dictionary) -> int:
	var tick: int = int(w.get("b0", [0, 0, -1])[2])
	var game: Dictionary = _g["game"]
	var per_day: int = maxi(1, int(game["ticks_per_day"]))
	var day_start: int = int(game["sub_tick"]) - int(game["tick_in_day"])
	if tick < 0 or tick >= day_start:
		return _day
	return maxi(0, _day - 1 - (day_start - 1 - tick) / per_day)


# ---- the report ---------------------------------------------------------------------------------

## The report; `most` > 0 shortens each list of names to that many.
func _report(most: int) -> Array[String]:
	var lines: Array[String] = []
	var side: String = GameSettings.PlayerFaction.DisplayName if GameSettings.PlayerFaction != null else "?"
	lines.append("Imported from Star Wars: Rebellion: \"%s\", Day %d, %s, %s, %s galaxy." % [str(_g["name"]), _day, side,
		JsonUtil.enum_name(Enums.Difficulty, GameSettings.SelectedDifficulty), JsonUtil.enum_name(Enums.GalaxySize, GameSettings.SelectedSize).to_lower()])
	var carried: Array = []
	for what in _carried:
		carried.append("%d %s" % [_carried[what], what])
	lines.append("Carried across: %s." % ", ".join(carried))
	if not _left.is_empty():
		lines.append("Not carried:")
		for why in _left:
			var names: Array = _left[why]
			var shown: Array = names if most <= 0 or names.size() <= most else names.slice(0, most)
			var more: String = "" if shown.size() == names.size() else " and %d more" % (names.size() - shown.size())
			lines.append("  - %s%s%s" % [why, (": " + ", ".join(shown)) if not names.is_empty() else "", more])
	if not _notes.is_empty():
		lines.append("Carried, with a difference:")
		for n in _notes:
			lines.append("  - %s" % n)
	if not Unaccounted.is_empty():
		lines.append("NOT ACCOUNTED FOR (a fault in the importer): %s" % ", ".join(Unaccounted))
	return lines


func _tell_player() -> void:
	var f: Faction = GameSettings.PlayerFaction
	if f == null:
		return
	var msg := GameMessage.new("Game imported", "\n".join(_report(6)), Enums.MessageCategory.All, _day + 1)
	EventBus.Tell(f, msg)
