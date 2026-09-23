extends SceneTree
## The Build Selection chooser for ships and troops (manual p045, p112 Fig
## 3.58). It crashed before listing anything: it read `r.Name` off the
## catalogue's UnitDef, which has DisplayName (the pack migration's rename),
## so nothing could be built at a shipyard or a training facility from the
## Manufacturing window. The build command finds the unit by that same
## DisplayName, so an order placed from the list must land in the queue.
##
##   Godot_console.exe --headless --path . -s tests/build_chooser.gd [-- --faction=alliance]

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[build_chooser] ok   %s" % what)
	else:
		_fails += 1
		print("[build_chooser] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	GameSettings.PlayerFaction = FactionRegistry.ById(_arg("--faction=", FactionRegistry.Playable[0].Id))
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 8:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var tried := 0
	# Day 0's stockpile is empty (every order is refused for want of refined
	# material); give it some so an order can be placed from the list.
	Economy.For(us).RefinedMaterials = 1000
	for role in ["produces_unit", "produces_troop"]:
		var world: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
			return p.ControllingFaction == us and Lq.any(p.Facilities, func(f: Facility) -> bool: return f.HasRole(role)))
		if world == null:
			print("[build_chooser] (no %s world of ours to try %s)" % [us.Id, role])
			continue
		tried += 1
		ui.OnEconomyClicked(world)
		for _i in 3:
			await process_frame
		var ew: Node = ui._openWindows.get(world.Name + " Economy")
		ew.OpenBuildChooser(world, role)
		for _i in 3:
			await process_frame
		var dialog: ConfirmationDialog = Lq.first_or_null(ew.get_children(), func(c) -> bool: return c is ConfirmationDialog)
		var bs: Node = ui._openWindows.get("Build Selection")
		_check(dialog != null or bs != null, "%s: the chooser opens at %s" % [role, world.Name])
		if bs != null and role == "produces_troop":
			# The original's training list starts with the regiments (TeeJ's screenshot).
			var kinds: Array = Lq.select(bs._items, func(it: Dictionary) -> String:
				var def: PackDefs.UnitDef = Lq.first_or_null(MilitaryCatalog.All(), func(r) -> bool: return r.DisplayName == str(it.name))
				return def.Kind if def != null else "?")
			var first_other: int = kinds.find("spec_force")
			_check(first_other < 0 or not kinds.slice(first_other).has("troop"),
				"the training list puts the regiments first %s" % str(kinds))
			bs.CloseWindow()
			for _i in 2:
				await process_frame
		var wanted: Array = Lq.select(MilitaryCatalog.BuildableAt(role, us), func(r) -> String: return r.DisplayName)
		if dialog != null:
			var picker: OptionButton = dialog.find_children("*", "OptionButton", true, false)[0]
			var listed: Array = []
			for i in picker.item_count:
				listed.append(picker.get_item_text(i))
			_check(listed == wanted, "%s: it lists the catalogue's units by name %s" % [role, str(listed)])
			# The first item nothing blocks here (day 0 blocks some for want of
			# materials or research).
			for i in picker.item_count:
				picker.select(i)
				picker.item_selected.emit(i)
				if not dialog.get_ok_button().disabled:
					break
			var before: int = world.ShipyardQueue.size() + world.TrainingQueue.size()
			if dialog.get_ok_button().disabled:
				print("[build_chooser] (%s: every item is blocked here - order not tried)" % role)
			else:
				var named: String = picker.get_item_text(picker.selected)
				dialog.confirmed.emit()
				await process_frame
				var after: int = world.ShipyardQueue.size() + world.TrainingQueue.size()
				_check(after == before + 1, "%s: ordering %s queues it (%d -> %d)" % [role, named, before, after])
		ew.CloseWindow()
		for _i in 2:
			await process_frame
	_check(tried > 0, "%s holds a shipyard or a training facility" % us.Id)
	print("[build_chooser] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
