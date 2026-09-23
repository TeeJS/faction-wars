class_name Artwork
extends RefCounted
## THE PLAYER'S OWN ARTWORK OVERLAY. tools/RebellionArtImporter copies pictures
## out of a player's installed Star Wars: Rebellion into
## packs/<id>/original/ (gitignored: the repo never carries them). This is the
## one reader: a picture the overlay has wins, one it lacks means "draw what
## you draw today". Nothing here is required, so a player without the original
## sees exactly the engine's own art.
##
## Two places are searched, in order:
##   res://packs/<pack id>/original/...   the importer's output (running from
##                                        the project, as TeeJ does)
##   user://original/<pack id>/...        the same layout for an exported build,
##                                        where the pack folder is inside the pck
## Files are read with Image.load_from_file, not load(): they are not imported
## resources and never will be.

static var _cache: Dictionary = {}      # relative path -> Texture2D or null
static var _cache_pack: String = ""
## Tests only: look in user:// alone, so a developer's own imported folder in
## the project does not decide what a test sees.
static var IgnoreProjectFolder: bool = false


## A sector-window corner icon in the side's own colours:
## original/icons/<glyph>.<faction id>.png, or .hover.png. Null when absent.
static func CornerIcon(glyph: String, faction_id: String, hover: bool = false) -> Texture2D:
	return _texture("icons/%s.%s%s.png" % [glyph, faction_id, ".hover" if hover else ""])


## The planet sprite for a map.json artwork_id: original/planet_sprites/<n>.png.
static func PlanetSprite(artwork_id: int) -> Texture2D:
	if artwork_id <= 0:
		return null
	return _texture("planet_sprites/%d.png" % artwork_id)


## The Encyclopedia picture for one pack row: original/<kind>/<id>.png.
static func Picture(kind: String, id: String) -> Texture2D:
	return _texture("%s/%s.png" % [kind, id])


## Forget everything loaded (a new pack, or a test that wrote files).
static func Reset() -> void:
	_cache.clear()
	_cache_pack = ""


static func _texture(rel: String) -> Texture2D:
	var pack_id: String = FactionRegistry.Pack.Manifest.Id if FactionRegistry.Pack != null else ""
	if pack_id != _cache_pack:
		_cache.clear()
		_cache_pack = pack_id
	if _cache.has(rel):
		return _cache[rel]
	var tex: Texture2D = null
	var roots: Array[String] = ["user://original/%s" % pack_id]
	if not IgnoreProjectFolder:
		roots.push_front("%s/%s/original" % [FactionRegistry.PACKS_ROOT, pack_id])
	for base in roots:
		var path := "%s/%s" % [base, rel]
		if not FileAccess.file_exists(path):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
			break
	_cache[rel] = tex
	return tex
