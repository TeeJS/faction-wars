extends SceneTree
## UI smoke test - the step 3 gate. Starts the seed-12345 galaxy, builds a bare
## UIManager (no Main.tscn, so one window can be tested while the others are
## still being written), opens the requested window(s) exactly the way the game
## does, lets the repaint poll run, advances a few days so Refresh() is
## exercised, and quits. Failures show up as SCRIPT ERROR lines on stderr.
##
##   Godot_console.exe --headless --path . -s tests/ui_smoke.gd -- --window=FleetWindow
##   Godot_console.exe --headless --path . -s tests/ui_smoke.gd            (every window)
##   ... -- --main   (instantiates Main.tscn itself instead of the bare UIManager)

const ALL := [
	"SectorWindow", "PlanetWindow", "DefenseWindow", "FleetWindow", "EconomyWindow",
	"MissionWindow", "InGameMenuWindow", "MessageWindow", "CharacterStatusWindow",
	"PersonnelFinder", "PlanetFinder", "TransitConfirmWindow", "UnitStatusWindow",
	"DefenseFacilityStatusWindow", "FleetStatusWindow", "GalaxyOverviewWindow",
	"ObjectivesWindow", "BattleAlertWindow", "BattleResultsWindow", "TacticalView",
	"MilitaryDataEditor",
]

var _ui: UIManager
var _engine: StrategicTickManager
var _main: Node = null


func _init() -> void:
	var only := _arg("--window=", "")
	var wanted: Array = [only] if not only.is_empty() else ALL
	var use_main := OS.get_cmdline_user_args().has("--main")

	if use_main:
		# Main.tscn's GameManager starts the game itself (pass --seed=12345 on
		# the command line for the fixture galaxy); its _ready runs once the
		# tree is up, so the engine and UIManager are picked up in _run.
		_main = load("res://Main.tscn").instantiate()
		root.add_child(_main)
	else:
		_engine = GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Large, 12345)
		_ui = UIManager.new()
		_ui.name = "UIManager"
		var panel := PanelContainer.new()
		panel.name = "TaskbarPanel"
		_ui.add_child(panel)
		var list := VBoxContainer.new()
		list.name = "TaskbarList"
		panel.add_child(list)
		list.owner = _ui
		list.unique_name_in_owner = true
		root.add_child(_ui)
		for w in wanted:
			_assign_template(w)

	print("[ui_smoke] windows: %s" % ", ".join(wanted))
	_run(wanted)


func _run(wanted: Array) -> void:
	# The bare UIManager has no viewport until the tree has run a frame.
	await process_frame
	if _main != null:
		_ui = _main.get_node("UIManager")
		_engine = _main._strategicEngine
	AiManager.DriveAllFactions = true
	var galaxy: Array = GameState.ActiveGalaxy
	var us: Faction = GameSettings.PlayerFaction
	var owned: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and not p.OrbitingFleets.is_empty())
	if owned == null:
		owned = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	var anyPlanet: Planet = GameState.AllPlanets()[0]
	var ours: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool: return c.Faction == us and c.Attached != null)
	var fleet: Fleet = owned.OrbitingFleets[0] if not owned.OrbitingFleets.is_empty() else null
	var unit: Unit = fleet.Ships[0] if fleet != null and not fleet.Ships.is_empty() else (owned.Garrison[0] if not owned.Garrison.is_empty() else null)
	var facility: Facility = Lq.first_or_null(owned.Facilities, func(_f: Facility) -> bool: return true)

	for w in wanted:
		print("[ui_smoke] open %s" % w)
		match w:
			"SectorWindow": _ui.OnSectorClicked(galaxy[0])
			"PlanetWindow": _ui.OnPlanetClicked(owned)
			"DefenseWindow": _ui.OnDefenseClicked(owned)
			"FleetWindow": _ui.OnFleetClicked(owned)
			"EconomyWindow": _ui.OnEconomyClicked(owned)
			"MissionWindow": _ui.OnMissionClicked(owned)
			"InGameMenuWindow": _ui.OnMenuButtonClicked()
			"MessageWindow": _ui.OnMessageIndexClicked("All")
			"CharacterStatusWindow":
				if ours != null:
					_ui.OpenCharacterStatusWindow(ours)
			"PersonnelFinder": _ui.OpenPersonnelFinder()
			"PlanetFinder": _ui.OpenPlanetFinder()
			"TransitConfirmWindow":
				if ours != null:
					_ui.OpenTransitConfirm([ours], 3, func() -> void: print("[ui_smoke] transit confirmed"))
			"UnitStatusWindow":
				if unit != null:
					_ui.OpenUnitStatusWindow(unit)
			"DefenseFacilityStatusWindow":
				if facility != null:
					_ui.OpenDefenseFacilityStatusWindow(facility)
			"FleetStatusWindow":
				if fleet != null:
					_ui.OpenFleetStatusWindow(fleet)
			"GalaxyOverviewWindow": _ui.OpenGalaxyOverview()
			"ObjectivesWindow": _ui.OpenObjectives()
			"BattleAlertWindow", "BattleResultsWindow", "TacticalView":
				_battle_windows(w)
			"MilitaryDataEditor":
				var scene: PackedScene = load("res://src/ui/MilitaryDataEditor.tscn")
				if scene != null:
					root.add_child(scene.instantiate())
			_:
				push_error("[ui_smoke] unknown window %s" % w)
		await process_frame
		await process_frame

	# Let the poll repaint, then run days so every Refresh() path is exercised.
	await create_timer(0.6).timeout
	for i in 5:
		_engine.AdvanceDay()
		await process_frame
	await create_timer(0.6).timeout

	var open := 0
	for name in _ui._openWindows.keys():
		if is_instance_valid(_ui._openWindows[name]):
			open += 1
	print("[ui_smoke] done: %d tracked windows open, day %d" % [open, StrategicTickManager.Today])
	quit(0)


## The battle windows need a real engagement, so run the AI until one is raised.
func _battle_windows(w: String) -> void:
	var days := 0
	while not FleetBattleManager.HasPendingBattle() and days < 120:
		_engine.AdvanceDay()
		days += 1
		while FleetBattleManager.HasPendingBattle() and _battle_is_not_ours():
			FleetBattleManager.SimulateResults(FleetBattleManager.AwaitingOrders()[0], StrategicTickManager.Today)
	if not FleetBattleManager.HasPendingBattle():
		print("[ui_smoke] no battle raised in %d days - %s not exercised" % [days, w])
		return
	print("[ui_smoke] battle raised on day %d" % StrategicTickManager.Today)
	_ui.ShowPendingBattle()
	var alert: BattleAlertWindow = _ui.get_node_or_null("BattleAlertWindow")
	if alert == null:
		return
	match w:
		"BattleAlertWindow":
			alert.Redraw()
		"BattleResultsWindow":
			alert.OnSimulate()
			_ui.RefreshActiveWindows(StrategicTickManager.Today)
			var results: BattleResultsWindow = _ui.get_node_or_null("BattleResultsWindow")
			if results != null:
				results._page = 1
				results.Redraw()
		"TacticalView":
			alert.OnTakeCommand()
			var view: TacticalView = _ui.get_node_or_null("TacticalView")
			if view != null:
				for i in 30:
					view._process(1.0)
				view.Finish()


func _battle_is_not_ours() -> bool:
	return false


func _assign_template(w: String) -> void:
	var path := "res://src/ui/%s.tscn" % w
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	var prop := "%sTemplate" % w
	if scene != null and prop in _ui:
		_ui.set(prop, scene)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
