class_name PackLoader
extends RefCounted
## backend/Packs/PackLoader.cs - reads a faction pack off disk and validates it.
## Validation collects EVERY problem rather than stopping at the first, so a pack
## author sees the whole list in one pass (SCHEMA.md section 11).

const SupportedSchemaVersion := 1
const KNOWN_HQ_KINDS := ["fixed", "hidden"]
const KNOWN_OCCUPATION_POLICIES := ["garrison_bonus", "occupation_penalty"]
const KNOWN_COMMAND_RANKS := ["admiral", "commander", "general"]
## SCHEMA.md section 5. The engine's selection vocabulary for this schema_version.
## Rejecting an unknown role is what stops a typo silently creating an inert
## facility that no system ever asks for.
const KNOWN_FACILITY_ROLES := ["headquarters", "extracts_raw", "refines",
	"produces_unit", "produces_troop", "produces_facility", "planet_defense",
	"shield", "disable", "anti_ship", "superweapon_shield"]
## SCHEMA.md section 6. What a weapon DOES; the tactical engine branches on
## these and on nothing else about a weapon.
const KNOWN_WEAPON_ROLES := ["fighter_accuracy_scaled", "no_fighter_effect",
	"requires_shields_down", "squadron_only"]
## Which producer and queue a unit uses is engine structure, not pack vocabulary.
const KNOWN_UNIT_KINDS := ["capital_ship", "fighter", "troop", "spec_force"]
## SCHEMA.md section 10. The quantities the engine can compute for a GID mode -
## measured from the catalog it replaced, one per distinct magnitude reader.
const KNOWN_GID_KINDS := ["support", "uprising", "my_fleets", "personnel",
	"status_figure", "facility_count", "idle_producer", "defence_figure",
	"intel_line_count", "constant_zero"]
const KNOWN_GID_FLARES := ["big", "mid", "low", "none"]
const SPECIAL_POWER_RANK_KEYS := ["none", "novice", "trainee", "student", "knight", "master"]
## SCHEMA.md section 10, `terms`: the engine concepts a pack may label. The
## engine reads stats and resources by THESE keys (they are vocabulary, like
## roles); the pack supplies the values and, here, the words. Optional - a key
## a pack omits falls back to the engine's neutral label - but an unknown key is
## an error, so a typo cannot silently label nothing.
const KNOWN_TERMS := [
	# unit stats
	"hyperdrive", "sublight", "shield", "hull", "detection", "weapons",
	"bombardment", "bombardment_defense", "bombardment_modifier",
	"maintenance", "squadron_size", "fighter_capacity", "troop_capacity",
	# the economy
	"energy", "raw_materials", "refined_materials", "mine", "mines", "refinery", "refineries",
	# the two defence kinds, as prose plurals
	"planetary_shields", "orbital_batteries",
	# unit kinds, singular and plural
	"fighter_squadron", "fighter_squadrons", "trooper_regiment", "trooper_regiments",
	# movement between systems
	"in_transit",
	# the five ship systems tactical damage tracks
	"system_shield_recharge", "system_weapon_recharge", "system_tractor", "system_engines", "system_hyperdrive",
	# a standing defence's state tag in the Defenses window
	"shield_active", "weapon_armed",
]
## SCHEMA.md section 2, `menu`. Every function of the Shuttle Cockpit (manual
## p021, Fig. 2.2); a picture menu must offer each one, so no function is lost
## behind an image that forgot it.
const KNOWN_MENU_ACTIONS := ["difficulty", "galaxy_size", "start", "load_game",
	"credits", "hq_only_victory", "multiplayer", "exit"]
const KNOWN_DIFFICULTIES := ["easy", "medium", "hard"]
## SCHEMA.md section 7. Day-zero placement and the story parts. Each story
## part is ONE character - the set-pieces are written for one pilgrim, one
## heir, and so on.
const KNOWN_CHARACTER_ROLES := ["starts_at_first_world", "starts_at_hq", "starts_at_random_holding",
	"pilgrim", "heir", "dark_lord", "dark_master", "smuggler", "companion"]
const SINGLETON_CHARACTER_ROLES := ["pilgrim", "heir", "dark_lord", "dark_master", "smuggler", "companion"]
## SCHEMA.md section 6. The engine's special cases for a unit.
const KNOWN_UNIT_ROLES := ["superweapon", "garrison_troop"]
## SCHEMA.md section 14. The art sets the engine knows - each one a player's
## own export (tools/FactionWarsExporter), never shipped - and the side looks
## (skins) each has.
const KNOWN_ART_SETS := {"swr-original": ["alliance", "empire"]}
## The row kinds an `art` reference may name.
const ART_KINDS := ["characters", "units", "facilities", "missions", "planets"]


class LoadedPack:
	var Manifest: PackDefs.PackManifest
	var Factions: Array[PackDefs.FactionDef] = []
	var Map: PackDefs.MapFile
	var Characters: Array[PackDefs.CharacterDef] = []
	var Facilities: Array[PackDefs.FacilityDef] = []
	var Units: Array[PackDefs.UnitDef] = []
	var Weapons: Array[PackDefs.WeaponDef] = []
	var Missions: Array[PackDefs.MissionDefPack] = []
	var MissionTables: Dictionary = {}   # table id -> PackDefs.MissionTableDef
	## Raw rows - see PackDefs.SetupFile.
	var Rules: Array = []
	var Setup: PackDefs.SetupFile
	var Display: PackDefs.DisplayDef


## Returns the pack, or null with `errors` populated. Never throws on bad pack
## content - malformed JSON is reported as an error like any other.
static func Load(pack_dir: String, errors: Array[String]) -> LoadedPack:
	var manifest_d: Variant = _read_json("%s/pack.json" % pack_dir, errors)
	var factions_d: Variant = _read_json("%s/factions.json" % pack_dir, errors)
	var map_d: Variant = _read_json("%s/map.json" % pack_dir, errors)
	var chars_d: Variant = _read_json("%s/characters.json" % pack_dir, errors)
	var facil_d: Variant = _read_json("%s/facilities.json" % pack_dir, errors)
	var units_d: Variant = _read_json("%s/units.json" % pack_dir, errors)
	var weapons_d: Variant = _read_json("%s/weapons.json" % pack_dir, errors)
	var missions_d: Variant = _read_json("%s/missions.json" % pack_dir, errors)
	var mtables_d: Variant = _read_json("%s/mission_tables.json" % pack_dir, errors)
	var rules_d: Variant = _read_json("%s/rules.json" % pack_dir, errors)
	var setup_d: Variant = _read_json("%s/setup.json" % pack_dir, errors)
	var display_d: Variant = _read_json("%s/display.json" % pack_dir, errors)
	for d in [manifest_d, factions_d, map_d, chars_d, facil_d, units_d, weapons_d, missions_d, mtables_d, rules_d, setup_d, display_d]:
		if d == null:
			return null
	var pack := LoadedPack.new()
	pack.Manifest = PackDefs.PackManifest.from_dict(manifest_d)
	pack.Factions = PackDefs.FactionsFile.from_dict(factions_d).Factions
	pack.Map = PackDefs.MapFile.from_dict(map_d)
	pack.Characters = PackDefs.CharactersFile.from_dict(chars_d).Characters
	pack.Facilities = PackDefs.FacilitiesFile.from_dict(facil_d).Facilities
	pack.Units = PackDefs.UnitsFile.from_dict(units_d).Units
	pack.Weapons = PackDefs.WeaponsFile.from_dict(weapons_d).Weapons
	pack.Missions = PackDefs.MissionsFile.from_dict(missions_d).Missions
	pack.MissionTables = PackDefs.MissionTablesFile.from_dict(mtables_d).Tables
	pack.Rules = rules_d if rules_d is Array else []
	pack.Setup = PackDefs.SetupFile.from_dict(setup_d)
	pack.Display = PackDefs.DisplayDef.from_dict(display_d)
	_validate(pack, pack_dir, errors)
	return pack if errors.is_empty() else null


static func _read_json(path: String, errors: Array[String]) -> Variant:
	var text := JsonUtil.read_text(path)
	if text.strip_edges().is_empty():
		errors.append("%s: missing or empty." % path)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: malformed JSON - %s" % [path, json.get_error_message()])
		return null
	return json.data


static func _validate(pack: LoadedPack, pack_dir: String, errors: Array[String]) -> void:
	var m := pack.Manifest

	# 1. Manifest identity and version.
	var folder := pack_dir.trim_suffix("/").get_file()
	if m.Id != folder:
		errors.append("pack.json: id '%s' does not match folder name '%s'." % [m.Id, folder])
	if m.SchemaVersion > SupportedSchemaVersion:
		errors.append("pack.json: schema_version %d is newer than this engine supports (%d)." % [m.SchemaVersion, SupportedSchemaVersion])

	# 2. Faction count, 2-4, and matching the declared count.
	var count := pack.Factions.size()
	if count < 2 or count > 4:
		errors.append("factions.json: %d factions declared; must be 2-4." % count)
	if m.FactionCount != count:
		errors.append("pack.json: faction_count is %d but factions.json declares %d." % [m.FactionCount, count])

	if m.Neutral == null or m.Neutral.Id.strip_edges().is_empty():
		errors.append("pack.json: 'neutral' must declare an id, display_name and color.")
	else:
		_require_color(m.Neutral.ColorHex, "pack.json: neutral.color", errors)
	_require_color(m.UnexploredColor, "pack.json: unexplored_color", errors)

	var seen := {}
	for f in pack.Factions:
		var ctx := "factions.json[%s]" % (f.Id if not f.Id.is_empty() else "?")

		if f.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif seen.has(f.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			seen[f.Id] = true
		if m.Neutral != null and f.Id == m.Neutral.Id:
			errors.append("%s: id collides with the neutral id; neutral is not a playable faction." % ctx)

		if f.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		if f.LoyaltyLabel.strip_edges().is_empty():
			errors.append("%s: missing loyalty_label." % ctx)
		_require_color(f.ColorHex, "%s: color" % ctx, errors)

		if not f.OccupationSupportPolicy.is_empty() and not KNOWN_OCCUPATION_POLICIES.has(f.OccupationSupportPolicy):
			errors.append("%s: unknown occupation_support_policy '%s'. Known: %s." % [ctx, f.OccupationSupportPolicy, ", ".join(KNOWN_OCCUPATION_POLICIES)])

		# 6. HQ internal consistency.
		if f.Hq == null:
			errors.append("%s: missing hq." % ctx)
		elif not KNOWN_HQ_KINDS.has(f.Hq.Kind):
			errors.append("%s: unknown hq.kind '%s'. Known: %s." % [ctx, f.Hq.Kind, ", ".join(KNOWN_HQ_KINDS)])
		elif f.Hq.Kind == "fixed" and f.Hq.Planet.strip_edges().is_empty():
			errors.append("%s: hq.kind 'fixed' requires hq.planet." % ctx)
		elif f.Hq.Kind == "hidden" and f.Hq.Placement.strip_edges().is_empty():
			errors.append("%s: hq.kind 'hidden' requires hq.placement (a planet id or 'random_rim')." % ctx)

	_validate_map(pack, pack_dir, errors)
	_validate_characters(pack, errors)
	_validate_facilities(pack, errors)
	_validate_units(pack, errors)
	_validate_missions(pack, errors)
	_validate_setup(pack, errors)
	_validate_display(pack, errors)
	_validate_menu(pack, pack_dir, errors)
	_validate_icons(pack, pack_dir, errors)
	_validate_roles(pack, errors)
	_validate_art(pack, errors)


## Rule 12: character roles, unit roles and mission behaviours are in the
## engine's vocabulary; each story part and each behaviour is declared once.
static func _validate_roles(pack: LoadedPack, errors: Array[String]) -> void:
	var story_count: Dictionary = {}
	for c in pack.Characters:
		var ctx := "characters.json[%s]" % (c.Id if not c.Id.is_empty() else "?")
		for r in c.Roles:
			if not KNOWN_CHARACTER_ROLES.has(r):
				errors.append("%s: unknown role '%s'. Known: %s." % [ctx, r, ", ".join(KNOWN_CHARACTER_ROLES)])
			elif SINGLETON_CHARACTER_ROLES.has(r):
				story_count[r] = story_count.get(r, 0) + 1
	for r in story_count:
		if story_count[r] > 1:
			errors.append("characters.json: %d characters carry the story role '%s'; the set-pieces are written for one." % [story_count[r], r])
	for u in pack.Units:
		var ctx := "units.json[%s]" % (u.Id if not u.Id.is_empty() else "?")
		for r in u.Roles:
			if not KNOWN_UNIT_ROLES.has(r):
				errors.append("%s: unknown role '%s'. Known: %s." % [ctx, r, ", ".join(KNOWN_UNIT_ROLES)])
	var known := MissionCatalog.KnownBehaviours()
	var seen: Dictionary = {}
	for m in pack.Missions:
		if m.Behaviour.is_empty():
			continue
		var ctx := "missions.json[%s]" % (m.Id if not m.Id.is_empty() else "?")
		if not known.has(m.Behaviour):
			errors.append("%s: unknown behaviour '%s'. Known: %s." % [ctx, m.Behaviour, ", ".join(known)])
		elif seen.has(m.Behaviour):
			errors.append("%s: behaviour '%s' is already '%s' - one mission per engine behaviour." % [ctx, m.Behaviour, seen[m.Behaviour]])
		else:
			seen[m.Behaviour] = m.Id


## Rule 11: the Cockpit picture, when a pack has one, reaches every menu function
## exactly the way the button menu does - one region per difficulty, per offered
## galaxy size and per playable faction, and one each of the rest.
## The sector window's corner glyphs (manual p070 Fig 3.7). A pack may ship its
## own picture for any of them; the engine's assets/icons/ stands in otherwise.
const KNOWN_CORNER_ICONS := ["manufacturing", "defenses", "fleet", "mission", "uprising"]


## Rule 17: display.json icons name known glyphs and files the pack ships.
static func _validate_icons(pack: LoadedPack, pack_dir: String, errors: Array[String]) -> void:
	if pack.Display == null:
		return
	for key in pack.Display.Icons:
		if not KNOWN_CORNER_ICONS.has(key):
			errors.append("display.json: icons names '%s', which is not a corner glyph. Known: %s." % [key, ", ".join(KNOWN_CORNER_ICONS)])
			continue
		var file: String = str(pack.Display.Icons[key]).strip_edges()
		var image_path := "%s/%s" % [pack_dir, file]
		if file.is_empty() or not (ResourceLoader.exists(image_path) or FileAccess.file_exists(image_path)):
			errors.append("display.json: icons['%s'] = '%s' is not in %s." % [key, file, pack_dir])


static func _validate_menu(pack: LoadedPack, pack_dir: String, errors: Array[String]) -> void:
	var setup := pack.Manifest.Setup
	var sizes: Array[String] = setup.GalaxySizes if setup != null else []
	# The game offers three galaxy sizes (the menu's buttons, a multiplayer
	# room's settings - Enums.GalaxySize); a pack with fewer gives an empty
	# galaxy for the ones it lacks. More are allowed.
	if sizes.size() < 3:
		errors.append("pack.json: setup.galaxy_sizes has %d; the game offers three sizes, so it needs at least 3." % sizes.size())
	if setup != null and not setup.GalaxySizeDefault.is_empty() and not sizes.has(setup.GalaxySizeDefault):
		errors.append("pack.json: setup.galaxy_size_default '%s' is not one of setup.galaxy_sizes (%s)." % [setup.GalaxySizeDefault, ", ".join(sizes)])
	if setup != null and not setup.DifficultyDefault.is_empty() and not KNOWN_DIFFICULTIES.has(setup.DifficultyDefault):
		errors.append("pack.json: setup.difficulty_default '%s' is not one of %s." % [setup.DifficultyDefault, ", ".join(KNOWN_DIFFICULTIES)])
	var tips := pack.Manifest.VictoryTips
	if tips != null and (tips.Standard.strip_edges().is_empty() or tips.HqOnly.strip_edges().is_empty()):
		errors.append("pack.json victory_tips: 'standard' and 'hq_only' texts are both required (manual p162).")
	var menu := pack.Manifest.Menu
	if menu == null:
		return
	if menu.ImageFile.strip_edges().is_empty():
		errors.append("pack.json menu: 'image' is required - name the Cockpit picture shipped with the pack.")
	elif SplitArtRef(menu.ImageFile)[0].is_empty():
		var image_path := "%s/%s" % [pack_dir, menu.ImageFile]
		if not (ResourceLoader.exists(image_path) or FileAccess.file_exists(image_path)):
			errors.append("pack.json menu: image '%s' is not in %s." % [menu.ImageFile, pack_dir])
	_require_color(menu.SelectedColorHex, "pack.json menu.selected_color", errors)
	if menu.Readout == null:
		errors.append("pack.json menu: 'readout' is required - the panel that shows Standard Game / Headquarters Only Victory.")
	else:
		if menu.Readout.Rect.size() != 4 or menu.Readout.Rect[2] <= 0 or menu.Readout.Rect[3] <= 0:
			errors.append("pack.json menu.readout: rect must be [x, y, w, h] with w and h > 0.")
		if menu.Readout.Standard.strip_edges().is_empty() or menu.Readout.HqOnly.strip_edges().is_empty():
			errors.append("pack.json menu.readout: 'standard' and 'hq_only' texts are required.")
		_require_color(menu.Readout.ColorHex, "pack.json menu.readout.color", errors)

	var faction_ids: Array[String] = []
	for f in pack.Factions:
		faction_ids.append(f.Id)
	var seen: Dictionary = {}   # "action" or "action:value" -> count
	for i in menu.Regions.size():
		var r := menu.Regions[i]
		var ctx := "pack.json menu.regions[%d]" % i
		if not KNOWN_MENU_ACTIONS.has(r.Action):
			errors.append("%s: action '%s' is not one of %s." % [ctx, r.Action, ", ".join(KNOWN_MENU_ACTIONS)])
			continue
		if r.Rect.size() != 4 or r.Rect[2] <= 0 or r.Rect[3] <= 0:
			errors.append("%s (%s): rect must be [x, y, w, h] with w and h > 0." % [ctx, r.Action])
		if not r.SelectedColorHex.is_empty():
			_require_color(r.SelectedColorHex, "%s (%s) selected_color" % [ctx, r.Action], errors)
		if r.QuadGiven and r.Quad.size() != 4:
			errors.append("%s (%s): quad must be four [x, y] corners - top-left, top-right, bottom-right, bottom-left." % [ctx, r.Action])
		var key := r.Action
		match r.Action:
			"difficulty":
				if not KNOWN_DIFFICULTIES.has(r.Value):
					errors.append("%s: difficulty value '%s' is not one of %s." % [ctx, r.Value, ", ".join(KNOWN_DIFFICULTIES)])
				key = "difficulty:%s" % r.Value
			"galaxy_size":
				if not sizes.has(r.Value):
					errors.append("%s: galaxy_size value '%s' is not one of pack.json setup.galaxy_sizes (%s)." % [ctx, r.Value, ", ".join(sizes)])
				key = "galaxy_size:%s" % r.Value
			"start":
				if not faction_ids.has(r.Value):
					errors.append("%s: start value '%s' is not a faction id in factions.json." % [ctx, r.Value])
				key = "start:%s" % r.Value
		seen[key] = seen.get(key, 0) + 1

	var required: Array[String] = ["load_game", "credits", "hq_only_victory", "multiplayer", "exit"]
	for d in KNOWN_DIFFICULTIES:
		required.append("difficulty:%s" % d)
	for sz in sizes:
		required.append("galaxy_size:%s" % sz)
	for fid in faction_ids:
		required.append("start:%s" % fid)
	for key in required:
		var n: int = seen.get(key, 0)
		if n == 0:
			errors.append("pack.json menu: no region for '%s' - every Cockpit function needs one (manual p021, Fig. 2.2)." % key)
		elif n > 1:
			errors.append("pack.json menu: '%s' has %d regions; one each." % [key, n])

	# The monitors' pictures (manual p021, Fig. 2.2): a strip of frames, where
	# it sits, and - for a picture that changes with a choice - the region.
	if menu.MonitorFps <= 0:
		errors.append("pack.json menu.monitor_fps: must be above 0.")
	for i in menu.Monitors.size():
		var m := menu.Monitors[i]
		var ctx := "pack.json menu.monitors[%d]" % i
		for pair in [["image", m.ImageFile], ["selected_image", m.SelectedImageFile]]:
			if pair[1].is_empty():
				if pair[0] == "image":
					errors.append("%s: 'image' is required." % ctx)
				continue
			if SplitArtRef(pair[1])[0].is_empty():
				var path := "%s/%s" % [pack_dir, pair[1]]
				if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
					errors.append("%s: %s '%s' is not in %s." % [ctx, pair[0], pair[1], pack_dir])
		if m.At.size() != 2:
			errors.append("%s: 'at' must be [x, y]." % ctx)
		if m.Frames < 1:
			errors.append("%s: 'frames' must be 1 or more." % ctx)
		if m.Still >= m.Frames:
			errors.append("%s: 'still' must be a frame of the strip (0 to %d)." % [ctx, m.Frames - 1])
		if not m.Region.is_empty() and not seen.has(m.Region):
			errors.append("%s: region '%s' is not a region of the menu." % [ctx, m.Region])
		if not m.SelectedImageFile.is_empty() and m.Region.is_empty():
			errors.append("%s: 'selected_image' needs the 'region' it shows for." % ctx)
		for key in m.FrameBy:
			if not seen.has(key):
				errors.append("%s: frame_by region '%s' is not a region of the menu." % [ctx, key])
			if int(m.FrameBy[key]) < 0 or int(m.FrameBy[key]) >= m.Frames:
				errors.append("%s: frame_by '%s' must be a frame of the strip (0 to %d)." % [ctx, key, m.Frames - 1])


## SCHEMA.md section 11 rules 4 and 8 for the display catalog.
static func _validate_display(pack: LoadedPack, errors: Array[String]) -> void:
	var d := pack.Display
	if d == null:
		errors.append("display.json: unreadable.")
		return
	var mode_ids := {}
	for c in d.Categories:
		var cctx := "display.json categories[%s]" % (c.Id if not c.Id.is_empty() else "?")
		if c.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % cctx)
		if c.Modes.is_empty():
			errors.append("%s: declares no modes." % cctx)
		for m in c.Modes:
			var ctx := "display.json modes[%s]" % (m.Id if not m.Id.is_empty() else "?")
			if m.Id.strip_edges().is_empty():
				errors.append("%s: missing id." % ctx)
			elif mode_ids.has(m.Id):
				errors.append("%s: duplicate id." % ctx)
			else:
				mode_ids[m.Id] = true
			if m.LabelText.strip_edges().is_empty():
				errors.append("%s: missing label." % ctx)
			# Rule 4: an unknown kind is a mode the engine cannot compute.
			if not KNOWN_GID_KINDS.has(m.Kind):
				errors.append("%s: unknown quantity.kind '%s'. Known: %s." % [ctx, m.Kind, ", ".join(KNOWN_GID_KINDS)])
			# Rule 8: tiers descend and end at a min-0 bare-dot tier.
			if m.Tiers.is_empty():
				errors.append("%s: declares no tiers." % ctx)
			else:
				var prev := INF
				for t in m.Tiers:
					if t.Min > prev:
						errors.append("%s: tiers must be ordered descending by min (%s after %s)." % [ctx, str(t.Min), str(prev)])
					prev = t.Min
					if not KNOWN_GID_FLARES.has(t.Flare):
						errors.append("%s: unknown flare '%s'. Known: %s." % [ctx, t.Flare, ", ".join(KNOWN_GID_FLARES)])
				if m.Tiers[m.Tiers.size() - 1].Min != 0.0:
					errors.append("%s: the last tier must have min 0 - it is the bare dot every world falls into." % ctx)
	for id in d.GalaxyDisplayModes:
		if not mode_ids.has(id):
			errors.append("display.json: galaxy_display_modes names '%s', which no category declares." % id)
	for key in SPECIAL_POWER_RANK_KEYS:
		if not d.SpecialPowerRanks.has(key):
			errors.append("display.json: special_power_ranks has no label for '%s'." % key)
	# Rule 16: loyalty_bar, when given, is every playable faction exactly once.
	if not d.LoyaltyBar.is_empty():
		var faction_ids: Array[String] = []
		for f in pack.Factions:
			faction_ids.append(f.Id)
		for id in d.LoyaltyBar:
			if not faction_ids.has(id):
				errors.append("display.json: loyalty_bar names '%s', which is not a faction id." % id)
			elif d.LoyaltyBar.count(id) > 1:
				errors.append("display.json: loyalty_bar names '%s' more than once." % id)
		for id in faction_ids:
			if not d.LoyaltyBar.has(id):
				errors.append("display.json: loyalty_bar leaves out '%s' - name every faction, or leave the key out for faction order." % id)
	# Rule 14: terms are the engine's known concepts, each with a non-empty label.
	for key in d.Terms:
		if not KNOWN_TERMS.has(key):
			errors.append("display.json: terms names '%s', which the engine has no concept for. Known: %s." % [key, ", ".join(KNOWN_TERMS)])
		elif str(d.Terms[key]).strip_edges().is_empty():
			errors.append("display.json: terms['%s'] is empty - leave the key out to take the engine's default." % key)


## SCHEMA.md section 11 rules 3 and 13 for setup: every logistics table a faction
## names must exist, and every row in every table must name a unit or facility
## the pack declares - or day zero seeds that side with nothing and says nothing.
static func _validate_setup(pack: LoadedPack, errors: Array[String]) -> void:
	if pack.Rules.is_empty():
		errors.append("rules.json: no rule entries.")
	if pack.Setup == null:
		errors.append("setup.json: unreadable.")
		return
	if pack.Setup.SideLottery.is_empty():
		errors.append("setup.json: 'side_lottery' is empty.")
	for f in pack.Factions:
		var named: Array[String] = []
		if f.Seed != null:
			for v in [f.Seed.HqFacilities, f.Seed.HqGarrison, f.Seed.Fleet, f.Seed.ProceduralFleet]:
				if not v.is_empty():
					named.append(v)
			# What day zero reads without asking (DayZeroGenerator,
			# "POPULATION, ECONOMY & LOGISTICS"): a seeded side's headquarters
			# takes hq_facilities, hq_garrison and fleet, and a starting world
			# with a garrison takes fleet. Left empty they passed here and
			# stopped the game at its first day (the editor handoff, 2026-09-23).
			var garrisoned: bool = Lq.any(f.StartingPlanets, func(sp) -> bool: return not sp.Garrison.is_empty())
			var needs: Array = []
			if f.Hq != null:
				needs = [["hq_facilities", f.Seed.HqFacilities], ["hq_garrison", f.Seed.HqGarrison], ["fleet", f.Seed.Fleet]]
			elif garrisoned:
				needs = [["fleet", f.Seed.Fleet]]
			for n in needs:
				if str(n[1]).is_empty():
					errors.append("factions.json[%s]: seed.%s is empty; day zero seeds %s from it." % [f.Id, n[0],
						"the headquarters" if n[0] != "fleet" or f.Hq != null else "each garrisoned starting world"])
		for sp in f.StartingPlanets:
			if not sp.Garrison.is_empty():
				named.append(sp.Garrison)
		for id in named:
			if not pack.Setup.Logistics.has(id):
				errors.append("factions.json[%s]: names logistics table '%s', which setup.json does not declare." % [f.Id, id])

	# Every inhabited world is seeded from core_system_facilities (a Core
	# sector, ring 1) or rim_system_facilities (any other), by those names.
	var rings := {}
	if pack.Map != null:
		for s in pack.Map.Sectors:
			rings["core_system_facilities" if s.Ring == 1 else "rim_system_facilities"] = true
	for table in rings:
		if not pack.Setup.Logistics.has(table):
			errors.append("setup.json: logistics has no '%s'; day zero seeds every %s world from it." % [table, "Core" if table.begins_with("core") else "Rim"])

	# Rule 13: every seeding asset names a declared unit or facility BY ID. A
	# row the engine cannot resolve would seed nothing and say nothing - that is
	# how the WWII pack's first soak opened with "0 Fleets containing 0 Capital
	# Ships". The original's FamilyId/AssetId numbers are refused outright.
	var unit_ids := {}
	for u in pack.Units:
		unit_ids[u.Id] = true
	var facility_ids := {}
	for fd in pack.Facilities:
		facility_ids[fd.Id] = true
	for table_id in pack.Setup.Logistics:
		var table: Variant = pack.Setup.Logistics[table_id]
		if not (table is Dictionary):
			# The seeder reads every table as an object and stops the game
			# when one is not (SeedManager.Load).
			errors.append("setup.json: logistics['%s'] is not an object." % table_id)
			continue
		var entries: Variant = JsonUtil.get_ci(table, "Entries")
		if not (entries is Array):
			continue
		for i in entries.size():
			var e: Variant = entries[i]
			if not (e is Dictionary):
				continue
			var assets: Array = []
			var one: Variant = JsonUtil.get_ci(e, "Asset")
			if one != null:
				assets.append(one)
			var many: Variant = JsonUtil.get_ci(e, "Assets")
			if many is Array:
				assets.append_array(many)
			for a in assets:
				var ctx := "setup.json logistics[%s] entry %d" % [table_id, i + 1]
				if a == null:
					continue   # the original's "None" row: an empty carrier slot, places nothing
				if not (a is Dictionary):
					errors.append("%s: asset is not an object." % ctx)
					continue
				if a.has("FamilyId") or a.has("AssetId"):
					errors.append("%s: names its asset by FamilyId/AssetId; seeding rows name a 'unit' or 'facility' id (SCHEMA.md section 12 Q1)." % ctx)
					continue
				var uid: String = JsonUtil.str_or(a, "unit", "")
				var fid: String = JsonUtil.str_or(a, "facility", "")
				if uid.is_empty() and fid.is_empty():
					errors.append("%s: asset names neither a 'unit' nor a 'facility'." % ctx)
				elif not uid.is_empty() and not fid.is_empty():
					errors.append("%s: asset names both a unit and a facility; one per row." % ctx)
				elif not uid.is_empty() and not unit_ids.has(uid):
					errors.append("%s: unit '%s' is not declared in units.json." % [ctx, uid])
				elif not fid.is_empty() and not facility_ids.has(fid):
					errors.append("%s: facility '%s' is not declared in facilities.json." % [ctx, fid])


## SCHEMA.md section 11 rules 3 and 5 for the mission catalog.
static func _validate_missions(pack: LoadedPack, errors: Array[String]) -> void:
	var faction_ids := {}
	for f in pack.Factions:
		faction_ids[f.Id] = true
	var unit_ids := {}
	for u in pack.Units:
		unit_ids[u.Id] = true

	var ids := {}
	for m in pack.Missions:
		var ctx := "missions.json[%s]" % (m.Id if not m.Id.is_empty() else "?")
		if m.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif ids.has(m.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			ids[m.Id] = true
		if m.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		for who in m.AvailableTo:
			if not faction_ids.has(who):
				errors.append("%s: available_to '%s' is not a declared faction." % [ctx, who])
		# Rule 3: a SpecForce nobody can field can never run the mission.
		for uid in m.SpecForces:
			if not unit_ids.has(uid):
				errors.append("%s: spec_forces names '%s', which units.json does not declare." % [ctx, uid])


## SCHEMA.md section 11 rules 3, 4 and 5 for units and their weapons.
static func _validate_units(pack: LoadedPack, errors: Array[String]) -> void:
	var faction_ids := {}
	for f in pack.Factions:
		faction_ids[f.Id] = true

	var weapon_ids := {}
	for w in pack.Weapons:
		var wctx := "weapons.json[%s]" % (w.Id if not w.Id.is_empty() else "?")
		if w.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % wctx)
		elif weapon_ids.has(w.Id):
			errors.append("%s: duplicate id." % wctx)
		else:
			weapon_ids[w.Id] = true
		if w.Roles.is_empty():
			errors.append("%s: declares no roles; the tactical engine would treat it as an ordinary gun." % wctx)
		for role in w.Roles:
			if not KNOWN_WEAPON_ROLES.has(role):
				errors.append("%s: unknown role '%s'. Known: %s." % [wctx, role, ", ".join(KNOWN_WEAPON_ROLES)])

	var ids := {}
	for u in pack.Units:
		var ctx := "units.json[%s]" % (u.Id if not u.Id.is_empty() else "?")
		if u.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif ids.has(u.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			ids[u.Id] = true
		if u.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		if not KNOWN_UNIT_KINDS.has(u.Kind):
			errors.append("%s: unknown kind '%s'. Known: %s." % [ctx, u.Kind, ", ".join(KNOWN_UNIT_KINDS)])
		for who in u.BuildableBy:
			if not faction_ids.has(who):
				errors.append("%s: buildable_by '%s' is not a declared faction." % [ctx, who])
		# Rule 3: a weapon nothing declares can never fire.
		for wid in u.Weapons:
			if not weapon_ids.has(wid):
				errors.append("%s: carries weapon '%s', which weapons.json does not declare." % [ctx, wid])


## SCHEMA.md section 11 rules 3, 4 and 5 for the facility catalog.
static func _validate_facilities(pack: LoadedPack, errors: Array[String]) -> void:
	var faction_ids := {}
	for f in pack.Factions:
		faction_ids[f.Id] = true

	var ids := {}
	var tiers_by_family := {}
	for fd in pack.Facilities:
		var ctx := "facilities.json[%s]" % (fd.Id if not fd.Id.is_empty() else "?")
		if fd.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif ids.has(fd.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			ids[fd.Id] = true
		if fd.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		if fd.Family.strip_edges().is_empty():
			errors.append("%s: missing family." % ctx)
		else:
			if not tiers_by_family.has(fd.Family):
				tiers_by_family[fd.Family] = {}
			if tiers_by_family[fd.Family].has(fd.Tier):
				errors.append("%s: family '%s' already declares tier %d." % [ctx, fd.Family, fd.Tier])
			tiers_by_family[fd.Family][fd.Tier] = true

		# Rule 4: an unknown role is a facility no system will ever select.
		if fd.Roles.is_empty():
			errors.append("%s: declares no roles; nothing would ever select it." % ctx)
		for role in fd.Roles:
			if not KNOWN_FACILITY_ROLES.has(role):
				errors.append("%s: unknown role '%s'. Known: %s." % [ctx, role, ", ".join(KNOWN_FACILITY_ROLES)])

		# Rule 5: buildable_by must name declared factions.
		for who in fd.BuildableBy:
			if not faction_ids.has(who):
				errors.append("%s: buildable_by '%s' is not a declared faction." % [ctx, who])

	# The catalog indexes on (family, tier) and only ever offers tier 1, so a
	# family that starts at tier 2 can never be built.
	for fam in tiers_by_family:
		if not tiers_by_family[fam].has(1):
			errors.append("facilities.json: family '%s' has no tier 1; it could never be built." % fam)

	# Somebody has to be the headquarters: day zero places one per faction.
	var hq := 0
	for fd in pack.Facilities:
		if fd.HasRole("headquarters"):
			hq += 1
	if hq == 0:
		errors.append("facilities.json: no facility has the 'headquarters' role; day zero has nothing to place.")


## SCHEMA.md section 11 rules 3 and 5, for the roster: ids unique, every faction
## reference declared, and the worlds a faction must capture people ON resolve.
static func _validate_characters(pack: LoadedPack, errors: Array[String]) -> void:
	var faction_ids := {}
	for f in pack.Factions:
		faction_ids[f.Id] = true

	var ids := {}
	var names := {}
	for c in pack.Characters:
		var ctx := "characters.json[%s]" % (c.Id if not c.Id.is_empty() else "?")
		if c.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif ids.has(c.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			ids[c.Id] = true
		if c.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		else:
			names[c.DisplayName] = true
		# Rule 5: a character on a side the pack does not declare can never act.
		if not faction_ids.has(c.FactionId):
			errors.append("%s: faction '%s' is not declared in factions.json." % [ctx, c.FactionId])
		for rank in c.CanCommand:
			if not KNOWN_COMMAND_RANKS.has(rank):
				errors.append("%s: unknown can_command entry '%s'. Known: %s." % [ctx, rank, ", ".join(KNOWN_COMMAND_RANKS)])
		# Rule 15: a declared start is a world the character's own side holds at
		# day zero - one of its starting_planets or its fixed HQ - so nobody opens
		# on enemy or empty ground.
		if not c.StartsAt.is_empty():
			var side: PackDefs.FactionDef = null
			for f in pack.Factions:
				if f.Id == c.FactionId:
					side = f
			var held: Array[String] = []
			if side != null:
				for sp in side.StartingPlanets:
					held.append(sp.Planet)
				if side.Hq != null and side.Hq.Kind == "fixed" and not side.Hq.Planet.is_empty():
					held.append(side.Hq.Planet)
			var on_map := false
			if pack.Map != null:
				for p in pack.Map.Planets:
					if p.Id == c.StartsAt:
						on_map = true
			if not on_map:
				errors.append("%s: starts_at '%s' is not a planet id in map.json." % [ctx, c.StartsAt])
			elif not held.has(c.StartsAt):
				errors.append("%s: starts_at '%s' is not a world %s holds at day zero (its starting_planets or fixed hq)." % [ctx, c.StartsAt, c.FactionId])

	# Rule 3: a victory condition that names nobody can never be met. By ID (Q1).
	for f in pack.Factions:
		if f.Victory == null:
			continue
		for n in f.Victory.CaptureCharacters:
			if not ids.has(n):
				errors.append("factions.json[%s]: victory target '%s' is not a character id in characters.json." % [f.Id, n])


## SCHEMA.md section 11 rules 3, 7, 9 and 10. The map is pack-loaded now, so the
## cross-references the loader used to defer are checkable.
static func _validate_map(pack: LoadedPack, pack_dir: String, errors: Array[String]) -> void:
	var m := pack.Map
	if m == null:
		errors.append("map.json: unreadable.")
		return

	var sizes: Array[String] = pack.Manifest.Setup.GalaxySizes if pack.Manifest.Setup != null else []
	var sector_ids := {}
	var sizes_used := {}
	for s in m.Sectors:
		var ctx := "map.json sectors[%s]" % (s.Id if not s.Id.is_empty() else "?")
		if s.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif sector_ids.has(s.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			sector_ids[s.Id] = true
		if s.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		# Rule 10: a sector outside every declared size can never appear in a game.
		if s.MinSize.is_empty():
			errors.append("%s: missing min_size." % ctx)
		elif not sizes.is_empty() and not sizes.has(s.MinSize):
			errors.append("%s: min_size '%s' is not one of pack.json setup.galaxy_sizes (%s)." % [ctx, s.MinSize, ", ".join(sizes)])
		else:
			sizes_used[s.MinSize] = true

	# Rule 10, second half: the smallest size offered must not be an empty galaxy.
	if not sizes.is_empty() and not sizes_used.has(sizes[0]):
		errors.append("map.json: no sector declares min_size '%s', the smallest size pack.json offers - that menu option would start an empty galaxy." % sizes[0])

	# Rule 3: every planet resolves to a declared sector.
	var planet_ids := {}
	var planet_names := {}
	for p in m.Planets:
		var ctx := "map.json planets[%s]" % (p.Id if not p.Id.is_empty() else "?")
		if p.Id.strip_edges().is_empty():
			errors.append("%s: missing id." % ctx)
		elif planet_ids.has(p.Id):
			errors.append("%s: duplicate id." % ctx)
		else:
			planet_ids[p.Id] = true
		if p.DisplayName.strip_edges().is_empty():
			errors.append("%s: missing display_name." % ctx)
		else:
			planet_names[p.DisplayName] = true
		if not sector_ids.has(p.Sector):
			errors.append("%s: sector '%s' is not declared in map.json." % [ctx, p.Sector])

	# Rule 7: a faction's named worlds exist - BY ID (SCHEMA.md section 12 Q1).
	# A hidden HQ's placement is either the random_rim sentinel or a planet id.
	for f in pack.Factions:
		for sp in f.StartingPlanets:
			if not sp.Planet.is_empty() and not planet_ids.has(sp.Planet):
				errors.append("factions.json[%s]: starting planet '%s' is not a planet id in map.json." % [f.Id, sp.Planet])
		if f.Hq != null and f.Hq.Kind == "fixed" and not f.Hq.Planet.is_empty() and not planet_ids.has(f.Hq.Planet):
			errors.append("factions.json[%s]: hq.planet '%s' is not a planet id in map.json." % [f.Id, f.Hq.Planet])
		if f.Hq != null and f.Hq.Kind == "hidden" and f.Hq.Placement != "random_rim" and not planet_ids.has(f.Hq.Placement):
			errors.append("factions.json[%s]: hq.placement '%s' is neither 'random_rim' nor a planet id in map.json." % [f.Id, f.Hq.Placement])

	# Rule 9: the pack declares its map image and ships it. An export ships an
	# imported texture as its .import remap plus the .ctex, never the source
	# file, so FileAccess alone says "missing" in every exported build (that
	# stopped the web game at the faction buttons, 2026-09-22). ResourceLoader
	# follows the remap; FileAccess still covers a raw file in the editor.
	if pack.Manifest.MapImage.strip_edges().is_empty():
		errors.append("pack.json: 'map_image' is required - name the galaxy backdrop shipped with the pack.")
	var rect := pack.Manifest.MapImageRect
	if rect != Rect2() and (rect.size.x <= 0.0 or rect.size.y <= 0.0):
		errors.append("pack.json: map_image_rect must be [x, y, w, h] with w and h > 0.")
	elif SplitArtRef(pack.Manifest.MapImage)[0].is_empty():
		var image_path := "%s/%s" % [pack_dir, pack.Manifest.MapImage]
		if not (ResourceLoader.exists(image_path) or FileAccess.file_exists(image_path)):
			errors.append("pack.json: map_image '%s' is not in %s." % [pack.Manifest.MapImage, pack_dir])
	# card_image is not checked for here: it is only the picker card's picture,
	# and a copy of a shipped pack that leaves it behind must still load (the
	# card then has no picture). An art-set reference is checked with the rest.


## Rule 18 (SCHEMA.md section 14): art sets, skins and art references.
static func _validate_art(pack: LoadedPack, errors: Array[String]) -> void:
	var sets := pack.Manifest.ArtSets
	var skins: Array = []
	for s in sets:
		if not KNOWN_ART_SETS.has(s):
			errors.append("pack.json art_sets: '%s' is not an art set the engine knows (%s)." % [s, ", ".join(KNOWN_ART_SETS.keys())])
		else:
			skins.append_array(KNOWN_ART_SETS[s])
	for f in pack.Factions:
		var ctx := "factions.json[%s]" % f.Id
		if sets.is_empty():
			if not f.ArtSkin.is_empty():
				errors.append("%s: skin '%s' needs pack.json art_sets - a skin is one of an art set's side looks." % [ctx, f.ArtSkin])
		elif f.ArtSkin.is_empty():
			errors.append("%s: 'skin' is required when the pack declares art_sets - which side look does it wear (%s)?" % [ctx, ", ".join(skins)])
		elif not skins.is_empty() and not skins.has(f.ArtSkin):
			errors.append("%s: skin '%s' is not a side look of %s (%s)." % [ctx, f.ArtSkin, ", ".join(sets), ", ".join(skins)])
	for pair in [["characters.json", pack.Characters], ["units.json", pack.Units], ["facilities.json", pack.Facilities],
			["missions.json", pack.Missions], ["map.json", pack.Map.Planets if pack.Map != null else []]]:
		for row in pair[1]:
			if row.Art.is_empty():
				continue
			var ctx := "%s[%s] art" % [pair[0], row.Id]
			if sets.is_empty():
				errors.append("%s: '%s' needs pack.json art_sets." % [ctx, row.Art])
			elif ParseArtRef(row.Art, sets).is_empty():
				errors.append("%s: '%s' must be [<art set>:]<kind>/<id>, the art set one of %s and the kind one of %s." % [ctx, row.Art, ", ".join(sets), ", ".join(ART_KINDS)])
	var images: Array = [["map_image", pack.Manifest.MapImage], ["card_image", pack.Manifest.CardImage],
		["menu.image", pack.Manifest.Menu.ImageFile if pack.Manifest.Menu != null else ""]]
	if pack.Manifest.Menu != null:
		for m in pack.Manifest.Menu.Monitors:
			images.append(["menu.monitors image", m.ImageFile])
			images.append(["menu.monitors selected_image", m.SelectedImageFile])
	for pair in images:
		var split := SplitArtRef(pair[1])
		if not split[0].is_empty() and not sets.has(split[0]):
			errors.append("pack.json %s: '%s' names art set '%s', which art_sets does not declare." % [pair[0], pair[1], split[0]])


## "<set>:<path>" -> [set, path]; a plain file name -> ["", name].
static func SplitArtRef(ref: String) -> PackedStringArray:
	var colon := ref.find(":")
	if colon <= 0 or ref.find("://") >= 0 or ref.substr(0, colon).contains("/"):
		return PackedStringArray(["", ref])
	return PackedStringArray([ref.substr(0, colon), ref.substr(colon + 1)])


## A row's `art`, "[<set>:]<kind>/<id>", as [set, kind, id] (set "" = any of
## the pack's), or [] when malformed or naming a set the pack does not declare.
static func ParseArtRef(ref: String, sets: Array) -> Array:
	var split := SplitArtRef(ref)
	if not split[0].is_empty() and not sets.has(split[0]):
		return []
	var parts := split[1].split("/")
	if parts.size() != 2 or not ART_KINDS.has(parts[0]) or parts[1].strip_edges().is_empty():
		return []
	return [split[0], parts[0], parts[1]]


static func _require_color(value: String, ctx: String, errors: Array[String]) -> void:
	if value.strip_edges().is_empty():
		errors.append("%s: missing." % ctx)
		return
	var ok := value.length() == 7 and value[0] == "#"
	if ok:
		for i in range(1, 7):
			if not value[i].is_valid_hex_number():
				ok = false
				break
	if not ok:
		errors.append("%s: '%s' is not a #rrggbb color." % [ctx, value])
