extends SceneTree
## PackLoader._validate_map - SCHEMA.md section 11 rules 3, 7, 9, 10.
##
## A validator nobody has watched reject anything is not a validator. This feeds
## it deliberately broken packs and asserts it says so. The real pack must pass
## unchanged; every fault must be caught.
##
##   .\tools\run-gd.ps1 tests/pack_validation.gd

const PACK_DIR := "res://packs/star-wars-rebellion"

var _failed := 0
## Every case increments _ran on entry and _ok or _failed on exit. A runtime
## abort inside a case leaves _ran ahead - and that is a FAIL, not a pass.
var _ran := 0
var _ok := 0


func _init() -> void:
	_real_pack_passes()

	# Rule 10 - the size vocabulary.
	_case("sector min_size not offered by pack.json",
		_pack({"min_size": "enormous"}, {}, {}), "min_size 'enormous' is not one of")
	_case("no sector in the smallest offered size",
		_pack({"min_size": "huge"}, {}, {}), "that menu option would start an empty galaxy")
	_case("sector missing min_size",
		_pack({"min_size": ""}, {}, {}), "missing min_size")

	# Rule 11 - the Cockpit picture reaches every function (SCHEMA.md section 2).
	_case("menu region with an unknown action",
		_pack({}, {}, {"menu": _menu({"bad_action": true})}), "action 'launch' is not one of")
	_case("menu start region for a faction the pack does not have",
		_pack({}, {}, {"menu": _menu({"start_value": "nobody"})}), "start value 'nobody' is not a faction id")
	_case("menu with no exit region",
		_pack({}, {}, {"menu": _menu({"drop": "exit"})}), "no region for 'exit'")
	_case("menu with no region for an offered galaxy size",
		_pack({}, {}, {"menu": _menu({"drop": "galaxy_size:huge"})}), "no region for 'galaxy_size:huge'")
	_case("menu with two regions for one difficulty",
		_pack({}, {}, {"menu": _menu({"dup": "difficulty:easy"})}), "'difficulty:easy' has 2 regions")
	_case("menu image the pack does not ship",
		_pack({}, {}, {"menu": _menu({"image": "no-such-cockpit.png"})}), "is not in res://packs")
	_case("menu region rect with no height",
		_pack({}, {}, {"menu": _menu({"flat_rect": true})}), "rect must be [x, y, w, h]")
	_case("menu with no readout",
		_pack({}, {}, {"menu": _menu({"no_readout": true})}), "'readout' is required")
	_case("galaxy_size_default not offered",
		_pack({}, {}, {"size_default": "enormous"}), "galaxy_size_default 'enormous' is not one of")

	# Rule 12 - roles and behaviours (SCHEMA.md sections 6, 7, 9).
	_case("character with an unknown role",
		_pack({}, {}, {"char_roles": ["chosen_one"]}), "unknown role 'chosen_one'")
	_case("two characters cast as the pilgrim",
		_pack({}, {}, {"char_roles": ["pilgrim"], "char2_roles": ["pilgrim"]}), "2 characters carry the story role 'pilgrim'")
	_case("unit with an unknown role",
		_pack({}, {}, {"unit_roles": ["planet_killer"]}), "unknown role 'planet_killer'")
	_case("mission with an unknown behaviour",
		_pack({}, {}, {"mission_behaviour": "heist"}), "unknown behaviour 'heist'")
	_case("two missions for one behaviour",
		_pack({}, {}, {"mission2_behaviour": "reconnaissance"}), "behaviour 'reconnaissance' is already 'recon'")

	# Rule 3 - cross-references and identity.
	_case("planet points at an undeclared sector",
		_pack({}, {"sector": "nowhere"}, {}), "sector 'nowhere' is not declared")
	# The second planet is rim_world; colliding the first with it is the fault.
	_case("duplicate planet id",
		_pack({}, {"id": "rim_world"}, {}), "duplicate id")
	_case("sector missing display_name",
		_pack({"display_name": ""}, {}, {}), "missing display_name")

	# Rule 7 - a faction's named worlds exist.
	_case("starting planet absent from the map",
		_pack({}, {}, {"starting": "dantooine"}), "starting planet 'dantooine' is not a planet id")
	_case("fixed HQ on a planet absent from the map",
		_pack({}, {}, {"hq": "byss"}), "hq.planet 'byss' is not a planet id")
	# A DISPLAY NAME where an id belongs is exactly the mistake Q1 exists to catch.
	_case("a display name used where a planet id belongs",
		_pack({}, {}, {"starting": "Core World"}), "starting planet 'Core World' is not a planet id")

	# Rule 5 / 3 - the roster.
	_case("character on an undeclared faction",
		_pack({}, {}, {"char_faction": "hutts"}), "faction 'hutts' is not declared")
	_case("duplicate character id",
		_pack({}, {}, {"char_id": "second_person"}), "duplicate id")
	_case("unknown can_command rank",
		_pack({}, {}, {"char_command": ["warlord"]}), "unknown can_command entry 'warlord'")
	_case("victory target who is not a character",
		_pack({}, {}, {"victory": "nobody_at_all"}), "victory target 'nobody_at_all' is not a character id")
	_case("a display name used where a character id belongs",
		_pack({}, {}, {"victory": "Second Person"}), "victory target 'Second Person' is not a character id")

	# Rules 3 / 4 / 5 - the facility catalog.
	_case("unknown facility role",
		_pack({}, {}, {"fac_roles": ["teleporter"]}), "unknown role 'teleporter'")
	_case("facility with no roles at all",
		_pack({}, {}, {"fac_roles": []}), "declares no roles")
	_case("facility buildable by an undeclared faction",
		_pack({}, {}, {"fac_build": ["hutts"]}), "buildable_by 'hutts' is not a declared faction")
	_case("a family whose only tier is 2",
		_pack({}, {}, {"fac_tier": 2}), "has no tier 1")
	_case("no headquarters role anywhere",
		_pack({}, {}, {"fac_roles": ["extracts_raw"], "drop_hq": true}), "no facility has the 'headquarters' role")

	# Rules 3 / 4 - units and their weapons.
	_case("unit on an unknown kind",
		_pack({}, {}, {"unit_kind": "spaceship"}), "unknown kind 'spaceship'")
	_case("unit buildable by an undeclared faction",
		_pack({}, {}, {"unit_build": ["hutts"]}), "buildable_by 'hutts' is not a declared faction")
	_case("unit carries a weapon weapons.json never declares",
		_pack({}, {}, {"unit_weapon": "disruptor"}), "weapons.json does not declare")
	_case("weapon with no roles",
		_pack({}, {}, {"weapon_roles": []}), "declares no roles")
	_case("unknown weapon role",
		_pack({}, {}, {"weapon_roles": ["vaporises"]}), "unknown role 'vaporises'")

	# Rules 3 / 5 - the mission catalog.
	_case("mission available to an undeclared faction",
		_pack({}, {}, {"mission_to": ["hutts"]}), "available_to 'hutts' is not a declared faction")
	_case("mission needs a SpecForce no unit provides",
		_pack({}, {}, {"mission_spec": ["ghosts"]}), "units.json does not declare")

	# Rules 4 / 8 - the display catalog.
	_case("GID mode with a quantity kind the engine cannot compute",
		_pack({}, {}, {"gid_kind": "vibes"}), "unknown quantity.kind 'vibes'")
	_case("GID tiers that do not end at the min-0 bare dot",
		_pack({}, {}, {"gid_tiers": [{"min": 3, "label": "Some", "flare": "big"}, {"min": 1, "label": "One", "flare": "low"}]}),
		"the last tier must have min 0")
	_case("GID tiers out of descending order",
		_pack({}, {}, {"gid_tiers": [{"min": 1, "label": "One", "flare": "low"}, {"min": 3, "label": "Some", "flare": "big"}, {"min": 0, "label": "None", "flare": "none"}]}),
		"must be ordered descending")
	_case("GID tier with an unknown flare",
		_pack({}, {}, {"gid_tiers": [{"min": 1, "label": "One", "flare": "huge"}, {"min": 0, "label": "None", "flare": "none"}]}),
		"unknown flare 'huge'")
	_case("Alt+N slot names a mode no category declares",
		_pack({}, {}, {"gid_alt": ["no_such_mode"]}), "galaxy_display_modes names 'no_such_mode'")
	_case("a special-power band with no label",
		_pack({}, {}, {"gid_ranks_drop": "master"}), "no label for 'master'")

	# Rule 9 - the map image.
	_case("map_image not declared", _pack({}, {}, {"map_image": ""}), "'map_image' is required")
	_case("map_image names a file the pack does not ship",
		_pack({}, {}, {"map_image": "no-such-file.bmp"}), "is not in res://packs")

	_mission_join_resolves()
	_rank_labels_resolve()

	if _ok + _failed != _ran:
		_failed += _ran - _ok - _failed
		print("[pack_validation] %d case(s) ABORTED mid-run (a runtime error, not a verdict) - counted as failures" % (_ran - _ok))
	if _failed == 0:
		print("[pack_validation] every case behaved as specified (%d ran); PASS" % _ran)
	else:
		print("[pack_validation] %d of %d case(s) FAILED" % [_failed, _ran])
	quit(1 if _failed > 0 else 0)


static func _gid_mode_count(pack: PackLoader.LoadedPack) -> int:
	var n := 0
	if pack.Display != null:
		for c in pack.Display.Categories:
			n += c.Modes.size()
	return n


## The shipping pack must survive its own validator.
func _real_pack_passes() -> void:
	_ran += 1
	var errors: Array[String] = []
	var pack := PackLoader.Load(PACK_DIR, errors)
	if pack == null or not errors.is_empty():
		_failed += 1
		print("[pack_validation] FAIL: the real pack was rejected:")
		for e in errors:
			print("    %s" % e)
	else:
		_ok += 1
		print("[pack_validation] ok   the shipping pack validates (%d sectors, %d planets, %d characters, %d facilities, %d units, %d weapons, %d missions, %d GID modes)"
			% [pack.Map.Sectors.size(), pack.Map.Planets.size(), pack.Characters.size(),
			   pack.Facilities.size(), pack.Units.size(), pack.Weapons.size(), pack.Missions.size(),
			   _gid_mode_count(pack)])


## EVERY engine mission behaviour must resolve to a pack mission, a display name
## and an outcome table. The soak fixtures never run Superweapon Sabotage or
## Special Power Training, so the rename of those two members is checked HERE or
## nowhere.
func _mission_join_resolves() -> void:
	_ran += 1
	var errors: Array[String] = []
	var pack := PackLoader.Load(PACK_DIR, errors)
	if pack == null:
		_failed += 1
		print("[pack_validation] FAIL mission join: the pack did not load")
		return
	var before_failed := _failed
	MissionCatalog.LoadFromPack(pack)
	MissionTableManager.LoadFromPack(pack)
	for t in Enums.MissionType.values():
		var name := JsonUtil.enum_name(Enums.MissionType, t)
		var def := MissionCatalog.DefFor(t)
		if def == null:
			print("[pack_validation] ok   %s: this pack offers no such mission" % name)
			continue
		var shown := MissionCatalog.DisplayNameFor(t)
		# The wording must be the PACK's. For a single-word mission that happens
		# to equal the enum name, which is fine - what matters is the source.
		if shown != def.DisplayName:
			_failed += 1
			print("[pack_validation] FAIL %s: shown '%s' is not the pack's '%s'" % [name, shown, def.DisplayName])
		elif MissionCatalog.IdFor(t) <= 0:
			_failed += 1
			print("[pack_validation] FAIL %s: no source id" % name)
		else:
			print("[pack_validation] ok   %s -> '%s' (pack id %s, source 0x%x)" % [name, shown, def.Id, def.SourceId])
	if _failed == before_failed:
		_ok += 1


## EVERY special-power band must name itself with the PACK's wording, never the
## enum member. The bands are engine (thresholds in Character.SpecialPowerRankOf);
## the labels are display.json. No soak fixture ever renders one, so this is
## where the section 12 Q5 rename is proven.
func _rank_labels_resolve() -> void:
	_ran += 1
	var errors: Array[String] = []
	var pack := PackLoader.Load(PACK_DIR, errors)
	if pack == null:
		_failed += 1
		print("[pack_validation] FAIL rank labels: the pack did not load")
		return
	FactionRegistry.Load(pack)
	var before_failed := _failed
	# level -> the band the engine puts it in; the label must be the pack's.
	var probes := { 0: "none", 10: "novice", 20: "trainee", 80: "student", 100: "knight", 120: "master" }
	for level in probes:
		var c := Character.new()
		c.SpecialPowerLevel = level
		var rank: int = c.SpecialPowerRankOf()
		var shown := Character.RankLabel(rank)
		var want: String = pack.Display.RankLabel(probes[level])
		var member := JsonUtil.enum_name(Enums.SpecialPowerRank, rank)
		if shown != want:
			_failed += 1
			print("[pack_validation] FAIL level %d: shown '%s', the pack says '%s'" % [level, shown, want])
		elif shown == member and want != member:
			_failed += 1
			print("[pack_validation] FAIL level %d: the ENUM member '%s' leaked to the player" % [level, member])
		else:
			print("[pack_validation] ok   level %3d -> %-7s shown as '%s'" % [level, member, shown])
	if _failed == before_failed:
		_ok += 1


## A complete Cockpit picture for the test pack (one faction, three sizes),
## with one thing bent per call.
func _menu(over: Dictionary) -> Dictionary:
	var regions: Array = [
		{"action": "difficulty", "value": "easy", "rect": [0, 0, 10, 10]},
		{"action": "difficulty", "value": "medium", "rect": [10, 0, 10, 10]},
		{"action": "difficulty", "value": "hard", "rect": [20, 0, 10, 10]},
		{"action": "galaxy_size", "value": "standard", "rect": [0, 10, 10, 10]},
		{"action": "galaxy_size", "value": "large", "rect": [10, 10, 10, 10]},
		{"action": "galaxy_size", "value": "huge", "rect": [20, 10, 10, 10]},
		{"action": "start", "value": over.get("start_value", "test_side"), "rect": [0, 20, 10, 10]},
		{"action": "load_game", "rect": [10, 20, 10, 10]},
		{"action": "credits", "rect": [20, 20, 10, 10]},
		{"action": "hq_only_victory", "rect": [0, 30, 10, 10]},
		{"action": "multiplayer", "rect": [10, 30, 10, 10]},
		{"action": "exit", "rect": [20, 30, 10, 10]},
	]
	if over.has("bad_action"):
		regions.append({"action": "launch", "rect": [0, 40, 10, 10]})
	if over.has("drop"):
		var parts: PackedStringArray = str(over["drop"]).split(":")
		for i in range(regions.size() - 1, -1, -1):
			var r: Dictionary = regions[i]
			if r["action"] == parts[0] and (parts.size() == 1 or r.get("value", "") == parts[1]):
				regions.remove_at(i)
	if over.has("dup"):
		var parts: PackedStringArray = str(over["dup"]).split(":")
		regions.append({"action": parts[0], "value": parts[1], "rect": [0, 50, 10, 10]})
	if over.has("flat_rect"):
		regions[0]["rect"] = [0, 0, 10, 0]
	var m := {
		"image": over.get("image", "galaxyShaded.bmp"),
		"selected_color": "#ffd23c",
		"readout": {"rect": [0, 60, 30, 10], "standard": "Standard Game", "hq_only": "Headquarters Only", "color": "#40ff40"},
		"regions": regions,
		"credits": ["A line."],
	}
	if over.has("no_readout"):
		m.erase("readout")
	return m


## A minimal two-sector, two-planet pack, with one field bent per call.
func _pack(sector_over: Dictionary, planet_over: Dictionary, other: Dictionary) -> PackLoader.LoadedPack:
	var p := PackLoader.LoadedPack.new()

	var manifest := {
		"id": "test", "display_name": "Test", "schema_version": 1, "faction_count": 1,
		"neutral": {"id": "neutral", "display_name": "Neutral", "color": "#5499ff"},
		"unexplored_color": "#cccccc",
		"map_image": other.get("map_image", "galaxyShaded.bmp"),
		"setup": {"difficulty_default": "medium", "galaxy_sizes": ["standard", "large", "huge"],
			"galaxy_size_default": other.get("size_default", "standard")},
	}
	if other.has("menu"):
		manifest["menu"] = other["menu"]
	p.Manifest = PackDefs.PackManifest.from_dict(manifest)

	var s1 := {"id": "core", "display_name": "Core", "ring": 1, "starts_neutral": false,
		"map": {"x": 1, "y": 1}, "min_size": "standard", "intel_tier": "live", "source_id": 1}
	for k in sector_over:
		s1[k] = sector_over[k]
	var s2 := {"id": "rim", "display_name": "Rim", "ring": 2, "starts_neutral": true,
		"map": {"x": 2, "y": 2}, "min_size": "large", "intel_tier": "presence", "source_id": 2}

	var p1 := {"id": "core_world", "display_name": "Core World", "sector": "core",
		"starts_inhabited": true, "map": {"x": 1, "y": 1}, "artwork_id": 1, "source_id": 10}
	for k in planet_over:
		p1[k] = planet_over[k]
	var p2 := {"id": "rim_world", "display_name": "Rim World", "sector": "rim",
		"starts_inhabited": false, "map": {"x": 2, "y": 2}, "artwork_id": 2, "source_id": 11}

	p.Map = PackDefs.MapFile.from_dict({"sectors": [s1, s2], "planets": [p1, p2]})

	var faction := {
		"id": "test_side", "display_name": "Test Side", "color": "#ff0000",
		"loyalty_label": "Loyalty", "occupation_support_policy": "garrison_bonus",
		"hq": {"kind": "fixed", "planet": other.get("hq", "core_world")},
		"starting_planets": [{"planet": other.get("starting", "core_world"),
			"support": 100, "explored": true, "garrison": ""}],
		"victory": {"capture_characters": [other.get("victory", "second_person")]},
	}
	p.Factions = [PackDefs.FactionDef.from_dict(faction)]

	# Two characters, so a collision has something to collide WITH.
	var c1 := {"id": other.get("char_id", "first_person"), "display_name": "First Person",
		"faction": other.get("char_faction", "test_side"), "is_major": true,
		"ratings": {"diplomacy": {"base": 10, "var": 0}},
		"can_command": other.get("char_command", ["general"]),
		"wont_betray": true,
		"roles": other.get("char_roles", ["pilgrim"]),
		"special_power": {"probability": 0, "is_known_user": false,
			"level": {"base": 0, "var": 0}, "can_train": false}}
	var c2 := {"id": "second_person", "display_name": "Second Person",
		"faction": "test_side", "is_major": false, "ratings": {},
		"can_command": [], "wont_betray": false,
		"roles": other.get("char2_roles", [])}
	p.Characters = PackDefs.CharactersFile.from_dict({"characters": [c1, c2]}).Characters

	# A mine (the bent one) plus a headquarters, so "no HQ" is its own case.
	var f1 := {"id": "mine", "display_name": "Mine", "family": "mine",
		"tier": other.get("fac_tier", 1),
		"roles": other.get("fac_roles", ["extracts_raw"]),
		"buildable_by": other.get("fac_build", ["test_side"]),
		"construction_cost": 20, "maintenance_cost": 0,
		"stats": {"processing_rate": 5}, "source_family_id": 44}
	var facs := [f1]
	if not other.get("drop_hq", false):
		facs.append({"id": "hq", "display_name": "HQ", "family": "headquarters",
			"tier": 1, "roles": ["headquarters"], "buildable_by": ["test_side"],
			"construction_cost": 0, "maintenance_cost": 0, "stats": {},
			"source_family_id": 32})
	p.Facilities = PackDefs.FacilitiesFile.from_dict({"facilities": facs}).Facilities

	p.Weapons = PackDefs.WeaponsFile.from_dict({"weapons": [
		{"id": "laser", "display_name": "Laser",
		 "roles": other.get("weapon_roles", ["fighter_accuracy_scaled"]), "arcs": true}]}).Weapons
	p.Units = PackDefs.UnitsFile.from_dict({"units": [
		{"id": "scout", "display_name": "Scout", "kind": other.get("unit_kind", "fighter"),
		 "roles": other.get("unit_roles", []),
		 "buildable_by": other.get("unit_build", ["test_side"]),
		 "construction_cost": 5, "maintenance_cost": 1,
		 "weapons": {other.get("unit_weapon", "laser"): {"arcs": {"fore": 8}, "range": 17}},
		 "stats": {"hull": 10}}]}).Units
	var missions: Array = [
		{"id": "recon", "display_name": "Recon",
		 "behaviour": other.get("mission_behaviour", "reconnaissance"),
		 "available_to": other.get("mission_to", ["test_side"]),
		 "spec_forces": other.get("mission_spec", ["scout"]),
		 "length": {"base": 7, "spread": 3},
		 "flags": {"can_continue": true}, "targets": {"hostile": true},
		 "source_id": 21}]
	if other.has("mission2_behaviour"):
		missions.append({"id": "second", "display_name": "Second",
			"behaviour": other["mission2_behaviour"], "available_to": ["test_side"],
			"spec_forces": [], "length": {"base": 1, "spread": 0}, "flags": {}, "targets": {},
			"source_id": 22})
	p.Missions = PackDefs.MissionsFile.from_dict({"missions": missions}).Missions

	# One category, one mode, the full rank label set - each bendable.
	var ranks := {"none": "None", "novice": "Novice", "trainee": "Trainee",
		"student": "Adept", "knight": "Warden", "master": "Grandmaster"}
	if other.has("gid_ranks_drop"):
		ranks.erase(other["gid_ranks_drop"])
	p.Display = PackDefs.DisplayDef.from_dict({
		"categories": [{"id": "loyalty", "display_name": "Loyalty", "modes": [
			{"id": "popular_support", "label": "Popular Support", "title_from": "loyalty_label",
			 "quantity": {"kind": other.get("gid_kind", "support")},
			 "tiers": other.get("gid_tiers", [
				{"min": 50, "label": "Loyal", "flare": "big"},
				{"min": 0, "label": "Hostile", "flare": "none"}])}]}],
		"galaxy_display_modes": other.get("gid_alt", ["popular_support"]),
		"special_power_ranks": ranks})
	return p


func _case(what: String, pack: PackLoader.LoadedPack, expect: String) -> void:
	_ran += 1
	var errors: Array[String] = []
	PackLoader._validate_map(pack, PACK_DIR, errors)
	PackLoader._validate_characters(pack, errors)
	PackLoader._validate_facilities(pack, errors)
	PackLoader._validate_units(pack, errors)
	PackLoader._validate_missions(pack, errors)
	PackLoader._validate_display(pack, errors)
	PackLoader._validate_menu(pack, PACK_DIR, errors)
	PackLoader._validate_roles(pack, errors)
	for e in errors:
		if e.contains(expect):
			_ok += 1
			print("[pack_validation] ok   %s" % what)
			return
	_failed += 1
	print("[pack_validation] FAIL %s" % what)
	print("    expected an error containing: %s" % expect)
	print("    got %d error(s): %s" % [errors.size(), ", ".join(errors)])
