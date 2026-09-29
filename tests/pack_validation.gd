extends SceneTree
## PackLoader._validate_map - SCHEMA.md section 11 rules 3, 7, 9, 10 (and the
## others below, through rule 18).
##
## A validator nobody has watched reject anything is not a validator. This feeds
## it deliberately broken packs and asserts it says so. The real pack must pass
## unchanged; every fault must be caught.
##
##   .\tools\run-gd.ps1 tests/pack_validation.gd

const PACK_DIR := "res://packs/star-wars-rebellion"
## Rules 31-32 run against this pack: it ships a look and a credits file.
const WW2_DIR := "res://packs/ww2"

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

	# What day zero reads without asking would stop the game on its first day
	# (the editor handoff, 2026-09-23) - so the validator refuses it first.
	var full_seed := {"hq_facilities": "garrison", "hq_garrison": "garrison", "fleet": "garrison"}
	var no_garrison := full_seed.duplicate()
	no_garrison["hq_garrison"] = ""
	_case("a seeded side with a headquarters and no hq_garrison",
		_pack({}, {}, {"seed": no_garrison}), "seed.hq_garrison is empty")
	var no_fleet := full_seed.duplicate()
	no_fleet["fleet"] = ""
	_case("a seeded side with a headquarters and no fleet",
		_pack({}, {}, {"seed": no_fleet}), "seed.fleet is empty")
	_case("no core_system_facilities table for a Core sector",
		_pack({}, {}, {}), "logistics has no 'core_system_facilities'")
	_case("no rim_system_facilities table for a Rim sector",
		_pack({}, {}, {}), "logistics has no 'rim_system_facilities'")
	_case("a logistics table that is not an object",
		_pack({}, {}, {"logistics": {"core_system_facilities": "see the notes"}}), "logistics['core_system_facilities'] is not an object")
	_case("two galaxy sizes where the game offers three",
		_pack({"min_size": "standard"}, {}, {"sizes": ["standard", "large"]}), "setup.galaxy_sizes has 2")

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
	_case("menu region with a quad of three corners",
		_pack({}, {}, {"menu": _menu({"bad_quad": true})}), "quad must be four [x, y] corners")
	_case("menu region with a bad selected_color",
		_pack({}, {}, {"menu": _menu({"bad_color": true})}), "selected_color: 'red' is not a #rrggbb color")
	_case("victory_tips missing a text",
		_pack({}, {}, {"victory_tips": {"standard": "Win.", "hq_only": ""}}), "victory_tips: 'standard' and 'hq_only' texts are both required")
	_case("menu with no readout",
		_pack({}, {}, {"menu": _menu({"no_readout": true})}), "'readout' is required")
	_case("menu monitor for a region the menu does not have",
		_pack({}, {}, {"menu": _menu({"monitor": {"image": "galaxyShaded.bmp", "at": [0, 0], "frames": 1, "region": "nowhere"}})}),
		"region 'nowhere' is not a region of the menu")
	_case("menu monitor with no frames",
		_pack({}, {}, {"menu": _menu({"monitor": {"image": "galaxyShaded.bmp", "at": [0, 0], "frames": 0}})}), "'frames' must be 1 or more")
	_case("menu monitor with a selected_image and no region",
		_pack({}, {}, {"menu": _menu({"monitor": {"image": "galaxyShaded.bmp", "at": [0, 0], "frames": 1, "selected_image": "galaxyShaded.bmp"}})}),
		"'selected_image' needs the 'region' it shows for")
	_case("menu monitor from an art set the pack does not declare",
		_pack({}, {}, {"menu": _menu({"monitor": {"image": "swr-original:menu/empire.png", "at": [0, 0], "frames": 15}})}),
		"menu.monitors image: 'swr-original:menu/empire.png' names art set 'swr-original', which art_sets does not declare")
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
	# Rule 15 - a declared start is a world the side holds at day zero.
	_case("starts_at names a planet not on the map",
		_pack({}, {}, {"char_starts_at": "nowhere"}), "starts_at 'nowhere' is not a planet id")
	_case("starts_at names a world the side does not hold at day zero",
		_pack({}, {}, {"char_starts_at": "rim_world"}), "is not a world test_side holds at day zero")
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

	# Rule 17 - icons name known corner glyphs and files the pack ships.
	_case("icons names a glyph the sector window has no corner for",
		_pack({}, {}, {"icons": {"weather": "x.png"}}), "icons names 'weather', which is not a corner glyph")
	_case("icons names a file the pack does not ship",
		_pack({}, {}, {"icons": {"fleet": "no-such-file.png"}}), "icons['fleet'] = 'no-such-file.png' is not in")
	# Rule 16 - loyalty_bar is every faction exactly once.
	_case("loyalty_bar names a side that is not a faction",
		_pack({}, {}, {"loyalty_bar": ["test_side", "nobody"]}), "loyalty_bar names 'nobody', which is not a faction id")
	_case("loyalty_bar leaves a faction out",
		_pack({}, {}, {"loyalty_bar": ["nobody"]}), "loyalty_bar leaves out 'test_side'")
	# Rule 14 - terms are known concepts with labels.
	_case("terms with a key the engine has no concept for",
		_pack({}, {}, {"terms": {"warp": "Warp Factor"}}), "terms names 'warp', which the engine has no concept for")
	_case("terms with an empty label",
		_pack({}, {}, {"terms": {"hyperdrive": ""}}), "terms['hyperdrive'] is empty")

	# Rule 13 - seeding rows name a unit or facility the pack declares.
	_case("seeding row names a unit units.json never declares",
		_pack({}, {}, {"setup_asset": {"unit": "ghost_ship"}}), "unit 'ghost_ship' is not declared in units.json")
	_case("seeding row names a facility facilities.json never declares",
		_pack({}, {}, {"setup_asset": {"facility": "moisture_farm"}}), "facility 'moisture_farm' is not declared in facilities.json")
	_case("seeding row still uses the original's FamilyId/AssetId numbers",
		_pack({}, {}, {"setup_asset": {"FamilyId": 20, "AssetId": 69}}), "names its asset by FamilyId/AssetId")
	_case("seeding row names nothing",
		_pack({}, {}, {"setup_asset": {}}), "names neither a 'unit' nor a 'facility'")

	# Rule 9 - the map image.
	_case("map_image not declared", _pack({}, {}, {"map_image": ""}), "'map_image' is required")
	_case("map_image names a file the pack does not ship",
		_pack({}, {}, {"map_image": "no-such-file.bmp"}), "is not in res://packs")

	# Rule 18 - art sets, skins and art references (SCHEMA.md section 13).
	var art := {"art_sets": ["swr-original"], "skin": "empire"}
	_clean("an art-set pack: a skin, art references, art-set pictures",
		_pack({}, {"art": "swr-original:planets/coruscant"}, art.merged({"char_art": "characters/luke_skywalker",
			"map_image": "swr-original:screens/galaxy.png"})))
	_case("an art set the engine does not know",
		_pack({}, {}, {"art_sets": ["lotr-original"]}), "'lotr-original' is not an art set the engine knows")
	_case("art sets declared, a faction with no skin",
		_pack({}, {}, {"art_sets": ["swr-original"]}), "'skin' is required when the pack declares art_sets")
	_case("a skin the art set does not have",
		_pack({}, {}, art.merged({"skin": "republic"}, true)), "skin 'republic' is not a side look of swr-original")
	_case("a skin with no art set",
		_pack({}, {}, {"skin": "empire"}), "skin 'empire' needs pack.json art_sets")
	_case("an art reference that is not <kind>/<id>",
		_pack({}, {}, art.merged({"char_art": "luke_skywalker"})), "must be [<art set>:]<kind>/<id>")
	_case("an art reference to an art set the pack does not declare",
		_pack({}, {"art": "other-set:planets/coruscant"}, art), "must be [<art set>:]<kind>/<id>")
	_case("an art reference with no art set declared",
		_pack({}, {}, {"char_art": "characters/luke_skywalker"}), "'characters/luke_skywalker' needs pack.json art_sets")
	_case("a map_image in an art set the pack does not declare",
		_pack({}, {}, {"map_image": "swr-original:screens/galaxy.png"}), "names art set 'swr-original', which art_sets does not declare")

	# Rules 31-32 - look.json and credits.json (SCHEMA.md sections 15-16), against
	# the WWII pack, which ships both.
	_look_passes()
	var look: Dictionary = JsonUtil.parse(WW2_DIR + "/look.json")
	_look_case("a look missing a colour", look, {"drop_color": "brass"}, "colors: 'brass' is missing")
	_look_case("a look colour that is not #rrggbb", look, {"color": ["ink", "black"]}, "colors.ink: 'black' is not a #rrggbb color")
	_look_case("a colour the engine does not know", look, {"color": ["mauve", "#aa00aa"]}, "'mauve' is not a known colour")
	_look_case("a side colour for a faction the pack lacks", look, {"side": ["empire", "#00ff00"]}, "sides: 'empire' is not a faction")
	_look_case("a face in a role the engine does not know", look, {"font": ["headline", {"file": "look/fonts/Oswald-Variable.ttf"}]}, "fonts.headline: not a known role")
	_look_case("a face the pack does not ship", look, {"font": ["display", {"file": "look/fonts/Missing.ttf"}]}, "'look/fonts/Missing.ttf' is not in")
	_look_case("a face that is not a font file", look, {"font": ["display", {"file": "look/paper.png"}]}, "is not a .ttf or .otf")
	_look_case("a face at an impossible weight", look, {"font": ["display", {"file": "look/fonts/Oswald-Variable.ttf", "weight": 1200}]}, "weight must be a number from 100 to 900")
	_look_case("a size that is not a whole number", look, {"size": ["body", 15.5]}, "sizes.body: must be a positive whole number")
	_look_case("a size the engine does not know", look, {"size": ["huge", 40]}, "sizes: 'huge' is not known")
	_look_case("a negative metric", look, {"metric": ["radius", -1]}, "metrics.radius: must be a number, 0 or more")
	_look_case("an overlay alpha above 1", look, {"alpha": 1.5}, "overlay_alpha: must be a number from 0 to 1")
	_look_case("a texture the engine does not know", look, {"texture": ["wallpaper", "look/paper.png"]}, "textures.wallpaper: not a known texture")
	_look_case("a texture the pack does not ship", look, {"texture": ["paper", "look/missing.png"]}, "'look/missing.png' is not in")
	_look_case("a dossier map plate that is not [x, y, w, h]", look, {"dossier": ["map_rect", [10, 10, 0]]}, "dossier.map_rect: must be [x, y, w, h]")
	_look_case("a dossier field the engine does not know", look, {"dossier": ["banner", "x"]}, "dossier: 'banner' is not known")
	_look_case("a messages field the engine does not know", look, {"messages": ["footer", "x"]}, "messages: 'footer' is not known")
	_look_case("a dispatch header that is not text", look, {"messages": ["header", 3]}, "messages.header: must be text")
	_look_case("a stamp for no message category", look, {"stamp": ["Weather", "Met"]}, "messages.stamps: 'Weather' is not a message category")
	_look_case("a stamp with no word", look, {"stamp": ["Fleets", " "]}, "messages.stamps.Fleets: must be a word")
	_look_case("urgent that is not a list", look, {"messages": ["urgent", "Conflict"]}, "messages.urgent: must be a list")
	_look_case("an urgent category that is not one", look, {"messages": ["urgent", ["Battles"]]}, "messages.urgent: 'Battles' is not a message category")
	var credit := {"title": "Map", "author": "Someone", "licence": "CC0", "files": ["world_1941.jpg"]}
	_credits_case("a credit with no author", [credit.merged({"author": ""}, true)], "`author` is missing")
	_credits_case("a credit with no licence", [credit.merged({"licence": ""}, true)], "`licence` is missing")
	_credits_case("a credit naming no files", [credit.merged({"files": []}, true)], "`files` must list")
	_credits_case("a credit naming a file the pack lacks", [credit.merged({"files": ["nope.png"]}, true)], "'nope.png' is not in")
	_credits_case("a credit link that is not https", [credit.merged({"source": "http://example.com"}, true)], "`source` must be an https:// address")

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
	if over.has("bad_color"):
		regions[0]["selected_color"] = "red"
	if over.has("bad_quad"):
		regions[0]["quad"] = [[0, 0], [10, 0], [10, 10]]
	var m := {
		"image": over.get("image", "galaxyShaded.bmp"),
		"selected_color": "#ffd23c",
		"readout": {"rect": [0, 60, 30, 10], "standard": "Standard Game", "hq_only": "Headquarters Only", "color": "#40ff40"},
		"regions": regions,
		"credits": ["A line."],
	}
	if over.has("no_readout"):
		m.erase("readout")
	if over.has("monitor"):
		m["monitors"] = [over["monitor"]]
	return m


## A minimal two-sector, two-planet pack, with one field bent per call.
func _pack(sector_over: Dictionary, planet_over: Dictionary, other: Dictionary) -> PackLoader.LoadedPack:
	var p := PackLoader.LoadedPack.new()

	var manifest := {
		"id": "test", "display_name": "Test", "schema_version": 1, "faction_count": 1,
		"neutral": {"id": "neutral", "display_name": "Neutral", "color": "#5499ff"},
		"unexplored_color": "#cccccc",
		"map_image": other.get("map_image", "galaxyShaded.bmp"),
		"art_sets": other.get("art_sets", []),
		"setup": {"difficulty_default": "medium", "galaxy_sizes": other.get("sizes", ["standard", "large", "huge"]),
			"galaxy_size_default": other.get("size_default", "standard")},
	}
	if other.has("menu"):
		manifest["menu"] = other["menu"]
	if other.has("victory_tips"):
		manifest["victory_tips"] = other["victory_tips"]
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
		"skin": other.get("skin", ""),
	}
	if other.has("seed"):
		faction["seed"] = other["seed"]
	p.Factions = [PackDefs.FactionDef.from_dict(faction)]

	# Two characters, so a collision has something to collide WITH.
	var c1 := {"id": other.get("char_id", "first_person"), "display_name": "First Person",
		"faction": other.get("char_faction", "test_side"), "is_major": true,
		"ratings": {"diplomacy": {"base": 10, "var": 0}},
		"can_command": other.get("char_command", ["general"]),
		"wont_betray": true,
		"roles": other.get("char_roles", ["pilgrim"]),
		"starts_at": other.get("char_starts_at", ""),
		"art": other.get("char_art", ""),
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
		"special_power_ranks": ranks,
		"terms": other.get("terms", {"hyperdrive": "Transit"}),
		"loyalty_bar": other.get("loyalty_bar", []),
		"icons": other.get("icons", {})})

	# One seeding table with one row, so a row that resolves to nothing is a case.
	p.Rules = [{"EntryId": 1}]
	p.Setup = PackDefs.SetupFile.from_dict({
		"side_lottery": [{"EntryId": 1}],
		"logistics": other.get("logistics", {"garrison": {"Type": "CMUN/FACL (Hierarchical)", "Entries": [
			{"ParentId": 1, "ProbabilityThreshold": 1, "Multiplier": 1,
			 "Assets": [other.get("setup_asset", {"unit": "scout"})]}]}})})
	return p


## A pack that must validate with no error at all.
func _clean(what: String, pack: PackLoader.LoadedPack) -> void:
	_ran += 1
	var errors: Array[String] = []
	PackLoader._validate_map(pack, PACK_DIR, errors)
	PackLoader._validate_characters(pack, errors)
	PackLoader._validate_menu(pack, PACK_DIR, errors)
	PackLoader._validate_art(pack, errors)
	if errors.is_empty():
		_ok += 1
		print("[pack_validation] ok   %s" % what)
	else:
		_failed += 1
		print("[pack_validation] FAIL %s - expected no error, got: %s" % [what, ", ".join(errors)])


## The WWII pack's own look and credits pass rules 31-32 unchanged.
func _look_passes() -> void:
	_ran += 1
	var errors: Array[String] = []
	var pack := PackLoader.Load(WW2_DIR, errors)
	if pack == null or pack.Look.is_empty() or pack.AssetCredits.is_empty():
		_failed += 1
		print("[pack_validation] FAIL the WWII pack's look/credits: %s" % (", ".join(errors) if not errors.is_empty() else "not loaded"))
		return
	_ok += 1
	print("[pack_validation] ok   the WWII pack's look.json and credits.json validate (%d assets credited)" % pack.AssetCredits.size())


## Rule 31: the WWII look with one thing broken must be refused for it.
func _look_case(what: String, look: Dictionary, change: Dictionary, expect: String) -> void:
	var l: Dictionary = look.duplicate(true)
	if change.has("drop_color"):
		(l["colors"] as Dictionary).erase(change["drop_color"])
	if change.has("color"):
		l["colors"][change["color"][0]] = change["color"][1]
	if change.has("side"):
		l["sides"][change["side"][0]] = change["side"][1]
	if change.has("font"):
		l["fonts"][change["font"][0]] = change["font"][1]
	if change.has("size"):
		l["sizes"][change["size"][0]] = change["size"][1]
	if change.has("metric"):
		l["metrics"][change["metric"][0]] = change["metric"][1]
	if change.has("alpha"):
		l["overlay_alpha"] = change["alpha"]
	if change.has("texture"):
		l["textures"][change["texture"][0]] = change["texture"][1]
	if change.has("dossier"):
		l["dossier"][change["dossier"][0]] = change["dossier"][1]
	if change.has("messages"):
		l["messages"][change["messages"][0]] = change["messages"][1]
	if change.has("stamp"):
		l["messages"]["stamps"][change["stamp"][0]] = change["stamp"][1]
	var p := _ww2()
	p.Look = l
	_expect(what, func(errors: Array[String]) -> void: PackLoader._validate_look(p, WW2_DIR, errors), expect)


## Rule 32: a broken credits entry must be refused for it.
func _credits_case(what: String, assets: Array, expect: String) -> void:
	var p := _ww2()
	p.AssetCredits = assets
	_expect(what, func(errors: Array[String]) -> void: PackLoader._validate_credits(p, WW2_DIR, errors), expect)


func _ww2() -> PackLoader.LoadedPack:
	var errors: Array[String] = []
	return PackLoader.Load(WW2_DIR, errors)


func _expect(what: String, run: Callable, expect: String) -> void:
	_ran += 1
	var errors: Array[String] = []
	run.call(errors)
	for e in errors:
		if e.contains(expect):
			_ok += 1
			print("[pack_validation] ok   %s" % what)
			return
	_failed += 1
	print("[pack_validation] FAIL %s" % what)
	print("    expected an error containing: %s" % expect)
	print("    got %d error(s): %s" % [errors.size(), ", ".join(errors)])


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
	PackLoader._validate_icons(pack, PACK_DIR, errors)
	PackLoader._validate_roles(pack, errors)
	PackLoader._validate_setup(pack, errors)
	PackLoader._validate_art(pack, errors)
	for e in errors:
		if e.contains(expect):
			_ok += 1
			print("[pack_validation] ok   %s" % what)
			return
	_failed += 1
	print("[pack_validation] FAIL %s" % what)
	print("    expected an error containing: %s" % expect)
	print("    got %d error(s): %s" % [errors.size(), ", ".join(errors)])
