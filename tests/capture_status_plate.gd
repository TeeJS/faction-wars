extends SceneTree
## Renders the original's Status window (manual p064) for a trooper regiment,
## the Facilities Under Construction queue, a manufacturing facility, a
## character, a fleet (one ship damaged), a capital ship, a fighter squadron
## and a defense facility, each cropped to the window. Needs a window (NOT
## --headless):
##
##   Godot_console.exe --path . --resolution 1440x850 -s tests/capture_status_plate.gd -- --out=C:/tmp/st.png [--faction=alliance]
##   writes <out minus .png>_unit.png, _queue.png, _facility.png, _character.png,
##   _fleet.png, _capship.png, _fighter.png and _defense.png (a kind missing
##   from this galaxy is skipped)

func _init() -> void:
	await process_frame
	var out := _arg("--out=", "user://st.png").trim_suffix(".png")
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", "empire"))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var regiment: Unit = null
	var yard: Facility = null
	var home: Planet = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		for u in p.Garrison:
			if regiment == null and u.Type == Enums.UnitType.Troop:
				regiment = u
		for f in p.Facilities:
			if yard == null and f.HasRole("produces_unit"):
				yard = f
				home = p
	var person: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and not c.IsOffMap())
	var fleet: Fleet = null
	var fighter: Unit = null
	var shield: Facility = null
	for p in GameState.AllPlanets():
		if p.ControllingFaction != us:
			continue
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and not f.Ships.is_empty():
				fleet = f
			for sh in f.Ships:   # a squadron aboard a carrier
				for u in sh.Hangar:
					if fighter == null and f.Faction == us and u.Type == Enums.UnitType.Fighter:
						fighter = u
		for u in p.Garrison:
			if fighter == null and u.Type == Enums.UnitType.Fighter:
				fighter = u
		for f in p.Facilities:
			if shield == null and f.HasRole("shield"):
				shield = f
	var ship: Unit = fleet.Ships[0] if fleet != null else null
	if ship != null:   # damaged, as the original's Corellian Corvette 4 was
		ship.DamageState().Hull -= 1
	var ok := true
	var shots := [["unit", func() -> void: ui.OpenUnitStatusWindow(regiment)],
		["queue", func() -> void: ui.OpenQueueStatusWindow(home, "produces_facility")],
		["facility", func() -> void: ui.OpenDefenseFacilityStatusWindow(yard)],
		["character", func() -> void: ui.OpenCharacterStatusWindow(person)],
		["fleet", func() -> void: ui.OpenFleetStatusWindow(fleet)],
		["capship", func() -> void: ui.OpenUnitStatusWindow(ship)],
		["fighter", func() -> void: ui.OpenUnitStatusWindow(fighter)],
		["defense", func() -> void: ui.OpenDefenseFacilityStatusWindow(shield)]]
	var subjects := {"unit": regiment, "queue": home, "facility": yard, "character": person, "fleet": fleet, "capship": ship, "fighter": fighter, "defense": shield}
	for shot in shots:
		if subjects.has(shot[0]) and subjects[shot[0]] == null:
			print("[capture_status_plate] no %s here - skipped" % shot[0])
			continue
		(shot[1] as Callable).call()
		for _i in 4:
			await process_frame
		var w: Control = null
		for k in ui._openWindows:
			if "Status" in str(k) and is_instance_valid(ui._openWindows[k]):
				w = ui._openWindows[k]
		if w == null:
			ok = false
			continue
		var img: Image = root.get_viewport().get_texture().get_image()
		ok = img.get_region(Rect2i(Vector2i(w.global_position), Vector2i(w.size))).save_png("%s_%s.png" % [out, shot[0]]) == OK and ok
		(w as DraggableWindow).CloseWindow()
		for _i in 2:
			await process_frame
	print("[capture_status_plate] %s, %s, %s -> %s" % [regiment.Name if regiment else "-", home.Name if home else "-", yard.Name() if yard else "-", "ok" if ok else "error"])
	quit(0 if ok else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
