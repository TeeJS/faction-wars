extends SceneTree
## ITEM 7 of TeeJ's 2026-09-30 list ("the indicator for idle mfg locations is
## too small to see"): the Idle Naval Yards view showed nothing because the
## Allies could start with no naval yard at all.
##   - The Allies start with a naval yard in Britain (allies_hq_facilities)
##     and in the United States (united_states_start_garrison), on every seed
##     and galaxy size.
##   - A mode that marks no world says "None" under its name; one that marks
##     any does not, and neither does Display Off.
##
##   .\tools\run-gd.ps1 tests/gid_none.gd -- --pack=ww2

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[gid_none] ok   %s" % what)
	else:
		_fails += 1
		print("[gid_none] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.LoadedId() != "ww2":
		print("[gid_none] (run with --pack=ww2)")
		print("[gid_none] 0 checks, 0 failed")
		quit(0)
		return

	# The start: Britain and the United States each hold a naval yard.
	for size in [Enums.GalaxySize.Standard, Enums.GalaxySize.Huge]:
		for seed in [12345, 1, 2, 3, 4243]:
			MpSetup.reset()
			GameSession.new_game("allies", Enums.Difficulty.Medium, size, seed)
			var yards := {}
			for s in GameState.ActiveGalaxy:
				for p in s.Planets:
					if p.PackId in ["britain", "united_states"]:
						yards[p.PackId] = Lq.count(p.Facilities, func(f) -> bool: return f.Def != null and f.Def.Id == "shipyard")
			_check(int(yards.get("britain", 0)) >= 1 and int(yards.get("united_states", 0)) >= 1,
				"size %d, seed %d: the Allies start with yards in Britain and the United States (%s)" % [size, seed, str(yards)])

	# The view: the Axis on a seed where it starts with no yard.
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById("axis")
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var map: GalaxyMap = main.get_node("GalaxyMap")
	var none: Label = map._bar._noneLabel
	var axis_yards := 0
	for s in GameState.ActiveGalaxy:
		for p in s.Planets:
			if p.ControllingFaction == GameSettings.PlayerFaction:
				axis_yards += Lq.count(p.Facilities, func(f) -> bool: return f.Def != null and f.Def.Id == "shipyard")
	_check(none != null and none.get_parent() == map._bar._activeLabel, "the None line sits under the mode's name")

	for pair in [["idle_shipyards", axis_yards == 0], ["mines", false]]:
		var mode = Gid.ModeById(pair[0])
		_check(mode != null, "the mode %s exists" % pair[0])
		if mode == null:
			continue
		map.SetMode(mode)
		map.RefreshVisuals()
		await process_frame
		var lit := 0
		for s in GameState.ActiveGalaxy:
			for p in s.Planets:
				if mode.Reveal.call(p) and mode.TierFor(mode.Magnitude.call(p)).FlareSize > 0:
					lit += 1
		_check(none.visible == (lit == 0), "%s marks %d worlds: None %s" % [pair[0], lit, "shown" if none.visible else "hidden"])
		if pair[1]:
			_check(none.visible, "the Axis with no yard: Idle Naval Yards says None")

	map.SetMode(Gid.DisplayOff)
	map.RefreshVisuals()
	await process_frame
	_check(not none.visible, "Display Off: no None")

	print("[gid_none] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
