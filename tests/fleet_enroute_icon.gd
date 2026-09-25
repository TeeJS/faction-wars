extends SceneTree
## A fleet of ours on its way to a system shows on the map while in transit
## (TeeJ, 2026-09-24: "I moved a fleet from Coruscant to Yaga Minor - it did
## not show up until it arrived"): the destination's fleet corner carries our
## fleet icon with the arrival day, and opens its Fleet window; an opponent's
## inbound fleet does not show (fog).
##
## THE SAME ICON AS IN ORBIT, never the hyperspace picture, before or after a
## mouse-over (TeeJ, 2026-09-24: it flipped between the two - "The original
## just always shows the same icon at the planet"). Writes and removes its own
## test art, never the player's own.
##
##   .\tools\run-gd.ps1 tests/fleet_enroute_icon.gd

const Art := preload("res://src/ui/artwork.gd")

const FleetColor := Color(0, 1, 0)
const HoverColor := Color(1, 1, 1)
const HyperspaceColor := Color(0, 0, 1)
const MissionColor := Color(1, 0, 0)

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[fleet_enroute_icon] ok   %s" % what)
	else:
		_fails += 1
		print("[fleet_enroute_icon] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # only what this test writes counts
	Art.UserArtRoot = "user://test-fleet-enroute"
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

	# The corner pictures, as plain test pictures where an imported art set
	# lives: the fleet icon, its hover, the hyperspace one, and a mission icon
	# with no hover picture.
	var sets: Array = FactionRegistry.Pack.Manifest.ArtSets
	var dir := "%s/%s/icons" % [Art.UserArtRoot, sets[0] if not sets.is_empty() else "swr-original"]
	DirAccess.make_dir_recursive_absolute(dir)
	_png("%s/fleet.%s.png" % [dir, us.ArtSkin], FleetColor)
	_png("%s/fleet.%s.hover.png" % [dir, us.ArtSkin], HoverColor)
	_png("%s/enroute.%s.png" % [dir, us.ArtSkin], HyperspaceColor)
	_png("%s/mission.%s.png" % [dir, us.ArtSkin], MissionColor)
	Art.Reset()

	# A corner drawn twice keeps only the second picture's hover: the first
	# one's hooks used to put its picture back on the next mouse-over.
	var twice := Button.new()
	root.add_child(twice)
	SectorWindow._OriginalIcon(twice, "fleet", us.Id, 1.0)
	SectorWindow._OriginalIcon(twice, "mission", us.Id, 1.0)
	twice.mouse_entered.emit()
	twice.mouse_exited.emit()
	_check(_color(twice) == MissionColor, "a corner drawn twice keeps the second picture after a mouse-over")
	twice.free()

	var fleet: Fleet = null
	var from: Planet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if fleet == null and f.Faction == us and not f.Ships.is_empty():
				fleet = f
				from = p
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(from))
	# An UNCHARTED one when there is one: ours on the way show there too (it
	# passed only by luck before, on a charted world).
	var free: Array = Lq.where(sector.Planets, func(p: Planet) -> bool:
		return p != from and not Lq.any(p.OrbitingFleets, func(f: Fleet) -> bool: return f.Faction == us))
	var to: Planet = Lq.first_or_null(free, func(p: Planet) -> bool: return not p.IsExplored)
	if to == null:
		to = Lq.first_or_null(free, func(_p: Planet) -> bool: return true)
	_check(fleet != null and to != null, "a fleet of ours and a world in its sector with none of ours")
	if fleet == null or to == null:
		_finish()
		return
	ui.ExecuteSingleFleetMove(fleet, to, false)
	await process_frame
	_check(fleet.Status == Enums.Status.Enroute and fleet.Destination == to, "the fleet is on its way to %s" % to.Name)

	var icon: Button = await _fleet_corner(ui, sector, to)
	_check(icon != null and icon.get_meta("corner", "") == "fleet", "the destination's fleet corner shows it on the way")
	_check(icon != null and _color(icon) == FleetColor, "with our fleet icon, not the hyperspace picture")
	if icon != null:
		icon.mouse_entered.emit()
		_check(_color(icon) == HoverColor, "a mouse-over shows the fleet icon's own hover picture")
		icon.mouse_exited.emit()
		_check(_color(icon) == FleetColor, "and leaving puts the same fleet icon back")
	_check(icon != null and icon.tooltip_text.contains(fleet.Name) and icon.tooltip_text.contains("arrives day"),
		"its tooltip names the fleet and the arrival day ('%s')" % (icon.tooltip_text if icon != null else ""))
	if icon != null:
		icon.pressed.emit()
		for _i in 3:
			await process_frame
		var w: FleetWindow = Lq.first_or_null(ui.get_children(), func(n: Node) -> bool: return n is FleetWindow)
		_check(w != null, "clicking it opens the destination's Fleet window")

	# An opponent's inbound fleet does not show: the corner reads as it did.
	# (Its name is no test - each side numbers its own, so both have a
	# "Fleet 1".)
	var ours_only: String = icon.tooltip_text if icon != null else ""
	var enemy: Fleet = null
	for p in GameState.AllPlanets():
		for f in p.OrbitingFleets:
			if enemy == null and f.Faction != null and f.Faction != us and not f.Ships.is_empty():
				enemy = f
	if enemy != null:
		(enemy.Attached as Planet).OrbitingFleets.erase(enemy)
		to.OrbitingFleets.append(enemy)
		enemy.Attached = to
		enemy.Destination = to
		enemy.Status = Enums.Status.Enroute
		enemy.DaysToDestination = 5
		icon = await _fleet_corner(ui, sector, to)
		_check(icon != null and icon.tooltip_text == ours_only, "an opponent's inbound fleet is not shown ('%s')" % (icon.tooltip_text if icon != null else ""))
	_finish()


## The fleet corner by the system's planet, the sector window reopened.
func _fleet_corner(ui: UIManager, sector: Sector, planet: Planet) -> Button:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == sector.Name:
			(c as DraggableWindow).CloseWindow()
	for _i in 2:
		await process_frame
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == sector.Name:
			var map: Control = c.get_node("%SectorMap")
			var btn: Control = Lq.first_or_null(map.get_children(), func(n) -> bool: return n is SectorWindow.PlanetMapButton and n.AssociatedPlanet == planet)
			var best: Button = null
			var near := 80.0
			for n in map.get_children():
				if n is Button and str(n.get_meta("corner", "")) == "fleet":
					var d: float = (n.position + n.size / 2.0).distance_to(btn.position + btn.size / 2.0)
					if d < near:
						near = d
						best = n
			return best
	return null


## The colour of the picture a button shows now (the test pictures are flat).
static func _color(btn: Button) -> Color:
	if btn.icon == null:
		return Color.TRANSPARENT
	return btn.icon.get_image().get_pixel(0, 0)


func _finish() -> void:
	_remove(Art.UserArtRoot)
	Art.Reset()
	print("[fleet_enroute_icon] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, color: Color) -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
