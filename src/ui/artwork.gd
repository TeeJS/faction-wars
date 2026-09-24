class_name Artwork
extends RefCounted
## THE ORIGINAL'S ARTWORK, FROM THE PLAYER'S OWN COPY. tools/FactionWarsExporter
## reads the pictures out of a player's installed Star Wars: Rebellion into an
## ART SET ("swr-original"); a pack declares the art sets its original look
## comes from (pack.json `art_sets`, docs/original-art-plan.md). This is the
## one reader: a picture found wins, one missing means "draw what you draw
## today". Nothing here is required - a player without the art set sees the
## engine's own art.
##
## Where a picture is looked for, in order (paths below are relative to these):
##   <pack folder>/art/          the pack's own pictures (its author's)
##   then, for each art set the pack declares:
##   res://art/<set>/            a checkout's exported folder (gitignored)
##   user://art/<set>/           the art set the player imported
## A pack row may borrow another row's pictures from a set (its `art`, e.g.
## "swr-original:facilities/orbital_shipyard"); the pack's own art/ still
## comes first. The original's side pictures are keyed by a SKIN
## ("alliance" / "empire": a faction's factions.json `skin`, OUI.Side), never
## by the faction id, so a custom side can wear the original's.
##
## A file under res:// is an imported resource (the editor imports every PNG it
## finds, and an export packs the import, not the source file), so it is read
## with load() - which is what makes the art work in a web export too, where
## there is no OS path to read. A file under user:// is a plain PNG and is read
## with Image.load_from_file.

static var _cache: Dictionary = {}      # lookup key -> Texture2D or null
static var _cache_pack: String = ""
static var _aliases: Dictionary = {}    # "<kind>/<id>" -> [set, kind, id], for the loaded pack
## Tests only: skip the project's own copy (res://art/), so a developer's
## exported art does not decide what a test sees.
static var IgnoreProjectFolder: bool = false
## Where imported art sets live: <this>/<set>/. Tests point it elsewhere, so a
## player's own imported art set is never touched by a test.
static var UserArtRoot: String = "user://art"


## A sector-window corner icon in the side's own colours:
## icons/<glyph>.<side>.png, or .hover.png. A glyph with no side (the uprising
## flame) is icons/<glyph>.png. Null when absent.
static func CornerIcon(glyph: String, side: String, hover: bool = false) -> Texture2D:
	var suffix := "" if side.is_empty() else "." + side
	return _texture("icons/%s%s%s.png" % [glyph, suffix, ".hover" if hover else ""])


## A Message Alert bar icon for a side and a category (the enum name in lower
## case), dim or lit: alerts/<side>.<category>[.lit].png.
static func AlertIcon(side: String, category: String, lit: bool) -> Texture2D:
	return _texture("alerts/%s.%s%s.png" % [side, category.to_lower(), ".lit" if lit else ""])


## The GID star for a side and a tier (big / mid / low / none):
## gid/<side>.<tier>.png; "unexplored" is a side of its own.
static func GidStar(side: String, tier: String) -> Texture2D:
	return _texture("gid/%s.%s.png" % [side, tier])


## A window's picture: windows/<name>.png.
static func WindowPicture(name: String) -> Texture2D:
	return _texture("windows/%s.png" % name)


## A whole screen of the original's: screens/<name>.png (the Game Options
## screen; the cockpit and the galaxy come through the pack's own references).
static func Screen(name: String) -> Texture2D:
	return _texture("screens/%s.png" % name)


## A window tab's icon: tabs/<name>[.<side>][.pressed|.grey].png.
## The per-side icons (manufacturing, fighters, troops, personnel) fall back
## to the sideless file, so a pack with one set still gets it.
static func TabIcon(name: String, side: String, state: String = "") -> Texture2D:
	var suffix := "" if state.is_empty() else "." + state
	var tex: Texture2D = null
	if not side.is_empty():
		tex = _texture("tabs/%s.%s%s.png" % [name, side, suffix])
	if tex == null:
		tex = _texture("tabs/%s%s.png" % [name, suffix])
	return tex


## A window button's picture: buttons/<name>[.pressed|.disabled].png.
static func ButtonIcon(name: String, state: String = "") -> Texture2D:
	return _texture("buttons/%s%s.png" % [name, "" if state.is_empty() else "." + state])


## The same picture pixel-doubled (nearest neighbour), for the 2x the HUD
## draws the original's small bitmaps at. Cached per texture and factor.
static var _scaled: Dictionary = {}

static func Scaled(tex: Texture2D, factor: int) -> Texture2D:
	if tex == null or factor <= 1:
		return tex
	var key := "%s@%d" % [tex.get_instance_id(), factor]
	if _scaled.has(key):
		return _scaled[key]
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(img)
	# What it was made from (a scaled picture has no path of its own).
	out.set_meta("source", tex.resource_path if not tex.resource_path.is_empty() else str(tex.get_meta("source", "")))
	_scaled[key] = out
	return out


## The planet sprite for a map.json artwork_id: planet_sprites/<n>.png.
static func PlanetSprite(artwork_id: int) -> Texture2D:
	if artwork_id <= 0:
		return null
	return _texture("planet_sprites/%d.png" % artwork_id)


## The Encyclopedia picture for one pack row: <kind>/<id>.png.
static func Picture(kind: String, id: String) -> Texture2D:
	return _row(kind, id, "{k}/{i}.png")


## A mission's picture for a side: missions/<mission id>.<side>.png, else the
## side-less missions/<mission id>.png.
static func MissionPicture(mission_id: String, side: String) -> Texture2D:
	var tex: Texture2D = _row("missions", mission_id, "{k}/{i}.%s.png" % side)
	return tex if tex != null else _row("missions", mission_id, "{k}/{i}.png")


## A mission's 130x65 picture in the Create Mission window, for a side:
## missions/<mission id>.<side>.small.png (GOKRES.DLL).
static func MissionCard(mission_id: String, side: String) -> Texture2D:
	return _row("missions", mission_id, "{k}/{i}.%s.small.png" % side)


## A mission's 73x48 picture in the Mission window's column, for a side:
## missions/<mission id>.<side>.tile.png (GOKRES.DLL).
static func MissionTile(mission_id: String, side: String) -> Texture2D:
	return _row("missions", mission_id, "{k}/{i}.%s.tile.png" % side)


## The original's 80x80 portrait of a character, unit or facility:
## portraits/<kind>/<id>.png (GOKRES.DLL, see the exporter's README). An id
## with a suffix ("<id>.damage", a ship's flames) keeps it through an `art`
## reference.
static func Portrait(kind: String, id: String) -> Texture2D:
	return _row(kind, id, "portraits/{k}/{i}.png")


## The original's 61x25 list miniature: miniatures/<kind>/<id>.png.
static func Miniature(kind: String, id: String) -> Texture2D:
	return _row(kind, id, "miniatures/{k}/{i}.png")


## A picture a pack's manifest names (map_image, menu.image): a file in the
## pack's folder, or "<set>:<path>" inside one of its art sets. For a pack that
## is not loaded (the picker's cards) pass its id and art sets. Null when absent.
static func PackImage(ref: String, pack_id: String = "", art_sets: Array = []) -> Texture2D:
	if ref.is_empty():
		return null
	var loaded: bool = pack_id.is_empty() or pack_id == FactionRegistry.LoadedId()
	var dir: String = _pack_dir() if loaded else FactionRegistry.PackDir(pack_id)
	var sets: Array = art_sets
	if loaded:
		sets = FactionRegistry.Pack.Manifest.ArtSets if FactionRegistry.Pack != null else []
	var split: PackedStringArray = PackLoader.SplitArtRef(ref)
	if split[0].is_empty():
		return _load("%s/%s" % [dir, ref])
	if not sets.has(split[0]):
		return null
	for root in _set_roots(split[0]):
		var tex: Texture2D = _load("%s/%s" % [root, split[1]])
		if tex != null:
			return tex
	return null


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


## The imported Encyclopedia description of one pack row, or "" - from
## descriptions.json ({ "characters": { id: text }, ... }): the pack's own
## art/ first, then the first art set that has one (through the row's `art`).
static var _descriptions_own: Dictionary = {}
static var _descriptions_set: Dictionary = {}
static var _descriptions_loaded: bool = false

static func Description(kind: String, id: String) -> String:
	_check_pack()
	if not _descriptions_loaded:
		_descriptions_loaded = true
		var own: Variant = _read_json("%s/art/descriptions.json" % _pack_dir())
		_descriptions_own = own if own is Dictionary else {}
		var found: Variant = _json_in_sets("descriptions.json")
		_descriptions_set = found if found is Dictionary else {}
	var section: Variant = _descriptions_own.get(kind)
	if section is Dictionary and section.has(id):
		return str(section[id])
	var a: Array = _alias(kind, id)
	section = _descriptions_set.get(a[1])
	return str(section.get(a[2], "")) if section is Dictionary else ""


## The original's mouse pointers (REBEXE.EXE; see the importer): "pointer"
## and "crosshair" - original/cursors/<name>.png - and each one's hotspot,
## from cursors/hotspots.json.
static func CursorPicture(name: String) -> Texture2D:
	return _texture("cursors/%s.png" % name)


static func CursorHotspot(name: String) -> Vector2:
	var spots: Variant = _json("cursors/hotspots.json")
	var at: Variant = spots.get(name) if spots is Dictionary else null
	return Vector2(float(at[0]), float(at[1])) if at is Array and at.size() == 2 else Vector2.ZERO


## A JSON file (the pack's own art/, then its art sets), or null.
static func _json(rel: String) -> Variant:
	var own: Variant = _read_json("%s/art/%s" % [_pack_dir(), rel])
	return own if own != null else _json_in_sets(rel)


static func _json_in_sets(rel: String) -> Variant:
	for s in _sets():
		for root in _set_roots(s):
			var parsed: Variant = _read_json("%s/%s" % [root, rel])
			if parsed != null:
				return parsed
	return null


static func _read_json(path: String) -> Variant:
	if FileAccess.file_exists(path):
		return JSON.parse_string(FileAccess.get_file_as_string(path))
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var res: Variant = load(path)   # an export packs the JSON as a resource
		if res != null and "data" in res:
			return res.data
	return null


## Forget everything loaded (a new pack, an import, or a test that wrote files).
static func Reset() -> void:
	_cache.clear()
	_cache_pack = ""
	_aliases.clear()
	_descriptions_loaded = false


## A new pack forgets the last one's pictures and aliases.
static func _check_pack() -> void:
	var pack_id: String = FactionRegistry.LoadedId()
	if pack_id != _cache_pack:
		Reset()
		_cache_pack = pack_id


## The loaded pack's art sets (pack.json `art_sets`).
static func _sets() -> Array:
	return FactionRegistry.Pack.Manifest.ArtSets if FactionRegistry.Pack != null else []


static func _pack_dir() -> String:
	if not FactionRegistry.LoadedDir.is_empty():
		return FactionRegistry.LoadedDir
	return FactionRegistry.PackDir(FactionRegistry.LoadedId()) if FactionRegistry.Pack != null else ""


## Where art set `set_id` may be, in order (see the header).
static func _set_roots(set_id: String) -> Array[String]:
	var roots: Array[String] = []
	if not IgnoreProjectFolder:
		roots.append("res://art/%s" % set_id)
	roots.append("%s/%s" % [UserArtRoot, set_id])
	return roots


## A pack row's picture: `fmt` with {k} = kind and {i} = id. The pack's own
## art/ is searched with the row itself; the art sets with the row its `art`
## names (the same row when it names none), in that set only when it names one.
static func _row(kind: String, id: String, fmt: String) -> Texture2D:
	var dot := id.find(".")
	var base := id if dot < 0 else id.substr(0, dot)
	var suffix := "" if dot < 0 else id.substr(dot)
	var a: Array = _alias(kind, base)
	return _find(fmt.format({"k": kind, "i": id}), fmt.format({"k": a[1], "i": str(a[2]) + suffix}), a[0])


## [set, kind, id] a row's pictures come from: its `art` reference, else itself.
static func _alias(kind: String, id: String) -> Array:
	_check_pack()
	if not _aliases.has("__built"):
		_aliases["__built"] = true
		var pack := FactionRegistry.Pack
		if pack != null:
			for pair in [["characters", pack.Characters], ["units", pack.Units], ["facilities", pack.Facilities],
					["missions", pack.Missions], ["planets", pack.Map.Planets if pack.Map != null else []]]:
				for row in pair[1]:
					if not row.Art.is_empty():
						var ref: Array = PackLoader.ParseArtRef(row.Art, pack.Manifest.ArtSets)
						if not ref.is_empty():
							_aliases["%s/%s" % [pair[0], row.Id]] = ref
	return _aliases.get("%s/%s" % [kind, id], ["", kind, id])


static func _texture(rel: String) -> Texture2D:
	return _find(rel, rel)


## The first picture found: `own_rel` in the pack's art/, then `set_rel` in
## each art set (only `only_set` when named). Cached per pack.
static func _find(own_rel: String, set_rel: String, only_set: String = "") -> Texture2D:
	_check_pack()
	var key := "%s|%s|%s" % [own_rel, set_rel, only_set]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var dir := _pack_dir()
	if not dir.is_empty():
		tex = _load("%s/art/%s" % [dir, own_rel])
	if tex == null:
		for s in _sets():
			if not only_set.is_empty() and s != only_set:
				continue
			for root in _set_roots(s):
				tex = _load("%s/%s" % [root, set_rel])
				if tex != null:
					break
			if tex != null:
				break
	_cache[key] = tex
	return tex


## Whether any copy of art set `set_id` is present (imported, or a checkout's
## export) - a folder with something in it.
static func HasArtSet(set_id: String) -> bool:
	for root in _set_roots(set_id):
		if not DirAccess.dir_exists_absolute(root):
			continue
		if not DirAccess.get_files_at(root).is_empty() or not DirAccess.get_directories_at(root).is_empty():
			return true
	return false


## One picture by path, or null: an imported resource under res://, a plain
## PNG under user://.
static func _load(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
