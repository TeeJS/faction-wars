extends SceneTree
## The System Defenses window must let the crosshair land on an ENEMY system's
## intel-seen personnel, troops and fighters - so you can abduct a character or
## sabotage a regiment/squadron, not just a facility. Before this, those tabs drew
## plain non-clickable labels (reported from play: "can't sabotage a TIE fighter /
## troops", "can't target enemy personnel for abduction"). The rows are also dated
## "(seen day N)" so a unit that has since moved is not mistaken for being in two
## places at once.
##
##   Godot_console.exe --headless --path . -s tests/enemy_intel_targeting.gd

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
	var alliance: Faction = GameSettings.PlayerFaction
	var empire: Faction = FactionRegistry.ById("empire")

	# An enemy world that has a garrison to sabotage.
	var them: Planet = _first(func(p): return p.ControllingFaction == empire and p.Troopers().size() > 0)
	_check(them != null, "an Empire world with a garrison exists")
	if them == null:
		_finish(); return

	# Park an Empire character there to abduct.
	var vader: Character = Lq.first_or_null(GameState.ActiveRoster, func(c): return c.Faction == empire and c.IsMajor and c.Status != Enums.Status.Dead)
	if vader != null:
		vader.Status = Enums.Status.AwaitingOrders
		vader.CapturedBy = null
		MilitaryCatalog.Relocate(vader, them)

	# The Alliance espionages the world: reveals its units and personnel.
	IntelManager.Capture(alliance, them, StrategicTickManager.Today, IntelManager.EspionageCategories)

	# Engine legality (the target is legal, so a click will produce a mission).
	var enemyTroop: Unit = Lq.first_or_null(them.Troopers(), func(u): return u.Faction == empire)
	_check(enemyTroop != null and MissionManager.CanSabotage(alliance, enemyTroop, them).ok, "an enemy regiment is a legal Sabotage target")
	if vader != null:
		_check(MissionManager.CanTargetPerson(Enums.MissionType.Abduction, alliance, vader).ok, "the enemy major is a legal Abduction target")

	# Populate the window for the enemy system.
	var ui := UIManager.new()
	ui.name = "UIManager"
	root.add_child(ui)
	var w = load("res://src/ui/DefenseWindow.tscn").instantiate()
	root.add_child(w)
	await process_frame
	w.Populate(them, ui)
	await process_frame

	var tabs: TabContainer = w.get_node("%DefenseTabs")
	var personnel: VBoxContainer = w.get_node("%PersonnelList")

	# Troops tab: clickable sabotage rows for the seen enemy regiments.
	var troopRows := _intel_rows(tabs.get_node("Troops"))
	_check(troopRows.size() >= 1, "Troops tab offers %d clickable enemy sabotage target(s)" % troopRows.size())

	# Personnel tab: clickable abduction rows for the seen enemy character(s).
	var personnelRows := _intel_rows(personnel)
	_check(personnelRows.size() >= 1, "Personnel tab offers %d clickable enemy target(s)" % personnelRows.size())

	# Fighters tab: if the world has an enemy squadron, it too must be clickable.
	var enemyFighters: Array = Lq.where(them.FighterSquadrons, func(u): return u.Faction == empire)
	if enemyFighters.size() > 0:
		var fighterRows := _intel_rows(tabs.get_node("Fighters"))
		_check(fighterRows.size() >= 1, "Fighters tab offers clickable enemy sabotage targets")

	# Staleness is dated somewhere (fixes the "in two places" confusion).
	_check(_has_seen_day_label(w), "intel rows are dated '(seen day N)'")

	# Before intel, nothing is offered (fog holds).
	IntelManager.Reset()
	w.Populate(them, ui)
	await process_frame
	_check(_intel_rows(tabs.get_node("Troops")).is_empty(), "no clickable enemy rows without intel")

	w.free()
	ui.free()
	_finish()


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


## Buttons flagged as intel target rows, anywhere under `node`.
func _intel_rows(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	if node is Button and node.has_meta("intel_target"):
		out.append(node)
	for c in node.get_children():
		out.append_array(_intel_rows(c))
	return out


func _has_seen_day_label(node: Node) -> bool:
	if node is Label and (node as Label).text.contains("seen day"):
		return true
	for c in node.get_children():
		if _has_seen_day_label(c):
			return true
	return false


func _finish() -> void:
	print("[enemy_intel_targeting] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
