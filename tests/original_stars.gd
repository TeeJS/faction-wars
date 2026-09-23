extends SceneTree
## The original's GID stars, uprising flame and unit miniatures from the
## player's own import (src/ui/artwork.gd): the galaxy map and the sector
## window draw the star bitmap for the world's side and tier instead of the
## "+" and "•" labels; the mission corner shows the flame; Fleet and Defenses
## unit rows carry the miniature. Nothing imported means the labels, as
## before. Writes and removes its own test files under user://.
##
##   .\tools\run-gd.ps1 tests/original_stars.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/original_stars.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_stars] ok   %s" % what)
	else:
		_fails += 1
		print("[original_stars] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	Art.UserArtRoot = "user://test-original_stars-art"   # never the player's own
	FactionRegistry.EnsureLoaded()
	if FactionRegistry.Pack.Manifest.ArtSets.is_empty():
		print("[original_stars] (this pack declares no art set - the original's pictures do not apply)")
		print("[original_stars] 0 checks, 0 failed")
		quit(0)
		return
	MpSetup.reset()
	GameSettings.SelectedDifficulty = Enums.Difficulty.Medium
	GameSettings.SelectedSize = Enums.GalaxySize.Standard
	var main: Node = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
	var ui: UIManager = main.get_node("UIManager")
	var map: GalaxyMap = main.get_node("GalaxyMap")
	var us: Faction = GameSettings.PlayerFaction
	var pack_id: String = FactionRegistry.Pack.Manifest.Id
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us and not p.Garrison.is_empty())
	_check(home != null, "%s holds a garrisoned world (%s)" % [us.Id, home.Name if home != null else "-"])

	# Without the overlay: the labels.
	Art.Reset()
	map.RefreshVisuals()
	_check(not map._planetSprites[home].visible and (map._planetStars[home].visible or map._planetFlares[home].visible), "without an import the map draws the labels")

	# Write a star for our side at every tier, an unexplored one, and a flame.
	var dir := "%s/%s" % [Art.UserArtRoot, FactionRegistry.Pack.Manifest.ArtSets[0]]
	DirAccess.make_dir_recursive_absolute(dir + "/gid")
	DirAccess.make_dir_recursive_absolute(dir + "/icons")
	DirAccess.make_dir_recursive_absolute(dir + "/miniatures/units")
	var written: Array[String] = []
	for tier in ["big", "mid", "low", "none"]:
		for side in [us.ArtSkin, "unexplored"]:
			var img := Image.create(15, 15, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 0.5, 0.2) if side == us.ArtSkin else Color(0.6, 0.6, 0.6))
			var path := "%s/gid/%s.%s.png" % [dir, side, tier]
			img.save_png(path)
			written.append(path)
	var flame := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	flame.fill(Color(1, 0.6, 0.1))
	flame.save_png(dir + "/icons/uprising.png")
	written.append(dir + "/icons/uprising.png")
	var mini := Image.create(61, 25, false, Image.FORMAT_RGBA8)
	mini.fill(Color(0.4, 0.6, 0.8))
	var troop: Unit = home.Garrison[0]
	mini.save_png("%s/miniatures/units/%s.png" % [dir, troop.PackId])
	written.append("%s/miniatures/units/%s.png" % [dir, troop.PackId])
	Art.Reset()

	# Galaxy map: the sprite, scaled, centred on the world; labels hidden.
	map.RefreshVisuals()
	var sprite: TextureRect = map._planetSprites[home]
	_check(sprite.visible and sprite.texture != null, "the map draws the imported star for a held world")
	_check(sprite.size == Vector2(15, 15) * GalaxyMap.StarScale, "the star is drawn at the map's scale (%s)" % str(sprite.size))
	_check((sprite.position + sprite.size / 2.0).distance_to(map.MapPos(home.MapX, home.MapY)) < 0.5, "the star is centred on the world")
	_check(not map._planetStars[home].visible and not map._planetFlares[home].visible, "the labels are hidden under the star")
	var dark: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return not p.ExploredBy(us))
	if dark != null:
		_check((map._planetSprites[dark] as TextureRect).visible, "an unexplored world gets the grey star")

	# Sector window: the star bitmap beside the world.
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(home))
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	var w: DraggableWindow = ui._openWindows.get(sector.Name)
	var smap: Control = w.get_node("%SectorMap")
	var stars: Array = Lq.where(smap.get_children(), func(c) -> bool: return c is TextureRect and c.has_meta("gid_star"))
	_check(stars.size() > 0, "the sector window draws star bitmaps (%d)" % stars.size())

	# Uprising: the flame in the mission corner, the original's when imported.
	home.IsInUprising = true
	w.CloseWindow()
	for _i in 2:
		await process_frame
	ui.OnSectorClicked(sector)
	for _i in 3:
		await process_frame
	w = ui._openWindows.get(sector.Name)
	var flame_btn: Button = Lq.first_or_null(w.get_node("%SectorMap").get_children(), func(c) -> bool: return c is Button and c.has_meta("corner") and c.get_meta("corner") == "uprising")
	_check(flame_btn != null and flame_btn.has_meta("original_icon"), "the uprising corner shows the imported flame")
	home.IsInUprising = false

	# Defenses window: the unit row carries the miniature.
	ui.OnDefenseClicked(home)
	for _i in 3:
		await process_frame
	var dw: DraggableWindow = ui._openWindows.get(home.Name + " Defenses")
	var row: Button = null
	if dw != null:
		for n in dw.find_children("*", "Button", true, false):
			if "UnitData" in n and n.UnitData == troop:
				row = n
	_check(row != null and row.has_meta("miniature") and row.icon != null, "the Defenses unit row carries the miniature")

	# Remove the files: labels again.
	for path in written:
		DirAccess.remove_absolute(path)
	Art.Reset()
	map.RefreshVisuals()
	_check(not map._planetSprites[home].visible, "with the files removed the map is back to the labels")

	print("[original_stars] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
