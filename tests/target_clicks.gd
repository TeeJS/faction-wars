extends SceneTree
## PICKING A SYSTEM WITH THE CROSSHAIRS IN THE SECTOR WINDOW. "Click on the
## system's icon in that system's Sector window" (manual p102 TIP); "Click on
## the system where you want a new facility" (manual p087).
##
## The original's corner icons are 27x19 quadrant cells laid with their inner
## corner on the system's centre (SectorWindow._PlaceCorner), so they COVER the
## planet's picture - and a click on the picture landed on an icon, which opened
## its own window and never named the system (TeeJ, 2026-09-23: "the cursor
## seems to try and select the icons 1st"). While a target is being picked,
## every part of a system's entry - picture, corner icons, star, bars, name -
## names that system. Outside targeting the icons still open their windows, and
## object targeting inside a system's windows is untouched.
##
## Real clicks, pushed through the viewport, so the GUI decides what is hit;
## an icon is clicked on its drawn pixels, read from its picture (the rest
## of its cell belongs to what is under it - tests/corner_masks.gd).
##
##   .\tools\run-gd.ps1 tests/target_clicks.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/target_clicks.gd              (Star Wars)

var _fails := 0
var _checks := 0

## What the crosshair named: the system (onTargetSelected) or an object.
var _picked: Planet = null
var _pickedObject: Variant = null

const WindowFor := {
	"manufacturing": " Economy", "defenses": " Defenses", "fleet": " Fleets",
	"mission": " Missions", "uprising": " Missions",
}


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[target_clicks] ok   %s" % what)
	else:
		_fails += 1
		print("[target_clicks] FAIL %s" % what)


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

	# A world of ours with its Manufacturing and Defenses icons drawn, and a
	# fleet in orbit if the start has one - as many icons round the picture as
	# there can be.
	var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and SectorWindow._KnownManufacturing(us, p) and SectorWindow._KnownDefenses(us, p))
	var home: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return not p.FleetsInOrbit().is_empty())
	if home == null and not ours.is_empty():
		home = ours[0]
	_check(home != null, "%s holds a world with Manufacturing and Defenses icons (%s)" % [us.Id, home.Name if home != null else "-"])
	if home == null:
		quit(1)
		return

	# --- 1. THE REPORT: a click on the picture where an icon's cell covers it. ---
	var w: SectorWindow = await _open_sector(ui, home)
	var parts: Dictionary = _parts(w, home)
	var pic: Rect2 = parts["picture"]
	# Read now, while this window's buttons exist: every step below reopens it.
	var glyphs: Dictionary = {}   # icon -> a point in the middle of its drawn pixels
	for corner in parts["corner_buttons"]:
		var g: Variant = _glyph_point(parts["corner_buttons"][corner])
		_check(g != null, "the %s icon has drawn pixels to click (%s)" % [corner, str(g)])
		if g != null:
			glyphs[corner] = g
	var covered: Dictionary = {}   # icon -> a point on the picture that the icon's cell covers
	for corner in parts["corners"]:
		var overlap: Rect2 = pic.intersection(parts["corners"][corner])
		if overlap.get_area() >= 1.0:
			covered[corner] = overlap.get_center()
	print("[target_clicks] %s: picture %s; icons %s; covering the picture: %s" % [home.Name, str(pic), str(parts["corners"]), str(covered.keys())])
	_check(not covered.is_empty(), "at least one corner icon's cell covers part of %s's picture (the regression's precondition)" % home.Name)
	for corner in covered:
		w = await _open_sector(ui, home)
		_aim(ui)
		var hit: String = await _click(w, covered[corner])
		_check(_picked == home and not ui.IsTargeting and _opened(ui, home).is_empty(),
			"a crosshair click on %s's picture where the %s icon's cell covers it names the system (under the pointer: %s; picked %s; opened %s)" \
				% [home.Name, corner, hit, _picked.Name if _picked != null else "nothing", str(_opened(ui, home))])

	# --- 2. EVERY PART OF THE SYSTEM'S ENTRY names it while the crosshair is up. ---
	var spots: Dictionary = {}   # what -> map point
	spots["the picture's centre"] = pic.get_center()
	for corner in glyphs:
		spots["the %s icon" % corner] = glyphs[corner]
	for kind in parts["bars"]:
		spots["the %s bar" % kind] = (parts["bars"][kind] as Rect2).get_center()
	_check(parts.has("name") and parts["bars"].size() >= 2, "the entry has its name and its bars (bars %s)" % str(parts["bars"].keys()))
	if parts.has("name"):
		spots["the name"] = (parts["name"] as Rect2).get_center()
	if parts.has("star"):
		spots["the GID star"] = (parts["star"] as Rect2).get_center()
	for what in spots:
		w = await _open_sector(ui, home)
		_aim(ui)
		var hit: String = await _click(w, spots[what])
		_check(_picked == home and not ui.IsTargeting and _opened(ui, home).is_empty(),
			"a crosshair click on %s names %s (under the pointer: %s; picked %s; opened %s)" \
				% [what, home.Name, hit, _picked.Name if _picked != null else "nothing", str(_opened(ui, home))])

	# --- 3. Blank space in the sector window names nothing; the crosshair stays up. ---
	w = await _open_sector(ui, home)
	var blank: Variant = _blank_spot(w)
	_check(blank != null, "the sector map has a blank spot to click")
	if blank != null:
		_aim(ui)
		var hit: String = await _click(w, blank)
		_check(_picked == null and ui.IsTargeting, "a crosshair click on blank space names nothing and the crosshair stays up (under the pointer: %s)" % hit)
		ui.CancelTargeting()

	# --- 4. Outside targeting the icons still open their own windows. ---
	for corner in glyphs:
		w = await _open_sector(ui, home)
		var hit: String = await _click(w, glyphs[corner])
		var title: String = home.Name + WindowFor.get(corner, "?")
		_check(_opened(ui, home).has(title) and _picked == null, "outside targeting the %s icon still opens '%s' (under the pointer: %s; opened %s)" % [corner, title, hit, str(_opened(ui, home))])

	# --- 5. Object targeting inside a system's window is untouched. ---
	# One of our people standing on a world, clicked in its System Defenses
	# window with the crosshair up, is the object (manual p040, p102).
	var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
		return c.Faction == us and c.Attached is Planet and not c.IsOffMap())
	_check(agent != null, "%s has someone standing on a world (%s)" % [us.Id, agent.Name if agent != null else "-"])
	if agent != null:
		var world: Planet = agent.Attached
		ui.CancelTargeting()
		ui.CloseAllWindows()
		for _i in 2:
			await process_frame
		ui.OnDefenseClicked(world)
		for _i in 3:
			await process_frame
		var dw: DraggableWindow = _window_titled(ui, world.Name + " Defenses")
		var row: CharacterMenuButton = null
		if dw != null:
			for c in dw.find_children("*", "", true, false):
				if c is CharacterMenuButton and (c as CharacterMenuButton).CharacterData == agent:
					row = c
					break
		_check(row != null, "%s is listed in %s's System Defenses window" % [agent.Name, world.Name])
		if row != null:
			_aim_object(ui)
			var how := "clicked"
			if row.is_visible_in_tree():
				await _press_at(row.get_global_transform_with_canvas() * (row.size / 2.0))
			else:
				how = "toggled (its tab is not showing)"
				row.toggled.emit(true)
			_check(_pickedObject == agent and _picked == null and not ui.IsTargeting,
				"object targeting: %s, %s in the System Defenses window, is picked as the object" % [agent.Name, how])
	w = await _open_sector(ui, home)
	_aim_object(ui)
	var at: Vector2 = covered.values()[0] if not covered.is_empty() else pic.get_center()
	var objHit: String = await _click(w, at)
	_check(_picked == home and _pickedObject == null and not ui.IsTargeting,
		"object targeting: a click on %s's picture names the system itself (under the pointer: %s)" % [home.Name, objHit])

	# --- 6. From the galaxy map: the region opens its theatre with the crosshair still up. ---
	ui.CancelTargeting()
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame
	var galaxy: GalaxyMap = main.get_node("GalaxyMap")
	_aim(ui)
	(galaxy.RegionButtons()[home] as Button).pressed.emit()
	for _i in 3:
		await process_frame
	var sw: SectorWindow = _window_titled(ui, _sector_of(home).Name) as SectorWindow
	_check(sw != null and ui.IsTargeting and _picked == null,
		"a crosshair click on %s's region on the galaxy map opens its theatre and keeps the crosshair up" % home.Name)
	if sw != null:
		sw.move_to_front()
		await process_frame
		var mapHit: String = await _click(sw, at)
		_check(_picked == home and not ui.IsTargeting, "...and a click on %s's picture there names the system (under the pointer: %s)" % [home.Name, mapHit])
	ui.CancelTargeting()
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame

	print("[target_clicks] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _aim(ui: UIManager) -> void:
	_picked = null
	_pickedObject = null
	ui.StartTargeting(func(p: Planet) -> void: _picked = p)


func _aim_object(ui: UIManager) -> void:
	_picked = null
	_pickedObject = null
	ui.StartTargetingObject(func(p: Planet) -> void: _picked = p, func(o: Variant) -> void: _pickedObject = o)


## `planet`'s sector window, opened afresh with nothing else on screen.
func _open_sector(ui: UIManager, planet: Planet) -> SectorWindow:
	ui.CancelTargeting()
	ui.CloseAllWindows()
	for _i in 2:
		await process_frame
	_picked = null
	_pickedObject = null
	ui.OnSectorClicked(_sector_of(planet))
	for _i in 3:
		await process_frame
	var w: SectorWindow = _window_titled(ui, _sector_of(planet).Name) as SectorWindow
	w.move_to_front()
	await process_frame
	return w


## A left click at a point of the window's sector map, pushed through the
## viewport as the mouse would send it. Returns what the GUI had under the
## pointer, named before the click (a click can repaint the map).
func _click(w: SectorWindow, local: Vector2) -> String:
	var map: Control = w.get_node("%SectorMap")
	return await _press_at(map.get_global_transform_with_canvas() * local)


## A left click at a viewport point. The pointer is moved, then moved again
## with the press and the release in the same frame: StartTargeting's cursor
## change makes Input send a motion of its own at ITS idea of the pointer,
## which headless is not where these pushes put it, and landing between them
## it would un-hover the button.
func _press_at(at: Vector2) -> String:
	_push_motion(at)
	await process_frame
	_push_motion(at)
	var over: String = _describe(root.gui_get_hovered_control())
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		b.position = at
		b.global_position = at
		root.push_input(b, true)
	for _i in 2:
		await process_frame
	return over


func _push_motion(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)


static func _describe(c: Control) -> String:
	if c == null:
		return "nothing"
	if c.name == "SectorMap":
		return "blank map"
	if c is SectorWindow.PlanetMapButton:
		return "the picture"
	if c.has_meta("corner"):
		return "the %s icon" % c.get_meta("corner")
	if c.has_meta("bar_row"):
		return "the %s bar" % c.get_meta("bar_row")
	return "%s '%s'" % [c.get_class(), c.name]


## Map-local rectangles of what the window drew for `planet`.
func _parts(w: SectorWindow, planet: Planet) -> Dictionary:
	var map: Control = w.get_node("%SectorMap")
	var kids: Array = Lq.where(map.get_children(), func(c) -> bool: return c is Control and not c.is_queued_for_deletion())
	var btn: Control = Lq.first_or_null(kids, func(c) -> bool: return c is SectorWindow.PlanetMapButton and c.AssociatedPlanet == planet)
	var pic := Rect2(btn.position, btn.size)
	var centre: Vector2 = pic.get_center()
	var star_at: Vector2 = centre + Vector2(-SectorWindow.StarOffsetX, SectorWindow.StarOffsetY)
	var out := {"picture": pic, "corners": {}, "corner_buttons": {}, "bars": {}}
	for c in kids:
		var r := Rect2(c.position, c.size)
		if c is Button and c.has_meta("corner") and r.get_center().distance_to(centre) < 40:
			out["corners"][c.get_meta("corner")] = r
			out["corner_buttons"][c.get_meta("corner")] = c
		elif c.has_meta("bar_row") and absf(c.position.x - (centre.x - SectorWindow.BarsLeft)) < 0.5 \
				and c.position.y > centre.y and c.position.y < centre.y + 80:
			out["bars"][c.get_meta("bar_row")] = r
		elif c is Label and c.text == planet.Name:
			out["name"] = r
		elif (c.has_meta("gid_star") or (c is Label and c.text == "+")) and r.get_center().distance_to(star_at) < 2.0:
			out["star"] = r
	return out


## A sector-map point in the middle of an icon's drawn pixels, read from its
## picture: drawn at its own size and centred in the button (a Button with no
## text and expand_icon off), the drawn pixel with drawn pixels all round it
## nearest their centroid (any drawn pixel, if none has). Null when the
## picture cannot be read or draws nothing.
static func _glyph_point(btn: Button) -> Variant:
	var img: Image = btn.icon.get_image() if btn.icon != null else null
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	var drawn: Vector2 = btn.icon.get_size()
	var origin: Vector2 = btn.position + ((btn.size - drawn) / 2.0).floor()
	var solid: Array = []
	var sum := Vector2.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				solid.append(Vector2i(x, y))
				sum += Vector2(x, y)
	if solid.is_empty():
		return null
	var centroid: Vector2 = sum / solid.size()
	for inner in [true, false]:
		var best: Variant = null
		var bestD: float = INF
		for px: Vector2i in solid:
			if inner and not _surrounded(img, px):
				continue
			var d: float = centroid.distance_to(Vector2(px))
			if d < bestD:
				best = px
				bestD = d
		if best != null:
			return origin + (Vector2(best) + Vector2(0.5, 0.5)) * drawn / Vector2(img.get_size())
	return null


static func _surrounded(img: Image, px: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q: Vector2i = px + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height() or img.get_pixel(q.x, q.y).a < 0.5:
				return false
	return true


## A point of the sector map that nothing is drawn on, or null.
func _blank_spot(w: SectorWindow) -> Variant:
	var map: Control = w.get_node("%SectorMap")
	var s: Vector2 = map.size
	for p in [Vector2(3, 3), Vector2(s.x - 4, 3), Vector2(3, s.y - 4), Vector2(s.x - 4, s.y - 4)]:
		var free := true
		for c in map.get_children():
			if c is Control and not c.is_queued_for_deletion() and Rect2(c.position, c.size).has_point(p):
				free = false
				break
		if free:
			return p
	return null


## The windows open on `planet` (its System window and the four the icons
## open), by title. The sector window itself is not counted.
static func _opened(ui: UIManager, planet: Planet) -> Array:
	var out: Array = []
	for c in ui.get_children():
		if c is DraggableWindow and not (c is SectorWindow) and not c.is_queued_for_deletion() \
				and (c.WindowTitle == planet.Name or c.WindowTitle.begins_with(planet.Name + " ")):
			out.append(c.WindowTitle)
	return out


static func _sector_of(planet: Planet) -> Sector:
	return Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))


static func _window_titled(ui: Node, title: String) -> DraggableWindow:
	for c in ui.get_children():
		if c is DraggableWindow and not c.is_queued_for_deletion() and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
