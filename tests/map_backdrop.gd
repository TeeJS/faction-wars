extends SceneTree
## The map picture comes from the pack: GalaxyMap draws pack.json's
## `map_image` behind the regions, fitted into its frame, and every marker is
## placed at map.json coordinate * that scale (SCHEMA.md section 4).
##
##   .\tools\run-gd.ps1 tests/map_backdrop.gd              (Star Wars)
##   .\tools\run-gd.ps1 tests/map_backdrop.gd -- --pack=ww2

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[map_backdrop] ok   %s" % what)
	else:
		_fails += 1
		print("[map_backdrop] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 10:
		await process_frame

	var pack := FactionRegistry.Pack
	var map: GalaxyMap = main.get_node("GalaxyMap")
	_check(map != null, "the map view is in the main scene")
	_check(main.find_child("TextureRect", false, false) == null, "no picture is baked into Main.tscn any more")

	var backdrop := map.Backdrop()
	_check(backdrop != null and backdrop.texture != null, "the map draws a backdrop")
	# The pack's picture, or its art set's ("swr-original:screens/galaxy.png").
	var expected: Texture2D = Art.PackImage(pack.Manifest.MapImage)
	_check(backdrop != null and backdrop.texture.get_size() == expected.get_size(),
		"the backdrop is the pack's map_image '%s' (%s)" % [pack.Manifest.MapImage, str(expected.get_size())])
	var rect := pack.Manifest.MapImageRect
	if rect.size.x <= 0.0:
		rect = Rect2(Vector2.ZERO, expected.get_size())
	var want_scale := minf(GalaxyMap.Frame.x / rect.size.x, GalaxyMap.Frame.y / rect.size.y)
	_check(absf(map.MapScale() - want_scale) < 0.0001, "the map space is fitted into the frame by the picture's rect (scale %.4f)" % map.MapScale())
	_check(backdrop != null and backdrop.position == Vector2.ZERO
		and backdrop.scale.is_equal_approx(rect.size * want_scale / expected.get_size()),
		"the backdrop fills the frame from its top-left, at that scale")
	_check(backdrop != null and backdrop.z_index < 0, "the backdrop is behind every marker")

	# A marker lands at coordinate * scale - the picture and the regions agree.
	# A VISIBLE marker: an unexplored world's dot is hidden and never placed.
	# With the original's art imported, the marker is its star sprite and the
	# label is hidden.
	var planet: Planet = null
	var star: Control = null
	for sector in GameState.ActiveGalaxy:
		for p in sector.Planets:
			var sprite: Control = map._planetSprites[p]
			var label: Control = map._planetStars[p]
			star = sprite if sprite.visible else (label if label.visible else null)
			if star != null:
				planet = p
				break
		if planet != null:
			break
	_check(planet != null, "some world has a visible marker")
	if planet == null:
		print("[map_backdrop] %d checks, %d failed" % [_checks, _fails])
		quit(1)
		return
	var centre: Vector2 = star.position + star.size / 2.0
	_check(centre.is_equal_approx(map.MapPos(planet.MapX, planet.MapY)),
		"%s's marker is at its coordinate x scale (%s)" % [planet.Name, str(centre)])
	_check(map.MapPos(planet.MapX, planet.MapY).x <= GalaxyMap.Frame.x + 1 and map.MapPos(planet.MapX, planet.MapY).y <= GalaxyMap.Frame.y + 1,
		"and inside the frame")
	# Star Wars: everything lands exactly where the old scene put it - the
	# picture at screen (150,99), markers at (155 + x, -11 + y), unscaled.
	if pack.Manifest.Id == "star-wars-rebellion":
		_check(absf(map.MapScale() - 1.0) < 0.0001, "Star Wars: coordinates unscaled")
		_check((map.position + backdrop.position).is_equal_approx(Vector2(150, 99)), "Star Wars: the picture at screen (150,99) as Main.tscn baked it")
		_check((map.position + map.MapPos(planet.MapX, planet.MapY)).is_equal_approx(Vector2(155 + planet.MapX, -11 + planet.MapY)),
			"Star Wars: %s at screen (155+x, -11+y) as the old map node placed it" % planet.Name)

	print("[map_backdrop] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
