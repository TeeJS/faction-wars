extends SceneTree
## The original's battle windows (manual p141 Fig. 4.1, p142 Fig. 4.2, p152;
## src/ui/original_battle.gd): with the art imported the Battle Alert is the
## original's - "Battle at <system>", the situation in the original's words,
## the column's four pages by side, the forces list with a fleet's ships and
## what they carry, Retreat / Simulate Results / Take Command - and the
## results show the composed outcome under the title, with the column's close,
## pages and Goto System, and each side's forces as TeeJ's screenshots of the
## original's have them (the side's name, Filters and its four tabs, the
## table's columns, pictures, "No Casualties"). The sentences turn on who
## moved in (manual p021 Fig. 2.1, p141 Fig. 4.1) and name the sides by their
## adjectives. Writes and removes its own test art.
##
##   .\tools\run-gd.ps1 tests/original_battle.gd

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_battle] ok   %s" % what)
	else:
		_fails += 1
		print("[original_battle] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-battle-art"
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	for sub in ["windows", "buttons", "tabs"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	for side in ["alliance", "empire"]:
		_png("%s/windows/battle_frame.%s.png" % [dir, side], 470, 331, Color(0.4, 0.4, 0.4, 0.5))
		_png("%s/windows/frame.%s.png" % [dir, side], 470, 331, Color(0.4, 0.4, 0.4, 0.5))
		for w in ["battle_alert", "battle_forces", "battle_result"]:
			_png("%s/windows/%s.%s.png" % [dir, w, side], 400, 310, Color(0.1, 0.1, 0.2))
		for b in ["battle_retreat", "battle_simulate", "battle_command"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 134, 27, Color(0.5, 0.5, 0.6))
			_png("%s/buttons/%s.%s.disabled.png" % [dir, b, side], 134, 27, Color(0.3, 0.3, 0.3))
		for b in ["battle_close", "battle_goto"]:
			_png("%s/buttons/%s.%s.png" % [dir, b, side], 44, 41, Color(0.6, 0.6, 0.6))
		for t in ["battle_summary", "battle_alliance_forces", "battle_empire_forces", "battle_system"]:
			_png("%s/tabs/%s.%s.png" % [dir, t, side], 44, 41, Color(0.5, 0.5, 0.5))
			_png("%s/tabs/%s.%s.pressed.png" % [dir, t, side], 44, 41, Color(0.8, 0.8, 0.8))
		for t in ["ency_tab_ship", "battle_filter_fighter", "ency_tab_troop", "ency_tab_personnel"]:
			_png("%s/tabs/%s.%s.png" % [dir, t, side], 49, 41, Color(0.5, 0.5, 0.5))
			_png("%s/tabs/%s.%s.pressed.png" % [dir, t, side], 49, 41, Color(0.2, 0.2, 0.9))
	for t in ["battle_table2", "battle_table3", "battle_result_none"]:
		_png("%s/windows/%s.png" % [dir, t], 400, 310, Color(0.1, 0.1, 0.4))
	Art.Reset()

	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var fleets := {}
	var where: Planet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			var id: String = f.Faction.Id if f.Faction != null else ""
			if not fleets.has(id) and not f.Ships.is_empty():
				fleets[id] = f
				if id == "empire":
					where = p
	_check(fleets.has("alliance") and fleets.has("empire"), "a fleet on each side to stage a battle with")
	if not (fleets.has("alliance") and fleets.has("empire")):
		_finish()
		return
	var r := FleetBattleManager.BattleReport.new()
	r.Where = where
	r.Ours = fleets["alliance"]
	r.Theirs = fleets["empire"]
	r.WeLost = true
	r.LoserWithdrew = true
	var alliance: Faction = r.Ours.Faction
	var empire: Faction = r.Theirs.Faction
	_check(alliance.Adjective == "Alliance" and empire.Adjective == "Imperial", "the sides' adjectives: Alliance, Imperial")
	_Sentences(r, where, alliance, empire)
	r.Arriving = null
	r.WeLost = true
	r.TheirsLost = false
	r.LoserWithdrew = true
	for s in r.Theirs.Ships:
		if s.Type == Enums.UnitType.CapitalShip:
			r.TheirLosses.add("CapitalShipsOperational", s.Name, "units", s.PackId, false)
	# A lost Alliance ship, undamaged before it went, with its picture and its
	# flames: a destroyed craft burns (TeeJ, 2026-09-24, the original's lost Y-wing).
	var lost: Unit = null
	for s in r.Ours.Ships:
		if s.Type == Enums.UnitType.CapitalShip:
			lost = s
			break
	if lost != null:
		DirAccess.make_dir_recursive_absolute("%s/portraits/units" % dir)
		_png("%s/portraits/units/%s.png" % [dir, lost.PackId], 122, 50, Color(0.7, 0.7, 0.7))
		_png("%s/portraits/units/%s.damage.png" % [dir, lost.PackId], 122, 50, Color(1, 0.5, 0))
		Art.Reset()
		r.OurLosses.add("CapitalShipsDestroyed", lost.Name, "units", lost.PackId, false)

	var alert := BattleAlertWindow.new()
	alert.name = "BattleAlertWindow"
	ui.add_child(alert)
	alert.Setup(r)
	await process_frame
	_check(alert._o != null, "the Battle Alert is the original's")
	var title: Label = alert._oBody.get_node_or_null("Title")
	_check(title != null and title.text == "Battle at %s" % where.Name, "titled 'Battle at %s'" % where.Name)
	var situation: Label = alert._oBody.get_node_or_null("Situation")
	_check(situation != null and situation.text.contains(where.Name) and situation.text == alert._Situation(),
		"the situation in the original's words ('%s')" % (situation.text if situation != null else ""))
	_check(alert._oButtons.size() == 4 and (alert._oButtons[0] as TextureButton).texture_normal == alert._oButtons[0].get_meta("current"),
		"four pages in the column, Battle Summary current")
	# The Imperial Forces page: the Empire's fleet, its ships and what they carry.
	(alert._oButtons[2] as TextureButton).pressed.emit()
	await process_frame
	var fleet: Fleet = fleets["empire"]
	var list: Control = alert._oBody.get_node_or_null("List")
	var want: int = OriginalBattle_rows(fleet)
	_check(list != null and int(list.get_meta("rows")) == want, "the Imperial Forces list: the fleet, %d rows" % want)
	var page_name: Label = alert._oBody.get_node_or_null("PageName")
	_check(page_name != null and page_name.text.ends_with("Forces"), "the page named '%s'" % (page_name.text if page_name != null else ""))
	(alert._oButtons[3] as TextureButton).pressed.emit()
	await process_frame
	page_name = alert._oBody.get_node_or_null("PageName")
	_check(page_name != null and page_name.text == "System Assets", "the System Summary page: System Assets")
	var buttons: Array = Lq.select(alert._o.get_children().filter(func(n: Node) -> bool: return n is TextureButton and n.name.begins_with("battle_")),
		func(n: Node) -> String: return n.name)
	_check(buttons.has("battle_retreat_%s" % OUI_side()) and buttons.has("battle_simulate_%s" % OUI_side()) and buttons.has("battle_command_%s" % OUI_side()),
		"Retreat, Simulate Results and Take Command along the bottom")
	alert.queue_free()
	await process_frame

	var results := BattleResultsWindow.new()
	results.name = "BattleResultsWindow"
	ui.add_child(results)
	results.Setup(r)
	await process_frame
	_check(results._o != null, "the results are the original's")
	var outcome: Label = results._oBody.get_node_or_null("Outcome")
	var lines: Array[String] = BattleResultsWindow.OutcomeLines(r, GameSettings.LocalFaction())
	_check(outcome != null and outcome.text == lines[0], "the outcome in large type: '%s'" % lines[0])
	var rest: Label = results._oBody.get_node_or_null("Rest")
	_check(rest != null and rest.text == " ".join(lines.slice(1)), "the rest of it below")
	(results._oButtons[2] as TextureButton).pressed.emit()
	await process_frame
	_check(results._page == 2 and results._oBody.get_node_or_null("Head0") != null, "the Empire's forces page, its table's columns")
	var body: Control = results._oBody
	_check(_text(body, "PageName") == "Imperial Forces", "the page named 'Imperial Forces' ('%s')" % _text(body, "PageName"))
	_check(_text(body, "Filters") == "Filters", "'Filters' before the tabs")
	var tabs: Array = []
	for i in 4:
		tabs.append(body.get_node_or_null("Filter%d" % i))
	_check(not tabs.has(null), "four filter tabs: capital ships, fighters, troops, personnel")
	_check(_text(body, "Band") == "Capital Ships", "the table's band: 'Capital Ships' ('%s')" % _text(body, "Band"))
	_check(_text(body, "Head0") == "Operational" and _text(body, "Head1") == "Destroyed", "the columns: Operational, Destroyed")
	var ships: int = r.TheirLosses.CapitalShipsOperational.size()
	_check(ships == 0 or body.get_node_or_null("Rows/Inner/Name0_0") != null, "each operational ship's picture and name")
	_check(_text(body, "Empty1") == "No Casualties", "an empty Destroyed column: 'No Casualties'")
	_check((body.get_node_or_null("ScrollBar") != null) == (ships > 2), "a scroll bar only past two pictures (%d ships)" % ships)
	(tabs[3] as TextureButton).pressed.emit()
	await process_frame
	_check(results._tab == 3 and _text(body, "Band") == "Personnel" and _text(body, "Head2") == "Killed",
		"the personnel filter: Survivors, Captured, Killed")
	_check(_text(body, "Empty2") == "No Casualties" and _text(body, "Empty1") == "None", "empty personnel columns: None, No Casualties")
	if lost != null:
		results._tab = 0
		(results._oButtons[1] as TextureButton).pressed.emit()
		await process_frame
		var live := func(n: String) -> Node:
			for c in body.find_children(n, "", true, false):
				if not c.is_queued_for_deletion():
					return c
			return null
		_check(live.call("Picture1_0") != null and live.call("Flames1_0") != null,
			"the Alliance's lost %s burns in the Destroyed column" % lost.Name)
	results.queue_free()
	_finish()


## The alert's and results' sentences (manual p021 Fig. 2.1, p141 Fig. 4.1,
## TeeJ's Chandrila screenshots), whoever holds the world the test stages at.
func _Sentences(r: FleetBattleManager.BattleReport, where: Planet, alliance: Faction, empire: Faction) -> void:
	var owner: Faction = where.ControllingFaction
	var world: String = where.Name
	var alert := BattleAlertWindow.new()
	alert._battle = r
	var saved: Faction = GameSettings.PlayerFaction
	GameSettings.PlayerFaction = empire
	# The Alliance moves in on a world.
	r.Arriving = r.Ours
	var s: String = alert._Situation()
	if owner == alliance:
		_check(s == "The Alliance fleet is attempting to break the Imperial blockade at %s." % world, "arriving at its own world: '%s'" % s)
	elif owner == empire:
		_check(s == "The Alliance fleet is threatening %s. Imperial forces are moving to intercept." % world, "they move in on our world: '%s'" % s)
		GameSettings.PlayerFaction = alliance
		s = alert._Situation()
		_check(s == "The Alliance fleet has entered the %s system. Imperial forces have been detected on an intercept course." % world,
			"we move in on theirs: '%s'" % s)
		GameSettings.PlayerFaction = empire
	r.Arriving = null
	s = alert._Situation()
	_check(s == "Alliance and Imperial forces are about to engage in battle near the %s system." % world, "neither moved in: '%s'" % s)
	alert.free()
	# The results: the Alliance beaten and withdrawn, one victory clause.
	r.WeLost = true
	r.TheirsLost = false
	r.LoserWithdrew = true
	var lines: Array[String] = BattleResultsWindow.OutcomeLines(r, empire)
	_check(lines.size() == 3 and lines[0] == "The Imperial fleet is victorious." and lines[2] == "The Alliance fleet has withdrawn.",
		"the victor's view: %s" % str(lines))
	lines = BattleResultsWindow.OutcomeLines(r, alliance)
	_check(lines[0] == "The Alliance fleet is defeated.", "the loser's view: '%s'" % lines[0])
	# A side moving in on its own world: the blockade broken, or maintained.
	if owner == empire:
		r.Arriving = r.Theirs
		r.WeLost = true
		r.TheirsLost = false
		lines = BattleResultsWindow.OutcomeLines(r, empire)
		_check(lines[1] == "Imperial forces have broken the blockade of %s." % world, "the blockade broken: '%s'" % lines[1])
		r.WeLost = false
		r.TheirsLost = true
		r.LoserWithdrew = false
		lines = BattleResultsWindow.OutcomeLines(r, empire)
		_check(lines[1] == "Alliance forces have maintained the blockade of %s." % world and lines[2] == "The Imperial fleet has been completely destroyed.",
			"the blockade maintained, the loser destroyed: %s" % str(lines))
	GameSettings.PlayerFaction = saved


static func _text(parent: Node, path: String) -> String:
	var l: Label = parent.get_node_or_null(path) as Label
	return l.text if l != null else ""


static func OUI_side() -> String:
	return GameSettings.LocalFaction().ArtSkin


## The rows the forces page should list for a fleet (as OriginalBattle does).
static func OriginalBattle_rows(fleet: Fleet) -> int:
	return preload("res://src/ui/original_battle.gd").FleetRows(fleet).size()


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[original_battle] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int, color: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
