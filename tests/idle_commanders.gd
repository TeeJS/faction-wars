extends SceneTree
## A character holding a command rank is not "Idle Personnel" (TeeJ,
## 2026-09-24: "personnel should not show as 'idle' when they have a command
## position"; his screenshot of the original: General Jerjerrod alone at Sluis
## Van, no idle flare). The GID count and the Sector window's flare, both.
## And the rank is a prefix to the name - on the card and in the Status window
## ("General Jerjerrod", "Commanding: Sluis Van" - his screenshots of the
## original, the same day).
##
##   .\tools\run-gd.ps1 tests/idle_commanders.gd

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[idle_commanders] ok   %s" % what)
	else:
		_fails += 1
		print("[idle_commanders] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var us: Faction = GameSettings.PlayerFaction
	var who: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.CanBeGeneral and c.Attached is Planet and c.CanTakeOrders())
	_check(who != null, "one of ours can be a General")
	if who == null:
		quit(1)
		return
	var here: Planet = who.Attached
	# Alone there: everyone else of ours, and our Special Forces, elsewhere.
	var away: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p != here and p.ControllingFaction == us)
	for c: Character in GameState.ActiveRoster:
		if c != who and c.Faction == us and OrderManager.SystemOf(c.Attached) == here:
			c.Attached = away
	for u in here.SpecForces().duplicate():
		if u.Faction == us:
			here.Garrison.erase(u)
	for f in here.OrbitingFleets:
		for c: Character in GameState.ActiveRoster:
			if c.Attached == f:
				c.Attached = away
	var idle: Gid.GidMode = Gid.ModeById("idle_personnel")
	_check(idle.Magnitude.call(here) == 1.0, "%s alone at %s, no command: idle (%s)" % [who.Name, here.Name, idle.Magnitude.call(here)])

	# The Sector window, showing Idle Personnel.
	Gid.SetActiveMode(idle)
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(here))
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	var before: int = _idle_flares(ui, sector)
	_check(before >= 1, "the Sector window flares %d idle system(s), %s among them" % [before, here.Name])

	# Made General there - as the character menu does.
	var r: Result = CommandBus.issue("take_command", { "character": who.Name, "rank": Enums.Rank.General })
	_check(r.ok and who.Rank == Enums.Rank.General, "%s takes command as General (%s)" % [who.Name, r.error if not r.ok else "ok"])
	_check(idle.Magnitude.call(here) == 0.0, "a General is not idle (%s)" % idle.Magnitude.call(here))
	for _i in 3:
		await process_frame
	_check(_idle_flares(ui, sector) == before - 1, "the open Sector window drops %s's flare (%d -> %d)" % [here.Name, before, _idle_flares(ui, sector)])

	# The name with the rank before it; the post commanded, not the rank.
	var titled: String = "General " + who.Name
	_check(who.TitledName() == titled, "titled '%s'" % who.TitledName())
	var data: Dictionary = CharacterStatusWindow.StatusData(who)
	_check(str(data["name"]) == titled, "the Status window's name reads '%s'" % data["name"])
	var commanding: Array = Lq.first_or_null(data["fields"], func(r: Array) -> bool: return r[0] == "Commanding:")
	_check(commanding != null and commanding[1] == here.Name, "Commanding: %s" % (commanding[1] if commanding != null else "-"))
	ui.OnDefenseClicked(here)
	for _i in 3:
		await process_frame
	var names: Array = []
	for w in ui._openWindows.values():
		if w is DefenseWindow:
			for l in (w as Node).find_children("Name", "Label", true, false):
				names.append((l as Label).text)
	_check(names.has(titled), "the card reads '%s' (%s)" % [titled, ", ".join(names.slice(0, 6))])
	print("[idle_commanders] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The Sector window's Idle flares.
func _idle_flares(ui: UIManager, sector: Sector) -> int:
	var w: Control = ui._openWindows.get(sector.Name)
	if w == null:
		return -1
	var n := 0
	for c in w.find_children("*", "Control", true, false):
		if (c as Control).tooltip_text == "%s: Idle" % Gid.TitleFor(Gid.ActiveMode()):
			n += 1
	return n
