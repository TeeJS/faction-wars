extends SceneTree
## THE PLAYER-FACING WINDOWS OBEY THE FOG (manual p069). Two windows were reading
## the live enemy world for any system merely explored once:
##
##   PlanetWindow  - showed the live holder, both live supports, live uprising and
##                   the live facility list (Headquarters included) of a world
##                   scouted long ago. Now: Unexplored -> nothing; ours -> live;
##                   else the dated sighting, with Core owner/support live (p069).
##   PersonnelFinder - listed an enemy at their LIVE location if we held Characters
##                   intel on whatever world they stand on TODAY. Now: only where a
##                   Characters SIGHTING actually placed them, at that world.
##
##   Godot_console.exe --headless --path . -s tests/ui_fog.gd

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

	await _planet_window(alliance, empire)
	await _personnel_finder(alliance, empire)

	print("[ui_fog] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _planet_window(alliance: Faction, empire: Faction) -> void:
	var pw = load("res://src/ui/PlanetWindow.tscn").instantiate()
	root.add_child(pw)
	await process_frame

	# An uncharted world shows nothing about itself.
	var dark: Planet = _first(func(p: Planet) -> bool: return not p.ExploredBy(alliance) \
			and p.ControllingFaction == empire and not IntelManager.IsCore(p))
	if dark != null:
		pw.Populate(dark)
		_check((pw.get_node("%status") as Label).text == "Unexplored Planet", "planet window: an uncharted world shows 'Unexplored Planet', not live state")

	# A scouted Rim world reports the SIGHTING, not the live world that moved on.
	# (Both sides start mostly in the Core - p069 - so a Rim non-ours world is neutral.)
	var r: Planet = _first(func(p: Planet) -> bool: return p.ControllingFaction != alliance and not IntelManager.IsCore(p))
	if r != null:
		StrategicTickManager.Today = 3
		r.SetSupportFor(alliance, 15)
		IntelManager.Capture(alliance, r, 3, IntelManager.ReconnaissanceCategories)
		pw.Populate(r)
		var facAtCapture: int = _count_labels(pw.get_node("%facilities"))
		# The world changes after we looked: support swings, defences go up.
		r.SetSupportFor(alliance, 88)
		r.AddFacility("planetary_shield", 1)
		r.AddFacility("planetary_shield", 1)
		pw.Populate(r)
		var status: String = (pw.get_node("%status") as Label).text
		_check(status.contains("15%") and not status.contains("88%"), "planet window shows the SCOUTED support (15%%), not the live value (88%%)")
		_check(_count_labels(pw.get_node("%facilities")) == facAtCapture, "planet window's facility list is the snapshot, not the live (grown) one")

	# A Core world we don't hold: the holder IS live (the one p069 exception).
	var core_enemy: Planet = _first(func(p: Planet) -> bool: return IntelManager.IsCore(p) and p.ControllingFaction == empire)
	if core_enemy != null:
		pw.Populate(core_enemy)
		var neutral: Faction = FactionRegistry.Neutral
		core_enemy.ControllingFaction = neutral
		pw.Populate(core_enemy)
		_check((pw.get_node("%status") as Label).text.contains("Held by: %s" % neutral.DisplayName), "planet window: a Core world's holder is LIVE (p069)")

	pw.free()


func _personnel_finder(alliance: Faction, empire: Faction) -> void:
	var pf = load("res://src/ui/PersonnelFinder.tscn").instantiate()
	root.add_child(pf)
	await process_frame

	var enemy: Character = _first_char(func(c: Character) -> bool: return c.Faction == empire \
			and c.Status != Enums.Status.Dead and not c.IsOffMap())
	var w: Planet = _first(func(p: Planet) -> bool: return p.ControllingFaction != alliance \
			and not IntelManager.IsCore(p) and not p.ExploredBy(alliance))
	var w2: Planet = _first(func(p: Planet) -> bool: return p != w and p.ControllingFaction != alliance \
			and not IntelManager.IsCore(p) and not p.ExploredBy(alliance))
	_check(enemy != null and w != null and w2 != null and w != w2, "an enemy and two distinct unscouted Rim worlds exist")
	if enemy == null or w == null or w2 == null or w == w2:
		pf.free()
		return

	enemy.Attached = w
	enemy.Destination = null
	enemy.Status = Enums.Status.AwaitingOrders
	enemy.DaysToDestination = 0

	# Not yet seen there: the finder must NOT list them.
	_check(not _mentions(_texts(pf, empire), enemy.Name), "an enemy we have not seen is NOT listed")

	# Espionage sees them at w: now they are listed, AT w.
	StrategicTickManager.Today = 7
	IntelManager.Capture(alliance, w, 7, IntelManager.EspionageCategories)
	var texts: Array = _texts(pf, empire)
	_check(_mentions(texts, enemy.Name), "after espionage, the enemy IS listed")
	_check(_row_in(texts, enemy.Name).contains(w.Name), "listed at the world we saw them on (%s)" % w.Name)

	# They move on, unseen: the finder still shows the world we SAW them at, not the new one.
	enemy.Attached = w2
	var row: String = _row_in(_texts(pf, empire), enemy.Name)
	_check(row.contains(w.Name) and not row.contains(w2.Name), "after they move unseen, the finder still shows %s, not their live world" % w.Name)

	pf.free()


func _first(pred: Callable) -> Planet:
	for p in GameState.AllPlanets():
		if pred.call(p):
			return p
	return null


func _first_char(pred: Callable) -> Character:
	for c in GameState.ActiveRoster:
		if pred.call(c):
			return c
	return null


func _count_labels(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is Label:
			n += 1
	return n


func _all_text(node: Node, out: Array = []) -> Array:
	if node is Button:
		out.append((node as Button).text)
	elif node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_all_text(c, out)
	return out


## The finder's rows for a side: the original's (CharactersOf - its list
## shows one side's page at a time) or the plain window's two lists.
func _texts(pf: Node, side: Faction) -> Array:
	if pf.get("_allianceList") == null:
		return pf.CharactersOf(side).map(func(e) -> String: return e.Text)
	pf.PopulateLists("")
	return _all_text(pf)


## The first row text that names `who` (a personnel row is "Name - World ...").
func _row_in(texts: Array, who: String) -> String:
	for t in texts:
		if str(t).contains(who):
			return str(t)
	return ""


func _mentions(texts: Array, name: String) -> bool:
	for t in texts:
		if str(t).contains(name):
			return true
	return false
