extends SceneTree
## THE PLAIN FINDERS IN THE PACK'S WORDS (TeeJ, 2026-09-29): the System and
## Personnel Finders' side tabs carry the pack's short side names, and the
## System Finder's search hint is the pack's `search_systems` term - not the
## scene's "Alliance", "Empire" and "Search galaxy...". The Star Wars pack's
## own words are exactly those, so its finders read as before. One pack per
## process:
##
##   .\tools\run-gd.ps1 tests/finder_side_names.gd -- --pack=ww2 --seed=12345
##   .\tools\run-gd.ps1 tests/finder_side_names.gd -- --seed=12345      (Star Wars)

const Art := preload("res://src/ui/artwork.gd")
const StandIns := preload("res://src/ui/art_standins.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[finder_side_names] ok   %s" % what)
	else:
		_fails += 1
		print("[finder_side_names] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-finder-names-none"
	# The plain finders (without the art the Star Wars pack builds the
	# original's from our stand-ins).
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
	var first: String = (FactionRegistry.Playable[0] as Faction).ShortName
	var second: String = (FactionRegistry.Playable[1] as Faction).ShortName

	ui.OpenPlanetFinder()
	for _i in 3:
		await process_frame
	var pf: Control = ui._openWindows.get("PlanetFinder")
	_check(pf != null, "%s: the System Finder opened" % id)
	if pf != null:
		var tabs: TabContainer = pf.get_node("%FactionTabs")
		var titles: Array = []
		for i in tabs.get_tab_count():
			titles.append(tabs.get_tab_title(i))
		_check(titles[1] == first and titles[2] == second, "System Finder tabs: %s" % ", ".join(titles))
		var hint: String = (pf.get_node("%SearchBar") as LineEdit).placeholder_text
		_check(hint == Terms.label("search_systems"), "its search hint is the pack's (%s)" % hint)
		if id == "star-wars-rebellion":
			_check(titles == ["All Systems", "Alliance", "Empire", "Neutral", "Unexplored"] and hint == "Search galaxy...",
				"Star Wars: the words it always had")
		else:
			_check(not titles.has("Alliance") and not titles.has("Empire") and not hint.to_lower().contains("galaxy"),
				"%s: no Star Wars words left" % id)
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame

	ui.OpenPersonnelFinder()
	for _i in 3:
		await process_frame
	var pers: Control = ui._openWindows.get("PersonnelFinder")
	_check(pers != null, "%s: the Personnel Finder opened" % id)
	if pers != null:
		var tabs: TabContainer = pers.get_node("%FactionTabs")
		_check(tabs.get_tab_title(0) == first and tabs.get_tab_title(1) == second,
			"Personnel Finder tabs: %s, %s" % [tabs.get_tab_title(0), tabs.get_tab_title(1)])
		if id == "star-wars-rebellion":
			_check(tabs.get_tab_title(0) == "Alliance" and tabs.get_tab_title(1) == "Empire", "Star Wars: the words it always had")
	print("[finder_side_names] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
