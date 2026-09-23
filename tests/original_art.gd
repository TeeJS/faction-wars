extends SceneTree
## The player's own artwork overlay (src/ui/artwork.gd, tools/RebellionArtImporter):
## when user://original/<pack>/ holds a corner icon or a planet sprite, the
## sector window draws it - the icon untinted in its own colours, the planet as
## its sprite with the name in the side's colour - and falls back to the
## engine's art when the file is gone. Writes and removes its own test files.
##
##   .\tools\run-gd.ps1 tests/original_art.gd -- --pack=ww2
##   .\tools\run-gd.ps1 tests/original_art.gd              (Star Wars)

const Art := preload("res://src/ui/artwork.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[original_art] ok   %s" % what)
	else:
		_fails += 1
		print("[original_art] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true   # only what this test writes counts
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
	var pack_id: String = FactionRegistry.Pack.Manifest.Id
	var home: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	var art_id: int = home.ArtworkId
	_check(home != null, "%s holds a world (%s, artwork_id %d)" % [us.Id, home.Name, art_id])

	# Nothing in the overlay: the engine's own art.
	Art.Reset()
	var before: Dictionary = await _corners_for(ui, home)
	_check(before.has("manufacturing") and (before["manufacturing"] as Button).icon.resource_path.begins_with("res://assets/icons/"),
		"without an overlay the manufacturing corner shows the engine's glyph")
	_check(Art.CornerIcon("manufacturing", us.Id) == null, "Artwork.CornerIcon is null without a file")

	# Write two test pictures where an exported build's overlay lives.
	var dir := "user://original/%s" % pack_id
	DirAccess.make_dir_recursive_absolute(dir + "/icons")
	DirAccess.make_dir_recursive_absolute(dir + "/planet_sprites")
	var icon := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0.2, 0.9, 0.3))
	var icon_path := "%s/icons/manufacturing.%s.png" % [dir, us.Id]
	icon.save_png(icon_path)
	var hover := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	hover.fill(Color(1, 1, 1))
	hover.save_png("%s/icons/manufacturing.%s.hover.png" % [dir, us.Id])
	var sprite_path := ""
	if art_id > 0:
		var sprite := Image.create(37, 37, false, Image.FORMAT_RGBA8)
		sprite.fill(Color(0.5, 0.5, 0.9))
		sprite_path = "%s/planet_sprites/%d.png" % [dir, art_id]
		sprite.save_png(sprite_path)
	Art.Reset()

	_check(Art.CornerIcon("manufacturing", us.Id) != null, "Artwork.CornerIcon finds the file under user://original")
	var after: Dictionary = await _corners_for(ui, home)
	var btn: Button = after.get("manufacturing")
	_check(btn != null and btn.has_meta("original_icon") and not btn.icon.resource_path.begins_with("res://"),
		"the manufacturing corner shows the imported icon")
	_check(btn != null and SectorWindow.IconTint(btn) == Color(1, 1, 1, 1), "the imported icon is not tinted (its colours are its own)")
	if btn != null:
		var plain: Texture2D = btn.icon
		btn.mouse_entered.emit()
		_check(btn.icon != plain, "hovering swaps in the highlighted version")
		btn.mouse_exited.emit()
		_check(btn.icon == plain, "leaving restores the normal one")
	if art_id > 0:
		var pb: Button = _planet_button(ui, home)
		_check(pb != null and pb.has_meta("sprite") and pb.icon != null, "the planet is drawn as its sprite")
		var lbl: Label = _name_label(ui, home)
		_check(lbl != null and lbl.get_theme_color("font_color") == home.GetFactionColor(), "the name takes the side's colour under a sprite")
	else:
		print("[original_art] (this pack declares no artwork_id - planet sprite not exercised)")

	# Remove the files: back to the engine's art.
	DirAccess.remove_absolute(icon_path)
	DirAccess.remove_absolute("%s/icons/manufacturing.%s.hover.png" % [dir, us.Id])
	if not sprite_path.is_empty():
		DirAccess.remove_absolute(sprite_path)
	Art.Reset()
	var gone: Dictionary = await _corners_for(ui, home)
	_check(gone.has("manufacturing") and (gone["manufacturing"] as Button).icon.resource_path.begins_with("res://assets/icons/"),
		"with the files removed the engine's glyph is back")

	print("[original_art] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


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
	var btn: Control = _planet_button(ui, planet)
	var centre: Vector2 = btn.position + Vector2(16, 16)
	var out := {}
	for c in map.get_children():
		if c is Button and c.has_meta("corner") and (c.position + Vector2(8, 8)).distance_to(centre) < 40:
			out[c.get_meta("corner")] = c
	return out


func _planet_button(ui: UIManager, planet: Planet) -> Button:
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))
	var w: DraggableWindow = _window_titled(ui, sector.Name)
	if w == null:
		return null
	return Lq.first_or_null(w.get_node("%SectorMap").get_children(), func(c) -> bool: return c is SectorWindow.PlanetMapButton and c.AssociatedPlanet == planet)


func _name_label(ui: UIManager, planet: Planet) -> Label:
	var sector: Sector = Lq.first_or_null(GameState.ActiveGalaxy, func(s: Sector) -> bool: return s.Planets.has(planet))
	var w: DraggableWindow = _window_titled(ui, sector.Name)
	for c in w.get_node("%SectorMap").get_children():
		if c is Label and c.text == planet.Name:
			return c
	return null


static func _window_titled(ui: Node, title: String) -> DraggableWindow:
	for c in ui.get_children():
		if c is DraggableWindow and (c as DraggableWindow).WindowTitle == title:
			return c
	return null
