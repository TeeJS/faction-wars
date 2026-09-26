extends SceneTree
## A pack switch leaves nothing behind: a game started after the Cockpit exits
## back to the picker and another pack is chosen must hash EXACTLY like the
## same game in a fresh process. Two runs, in this order:
##
##   .\tools\run-gd.ps1 tests/pack_switch.gd -- --pack=ww2 --write
##       (fresh process: WWII from the start; writes the day hashes to
##        user://pack-switch-ww2.txt)
##   .\tools\run-gd.ps1 tests/pack_switch.gd
##       (Star Wars loaded and played first, then FactionRegistry.Unload and
##        WWII loaded - the picker's return path - and the same game compared)
##
## Every static the pack fills is exercised by the first game: catalogs, rules,
## seeding, the GID catalog, missions.

const OUT := "user://pack-switch-ww2.txt"
const DAYS := 12
const SEED := 4242


func _init() -> void:
	await process_frame
	var write := OS.get_cmdline_user_args().has("--write")
	if write:
		FactionRegistry.EnsureLoaded("ww2")
		var hashes := _play("allies", SEED, DAYS)
		var f := FileAccess.open(OUT, FileAccess.WRITE)
		f.store_string("\n".join(hashes))
		f.close()
		print("[pack_switch] wrote %d day hashes for a fresh-process WWII game to %s" % [hashes.size(), OUT])
		quit(0)
		return

	if not FileAccess.file_exists(OUT):
		print("[pack_switch] SKIP: run first with -- --pack=ww2 --write")
		quit(0)
		return
	var expected: PackedStringArray = FileAccess.get_file_as_string(OUT).split("\n")

	# 1. Star Wars, loaded the way the Cockpit loads it, and played a while.
	FactionRegistry.EnsureLoaded("star-wars-rebellion")
	var sw := _play("alliance", 12345, 8)
	print("[pack_switch] played %d Star Wars days first" % sw.size())

	# 2. The picker's return path, then WWII.
	FactionRegistry.Unload()
	var ok := FactionRegistry.EnsureLoaded("ww2")
	if not ok:
		print("[pack_switch] FAIL: could not load ww2 after Unload")
		quit(1)
		return
	var got := _play("allies", SEED, DAYS)

	var first_bad := -1
	for i in got.size():
		if i >= expected.size() or got[i] != expected[i]:
			first_bad = i + 1
			break
	var fails := 0
	if first_bad < 0 and got.size() == expected.size():
		print("[pack_switch] ok   %d day hashes after the switch match the fresh-process game" % got.size())
	else:
		fails += 1
		print("[pack_switch] FAIL: day hashes diverge at day %d (%d vs %d recorded)" % [first_bad, got.size(), expected.size()])

	# 3. Two versions of one pack (strangers plan PR 3): a copy of WWII that
	# differs only in its summary, kept as an archived version, found by its
	# hash and switched to from the loaded WWII - the head-to-head join's path.
	# The same simulation, so the same hashes as the fresh process.
	fails += _other_version(expected)
	quit(0 if fails == 0 else 1)


func _other_version(expected: PackedStringArray) -> int:
	var fails := 0
	var real_root := FactionRegistry.PACK_VERSIONS_ROOT
	FactionRegistry.PACK_VERSIONS_ROOT = "user://test-pack-switch-versions"
	_remove(FactionRegistry.PACK_VERSIONS_ROOT)
	var staging := "user://test-pack-switch-staging/ww2"
	_remove(staging.get_base_dir())
	DirAccess.make_dir_recursive_absolute(staging)
	for f in DirAccess.get_files_at("res://packs/ww2"):
		if f.ends_with(".import"):
			continue
		var bytes := FileAccess.get_file_as_bytes("res://packs/ww2/" + f)
		if f == "pack.json":
			var d: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
			d["summary"] = "Another version of the WWII pack."
			d["version"] = "1.1"
			bytes = (JSON.stringify(d, "  ") + "\n").to_utf8_buffer()
		var w := FileAccess.open("%s/%s" % [staging, f], FileAccess.WRITE)
		w.store_buffer(bytes)
		w.close()
	var hash := FactionRegistry.ContentHash(staging)
	var dir := "%s/%s/ww2" % [FactionRegistry.PACK_VERSIONS_ROOT, hash.substr(0, 16).to_lower()]
	DirAccess.make_dir_recursive_absolute(dir.get_base_dir())
	DirAccess.rename_absolute(staging, dir)
	FactionRegistry.ClearHashCache()

	var shipped_hash := FactionRegistry.PackHash
	var found := FactionRegistry.FindByHash("ww2", hash)
	fails += _ok(hash != shipped_hash and found == dir and FactionRegistry.FindByHash("ww2", shipped_hash) == "res://packs/ww2",
		"FindByHash tells the two versions of ww2 apart: the archived copy and the shipped one")
	var broken := "user://test-pack-switch-staging/broken/ww2"
	DirAccess.make_dir_recursive_absolute(broken)
	fails += _ok(not FactionRegistry.SwitchTo(broken) and FactionRegistry.LoadedDir == "res://packs/ww2" and FactionRegistry.PackHash == shipped_hash,
		"SwitchTo a folder that will not load: false, and the loaded pack stays")
	fails += _ok(FactionRegistry.SwitchTo(found) and FactionRegistry.LoadedDir == dir and FactionRegistry.PackHash == hash
		and FactionRegistry.LoadedId() == "ww2" and FactionRegistry.Pack.Manifest.Version == "1.1", "SwitchTo the archived version: loaded, with its own hash")
	var got := _play("allies", SEED, DAYS)
	var same := got.size() == expected.size()
	for i in got.size():
		if i >= expected.size() or got[i] != expected[i]:
			same = false
	fails += _ok(same, "%d day hashes on the other version match the fresh-process game" % got.size())
	_remove(FactionRegistry.PACK_VERSIONS_ROOT)
	_remove(staging.get_base_dir())
	FactionRegistry.PACK_VERSIONS_ROOT = real_root
	FactionRegistry.ClearHashCache()
	return fails


static func _ok(cond: bool, what: String) -> int:
	print("[pack_switch] %s %s" % ["ok  " if cond else "FAIL", what])
	return 0 if cond else 1


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)


## A single-player game from day zero, the AI on both sides is not needed -
## the day-zero seeding, the economy and the missions tick are what a stale
## catalog would corrupt. Returns the hash after each day.
static func _play(faction: String, seed: int, days: int) -> Array[String]:
	var engine: StrategicTickManager = GameSession.new_game(faction, Enums.Difficulty.Medium, Enums.GalaxySize.Standard, seed)
	var out: Array[String] = [GameSignature.ReplayHash(GameState.ActiveGalaxy)]
	for _i in days:
		engine.AdvanceDay()
		out.append(GameSignature.ReplayHash(GameState.ActiveGalaxy))
	return out
