extends SceneTree
## THE RENAMED PICTURE FOLDERS (TeeJ, 2026-10-04: art/planets became
## art/locations, and planet_sprites location_sprites; src/ui/artwork.gd
## OldFolders): an art set that has only the old folders - one imported before
## the exporter wrote the new names - still shows its systems' pictures, map
## pictures and descriptions; with both, the new folder wins; and an `art`
## reference by the old kind name still parses. Writes and removes its own test
## art set, never the player's.
##
##   .\tools\run-gd.ps1 tests/art_old_folders.gd                 (Star Wars: an art set)
##   .\tools\run-gd.ps1 tests/art_old_folders.gd -- --pack=ww2   (WWII: the pack's own art/)

const Art := preload("res://src/ui/artwork.gd")
const ArtRoot := "user://test-art-old-folders"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[art_old_folders] ok   %s" % what)
	else:
		_fails += 1
		print("[art_old_folders] FAIL %s" % what)


func _init() -> void:
	await process_frame
	Art.IgnoreProjectFolder = true
	preload("res://src/ui/art_standins.gd").Enabled = false
	Art.UserArtRoot = ArtRoot
	FactionRegistry.EnsureLoaded()
	var pack: Variant = FactionRegistry.Pack
	var planet: Variant = pack.Map.Planets[0]
	var sets: Array = pack.Manifest.ArtSets

	_check(PackLoader.ParseArtRef("planets/%s" % planet.Id, sets) == ["", "locations", planet.Id],
		"an art reference by the old kind name reads as locations")
	_check(PackLoader.ParseArtRef("locations/%s" % planet.Id, sets) == ["", "locations", planet.Id],
		"an art reference by the new kind name")

	if sets.is_empty():
		# A pack with its own pictures and no art set (WWII): every system's
		# picture and map picture is found by the new names, whichever folder
		# the pack keeps them in.
		Art.Reset()
		var missing: Array = []
		for p in pack.Map.Planets:
			if Art.Picture("locations", p.Id) == null or (p.ArtworkId > 0 and Art.LocationSprite(p.ArtworkId) == null):
				missing.append(p.Id)
		_check(missing.is_empty(), "the pack's own art: every system's picture and map picture (missing: %s)" % ", ".join(missing))
		_check(not Art.Description("locations", planet.Id).is_empty(), "the pack's own description of %s" % planet.Id)
		_finish()
		return

	var dir := "%s/%s" % [ArtRoot, sets[0]]
	_remove(ArtRoot)
	for sub in ["planets", "planet_sprites"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [dir, sub])
	_png("%s/planets/%s.png" % [dir, planet.Id], 400, 200, Color(0.9, 0.1, 0.1))
	if planet.ArtworkId > 0:
		_png("%s/planet_sprites/%d.png" % [dir, planet.ArtworkId], 37, 37, Color(0.9, 0.1, 0.1))
	_write("%s/descriptions.json" % dir, {"planets": {planet.Id: "The old section's words."}})
	Art.Reset()

	# Only the old folders: found under the new names.
	var pic: Texture2D = Art.Picture("locations", planet.Id)
	_check(pic != null and pic.get_width() == 400, "an art set with only planets/ shows the system's picture")
	if planet.ArtworkId > 0:
		_check(Art.LocationSprite(planet.ArtworkId) != null, "an art set with only planet_sprites/ shows the map picture")
	_check(Art.Description("locations", planet.Id) == "The old section's words.", "a descriptions.json with only a \"planets\" section is read")

	# Both: the new folder wins.
	DirAccess.make_dir_recursive_absolute("%s/locations" % dir)
	_png("%s/locations/%s.png" % [dir, planet.Id], 400, 200, Color(0.1, 0.1, 0.9))
	_write("%s/descriptions.json" % dir, {"planets": {planet.Id: "Old."}, "locations": {planet.Id: "New."}})
	Art.Reset()
	pic = Art.Picture("locations", planet.Id)
	var px: Color = pic.get_image().get_pixel(10, 10) if pic != null else Color.BLACK
	_check(px.b > 0.5 and px.r < 0.5, "with both folders, locations/ wins")
	_check(Art.Description("locations", planet.Id) == "New.", "with both sections, \"locations\" wins")

	_remove(ArtRoot)
	Art.Reset()
	_finish()


func _finish() -> void:
	print("[art_old_folders] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func _png(path: String, w: int, h: int, c: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	img.save_png(path)


static func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
