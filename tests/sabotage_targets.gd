extends SceneTree
## Defences are Sabotage targets (manual p108; Encyclopedia: "a sabotage
## mission destroys a facility"), and the System Defenses window offers them
## to the crosshair. From TeeJ's feedback report 2026-09-03T23-56-45 (room
## AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #196/#198).
##
##   Godot_console.exe --headless --path . -s tests/sabotage_targets.gd

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
	MpSetup.reset()
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	var us: Faction = GameSettings.PlayerFaction
	var them: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction != null and p.ControllingFaction != us:
			them = p
			break
	_check(them != null, "an enemy system exists")
	if them == null:
		_finish()
		return
	them.AddFacility(Enums.FacilityType.PlanetaryShield)
	them.AddFacility(Enums.FacilityType.TurbolaserBattery)
	them.AddFacility(Enums.FacilityType.IonCannon)
	var defences: Array = Lq.where(them.Facilities, func(f: Facility) -> bool:
		return f.Type in [Enums.FacilityType.PlanetaryShield, Enums.FacilityType.TurbolaserBattery, Enums.FacilityType.IonCannon])
	_check(defences.size() >= 3, "shield, battery and ion cannon stand on %s" % them.Name)
	for f in defences:
		_check(MissionManager.CanSabotage(us, f, them).ok, "CanSabotage accepts the enemy %s" % f.Name())
	# Our own defences are not targets.
	var ours: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction == us:
			ours = p
			break
	if ours != null:
		ours.AddFacility(Enums.FacilityType.PlanetaryShield)
		var mine: Facility = ours.Facilities[ours.Facilities.size() - 1]
		_check(not MissionManager.CanSabotage(us, mine, ours).ok, "CanSabotage refuses our own shield")

	# The System Defenses window: an enemy system's defences are an intelligence
	# snapshot; once seen, one clickable row per defence.
	IntelManager.Capture(us, them, StrategicTickManager.Today, IntelManager.EspionageCategories)
	var scene: PackedScene = load("res://src/ui/DefenseWindow.tscn")
	var w: DefenseWindow = scene.instantiate()
	root.add_child(w)
	await process_frame
	var tabs: TabContainer = w.get_node("%DefenseTabs")
	w.PopulateOrbitalDefenses(tabs, them)
	await process_frame
	var rows: Array = []
	_collect_rows(tabs.get_node("Orbital Defenses"), rows)
	_check(rows.size() == defences.size(), "the Orbital Defenses tab has %d target rows (has %d)" % [defences.size(), rows.size()])
	var types: Array = []
	for r in rows:
		types.append(int(r.get_meta("defence_type")))
	for t in [Enums.FacilityType.PlanetaryShield, Enums.FacilityType.TurbolaserBattery, Enums.FacilityType.IonCannon]:
		_check(t in types, "a row names the %s" % Facility.NameOf(t))
	# Before any sighting the tab says so and offers nothing.
	IntelManager.Reset()
	w.PopulateOrbitalDefenses(tabs, them)
	await process_frame
	var blind: Array = []
	_collect_rows(tabs.get_node("Orbital Defenses"), blind)
	_check(blind.is_empty(), "unseen defences offer no rows")
	root.remove_child(w)
	w.free()
	_finish()


func _collect_rows(node: Node, out: Array) -> void:
	if node == null:
		return
	if node is Button and node.has_meta("defence_type") and int(node.get_meta("defence_type")) >= 0:
		out.append(node)
	for c in node.get_children():
		_collect_rows(c, out)


func _finish() -> void:
	print("[sabotage_targets] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
