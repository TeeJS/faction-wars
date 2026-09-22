extends SceneTree
## Terms (SCHEMA.md section 10): the pack's words for the engine's concepts,
## with the engine's neutral defaults behind them. The vocabulary is one list
## in two places (Terms.DEFAULTS, PackLoader.KNOWN_TERMS); this keeps them equal.
##
##   Godot_console.exe --headless --path . -s tests/terms.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()

	# One vocabulary.
	var defaults: Array = Terms.DEFAULTS.keys()
	defaults.sort()
	var known: Array = PackLoader.KNOWN_TERMS.duplicate()
	known.sort()
	_check(defaults == known, "Terms.DEFAULTS and PackLoader.KNOWN_TERMS are the same %d keys" % known.size())
	for key in Terms.DEFAULTS:
		_check(not str(Terms.DEFAULTS[key]).strip_edges().is_empty(), "default for '%s' is not empty" % key)

	# The Star Wars pack's words come through.
	var pack := FactionRegistry.Pack
	_check(pack.Manifest.Id == "star-wars-rebellion", "the active pack is star-wars-rebellion (got %s)" % pack.Manifest.Id)
	var expect := {"hyperdrive": "Hyperdrive Rating", "sublight": "Sub-Light Engine Rating", "shield": "Shield Strength",
		"hull": "Hull Value", "in_transit": "in hyperspace", "trooper_regiments": "Trooper Regiments"}
	for key in expect:
		_check(Terms.label(key) == expect[key], "%s -> '%s' (got '%s')" % [key, expect[key], Terms.label(key)])
	_check(Terms.field("hull") == "Hull Value:", "field() appends the colon (got '%s')" % Terms.field("hull"))
	_check(Terms.lower("trooper_regiments") == "trooper regiments", "lower() for prose (got '%s')" % Terms.lower("trooper_regiments"))
	_check(Terms.cap("in_transit") == "In hyperspace", "cap() for a sentence start (got '%s')" % Terms.cap("in_transit"))
	_check(Terms.lower("planetary_shields") == "planetary shields" and Terms.lower("mine") == "mine", "the prose nouns come through")

	# A key the pack leaves out falls back to the default; a pack word wins.
	var saved: Dictionary = pack.Display.Terms.duplicate()
	pack.Display.Terms.erase("shield")
	_check(Terms.label("shield") == Terms.DEFAULTS["shield"], "a missing key takes the default ('%s')" % Terms.label("shield"))
	pack.Display.Terms["shield"] = "Deflectors"
	_check(Terms.label("shield") == "Deflectors", "a pack word wins over the default")
	pack.Display.Terms = saved

	# An unknown key is shown raw, not blank, and does not crash.
	_check(Terms.label("no_such_concept") == "no_such_concept", "an unknown key comes back raw")

	print("[terms] %d checks, %d failed: %s" % [_checks, _fails, "PASS" if _fails == 0 else "FAIL"])
	quit(1 if _fails > 0 else 0)
