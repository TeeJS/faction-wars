class_name FactionRegistry
extends RefCounted
## backend/Packs/FactionRegistry.cs - the sides in the loaded pack. Which pack to
## load is CONFIG, not code: a caller names it (the pack picker, a save's header,
## a multiplayer room), else the `--pack=<id>` command-line argument, else
## packs/active.json. The engine holds no default pack id.
##
## ONE PACK AT A TIME. Every catalog is static state filled from the pack, so
## a second, different load is refused rather than half-applied. The ways to
## switch go through Unload(), and they have two callers, both before any game
## exists: the pack picker, when the Cockpit exits back to it, and a
## head-to-head join onto another version of a pack (SwitchTo). Nothing is
## mid-game then, and GameSession.load_catalogs refills every catalog from the
## new pack at StartGame. A game never changes pack mid-process.

const PACKS_ROOT := "res://packs"
## Packs the player imported (docs/original-art-plan.md): the same layout,
## in the user folder (browser storage on the web). A shipped pack wins.
## A static var, not a const, so a test can point it at a scratch folder and
## never touch a player's imported packs (as Artwork.UserArtRoot).
static var USER_PACKS_ROOT := "user://packs"
## Every other installed version of an imported pack (strangers plan, 2026-09-26):
## <root>/<first 16 of its content hash>/<id>/. The current version stays at
## USER_PACKS_ROOT/<id>, so the picker and the loader are unchanged, and the last
## folder of an archived one is still the pack's id, as the loader requires. A
## head-to-head game on an older version finds it here (FindByHash). A static
## var, so a test can point it at a scratch folder.
static var PACK_VERSIONS_ROOT := "user://pack-versions"
## Content hash per pack folder, so FindByHash does not re-read every version
## each time it looks. Cleared on every import and removal.
static var _hash_cache: Dictionary = {}
## The files a pack is made of - what PackLoader.Load reads and what the
## content hash covers, so two clients on the same pack id but different
## content are told so instead of desyncing (BACKLOG #13).
const PACK_FILES := ["pack.json", "factions.json", "map.json", "characters.json",
	"facilities.json", "units.json", "weapons.json", "missions.json",
	"mission_tables.json", "rules.json", "setup.json", "display.json"]

## THE LOADED PACK. Held here because this is what loads it, and the map, the
## rules and the catalogs all need it after the factions are built.
static var Pack: PackLoader.LoadedPack = null
static var Playable: Array[Faction] = []
static var Neutral: Faction = null
static var Unknown: Faction = null
static var _by_id: Dictionary = {}
static var _character_roles: Dictionary = {}   # character id -> Array[String]
static var _character_starts: Dictionary = {}  # character id -> planet id ("" = none)
## The loaded pack's folder: res://packs/<id> or user://packs/<id>.
static var LoadedDir: String = ""
## SHA-256 over PACK_FILES of the loaded pack, hex. Travels in the command-log
## header and the multiplayer room settings.
static var PackHash: String = ""


static func IsLoaded() -> bool:
	return Playable.size() > 0


## The loaded pack's id, or "" before any load.
static func LoadedId() -> String:
	return Pack.Manifest.Id if Pack != null else ""


## Which pack to load when nobody names one: `--pack=<id>` on the command line
## (headless tests, the soak gate), else packs/active.json.
static func DefaultPackId() -> String:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--pack="):
			return a.substr("--pack=".length())
	var active: Variant = JsonUtil.parse("%s/active.json" % PACKS_ROOT)
	if active == null:
		push_error("%s/active.json is missing; it must name the pack to load." % PACKS_ROOT)
		return ""
	return str(JsonUtil.get_ci(active, "pack"))


## Every folder under packs/ (shipped) or user://packs/ (imported) that
## carries a pack.json, sorted - the picker's list.
static func ListPackIds() -> Array[String]:
	var out: Array[String] = []
	for root in [PACKS_ROOT, USER_PACKS_ROOT]:
		var dir := DirAccess.open(root)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if dir.current_is_dir() and not name.begins_with(".") and not out.has(name) \
					and FileAccess.file_exists("%s/%s/pack.json" % [root, name]):
				out.append(name)
			name = dir.get_next()
		dir.list_dir_end()
	out.sort()
	return out


## Where pack `pack_id` lives: the shipped res://packs/<id>, else the
## imported user://packs/<id>.
static func PackDir(pack_id: String) -> String:
	var shipped := "%s/%s" % [PACKS_ROOT, pack_id]
	if FileAccess.file_exists("%s/pack.json" % shipped):
		return shipped
	var imported := "%s/%s" % [USER_PACKS_ROOT, pack_id]
	return imported if FileAccess.file_exists("%s/pack.json" % imported) else shipped


## Load `pack_id`, or the default when it is empty. Loading the pack that is
## already loaded is a no-op; asking for a DIFFERENT one is an error (one pack
## per process). Returns false on any failure, after reporting it.
static func EnsureLoaded(pack_id: String = "") -> bool:
	if IsLoaded():
		# No id means "whatever is loaded" - the default is only consulted when
		# nothing is, or a save opened from another pack would trip every later
		# bare EnsureLoaded() call on the active.json name.
		if pack_id.is_empty() or pack_id == LoadedId():
			return true
		push_error("[Pack] '%s' is loaded; cannot switch to '%s' in the same process." % [LoadedId(), pack_id])
		return false
	if pack_id.is_empty():
		pack_id = DefaultPackId()
	if pack_id.is_empty():
		push_error("[Pack] nothing names a pack to load (no caller id, no --pack=, no packs/active.json).")
		return false
	var errors: Array[String] = []
	var dir := PackDir(pack_id)
	var pack := PackLoader.Load(dir, errors)
	if pack == null:
		push_error("[Pack] '%s' failed to load - %d problem(s):" % [pack_id, errors.size()])
		for e in errors:
			push_error("[Pack]   %s" % e)
		assert(false)
		return false
	Load(pack)
	LoadedDir = dir
	PackHash = ContentHash(dir)
	print("[Pack] '%s' loaded from %s (hash %s)." % [pack.Manifest.DisplayName, dir, PackHash.substr(0, 12)])
	return true


## Forget the loaded pack so another can be chosen. The pack picker's call, on
## the way back from the Cockpit, and SwitchTo's, joining a head-to-head game
## on another version: nothing is mid-game either time, and the catalogs the
## old pack filled are all refilled by GameSession.load_catalogs before the
## next day zero. tests/pack_switch.gd proves a game after a switch hashes
## exactly like one in a fresh process.
static func Unload() -> void:
	Pack = null
	Playable = []
	Neutral = null
	Unknown = null
	_by_id.clear()
	_character_roles.clear()
	_character_starts.clear()
	_icons.clear()
	PackHash = ""
	LoadedDir = ""


## Load the pack at `dir` in place of the loaded one - a head-to-head join onto
## the version the host plays (strangers plan PR 5). Loaded FIRST: a pack that
## fails to load leaves the old one loaded and returns false (EnsureLoaded's
## failure path asserts, and the Multiplayer Options screen reads Playable[0]).
static func SwitchTo(dir: String) -> bool:
	var errors: Array[String] = []
	var pack := PackLoader.Load(dir, errors)
	if pack == null:
		push_warning("[Pack] could not switch to %s: %s" % [dir, "; ".join(errors)])
		return false
	Unload()
	Load(pack)
	LoadedDir = dir
	PackHash = ContentHash(dir)
	(load("res://src/ui/artwork.gd") as GDScript).call("Reset")
	print("[Pack] switched to '%s' from %s (hash %s)." % [pack.Manifest.DisplayName, dir, PackHash.substr(0, 12)])
	return true


## Every installed copy of pack `pack_id`: the shipped one, the imported
## current one, and the archived versions (PACK_VERSIONS_ROOT).
static func VersionDirs(pack_id: String) -> Array[String]:
	var out: Array[String] = []
	for d in ["%s/%s" % [PACKS_ROOT, pack_id], "%s/%s" % [USER_PACKS_ROOT, pack_id]]:
		if FileAccess.file_exists("%s/pack.json" % d):
			out.append(d)
	if DirAccess.dir_exists_absolute(PACK_VERSIONS_ROOT):
		for h in DirAccess.get_directories_at(PACK_VERSIONS_ROOT):
			var d := "%s/%s/%s" % [PACK_VERSIONS_ROOT, h, pack_id]
			if FileAccess.file_exists("%s/pack.json" % d):
				out.append(d)
	return out


## The folder of the installed copy of `pack_id` whose content hash is
## `hash`, or "" when there is none.
static func FindByHash(pack_id: String, hash: String) -> String:
	if hash.is_empty():
		return ""
	for d in VersionDirs(pack_id):
		if HashOf(d) == hash:
			return d
	return ""


## ContentHash, remembered per folder until the next import or removal.
static func HashOf(pack_dir: String) -> String:
	if not _hash_cache.has(pack_dir):
		_hash_cache[pack_dir] = ContentHash(pack_dir)
	return _hash_cache[pack_dir]


static func ClearHashCache() -> void:
	_hash_cache.clear()


## SHA-256 over the pack's JSON files, in PACK_FILES order. JSON only: an
## exported build ships images as .import remaps, so the bytes of a picture are
## not the same file on every client, and a picture never touches the simulation.
static func ContentHash(pack_dir: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for f in PACK_FILES:
		var path := "%s/%s" % [pack_dir, f]
		if FileAccess.file_exists(path):
			ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


## Why a saved game / replay / snapshot recorded under `header` cannot run on
## the loaded pack, or "" when it can. No `pack` key means "whatever is loaded"
## (the pre-plumbing headers). The id is what refuses; a content-hash
## difference is the multiplayer hello's business.
static func HeaderMismatch(header: Dictionary) -> String:
	var want := str(header.get("pack", ""))
	if want.is_empty():
		return ""
	if IsLoaded() and want != LoadedId():
		return "recorded on pack '%s'; '%s' is loaded" % [want, LoadedId()]
	if not IsLoaded() and not ListPackIds().has(want):
		return "recorded on pack '%s', which is not installed" % want
	return ""


static func Load(pack: PackLoader.LoadedPack) -> void:
	Pack = pack
	_by_id.clear()
	_icons.clear()
	_character_roles.clear()
	_character_starts.clear()
	for c in pack.Characters:
		_character_roles[c.Id] = c.Roles
		_character_starts[c.Id] = c.StartsAt
	var playable: Array[Faction] = []
	for def in pack.Factions:
		var f := Faction.FromPack(def)
		playable.append(f)
		_by_id[f.Id] = f
	Playable = playable

	var n := pack.Manifest.Neutral
	Neutral = Faction.Simple(n.Id, n.DisplayName, ParseColor(n.ColorHex))
	_by_id[Neutral.Id] = Neutral

	# The art sets name nobody's side "neutral", whatever the pack calls it.
	Neutral.ArtSkin = "neutral"
	Unknown = Faction.Simple("unknown", "Unexplored", ParseColor(pack.Manifest.UnexploredColor))

	var ids: Array[String] = []
	for f in Playable:
		ids.append(f.Id)
	print("[Pack] Factions loaded: %s (+%s)" % [", ".join(ids), Neutral.Id])


## A picture by path: an imported resource under res://, a plain file under
## user:// (an imported pack is not re-imported by the editor).
static func _load_texture(path: String) -> Texture2D:
	if not path.begins_with("user://"):
		return load(path) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null


## Declaration order in the pack.
static func OrderOf(f: Faction) -> int:
	for i in Playable.size():
		if Playable[i] == f:
			return i
	return -1


## C# `_byId` is a case-INSENSITIVE dictionary in effect? No - it is not: the
## source constructs it with the default comparer, and character data says
## "Alliance" while the pack says "alliance". FactionConverter resolves through
## here and the source comment promises case-insensitive resolution, so the
## lookup folds case. Kept exactly as the source behaves: exact key first.
static func ById(id: Variant) -> Faction:
	if id == null:
		return Unknown
	var key := str(id)
	if _by_id.has(key):
		return _by_id[key]
	var lower := key.to_lower()
	for k in _by_id.keys():
		if str(k).to_lower() == lower:
			return _by_id[k]
	return Unknown


## Use where a missing id is a bug rather than a data condition.
static func Require(id: String) -> Faction:
	var f := ById(id)
	if f != Unknown or id == "unknown":
		return f
	push_error("No faction '%s' in the loaded pack. Declared: %s." % [id, ", ".join(_by_id.keys())])
	assert(false)
	return null


## Every playable faction other than the given one.
static func Opponents(f: Faction) -> Array[Faction]:
	var out: Array[Faction] = []
	for p in Playable:
		if p != f:
			out.append(p)
	return out


static func ParseColor(hex: String) -> Color:
	return Color.html(hex)


## The display name behind a pack planet id, for text shown to the player. The
## id itself when the pack declares no such planet - visible, never blank.
static func PlanetNameOf(id: String) -> String:
	if Pack != null and Pack.Map != null:
		for pd in Pack.Map.Planets:
			if pd.Id == id:
				return pd.DisplayName
	return id


static func CharacterNameOf(id: String) -> String:
	if Pack != null:
		for cd in Pack.Characters:
			if cd.Id == id:
				return cd.DisplayName
	return id


## The roles characters.json gives this character (SCHEMA.md section 7).
static func CharacterRoles(id: String) -> Array:
	return _character_roles.get(id, [])


const ICONS_ROOT := "res://assets/icons"
static var _icons: Dictionary = {}   # glyph name -> Texture2D


## A sector-window corner glyph (manual p070 Fig 3.7): the pack's own picture
## when display.json `icons` names one, else the engine's assets/icons/<name>.png.
## White on alpha; the map tints it with the faction colour.
static func CornerIcon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var path := "%s/%s.png" % [ICONS_ROOT, name]
	if Pack != null and Pack.Display != null and Pack.Display.Icons.has(name):
		path = "%s/%s" % [LoadedDir if not LoadedDir.is_empty() else PackDir(Pack.Manifest.Id), Pack.Display.Icons[name]]
	var tex: Texture2D = _load_texture(path)
	if tex == null:
		push_error("[FactionRegistry] corner icon '%s' could not be loaded from %s." % [name, path])
	_icons[name] = tex
	return tex


## The playable sides left to right on the sector window's loyalty bar:
## display.json `loyalty_bar` when the pack declares it, else faction order.
static func LoyaltyBarOrder() -> Array[Faction]:
	var out: Array[Faction] = []
	if Pack != null and Pack.Display != null and not Pack.Display.LoyaltyBar.is_empty():
		for id in Pack.Display.LoyaltyBar:
			var f := ById(id)
			if f != null:
				out.append(f)
	if out.is_empty():
		for f in Playable:
			out.append(f)
	return out


## The planet id characters.json opens this character on, or "".
static func CharacterStartsAt(id: String) -> String:
	return _character_starts.get(id, "")
