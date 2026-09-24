extends SceneTree
## The sector window's corner glyphs (manual p070 Fig 3.7): Manufacturing top
## left, Fleet upper right, Defenses lower left, Mission lower right, the
## uprising flame over Mission - pictures from assets/icons (or the pack's own),
## tinted with the faction colour; the mission glyph lit while a mission runs.
##
##   .\tools\run-gd.ps1 tests/corner_icons.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/corner_icons.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[corner_icons] ok   %s" % what)
	else:
		_fails += 1
		print("[corner_icons] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # the engine's own glyphs, whatever the developer imported
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

	for name in PackLoader.KNOWN_CORNER_ICONS:
		var tex: Texture2D = FactionRegistry.CornerIcon(name)
		_check(tex != null and tex.get_width() == 16 and tex.get_height() == 16, "glyph '%s' loads at 16 px (%s)" % [name, tex.resource_path if tex != null else "-"])

	# A world we hold, with a fleet in orbit and some defense: Manufacturing,
	# Fleet, Defenses, Mission corners. (The galaxy is the clock's: a world
	# with a fleet and nothing else - Duros on seed 1 - rightly has no
	# Defenses corner, so one with a defense is preferred.)
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and not p.FleetsInOrbit().is_empty() and _defended(p))
	if home == null:
		home = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
			return p.ControllingFaction == us and not p.FleetsInOrbit().is_empty())
	if home == null:
		home = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	_check(home != null, "%s holds a world (%s)" % [us.Id, home.Name if home != null else "-"])
	var corners: Dictionary = await _corners_for(ui, home)
	_check(corners.has("manufacturing"), "the manufacturing corner is drawn under %s" % home.Name)
	_check(corners.has("defenses") == _defended(home), "the defenses corner is drawn under %s exactly when it has a defense" % home.Name)
	_check(not corners.has("mission"), "no mission corner while no mission runs (TeeJ, 2026-09-23)")
	if not home.FleetsInOrbit().is_empty():
		_check(corners.has("fleet"), "the fleet corner is drawn where a fleet is in orbit")
		if corners.has("fleet"):
			_check(SectorWindow.IconTint(corners["fleet"]) == us.FactionColor, "the fleet glyph is tinted in the owner's colour")
	for name in corners:
		var btn: Button = corners[name]
		_check(btn.icon != null and btn.icon.resource_path == "res://assets/icons/%s.png" % name and btn.text.is_empty(),
			"the %s corner shows the picture, not a letter (%s)" % [name, btn.icon.resource_path if btn.icon != null else "-"])
	if corners.has("manufacturing"):
		_check(SectorWindow.IconTint(corners["manufacturing"]) == home.GetFactionColor(), "the manufacturing glyph is tinted in the world's colour")
	# The corners sit tight against the planet: an inner corner within a few
	# pixels of the original's (+-15, +-9) from the centre.
	if corners.has("manufacturing"):
		var b: Button = corners["manufacturing"]
		var pad: Vector2 = (b.size - b.icon.get_size()).max(Vector2.ZERO) / 2.0
		var inner: Vector2 = b.position + b.size - pad - _lastCentre
		_check(inner.x >= -28 and inner.x <= -14 and inner.y >= -19 and inner.y <= -8,
			"the manufacturing corner hugs the planet (inner corner %s)" % str(inner))

	# A world we know has no defenses shows no Defenses corner.
	var bare: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and not _defended(p))
	if bare != null:
		_check(not (await _corners_for(ui, bare)).has("defenses"), "no Defenses corner on %s, which has none" % bare.Name)

	# A mission of ours lights the mission glyph in our colour.
	var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.Attached == home and c.CanTakeOrders() and not MissionManager.IsOnMissionTeam(c))
	if agent != null:
		var m: Mission = MissionManager.Launch(Enums.MissionType.Diplomacy, [agent], home, home)
		_check(m != null, "%s runs a mission at %s" % [agent.Name, home.Name])
		var lit: Dictionary = await _corners_for(ui, home)
		if lit.has("mission"):
			var tint: Color = SectorWindow.IconTint(lit["mission"])
			_check(tint == us.FactionColor, "the mission glyph is lit in our colour while the mission runs")

	# An uprising we have seen shows the flame in the mission corner.
	var seen: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and p != home and p.IsInhabited)
	if seen != null:
		seen.IsInUprising = true
		var flame: Dictionary = await _corners_for(ui, seen)
		_check(flame.has("uprising") and not flame.has("mission"), "an uprising puts the flame in the mission corner")
		if flame.has("uprising"):
			_check(SectorWindow.IconTint(flame["uprising"]) == SectorWindow.CUprising, "the flame has its own hot tint")
		seen.IsInUprising = false

	# An unexplored world: only the mission corner, and only for our own mission there.
	var dark: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return not p.ExploredBy(us))
	if dark != null:
		_check((await _corners_for(ui, dark)).is_empty(), "no corner glyphs on an unexplored world")

	print("[corner_icons] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


var _lastCentre: Vector2 = Vector2.ZERO


## Any defense on a world: troops, fighters, Special Forces, a character, or
## a defensive facility.
func _defended(p: Planet) -> bool:
	return not (p.Troopers().is_empty() and p.FighterSquadrons.is_empty() and p.SpecForces().is_empty() \
		and not Lq.any(GameState.ActiveRoster, func(c: Character) -> bool: return c.Attached == p and not c.IsOffMap()) \
		and not Lq.any(p.Facilities, func(f: Facility) -> bool: return IntelManager.IsDefensive(f)))

## Opens the planet's sector window and returns its corner buttons by glyph name.
func _corners_for(ui: UIManager, planet: Planet) -> Dictionary:
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))
	var w: DraggableWindow = _window_titled(ui, sector.Name)
	if w != null:
		w.CloseWindow()
		for _i in 2:
			await process_frame
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	w = _window_titled(ui, sector.Name)
	var map: Control = w.get_node("%SectorMap")
	var btn: Control = Lq.first_or_null(map.get_children(), func(c) -> bool: return c is SectorWindow.PlanetMapButton and c.AssociatedPlanet == planet)
	var centre: Vector2 = btn.position + Vector2(16, 16)
	var out := {}
	for c in map.get_children():
		if c is Button and c.has_meta("corner") and (c.position + c.size / 2.0).distance_to(centre) < 40:
			out[c.get_meta("corner")] = c
	_lastCentre = centre
	return out


static func _window_titled(ui: Node, title: String) -> DraggableWindow:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
