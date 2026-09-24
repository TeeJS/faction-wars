extends SceneTree
## A pack author's comments are never data (SCHEMA.md section 1; the editor
## handoff, 2026-09-23): a copy of the Star Wars pack with a "_comment" in
## EVERY JSON object - top-level, each record, and every keyed map (ratings,
## stats, weapons, flags, targets, mission tables, logistics, rules'
## By_Faction, display terms and icons) - loads with no errors, hydrates to
## what the pack itself does, and no keyed map has a "_comment" key. Before, a "_comment" in
## mission_tables.tables was a script error and one in setup's logistics a
## crash at game start.
##
##   .\tools\run-gd.ps1 tests/pack_comments.gd

const ID := "star-wars-rebellion"
const ROOT := "user://test-pack-comments"
const NOTE := "a pack author's note"

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[pack_comments] ok   %s" % what)
	else:
		_fails += 1
		print("[pack_comments] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded(ID)
	var dir := "%s/%s" % [ROOT, ID]   # rule 1: the folder is the pack's id
	_remove(ROOT)
	DirAccess.make_dir_recursive_absolute(dir)
	var added := 0
	for f in FactionRegistry.PACK_FILES:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://packs/%s/%s" % [ID, f]))
		added += _comment_everywhere(data)
		var out := FileAccess.open("%s/%s" % [dir, f], FileAccess.WRITE)
		out.store_string(JSON.stringify(data, "  "))
		out.close()
	_check(added > 1000, "%d comments written into the copy" % added)

	var errors: Array[String] = []
	var commented := PackLoader.Load(dir, errors)
	_check(commented != null and errors.is_empty(), "the commented copy loads with no errors (%s)" % "; ".join(errors.slice(0, 5)))
	var plain_errors: Array[String] = []
	var plain := PackLoader.Load("res://packs/%s" % ID, plain_errors)
	if commented != null and plain != null:
		# Records the engine keeps as read (rules rows, logistics tables) keep
		# the note as it was - harmless, since their fields are read by name.
		# A note turned into data (a rating, a flag, a table) is not the note's
		# text any more, so it still shows as a difference.
		var a: PackedStringArray = JSON.stringify(_strip(JSON.parse_string(Canonical.to_json(_dump(commented)))), "  ", true).split("\n")
		var b: PackedStringArray = JSON.stringify(JSON.parse_string(Canonical.to_json(_dump(plain))), "  ", true).split("\n")
		var first := -1
		for i in mini(a.size(), b.size()):
			if a[i] != b[i]:
				first = i
				break
		_check(first < 0 and a.size() == b.size(), "... and hydrates to what the pack does%s" % ("" if first < 0 else
			" (first difference at line %d: '%s' vs '%s')" % [first + 1, a[first].strip_edges(), b[first].strip_edges()]))
		# Every keyed map, by name: no "_comment" among its keys.
		var maps: Array = [commented.MissionTables, commented.Setup.Logistics, commented.Display.Terms,
			commented.Display.Icons, commented.Display.SpecialPowerRanks]
		for c in commented.Characters:
			maps.append(c.Ratings)
		for f in commented.Facilities:
			maps.append(f.Stats)
		for u in commented.Units:
			maps.append_array([u.Weapons, u.Stats])
		for m in commented.Missions:
			maps.append_array([m.Flags, m.Targets])
		# The rule rows and the side lottery hydrate when a game starts.
		for row in commented.Rules:
			var rule := CatalogDtos.GameRuleData.from_dict(row)
			maps.append(rule.By_Faction)
			maps.append_array(rule.By_Faction.values())
		for row in commented.Setup.SideLottery:
			var side := CatalogDtos.SideRuleData.from_dict(row)
			maps.append(side.By_Faction)
			for by_diff in side.By_Faction.values():
				maps.append(by_diff)
				maps.append_array((by_diff as Dictionary).values())
		var keyed: int = Lq.count(maps, func(d: Dictionary) -> bool: return d.has("_comment"))
		_check(keyed == 0, "none of %d keyed maps has a key named _comment (%d do)" % [maps.size(), keyed])
	_remove(ROOT)
	print("[pack_comments] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The tree without the note where it stands exactly as written.
func _strip(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			if k == "_comment" and v[k] is String and v[k] == NOTE:
				continue
			out[k] = _strip(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x): return _strip(x))
	return v


## Adds "_comment" to every object in the tree; returns how many.
func _comment_everywhere(v: Variant) -> int:
	var n := 0
	if v is Dictionary:
		for k in (v as Dictionary).keys():
			n += _comment_everywhere(v[k])
		v["_comment"] = NOTE
		n += 1
	elif v is Array:
		for x in v:
			n += _comment_everywhere(x)
	return n


func _dump(pack: PackLoader.LoadedPack) -> Dictionary:
	return {
		"pack_manifest": pack.Manifest, "factions": pack.Factions, "map": pack.Map,
		"characters": pack.Characters, "facilities": pack.Facilities, "units": pack.Units,
		"weapons": pack.Weapons, "missions": pack.Missions, "mission_tables": pack.MissionTables,
		"rules": pack.Rules, "setup": pack.Setup, "display": pack.Display,
	}


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
