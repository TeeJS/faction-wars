class_name PackLoader
extends RefCounted
## backend/Packs/PackLoader.cs - reads a faction pack off disk and validates it.
## Validation collects EVERY problem rather than stopping at the first, so a pack
## author sees the whole list in one pass (SCHEMA.md section 9).

const SupportedSchemaVersion := 1
const KNOWN_HQ_KINDS := ["fixed", "hidden"]
const KNOWN_OCCUPATION_POLICIES := ["garrison_bonus", "occupation_penalty"]
const KNOWN_COMMAND_RANKS := ["admiral", "commander", "general"]


class LoadedPack:
	var Manifest: PackDefs.PackManifest
	var Factions: Array[PackDefs.FactionDef] = []
	var Map: PackDefs.MapFile
	var Characters: Array[PackDefs.CharacterDef] = []


## Returns the pack, or null with `errors` populated. Never throws on bad pack
## content - malformed JSON is reported as an error like any other.
static func Load(pack_dir: String, errors: Array[String]) -> LoadedPack:
	var manifest_d: Variant = _read_json("%s/pack.json" % pack_dir, errors)
	var factions_d: Variant = _read_json("%s/factions.json" % pack_dir, errors)
	var map_d: Variant = _read_json("%s/map.json" % pack_dir, errors)
	var chars_d: Variant = _read_json("%s/characters.json" % pack_dir, errors)
	if manifest_d == null or factions_d == null or map_d == null or chars_d == null:
		return null
	var pack := LoadedPack.new()
	pack.Manifest = PackDefs.PackManifest.from_dict(manifest_d)
	pack.Factions = PackDefs.FactionsFile.from_dict(factions_d).Factions
	pack.Map = PackDefs.MapFile.from_dict(map_d)
	pack.Characters = PackDefs.CharactersFile.from_dict(chars_d).Characters
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
			errors.append("%s: hq.kind 'hidden' requires hq.placement (a planet name or 'random_rim')." % ctx)

	_validate_map(pack, pack_dir, errors)
	_validate_characters(pack, errors)


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

	# Rule 3: a victory condition that names nobody can never be met.
	for f in pack.Factions:
		if f.Victory == null:
			continue
		for n in f.Victory.CaptureCharacters:
			if not names.has(n):
				errors.append("factions.json[%s]: victory target '%s' is not a character in characters.json." % [f.Id, n])


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

	# Rule 7: a faction's named worlds exist. factions.json still names them by
	# DISPLAY NAME; SCHEMA.md section 12 Q1 moves it to ids, and this check moves
	# with it. Until then, match what the engine actually resolves on.
	for f in pack.Factions:
		for sp in f.StartingPlanets:
			if not sp.Planet.is_empty() and not planet_names.has(sp.Planet):
				errors.append("factions.json[%s]: starting planet '%s' is not in map.json." % [f.Id, sp.Planet])
		if f.Hq != null and f.Hq.Kind == "fixed" and not f.Hq.Planet.is_empty() and not planet_names.has(f.Hq.Planet):
			errors.append("factions.json[%s]: hq.planet '%s' is not in map.json." % [f.Id, f.Hq.Planet])

	# Rule 9: the pack declares its map image and ships it.
	if pack.Manifest.MapImage.strip_edges().is_empty():
		errors.append("pack.json: 'map_image' is required - name the galaxy backdrop shipped with the pack.")
	elif not FileAccess.file_exists("%s/%s" % [pack_dir, pack.Manifest.MapImage]):
		errors.append("pack.json: map_image '%s' is not in %s." % [pack.Manifest.MapImage, pack_dir])


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
