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
	if first_bad < 0 and got.size() == expected.size():
		print("[pack_switch] ok   %d day hashes after the switch match the fresh-process game" % got.size())
		quit(0)
	else:
		print("[pack_switch] FAIL: day hashes diverge at day %d (%d vs %d recorded)" % [first_bad, got.size(), expected.size()])
		quit(1)


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
