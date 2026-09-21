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


func _init() -> void:
	_real_pack_passes()

	# Rule 10 - the size vocabulary.
	_case("sector min_size not offered by pack.json",
		_pack({"min_size": "enormous"}, {}, {}), "min_size 'enormous' is not one of")
	_case("no sector in the smallest offered size",
		_pack({"min_size": "huge"}, {}, {}), "that menu option would start an empty galaxy")
	_case("sector missing min_size",
		_pack({"min_size": ""}, {}, {}), "missing min_size")

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
		_pack({}, {}, {"starting": "Dantooine"}), "starting planet 'Dantooine' is not in map.json")
	_case("fixed HQ on a planet absent from the map",
		_pack({}, {}, {"hq": "Byss"}), "hq.planet 'Byss' is not in map.json")

	# Rule 5 / 3 - the roster.
	_case("character on an undeclared faction",
		_pack({}, {}, {"char_faction": "hutts"}), "faction 'hutts' is not declared")
	_case("duplicate character id",
		_pack({}, {}, {"char_id": "second_person"}), "duplicate id")
	_case("unknown can_command rank",
		_pack({}, {}, {"char_command": ["warlord"]}), "unknown can_command entry 'warlord'")
	_case("victory target who is not a character",
		_pack({}, {}, {"victory": "Nobody At All"}), "victory target 'Nobody At All' is not a character")

	# Rule 9 - the map image.
	_case("map_image not declared", _pack({}, {}, {"map_image": ""}), "'map_image' is required")
	_case("map_image names a file the pack does not ship",
		_pack({}, {}, {"map_image": "no-such-file.bmp"}), "is not in res://packs")

	if _failed == 0:
		print("[pack_validation] every case behaved as specified; PASS")
	else:
		print("[pack_validation] %d case(s) FAILED" % _failed)
	quit(1 if _failed > 0 else 0)


## The shipping pack must survive its own validator.
func _real_pack_passes() -> void:
	var errors: Array[String] = []
	var pack := PackLoader.Load(PACK_DIR, errors)
	if pack == null or not errors.is_empty():
		_failed += 1
		print("[pack_validation] FAIL: the real pack was rejected:")
		for e in errors:
			print("    %s" % e)
	else:
		print("[pack_validation] ok   the shipping pack validates (%d sectors, %d planets, %d characters)"
			% [pack.Map.Sectors.size(), pack.Map.Planets.size(), pack.Characters.size()])


## A minimal two-sector, two-planet pack, with one field bent per call.
func _pack(sector_over: Dictionary, planet_over: Dictionary, other: Dictionary) -> PackLoader.LoadedPack:
	var p := PackLoader.LoadedPack.new()

	var manifest := {
		"id": "test", "display_name": "Test", "schema_version": 1, "faction_count": 1,
		"neutral": {"id": "neutral", "display_name": "Neutral", "color": "#5499ff"},
		"unexplored_color": "#cccccc",
		"map_image": other.get("map_image", "galaxyShaded.bmp"),
		"setup": {"difficulty_default": "medium", "galaxy_sizes": ["standard", "large", "huge"]},
	}
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
		"hq": {"kind": "fixed", "planet": other.get("hq", "Core World")},
		"starting_planets": [{"planet": other.get("starting", "Core World"),
			"support": 100, "explored": true, "garrison": ""}],
		"victory": {"capture_characters": [other.get("victory", "Second Person")]},
	}
	p.Factions = [PackDefs.FactionDef.from_dict(faction)]

	# Two characters, so a collision has something to collide WITH.
	var c1 := {"id": other.get("char_id", "first_person"), "display_name": "First Person",
		"faction": other.get("char_faction", "test_side"), "is_major": true,
		"ratings": {"diplomacy": {"base": 10, "var": 0}},
		"can_command": other.get("char_command", ["general"]),
		"wont_betray": true,
		"special_power": {"probability": 0, "is_known_user": false,
			"level": {"base": 0, "var": 0}, "can_train": false}}
	var c2 := {"id": "second_person", "display_name": "Second Person",
		"faction": "test_side", "is_major": false, "ratings": {},
		"can_command": [], "wont_betray": false}
	p.Characters = PackDefs.CharactersFile.from_dict({"characters": [c1, c2]}).Characters
	return p


func _case(what: String, pack: PackLoader.LoadedPack, expect: String) -> void:
	var errors: Array[String] = []
	PackLoader._validate_map(pack, PACK_DIR, errors)
	PackLoader._validate_characters(pack, errors)
	for e in errors:
		if e.contains(expect):
			print("[pack_validation] ok   %s" % what)
			return
	_failed += 1
	print("[pack_validation] FAIL %s" % what)
	print("    expected an error containing: %s" % expect)
	print("    got %d error(s): %s" % [errors.size(), ", ".join(errors)])
