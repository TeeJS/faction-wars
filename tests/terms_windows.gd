extends SceneTree
## The windows that show engine concepts take their words from the pack
## (Terms, SCHEMA.md section 10) and select facilities by role. On the Star
## Wars pack every label must read exactly as it did when it was a literal -
## the manual's words - and no neutral default may leak through.
##
##   Godot_console.exe --headless --path . -s tests/terms_windows.gd

var _fails := 0
var _checks := 0
var _ui: UIManager


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)


func _labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_labels(c, out)


## Opens a window through the UIManager and returns every Label text in it.
func _open(window_class: String, opener: Callable) -> Array:
	opener.call()
	await process_frame
	await process_frame
	var out: Array = []
	for c in _ui.get_children():
		if c.get_script() != null and str(c.get_script().get_global_name()) == window_class:
			_labels(c, out)
	return out


func _init() -> void:
	await process_frame
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Large, 12345)
	_ui = UIManager.new()
	_ui.name = "UIManager"
	# A bare UIManager has no inspector-wired templates (Main.tscn wires them);
	# give it the two this test opens by template.
	_ui.UnitStatusWindowTemplate = load("res://src/ui/UnitStatusWindow.tscn")
	_ui.PlanetWindowTemplate = load("res://src/ui/PlanetWindow.tscn")
	_ui.DefenseFacilityStatusWindowTemplate = load("res://src/ui/DefenseFacilityStatusWindow.tscn")
	root.add_child(_ui)
	await process_frame

	var us: Faction = GameSettings.PlayerFaction
	var owned: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and not p.OrbitingFleets.is_empty())
	_check(owned != null, "we hold a world with a fleet in orbit")
	var fleet: Fleet = owned.OrbitingFleets[0]
	var ship: Unit = Lq.first_or_null(fleet.Ships, func(s: Unit) -> bool: return s.Type == Enums.UnitType.CapitalShip)
	var fighter: Unit = null
	for s in fleet.Ships:
		if s.Hangar != null:
			fighter = Lq.first_or_null(s.Hangar, func(h: Unit) -> bool: return h.Type == Enums.UnitType.Fighter)
		if fighter != null:
			break
	if fighter == null:
		fighter = Lq.first_or_null(owned.FighterSquadrons, func(_h: Unit) -> bool: return true)
	_check(ship != null, "the fleet has a capital ship")

	var leaks := ["Transit Rating", "Combat Speed", "Shielding", "Structure", "Ground Regiment", "extractors"]

	# Capital ship status: the manual's stat names (p115-p117).
	if ship != null:
		var l: Array = await _open("UnitStatusWindow", func() -> void: _ui.OpenUnitStatusWindow(ship))
		_check(not l.is_empty(), "the ship status window opened")
		for want in ["Hyperdrive Rating:", "Sub-Light Engine Rating:", "Hull Value:", "Shield Strength:", "Bombardment Modifier:", "Maintenance Cost:"]:
			_check(l.has(want), "ship status shows '%s'" % want)
		for bad in leaks:
			_check(not Lq.any(l, func(t: String) -> bool: return t.contains(bad)), "ship status never shows the default '%s'" % bad)

	# Fighter status.
	if fighter != null:
		var l2: Array = await _open("UnitStatusWindow", func() -> void: _ui.OpenUnitStatusWindow(fighter))
		for want in ["Squadron Size:", "Hyperdrive Rating:", "Maximum Shield Strength:", "Sub-Light Engine Rating:", "Detection Rating:", "Bombardment Value:", "Weapons Rating:"]:
			_check(l2.has(want), "fighter status shows '%s'" % want)
		_check(Lq.any(l2, func(t: String) -> bool: return t.contains("Fighter Squadron Status")), "the fighter window is titled 'Fighter Squadron Status'")

	# Fleet status: the kind names and the hyperdrive yes/no.
	var l3: Array = await _open("FleetStatusWindow", func() -> void: _ui.OpenFleetStatusWindow(fleet))
	for want in ["   Fighter Squadrons:", "   Trooper Regiments:", "Hyperdrive Rating:"]:
		_check(l3.has(want), "fleet status shows '%s'" % want)
	for bad in leaks:
		_check(not Lq.any(l3, func(t: String) -> bool: return t.contains(bad)), "fleet status never shows the default '%s'" % bad)

	# Planet window: energy and raw materials.
	var l4: Array = await _open("PlanetWindow", func() -> void: _ui.OnPlanetClicked(owned))
	_check(not l4.is_empty(), "the planet window opened")
	_check(Lq.any(l4, func(t: String) -> bool: return t.begins_with("Energy: ") and t.contains("| Raw Materials: ")), "the planet window reads 'Energy: N | Raw Materials: N'")

	# Defense Facility Status (manual p085): title and type are the pack's name
	# for the KIND, the shield row is the pack's stat word, chosen by role.
	var shield: Facility = null
	var battery: Facility = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		for f in p.Facilities:
			if shield == null and f.HasRole("shield"):
				shield = f
			elif battery == null and f.HasRole("anti_ship"):
				battery = f
	_check(shield != null, "we hold a shield somewhere")
	_check(battery != null, "we hold a battery somewhere")
	if shield != null:
		var l5: Array = await _open("DefenseFacilityStatusWindow", func() -> void: _ui.OpenDefenseFacilityStatusWindow(shield))
		_check(l5.has("Planetary Shield Status"), "the shield's window is titled 'Planetary Shield Status'")
		_check(l5.has("Planetary Shield"), "the shield's type reads 'Planetary Shield'")
		_check(l5.has("Shield Strength:"), "the shield row reads 'Shield Strength:'")
		_check(Lq.any(l5, func(t: String) -> bool: return t.ends_with(" HP")), "the shield row has a value")
		_check(l5.has("🛡️"), "the shield's glyph")
	if battery != null:
		var l6: Array = await _open("DefenseFacilityStatusWindow", func() -> void: _ui.OpenDefenseFacilityStatusWindow(battery))
		_check(l6.has("Turbolaser Battery Status"), "the battery's window is titled 'Turbolaser Battery Status'")
		_check(l6.has("N/A"), "the battery has no shield strength")
		_check(l6.has("💥"), "the battery's glyph")
	_check(Terms.label("shield_active") == "Active Shielding" and Terms.label("weapon_armed") == "Weapon Armed", "the Defenses tags keep their words")

	print("[terms_windows] %d checks, %d failed: %s" % [_checks, _fails, "PASS" if _fails == 0 else "FAIL"])
	quit(1 if _fails > 0 else 0)
