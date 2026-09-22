extends SceneTree
## The map picture comes from the pack: GalaxyMap draws pack.json's
## `map_image` behind the regions, fitted into its frame, and every marker is
## placed at map.json coordinate * that scale (SCHEMA.md section 4).
##
##   .\tools\run-gd.ps1 tests/map_backdrop.gd              (Star Wars)
##   .\tools\run-gd.ps1 tests/map_backdrop.gd -- --pack=ww2

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
	var expected: Texture2D = load("%s/%s/%s" % [FactionRegistry.PACKS_ROOT, pack.Manifest.Id, pack.Manifest.MapImage])
	_check(backdrop != null and backdrop.texture.get_size() == expected.get_size(),
		"the backdrop is the pack's map_image '%s' (%s)" % [pack.Manifest.MapImage, str(expected.get_size())])
	var want_scale := minf(GalaxyMap.Frame.x / expected.get_size().x, GalaxyMap.Frame.y / expected.get_size().y)
	_check(absf(map.MapScale() - want_scale) < 0.0001, "the picture is fitted into the frame (scale %.4f)" % map.MapScale())
	_check(backdrop != null and backdrop.scale.is_equal_approx(Vector2(want_scale, want_scale)) and backdrop.position == Vector2.ZERO,
		"the backdrop sits at the origin at that scale")
	_check(backdrop != null and backdrop.z_index < 0, "the backdrop is behind every marker")

	# A marker lands at coordinate * scale - the picture and the regions agree.
	# A VISIBLE marker: an unexplored world's dot is hidden and never placed.
	var planet: Planet = null
	for sector in GameState.ActiveGalaxy:
		for p in sector.Planets:
			if (map._planetStars[p] as Label).visible:
				planet = p
				break
		if planet != null:
			break
	_check(planet != null, "some world has a visible marker")
	var star: Label = map._planetStars[planet]
	var centre: Vector2 = star.position + star.size / 2.0
	_check(centre.is_equal_approx(map.MapPos(planet.MapX, planet.MapY)),
		"%s's marker is at its coordinate x scale (%s)" % [planet.Name, str(centre)])
	_check(map.MapPos(planet.MapX, planet.MapY).x <= GalaxyMap.Frame.x + 1 and map.MapPos(planet.MapX, planet.MapY).y <= GalaxyMap.Frame.y + 1,
		"and inside the frame")

	print("[map_backdrop] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
