extends SceneTree
## THE WWII FACILITY PICTURES IN THE GAME (tools/look/make_ww2_facilities.py):
## a fresh WWII game and the windows that show a facility's picture, each the
## whole screen. Needs a window (NOT --headless), like tests/capture_look.gd:
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_ww2_facilities.gd -- `
##       --out=C:/tmp/ww2/facilities --pack=ww2 --record=user://capture-facilities.jsonl
##
## writes <out>_ency.png (the Encyclopedia at the Naval Yard), _ency_defense.png
## (at the Coastal Battery), _economy.png (the Economy window of the side's
## headquarters), _economy_yards.png (its second tab: facilities with their
## miniatures), _defense.png (its Defense window) and
## _status.png (a defence facility's status, when the headquarters has one).
## --record= is REQUIRED, so the player's user://last-session.jsonl is
## untouched. No art set is read.

const Art := preload("res://src/ui/artwork.gd")
const MoviesLib := preload("res://src/ui/movies.gd")


func _init() -> void:
	await process_frame
	if _arg("--record=", "").is_empty():
		push_error("[capture_ww2_facilities] pass --record=user://<file>.jsonl so the player's session log is untouched")
		quit(2)
		return
	var out := _arg("--out=", "user://ww2-facilities").trim_suffix(".png")
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-capture-facilities-none"
	MoviesLib.UserRoot = "user://test-capture-facilities-none"
	MoviesLib.LaunchPlayed = true
	FactionRegistry.EnsureLoaded()
	if not FactionRegistry.IsLoaded():
		push_error("[capture_ww2_facilities] no pack loaded - pass --pack=ww2")
		quit(3)
		return
	var ok := true

	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.HQOnlyVictory = false
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 12:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	# The world of ours with the most facilities: the headquarters, as a rule.
	var home: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction == us and (home == null or p.Facilities.size() > home.Facilities.size()):
			home = p
	var defence: Facility = Lq.first_or_null(home.Facilities, func(f: Facility) -> bool: return f.Def != null and f.WeaponRating > 0)

	var shots := [
		["ency", func() -> void: ui.OpenEncyclopedia("facilities", "shipyard")],
		["ency_defense", func() -> void: ui.OpenEncyclopedia("facilities", "coastal_battery")],
		["economy", func() -> void: ui.OnEconomyClicked(home)],
		["economy_yards", func() -> void:
			ui.OnEconomyClicked(home)
			for t in ui.find_children("*", "TabContainer", true, false):
				if (t as TabContainer).is_visible_in_tree() and (t as TabContainer).get_tab_count() > 1:
					(t as TabContainer).current_tab = 1
					break],
		["defense", func() -> void: ui.OnDefenseClicked(home)],
	]
	if defence != null:
		shots.append(["status", func() -> void: ui.OpenDefenseFacilityStatusWindow(defence)])
	for s in shots:
		ui.CloseAllWindows()
		for _i in 3:
			await process_frame
		(s[1] as Callable).call()
		for _i in 6:
			await process_frame
		ok = _shot(out, str(s[0])) and ok
	print("[capture_ww2_facilities] %s: %d facilities, defence %s" % [home.Name, home.Facilities.size(), defence.Name() if defence != null else "none"])
	quit(0 if ok else 1)


func _shot(out: String, what: String) -> bool:
	var path := "%s_%s.png" % [out, what]
	var img: Image = root.get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[capture_ww2_facilities] %s %s -> %s" % [what, str(img.get_size()), path if err == OK else ("error %d" % err)])
	return err == OK


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
