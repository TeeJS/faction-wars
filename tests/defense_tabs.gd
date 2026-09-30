extends SceneTree
## THE DEFENSES WINDOW'S TABS, PLAIN (the WWII windows fix, step 3; manual
## p126, Fig. 3.73). One pack per process:
##
##   .\tools\run-gd.ps1 tests/defense_tabs.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/defense_tabs.gd -- --pack=star-wars-rebellion
##
## In the plain window (no art set, the stand-ins off): the tabs carry the
## pack's words (TeeJ, 2026-09-30: "this shouldn't be called planetary"), every
## tab is shown (none behind scroll arrows), a tab with nothing on it is greyed
## and closed while one with something on it is open ("a tab with nothing on
## it is greyed", p126), the window opens on its first tab with something on
## it, and a facility's row carries its picture where the pack has one.

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[defense_tabs] ok   %s" % what)
	else:
		_fails += 1
		print("[defense_tabs] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-defense-tabs-none"
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
	var id := FactionRegistry.LoadedId()
	var us: Faction = GameSettings.PlayerFaction

	var want := ["Personnel", DefenseWindow._title_case(Terms.label("trooper_regiments")),
		DefenseWindow._title_case(Terms.label("fighter_squadrons")),
		DefenseWindow._title_case(Terms.label("planetary_shields")),
		DefenseWindow._title_case(Terms.label("orbital_batteries"))]
	if id == "ww2":
		_check(want == ["Personnel", "Divisions", "Air Squadrons", "Fortifications", "Coastal Batteries"],
			"ww2: the tabs' words are the pack's (%s)" % ", ".join(want))

	# Every world of ours: the tabs, and which are open.
	var worlds: Array = GameState.AllPlanets().filter(func(p: Planet) -> bool: return p.ControllingFaction == us)
	var saw_grey := false
	var saw_picture := false
	for planet in worlds.slice(0, 6):
		ui.CloseAllWindows()
		for _i in 2:
			await process_frame
		ui.OnDefenseClicked(planet)
		for _i in 4:
			await process_frame
		var w: Node = ui._openWindows.get("%s Defenses" % planet.Name)
		if w == null:
			w = Lq.first_or_null(ui._openWindows.values(), func(x) -> bool: return x is DefenseWindow)
		_check(w != null, "%s: the Defenses window opened" % planet.Name)
		if w == null:
			continue
		var tabs: TabContainer = w.get_node("%DefenseTabs")
		var titles: Array = []
		for i in tabs.get_tab_count():
			titles.append(tabs.get_tab_title(i))
		_check(titles == want, "%s: tabs %s" % [planet.Name, ", ".join(titles)])
		_check(not tabs.clip_tabs, "%s: every tab shown, none behind arrows" % planet.Name)
		var first := -1
		for i in tabs.get_tab_count():
			var rows: int = DefenseWindow._rows_on(tabs.get_child(i))
			if rows > 0 and first < 0:
				first = i
			if rows == 0 and tabs.is_tab_disabled(i):
				saw_grey = true
			_check((rows == 0) == tabs.is_tab_disabled(i) or (rows == 0 and i == maxi(first, 0) and first <= 0),
				"%s: %s has %d rows and is %s" % [planet.Name, titles[i], rows, "greyed" if tabs.is_tab_disabled(i) else "open"])
		_check(tabs.current_tab == maxi(first, 0), "%s: opens on its first tab with something on it (%s)" % [planet.Name, titles[tabs.current_tab]])
		for i in [3, 4]:
			for b in tabs.get_child(i).find_children("*", "Button", true, false):
				if (b as Button).icon != null:
					saw_picture = true
	_check(saw_grey, "%s: some empty tab was greyed" % id)
	if id == "ww2":
		_check(saw_picture, "ww2: a facility row carries its picture")
	print("[defense_tabs] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
