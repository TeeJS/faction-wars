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
	them.AddFacility("planetary_shield")
	them.AddFacility("turbolaser_battery")
	them.AddFacility("ion_cannon")
	var defences: Array = Lq.where(them.Facilities, func(f: Facility) -> bool:
		return f.Family() in ["planetary_shield", "turbolaser_battery", "ion_cannon"])
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
		ours.AddFacility("planetary_shield")
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
	_collect_rows(tabs.get_node("Planetary Shield"), rows)
	_collect_rows(tabs.get_node("Planetary Battery"), rows)
	_check(rows.size() == defences.size(), "the Planetary Shield and Battery tabs have %d target rows (have %d)" % [defences.size(), rows.size()])
	var types: Array = []
	for r in rows:
		types.append(str(r.get_meta("defence_type")))
	for t in ["planetary_shield", "turbolaser_battery", "ion_cannon"]:
		_check(t in types, "a row names the %s" % Facility.NameOf(t))
	_check(rows.all(func(r: Node) -> bool: return r.get_node_or_null("FacilityMenu") == null),
		"an enemy's sighted defences have no facility menu")

	# OUR OWN shields and batteries: the facility's right-click menu,
	# Encyclopedia, Status, Scrap (manual p085; TeeJ's screenshot of the
	# original, 2026-09-30).
	if ours != null:
		ours.AddFacility("turbolaser_battery")
		w._associatedPlanet = ours
		w.PopulateOrbitalDefenses(tabs, ours)
		await process_frame
		var own: Array = []
		_collect_rows(tabs.get_node("Planetary Shield"), own)
		_collect_rows(tabs.get_node("Planetary Battery"), own)
		var menus := 0
		var shield_row: Button = null
		for r in own:
			var m: PopupMenu = r.get_node_or_null("FacilityMenu")
			if m != null and m.item_count == 3 and m.get_item_text(0) == "Encyclopedia" and not m.is_item_disabled(0) \
					and m.get_item_text(1) == "Status" and m.get_item_text(2) == "Scrap":
				menus += 1
			if str(r.get_meta("defence_type")) == "planetary_shield":
				shield_row = r
		_check(own.size() >= 2 and menus == own.size(), "our shields and batteries: Encyclopedia, Status, Scrap on every row (%d of %d)" % [menus, own.size()])
		if shield_row != null:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT
			click.pressed = true
			shield_row.gui_input.emit(click)
			await process_frame
			var sm: PopupMenu = shield_row.get_node("FacilityMenu")
			_check(sm.visible, "a right-click on our shield opens its menu")
			sm.hide()
		var ourShield: Facility = Lq.first_or_null(ours.Facilities, func(f: Facility) -> bool: return f.Family() == "planetary_shield")
		if ourShield != null:
			w.ConfirmScrapFacility(ours, ourShield)
			await process_frame
			var ask: ConfirmationDialog = null
			for c in w.get_children():
				if c is ConfirmationDialog:
					ask = c
			_check(ask != null and ask.dialog_text.contains(ourShield.Name()), "Scrap asks first, naming the shield")
			if ask != null:
				ask.confirmed.emit()
				await process_frame
			_check(not ours.Facilities.has(ourShield), "... and the tick scraps it")
	# Before any sighting the tab says so and offers nothing.
	IntelManager.Reset()
	w.PopulateOrbitalDefenses(tabs, them)
	await process_frame
	var blind: Array = []
	_collect_rows(tabs.get_node("Planetary Shield"), blind)
	_collect_rows(tabs.get_node("Planetary Battery"), blind)
	_check(blind.is_empty(), "unseen defences offer no rows")
	# THE BUG TeeJ hit (report screenshot, room #232): a Facility target showed
	# "Target: Taanab" (the planet) because Facility.Name is a METHOD, read as a
	# field. The Create Mission window must name the actual object.
	var agent := Character.new()
	agent.Name = "Kyle Katarn"
	agent.Faction = us
	var shield: Facility = null
	for f in defences:
		if f.Family() == "planetary_shield":
			shield = f
			break
	_check(shield != null, "a Planetary Shield to target")
	if shield != null:
		w.OpenCreateMission([agent], ours, them, shield)
		await process_frame
		var label_text := _find_target_label(w)
		_check(label_text.contains(shield.Name()), "Create Mission names the facility: '%s' contains '%s'" % [label_text, shield.Name()])
		_check(not label_text.strip_edges().ends_with(them.Name), "the target is the shield, not the bare planet '%s'" % them.Name)
	root.remove_child(w)
	w.free()
	_finish()


## The "Target:" label anywhere under the node (the Create Mission dialog is a
## child of the window), or "" if none.
func _find_target_label(node: Node) -> String:
	if node == null:
		return ""
	if node is Label and (node as Label).text.begins_with("Target:"):
		return (node as Label).text
	for c in node.get_children():
		var found := _find_target_label(c)
		if not found.is_empty():
			return found
	return ""


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
