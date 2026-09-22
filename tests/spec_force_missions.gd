extends SceneTree
## The SpecForce mission roster (manual p098) now comes from the pack -
## missions.json `spec_forces` read the other way round - instead of a literal
## table of nine unit names in MissionManager. This proves the inversion says
## exactly what the table said, unit by unit, and that a unit built from the
## catalog carries the pack id the lookup keys on.
##
##   Godot_console.exe --headless --path . -s tests/spec_force_missions.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _init() -> void:
	await process_frame
	GameSession.load_catalogs()

	# The table MissionManager used to carry, by pack id (manual p098).
	var expected := {
		"longprobe_y_wing_recon_team": [Enums.MissionType.Reconnaissance],
		"bothan_spies":                [Enums.MissionType.Espionage],
		"guerrillas":                  [Enums.MissionType.InciteUprising, Enums.MissionType.SubdueUprising],
		"infiltrators":                [Enums.MissionType.Abduction, Enums.MissionType.Rescue, Enums.MissionType.Sabotage, Enums.MissionType.SuperweaponSabotage],
		"imperial_probe_droid":        [Enums.MissionType.Reconnaissance],
		"imperial_espionage_droid":    [Enums.MissionType.Espionage],
		"imperial_commandos":          [Enums.MissionType.SubdueUprising, Enums.MissionType.InciteUprising, Enums.MissionType.Sabotage],
		"noghri_death_commandos":      [Enums.MissionType.Abduction, Enums.MissionType.Assassination, Enums.MissionType.Rescue],
		"bounty_hunters":              [],
	}
	for unit_id in expected:
		var got: Array = MissionCatalog.SpecForceMissions(unit_id).duplicate()
		var want: Array = expected[unit_id].duplicate()
		got.sort()
		want.sort()
		_check(got == want, "%s may run %s (pack says %s)" % [unit_id, _names(want), _names(got)])

	# Every SpecForce the pack declares is in the table, and nothing else is.
	var declared: Array = []
	for d in MilitaryCatalog.All():
		if d.Kind == "spec_force":
			declared.append(d.Id)
	for unit_id in declared:
		_check(expected.has(unit_id), "the pack's SpecForce %s is one the roster knows" % unit_id)
	for unit_id in expected:
		_check(declared.has(unit_id), "the roster's %s is a SpecForce in the pack" % unit_id)

	# A catalog-built unit carries its pack id, and CanPerform reads it.
	var f: Faction = FactionRegistry.Playable[0]
	var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(d): return d.Id == "infiltrators")
	_check(def != null, "the pack declares infiltrators")
	if def != null:
		var u: Unit = MilitaryCatalog.Create(def, f, null)
		_check(u.PackId == "infiltrators", "MilitaryCatalog.Create stamps PackId (got '%s')" % u.PackId)
		_check(u.Type == Enums.UnitType.SpecForce, "it is a SpecForce unit")
		_check(MissionManager.CanPerform(u, Enums.MissionType.Sabotage), "infiltrators can perform Sabotage")
		_check(not MissionManager.CanPerform(u, Enums.MissionType.Assassination), "infiltrators cannot perform Assassination")
		_check(MissionManager.CanEverPerformMissions(u), "a SpecForce goes on missions at all")

	# Side lock from the pack: Assassination is available_to the second side only.
	var a: Faction = FactionRegistry.Playable[0]
	var b: Faction = FactionRegistry.Playable[1]
	_check(MissionCatalog.AvailableTo(Enums.MissionType.Assassination, b), "%s may assassinate (available_to)" % b.Id)
	_check(not MissionCatalog.AvailableTo(Enums.MissionType.Assassination, a), "%s may not (available_to)" % a.Id)

	# The agent name comes from the pack.
	_check(AgentDroid.NameFor(a) == "C-3PO" and AgentDroid.NameFor(b) == "IMP-22", "agent names from factions.json (%s / %s)" % [AgentDroid.NameFor(a), AgentDroid.NameFor(b)])

	print("[spec_force_missions] %d checks, %d failed: %s" % [_checks, _fails, "PASS" if _fails == 0 else "FAIL"])
	quit(1 if _fails > 0 else 0)


func _names(types: Array) -> String:
	var out: Array = []
	for t in types:
		out.append(JsonUtil.enum_name(Enums.MissionType, t))
	return ", ".join(out)
