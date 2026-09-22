class_name FactionRegistry
extends RefCounted
## backend/Packs/FactionRegistry.cs - the sides in the loaded pack. Which pack to
## load is CONFIG, not code: packs/active.json names it. The engine holds no
## default pack id.

const PACKS_ROOT := "res://packs"

## THE LOADED PACK. Held here because this is what loads it, and the map, the
## rules and the catalogs all need it after the factions are built.
static var Pack: PackLoader.LoadedPack = null
static var Playable: Array[Faction] = []
static var Neutral: Faction = null
static var Unknown: Faction = null
static var _by_id: Dictionary = {}


static func IsLoaded() -> bool:
	return Playable.size() > 0


static func EnsureLoaded() -> void:
	if IsLoaded():
		return
	var active: Variant = JsonUtil.parse("%s/active.json" % PACKS_ROOT)
	if active == null:
		push_error("%s/active.json is missing; it must name the pack to load." % PACKS_ROOT)
		assert(false)
		return
	var pack_id: String = str(JsonUtil.get_ci(active, "pack"))
	var errors: Array[String] = []
	var pack := PackLoader.Load("%s/%s" % [PACKS_ROOT, pack_id], errors)
	if pack == null:
		push_error("[Pack] '%s' failed to load - %d problem(s):" % [pack_id, errors.size()])
		for e in errors:
			push_error("[Pack]   %s" % e)
		assert(false)
		return
	Load(pack)
	print("[Pack] '%s' loaded from %s/%s." % [pack.Manifest.DisplayName, PACKS_ROOT, pack_id])


static func Load(pack: PackLoader.LoadedPack) -> void:
	Pack = pack
	_by_id.clear()
	var playable: Array[Faction] = []
	for def in pack.Factions:
		var f := Faction.FromPack(def)
		playable.append(f)
		_by_id[f.Id] = f
	Playable = playable

	var n := pack.Manifest.Neutral
	Neutral = Faction.Simple(n.Id, n.DisplayName, ParseColor(n.ColorHex))
	_by_id[Neutral.Id] = Neutral

	Unknown = Faction.Simple("unknown", "Unexplored", ParseColor(pack.Manifest.UnexploredColor))

	var ids: Array[String] = []
	for f in Playable:
		ids.append(f.Id)
	print("[Pack] Factions loaded: %s (+%s)" % [", ".join(ids), Neutral.Id])


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
