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
## original/icons/<glyph>.<faction id>.png, or .hover.png. A glyph with no
## side (the uprising flame) is original/icons/<glyph>.png. Null when absent.
static func CornerIcon(glyph: String, faction_id: String, hover: bool = false) -> Texture2D:
	var side := "" if faction_id.is_empty() else "." + faction_id
	return _texture("icons/%s%s%s.png" % [glyph, side, ".hover" if hover else ""])


## A Message Alert bar icon for a side and a category (the enum name in lower
## case), dim or lit: original/alerts/<faction id>.<category>[.lit].png.
static func AlertIcon(faction_id: String, category: String, lit: bool) -> Texture2D:
	return _texture("alerts/%s.%s%s.png" % [faction_id, category.to_lower(), ".lit" if lit else ""])


## The GID star for a side and a tier (big / mid / low / none):
## original/gid/<faction id>.<tier>.png; "unexplored" is a side of its own.
static func GidStar(faction_id: String, tier: String) -> Texture2D:
	return _texture("gid/%s.%s.png" % [faction_id, tier])


## The planet sprite for a map.json artwork_id: original/planet_sprites/<n>.png.
static func PlanetSprite(artwork_id: int) -> Texture2D:
	if artwork_id <= 0:
		return null
	return _texture("planet_sprites/%d.png" % artwork_id)


## The Encyclopedia picture for one pack row: original/<kind>/<id>.png.
static func Picture(kind: String, id: String) -> Texture2D:
	return _texture("%s/%s.png" % [kind, id])


## A mission's picture for a side: original/missions/<mission id>.<faction id>.png,
## else the side-less original/missions/<mission id>.png.
static func MissionPicture(mission_id: String, faction_id: String) -> Texture2D:
	var tex: Texture2D = _texture("missions/%s.%s.png" % [mission_id, faction_id])
	return tex if tex != null else _texture("missions/%s.png" % mission_id)


## The original's 80x80 portrait of a character, unit or facility:
## original/portraits/<kind>/<id>.png (GOKRES.DLL, see the importer's README).
static func Portrait(kind: String, id: String) -> Texture2D:
	return _texture("portraits/%s/%s.png" % [kind, id])


## The original's 61x25 list miniature: original/miniatures/<kind>/<id>.png.
static func Miniature(kind: String, id: String) -> Texture2D:
	return _texture("miniatures/%s/%s.png" % [kind, id])


## Put a picture into a window's placeholder rectangle - a TextureRect child
## named "Picture" that fills it, keeping the picture's aspect (centred, never
## cropped: a portrait is a portrait) - and hide the placeholder's own label. A null picture removes it and shows the
## placeholder again, so a window repainted for another item never keeps the
## last one's face. Returns the TextureRect, or null.
static func Fill(rect: Control, picture: Texture2D) -> TextureRect:
	if rect == null:
		return null
	var existing: TextureRect = rect.get_node_or_null("Picture")
	var label: Label = null
	for c in rect.get_children():
		if c is Label:
			label = c
	if picture == null:
		if existing != null:
			rect.remove_child(existing)
			existing.queue_free()
		if label != null:
			label.visible = true
		return null
	if existing == null:
		existing = TextureRect.new()
		existing.name = "Picture"
		existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(existing)
	existing.texture = picture
	# A picture smaller than its box is shown at 1:1 (blowing an 80 px face up
	# to 180 px is what made the message faces pixelated, TeeJ 2026-09-22);
	# a larger one is fitted, and filtered smoothly since it is being shrunk.
	var box := Vector2(maxf(rect.custom_minimum_size.x, rect.size.x), maxf(rect.custom_minimum_size.y, rect.size.y))
	var fits: bool = picture.get_width() <= box.x and picture.get_height() <= box.y
	existing.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED if fits else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	existing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if fits else CanvasItem.TEXTURE_FILTER_LINEAR
	if label != null:
		label.visible = false
	return existing


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
