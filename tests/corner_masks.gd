extends SceneTree
## A SECTOR-WINDOW CORNER ICON TAKES THE MOUSE ONLY ON ITS DRAWN PIXELS
## (SectorWindow.CornerButton).
##
## The original's corner icons are quadrant cells laid with their inner corner
## on the system's centre (SectorWindow._PlaceCorner): the glyph is drawn in
## the cell's outer corner and the transparent rest lies over the planet's
## picture. Whole-rectangle buttons took every click, hover and drop meant for
## the planet under them. Real mouse events, pushed through the viewport, so
## the GUI itself decides what is under the pointer:
##   1. outside targeting, a click on the planet's visible pixels where no
##      glyph pixel is drawn opens the System window; a click on a glyph opens
##      that icon's window;
##   2. the hover follows the drawn pixels: an icon lights only over them;
##   3. a character dragged onto the planet there is dropped on the planet (the
##      PlanetMapButton's drop handler), and the planet there takes a dragged
##      unit or fleet as well.
## What is drawn where is read from the pictures themselves (their alpha), not
## from the masks under test.
##
##   .\tools\run-gd.ps1 tests/corner_masks.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/corner_masks.gd              (Star Wars)

var _fails := 0
var _checks := 0

const WindowFor := {
	"manufacturing": " Economy", "defenses": " Defenses", "fleet": " Fleets",
	"mission": " Missions", "uprising": " Missions",
}


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[corner_masks] ok   %s" % what)
	else:
		_fails += 1
		print("[corner_masks] FAIL %s" % what)


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

	# A world of ours with its Manufacturing and Defenses icons drawn (a fleet
	# in orbit too if the start has one), and someone of ours on another world
	# to drag onto it.
	var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool:
		return p.ControllingFaction == us and SectorWindow._KnownManufacturing(us, p) and SectorWindow._KnownDefenses(us, p))
	ours.sort_custom(func(a: Planet, b: Planet) -> bool: return a.FleetsInOrbit().size() > b.FleetsInOrbit().size())
	var home: Planet = null
	var agent: Character = null
	for p: Planet in ours:
		agent = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
			return c.Faction == us and c.Attached is Planet and c.Attached != p and c.CanTakeOrders() \
				and c.Status != Enums.Status.Enroute and not c.IsOffMap() and not MissionManager.IsOnMissionTeam(c))
		if agent != null:
			home = p
			break
	_check(home != null, "%s holds a world with Manufacturing and Defenses icons, and has someone free on another world (%s; %s)" \
		% [us.Id, home.Name if home != null else "-", agent.Name if agent != null else "-"])
	if home == null:
		quit(1)
		return

	# Where things are drawn, read once from the first window (the layout is
	# the same every time the window is opened; points are sector-map points).
	var w: SectorWindow = await _open_sector(ui, home)
	var s: Dictionary = _scene(w, home)
	var corners: Dictionary = s["corners"]
	print("[corner_masks] %s: picture %s; icons %s" % [home.Name, str(Rect2(s["pic"].position, s["pic"].size)),
		str(Lq.select(corners.keys(), func(k) -> String: return "%s %s %s" % [k, str(Rect2(corners[k].position, corners[k].size)),
			(corners[k] as Button).icon.resource_path.get_file()]))])
	var bare: Variant = _bare_point(s["pic"], corners)
	_check(bare != null, "there is a point on %s's picture, inside an icon's cell, where no glyph pixel is drawn (%s)" \
		% [home.Name, ("%s, in the %s icon's cell" % [str(bare["at"]), bare["cell"]]) if bare != null else "none"])
	var glyphs: Dictionary = {}   # icon -> a map point in the middle of its drawn pixels
	for name in corners:
		var g: Variant = _glyph_point(corners[name])
		_check(g != null, "the %s icon has drawn pixels to click (%s)" % [name, str(g)])
		if g != null:
			glyphs[name] = g

	# --- 1. Outside targeting: the picture where no glyph is drawn, and each glyph. ---
	if bare != null:
		w = await _open_sector(ui, home)
		var over: String = await _click(w, bare["at"])
		_check(_opened(ui, home) == [home.Name],
			"a click on %s's picture where the %s icon's cell lies but no glyph is drawn opens the System window (under the pointer: %s; opened %s)" \
				% [home.Name, bare["cell"], over, str(_opened(ui, home))])
	for name in glyphs:
		w = await _open_sector(ui, home)
		var over: String = await _click(w, glyphs[name])
		var title: String = home.Name + WindowFor.get(name, "?")
		_check(_opened(ui, home) == [title], "a click on the %s glyph opens '%s' (under the pointer: %s; opened %s)" % [name, title, over, str(_opened(ui, home))])

	# --- 2. The hover follows the drawn pixels. ---
	# (The window's controls are read after the pointer settles, in the same
	# frame: a repaint in between would have replaced them.)
	if bare != null:
		w = await _open_sector(ui, home)
		var over: Control = await _hover(w, bare["at"])
		s = _scene(w, home)
		var cell: Button = s["corners"][bare["cell"]]
		_check(s["pic"].is_hovered() and not cell.is_hovered(),
			"the pointer on the picture there is over the planet, not the %s icon (under the pointer: %s)" % [bare["cell"], _describe(over)])
		if cell.has_meta("original_icon"):
			_check(not cell.icon.resource_path.ends_with(".hover.png"),
				"...and the %s icon keeps its plain picture (%s)" % [bare["cell"], cell.icon.resource_path.get_file()])
	for name in glyphs:
		w = await _open_sector(ui, home)
		var over: Control = await _hover(w, glyphs[name])
		s = _scene(w, home)
		var b: Button = s["corners"][name]
		_check(b.is_hovered() and not s["pic"].is_hovered(), "the pointer on the %s glyph lights that icon (under the pointer: %s)" % [name, _describe(over)])
		if b.has_meta("original_icon"):
			_check(b.icon.resource_path.ends_with(".hover.png"),
				"...showing the original's hover picture (%s)" % b.icon.resource_path.get_file())

	# --- 3. Dropping onto the picture there reaches the planet's drop handler. ---
	if bare != null:
		w = await _open_sector(ui, home)
		var over: Control = await _hover(w, bare["at"])
		s = _scene(w, home)
		var target: Control = over if over != null else _hovered_button(s)
		var local: Vector2 = target.get_global_transform_with_canvas().affine_inverse() \
			* (s["map"].get_global_transform_with_canvas() * bare["at"]) if target != null else Vector2.ZERO
		var unit: Unit = null
		var fleet: Fleet = null
		for p: Planet in GameState.AllPlanets():
			if p.ControllingFaction != us:
				continue
			for u: Unit in p.Troopers() + p.FighterSquadrons:
				if unit == null and u.Status != Enums.Status.Enroute:
					unit = u
			for f: Fleet in p.FleetsInOrbit():
				if fleet == null and f.Faction == us and f.Status != Enums.Status.Enroute:
					fleet = f
		_check(unit != null and fleet != null, "%s has a unit and a fleet to drag (%s; %s)" % [us.Id, unit.Name if unit != null else "-", fleet.Name if fleet != null else "-"])
		if unit != null:
			ui.StartUnitDrag([unit])
			_check(_accepts(target, local, "unit_move"), "a unit dragged over %s's picture there is taken (by %s)" % [home.Name, _describe(target)])
			ui.EndUnitDrag()
		if fleet != null:
			ui.StartFleetDrag([fleet])
			_check(_accepts(target, local, "fleet_move"), "a fleet dragged over %s's picture there is taken (by %s)" % [home.Name, _describe(target)])
			ui.EndFleetDrag()
		# The character, dropped for real: the GUI finds the drop target.
		var from: Planet = agent.Attached
		ui.StartCharacterDrag([agent])
		(s["map"] as Control).force_drag("character_move", Label.new())
		await _drop(w, bare["at"])
		_check(agent.Status == Enums.Status.Enroute and agent.Destination == home,
			"%s, dragged from %s and dropped on %s's picture there, is on the way to it (status %s, destination %s)" \
				% [agent.Name, from.Name, home.Name, Enums.Status.keys()[agent.Status], agent.Destination.Name if agent.Destination != null else "none"])
		ui.EndCharacterDrag()

	ui.CloseAllWindows()
	for _i in 2:
		await process_frame
	print("[corner_masks] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Whether a control would take this drag: the planet's own drop handler, or
## nothing for a control without one.
static func _accepts(c: Control, at: Vector2, kind: String) -> bool:
	return c != null and c.has_method("_can_drop_data") and c._can_drop_data(at, kind)


## `planet`'s sector window, opened afresh with nothing else on screen and
## the pointer well away from it.
func _open_sector(ui: UIManager, planet: Planet) -> SectorWindow:
	ui.CancelTargeting()
	ui.CloseAllWindows()
	_push_motion(Vector2(2, 2))
	for _i in 2:
		await process_frame
	ui.OnSectorClicked(_sector_of(planet))
	for _i in 3:
		await process_frame
	var w: SectorWindow = _window_titled(ui, _sector_of(planet).Name) as SectorWindow
	w.move_to_front()
	await process_frame
	return w


## The window's picture button and corner icons for `planet`.
static func _scene(w: SectorWindow, planet: Planet) -> Dictionary:
	var map: Control = w.get_node("%SectorMap")
	var kids: Array = Lq.where(map.get_children(), func(c) -> bool: return c is Control and not c.is_queued_for_deletion())
	var pic: Button = Lq.first_or_null(kids, func(c) -> bool: return c is SectorWindow.PlanetMapButton and c.AssociatedPlanet == planet)
	var centre: Vector2 = pic.position + pic.size / 2.0
	var corners := {}
	for c in kids:
		if c is Button and c.has_meta("corner") and (c.position + c.size / 2.0).distance_to(centre) < 40:
			corners[c.get_meta("corner")] = c
	return {"map": map, "pic": pic, "corners": corners}


## Moves the pointer to a sector-map point and returns the control the GUI
## has under it. Moved twice, a frame apart: a cursor-shape change makes Input
## send a motion of its own at its idea of the pointer, which headless is not
## where these pushes put it.
func _hover(w: SectorWindow, local: Vector2) -> Control:
	var at: Vector2 = (w.get_node("%SectorMap") as Control).get_global_transform_with_canvas() * local
	_push_motion(at)
	await process_frame
	_push_motion(at)
	return root.gui_get_hovered_control()


## A left click at a sector-map point; returns what the GUI had under it
## (named at once: the window repaints its map when a click changes what it
## shows, and frees the old controls).
func _click(w: SectorWindow, local: Vector2) -> String:
	var over: String = _describe(await _hover(w, local))
	var at: Vector2 = (w.get_node("%SectorMap") as Control).get_global_transform_with_canvas() * local
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


## Ends a drag already under way by letting go at a sector-map point.
func _drop(w: SectorWindow, local: Vector2) -> void:
	await _hover(w, local)
	var at: Vector2 = (w.get_node("%SectorMap") as Control).get_global_transform_with_canvas() * local
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = false
	b.position = at
	b.global_position = at
	root.push_input(b, true)
	for _i in 2:
		await process_frame


func _push_motion(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)


static func _hovered_button(s: Dictionary) -> Control:
	if (s["pic"] as Button).is_hovered():
		return s["pic"]
	for name in s["corners"]:
		if (s["corners"][name] as Button).is_hovered():
			return s["corners"][name]
	return null


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


# ---- What is drawn where, read from the pictures ----

static var _images: Dictionary = {}

static func _image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var key: int = tex.get_instance_id()
	if not _images.has(key):
		var img: Image = tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_images[key] = img if img != null and not img.is_empty() else null
	return _images[key]


## The alpha a corner icon draws at a sector-map point: its picture's pixel
## there, drawn at its own size and centred in the button (a Button with no
## text and expand_icon off); 0 on the padding round it or off the button.
static func _icon_alpha(btn: Button, at: Vector2) -> float:
	if not Rect2(btn.position, btn.size).has_point(at):
		return 0.0
	var img: Image = _image(btn.icon)
	if img == null:
		return 1.0   # unreadable: count the whole button as drawn
	var drawn: Vector2 = btn.icon.get_size()
	var p: Vector2 = at - btn.position - ((btn.size - drawn) / 2.0).floor()
	if p.x < 0 or p.y < 0 or p.x >= drawn.x or p.y >= drawn.y:
		return 0.0
	return img.get_pixel(int(p.x * img.get_width() / drawn.x), int(p.y * img.get_height() / drawn.y)).a


## The planet's own picture at a sector-map point: the original's sprite
## where it is drawn (expand_icon: fitted to the button inside its ring's
## border, centred), else the coloured disc of radius 16.
static func _planet_alpha(pic: Button, at: Vector2) -> float:
	var p: Vector2 = at - pic.position
	if not pic.has_meta("sprite") or pic.icon == null:
		return 1.0 if p.distance_to(pic.size / 2.0) <= 15.5 else 0.0
	var style: StyleBox = pic.get_theme_stylebox("normal")
	var tl := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	var box: Vector2 = pic.size - tl - Vector2(style.get_margin(SIDE_RIGHT), style.get_margin(SIDE_BOTTOM))
	var tex: Vector2 = pic.icon.get_size()
	var k: float = minf(box.x / tex.x, box.y / tex.y)
	var origin: Vector2 = tl + ((box - tex * k) / 2.0).floor()
	var q: Vector2 = (p - origin) / k
	if q.x < 0 or q.y < 0 or q.x >= tex.x or q.y >= tex.y:
		return 0.0
	var img: Image = _image(pic.icon)
	if img == null:
		return 1.0 if p.distance_to(pic.size / 2.0) <= 8.0 else 0.0
	return img.get_pixel(int(q.x * img.get_width() / tex.x), int(q.y * img.get_height() / tex.y)).a


## A point of the planet's visible picture inside some icon's cell where no
## icon draws anything - with a pixel's margin all round - nearest the
## planet's centre, as {at, cell}. Null when there is none.
static func _bare_point(pic: Button, corners: Dictionary) -> Variant:
	var centre: Vector2 = pic.position + pic.size / 2.0
	var best: Variant = null
	var bestD: float = INF
	for y in range(int(pic.position.y), int(pic.position.y + pic.size.y)):
		for x in range(int(pic.position.x), int(pic.position.x + pic.size.x)):
			var p := Vector2(x + 0.5, y + 0.5)
			var cell: String = ""
			for name in corners:
				if Rect2(corners[name].position, corners[name].size).has_point(p):
					cell = name
			if cell.is_empty() or p.distance_to(centre) >= bestD:
				continue
			var clear := true
			for dy in [-1.0, 0.0, 1.0]:
				for dx in [-1.0, 0.0, 1.0]:
					var q: Vector2 = p + Vector2(dx, dy)
					if _planet_alpha(pic, q) < 0.5:
						clear = false
					for name in corners:
						if _icon_alpha(corners[name], q) >= 0.1:
							clear = false
			if clear:
				best = {"at": p, "cell": cell}
				bestD = p.distance_to(centre)
	return best


## A sector-map point in the middle of an icon's drawn pixels: the drawn
## pixel with drawn pixels all round it nearest their centroid (any drawn
## pixel, if none has). Null when nothing is drawn.
static func _glyph_point(btn: Button) -> Variant:
	var img: Image = _image(btn.icon)
	if img == null:
		return null
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


## The windows open on `planet` (its System window and the ones its icons
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
