extends SceneTree
## The pack-selection plumbing: a pack is chosen by id (caller, `--pack=`,
## then packs/active.json), every pack is listable, the loaded pack signs the
## command-log header with its id and content hash, and a save, replay,
## snapshot or multiplayer room recorded on another pack is refused by name.
##
##   .\tools\run-gd.ps1 tests/pack_plumbing.gd -- --pack=ww2
##   .	ools
##   .\tools\run-gd.ps1 tests/replay.gd -- --log=user://ww2-plumb.jsonl
##
## Run WITH --pack=ww2: that is how the argument path is proven, while
## packs/active.json (Star Wars) stays untouched. The second line replays the
## log this test records in a fresh process that names no pack: the header
## must pick ww2 and every day hash must match.

var _ran := 0
var _ok := 0


func _init() -> void:
	if not OS.get_cmdline_user_args().has("--pack=ww2"):
		print("[pack_plumbing] SKIP: run with -- --pack=ww2 (the argument path is what it proves)")
		quit(0)
		return
	_check("--pack= wins over active.json", FactionRegistry.DefaultPackId() == "ww2",
		"DefaultPackId() = '%s'" % FactionRegistry.DefaultPackId())

	var ids := FactionRegistry.ListPackIds()
	_check("every pack folder is listed", ids.has("star-wars-rebellion") and ids.has("ww2"), str(ids))

	_check("EnsureLoaded() with no id loads the default", FactionRegistry.EnsureLoaded() and FactionRegistry.LoadedId() == "ww2",
		"loaded '%s'" % FactionRegistry.LoadedId())
	_check("loading the same pack again is a no-op", FactionRegistry.EnsureLoaded("ww2") and FactionRegistry.LoadedId() == "ww2", "")

	var h := FactionRegistry.PackHash
	_check("the loaded pack has a SHA-256 content hash", h.length() == 64 and h.is_valid_hex_number(), "hash '%s'" % h)
	var sw := FactionRegistry.ContentHash("%s/star-wars-rebellion" % FactionRegistry.PACKS_ROOT)
	_check("two packs hash differently", sw != h and sw.length() == 64, "sw '%s'" % sw.substr(0, 12))
	_check("the hash is stable", FactionRegistry.ContentHash("%s/ww2" % FactionRegistry.PACKS_ROOT) == h, "")

	var header := CommandLog.Header()
	_check("the command-log header names the pack", str(header.get("pack", "")) == "ww2", str(header))
	_check("the command-log header carries the content hash", str(header.get("pack_hash", "")) == h, "")

	_check("a header with no pack is accepted (pre-plumbing logs)", FactionRegistry.HeaderMismatch({"seed": 1}).is_empty(), "")
	_check("a header on the loaded pack is accepted", FactionRegistry.HeaderMismatch({"pack": "ww2"}).is_empty(), "")
	var why := FactionRegistry.HeaderMismatch({"pack": "star-wars-rebellion"})
	_check("a header on another pack is refused by name", why.contains("star-wars-rebellion") and why.contains("ww2"), why)

	var engine := Replayer.replay_entries({"pack": "star-wars-rebellion", "seed": 1, "local": "alliance"}, [])
	_check("Replayer refuses a log from another pack", engine == null, "")

	_check("a room with no pack key is playable (older host)", MpSetup.pack_mismatch({"side": "axis"}).is_empty(), "")
	_check("a room on the same pack and content is playable", MpSetup.pack_mismatch({"pack": "ww2", "pack_hash": h}).is_empty(), "")
	var other := MpSetup.pack_mismatch({"pack": "star-wars-rebellion", "pack_hash": sw})
	_check("a room on another pack is refused", other.contains("star-wars-rebellion"), other)
	var drift := MpSetup.pack_mismatch({"pack": "ww2", "pack_hash": "0000"})
	_check("a room on the same id with different files is refused", drift.contains("different files"), drift)

	# A real log, for the cross-process half: tests/replay.gd reads this file in a
	# FRESH process with no --pack and must pick ww2 from the header (and must be
	# refused when --pack=star-wars-rebellion is forced). See the header comment.
	var engine2: StrategicTickManager = GameSession.new_game("allies", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 99)
	CommandLog.Open("user://ww2-plumb.jsonl", CommandLog.Header())
	_check("an order on the recorded game", CommandBus.issue("droid", {"manage": "production", "on": true}).ok, "")
	for _i in 5:
		engine2.AdvanceDay()
		CommandBus.day_done()
	CommandLog.Reset()
	var back: Array = CommandLog.Read("user://ww2-plumb.jsonl")
	_check("the recorded log's header names ww2", str((back[0] as Dictionary).get("pack", "")) == "ww2", str(back[0]))
	_check("the recorded log carries 5 day hashes", (back[2] as Dictionary).size() == 5, str((back[2] as Dictionary).size()))

	print("[pack_plumbing] %d ran, %d ok, %d failed" % [_ran, _ok, _ran - _ok])
	quit(0 if _ok == _ran else 1)


func _check(what: String, cond: bool, detail: String) -> void:
	_ran += 1
	if cond:
		_ok += 1
		print("[pack_plumbing] ok   %s" % what)
	else:
		print("[pack_plumbing] FAIL %s  %s" % [what, detail])
