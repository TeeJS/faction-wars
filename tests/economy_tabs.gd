extends SceneTree
## THE ECONOMY WINDOW'S TABS, PLAIN (the WWII windows fix, step 4; manual
## p083-p084). One pack per process:
##
##   .\tools\run-gd.ps1 tests/economy_tabs.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/economy_tabs.gd -- --pack=star-wars-rebellion
##
## In the plain window (no art set, the stand-ins off), on each world of ours:
## all six tabs are shown (none behind scroll arrows), a facility tab with none
## of its facilities on the system is greyed ("grayed-out tabs indicate no
## facilities of that type are on the system", p084) unless it is the open one,
## and the three "built : built and being built" counts say what they are.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[economy_tabs] ok   %s" % what)
	else:
		_fails += 1
		print("[economy_tabs] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-economy-tabs-none"
	StandIns.Enabled = false
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.Playable[0]
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var roles := {1: "produces_unit", 2: "produces_troop", 3: "produces_facility", 4: "refines", 5: "extracts_raw"}
	var saw_grey := false
	var worlds: Array = GameState.AllPlanets().filter(func(p: Planet) -> bool: return p.ControllingFaction == us)
	for planet in worlds.slice(0, 6):
		ui.CloseAllWindows()
		for _i in 2:
			await process_frame
		ui.OnEconomyClicked(planet)
		for _i in 4:
			await process_frame
		var w: Node = Lq.first_or_null(ui._openWindows.values(), func(x) -> bool: return x is EconomyWindow)
		_check(w != null, "%s: the Economy window opened" % planet.Name)
		if w == null:
			continue
		var tabs: TabContainer = w.get_node("%EconomyTabs")
		_check(tabs.get_tab_count() == 6 and not tabs.clip_tabs, "%s: all six tabs shown, none behind arrows" % planet.Name)
		for i in roles:
			var n: int = Lq.count(planet.Facilities, func(f: Facility) -> bool: return f.HasRole(roles[i]))
			var greyed: bool = tabs.is_tab_disabled(i)
			if greyed:
				saw_grey = true
			_check(greyed == (n == 0 and i != tabs.current_tab), "%s: %s (%d here) is %s" % [planet.Name, tabs.get_tab_title(i), n, "greyed" if greyed else "open"])
		for path in ["%ShipCapLabel", "%TroopCapLabel", "%FacCapLabel"]:
			_check(not (w.get_node(path) as Label).tooltip_text.is_empty(), "%s: %s says what it counts" % [planet.Name, path])
	_check(saw_grey, "some empty facility tab was greyed")
	print("[economy_tabs] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
