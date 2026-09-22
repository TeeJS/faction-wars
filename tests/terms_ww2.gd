extends SceneTree
## The WWII pack's words for the engine's concepts (SCHEMA.md section 10):
## loads packs/ww2 the way the game does and reads a few labels through Terms,
## so a battleship says "Armour" and "Cruising Speed", never "Shield" and
## "Hyperdrive". Runs whatever packs/active.json says; it loads ww2 itself.
##
##   Godot_console.exe --headless --path . -s tests/terms_ww2.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	var errors: Array[String] = []
	var pack := PackLoader.Load("res://packs/ww2", errors)
	_check(pack != null, "packs/ww2 loads (%s)" % ", ".join(errors))
	if pack == null:
		quit(1)
		return
	FactionRegistry.Load(pack)

	var expect := {"hyperdrive": "Cruising Speed", "sublight": "Flank Speed", "shield": "Armour",
		"hull": "Hull", "energy": "Industry", "refined_materials": "War Materiel",
		"trooper_regiments": "Divisions", "fighter_squadron": "Air Squadron", "in_transit": "at sea",
		"planetary_shields": "fortifications", "orbital_batteries": "coastal batteries"}
	for key in expect:
		_check(Terms.label(key) == expect[key], "%s -> '%s' (got '%s')" % [key, expect[key], Terms.label(key)])
	_check(Terms.field("shield") == "Armour:", "a battleship's shield row reads 'Armour:'")
	_check(Terms.cap("in_transit") == "At sea", "a sentence start reads 'At sea'")
	for key in PackLoader.KNOWN_TERMS:
		_check(pack.Display.Terms.has(key), "ww2 names every term (%s)" % key)
	for bad in ["Hyperdrive", "Shield", "Sub-Light", "hyperspace"]:
		for key in pack.Display.Terms:
			_check(not str(pack.Display.Terms[key]).contains(bad), "no Star Wars word under '%s'" % key)

	print("[terms_ww2] %d checks, %d failed: %s" % [_checks, _fails, "PASS" if _fails == 0 else "FAIL"])
	quit(1 if _fails > 0 else 0)
