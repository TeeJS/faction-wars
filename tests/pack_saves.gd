extends SceneTree
## EACH PACK KEEPS ITS OWN SAVED GAMES (src/game/save_manager.gd header; TeeJ,
## 2026-09-30). The list every pack shared is copied into each pack's folder
## the first time that pack's list is read - by the pack each game's header
## names, a header naming none counting as Star Wars - and left untouched; a
## save goes to the loaded pack's folder; an import goes to the folder of the
## pack it was played on. Runs against a scratch save directory:
##
##   .\tools\run-gd.ps1 tests/pack_saves.gd -- --pack=star-wars-rebellion

var _fails := 0
var _checks := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("[pack_saves] ok   %s" % what)
	else:
		_fails += 1
		print("[pack_saves] FAIL %s" % what)


func _init() -> void:
	await process_frame
	FactionRegistry.EnsureLoaded()
	MpSetup.reset()
	var sw: String = FactionRegistry.LoadedId()
	_check(sw == SaveManager.PACK_BEFORE_HEADERS, "runs on the Star Wars pack (%s)" % sw)
	SaveManager.Dir = "user://test-pack-saves"
	_remove(SaveManager.Dir)

	# The shared list as a build before this one left it: a Star Wars game, a
	# WWII game, one whose header names no pack, one whose file is gone.
	var shared := {"next": 9, "seq": 12, "games": {
		"g1": {"name": "Rebel run", "day": 30, "saved_at": "2026-09-27T10:00:00", "side": "alliance", "seq": 10},
		"g2": {"name": "Blitz", "day": 12, "saved_at": "2026-09-29T10:00:00", "side": "axis", "seq": 12},
		"g3": {"name": "Very old", "day": 5, "saved_at": "2026-09-20T10:00:00", "side": "empire", "seq": 3},
		"g4": {"name": "Lost file", "day": 1, "saved_at": "2026-09-21T10:00:00", "side": "empire", "seq": 4},
	}}
	var files := {
		"g1": '{"pack":"star-wars-rebellion","seed":1}\n{"day":1}\n',
		"g2": '{"pack":"ww2","seed":2}\n{"day":1}\n',
		"g3": '{"seed":3}\n{"day":1}\n',
	}
	DirAccess.make_dir_recursive_absolute("%s/games" % SaveManager.Dir)
	for id: String in files:
		_write("%s/games/%s.jsonl" % [SaveManager.Dir, id], files[id])
	_write("%s/games.json" % SaveManager.Dir, JSON.stringify(shared))
	var shared_before: String = FileAccess.get_file_as_string("%s/games.json" % SaveManager.Dir)

	# The loaded pack's list: its own games only, in their order.
	var names: Array = SaveManager.Games().map(func(g: Dictionary) -> String: return g["name"])
	_check(names == ["Rebel run", "Very old"], "Star Wars lists its game and the headerless one, newest first (%s)" % str(names))
	var g1: Dictionary = SaveManager.Games()[0]
	_check(g1["id"] == "g1" and g1["day"] == 30 and g1["side"] == "alliance" and g1["saved_at"] == "2026-09-27T10:00:00", "same id, day, side and saved date")
	_check(SaveManager.GamePath("g1") == "%s/%s/games/g1.jsonl" % [SaveManager.Dir, sw] and FileAccess.get_file_as_string(SaveManager.GamePath("g1")) == files["g1"],
		"the file is copied into the pack's folder, byte for byte")
	names = SaveManager.Games("ww2").map(func(g: Dictionary) -> String: return g["name"])
	_check(names == ["Blitz"], "World War II lists only its own (%s)" % str(names))

	# The shared list is left as it was.
	_check(FileAccess.get_file_as_string("%s/games.json" % SaveManager.Dir) == shared_before, "the shared list is unchanged")
	var kept := true
	for id: String in files:
		kept = kept and FileAccess.get_file_as_string("%s/games/%s.jsonl" % [SaveManager.Dir, id]) == files[id]
	_check(kept, "the shared files are unchanged")

	# Once only: a game deleted from a pack's list stays deleted.
	_check(SaveManager.Delete("g3") and FileAccess.file_exists("%s/games/g3.jsonl" % SaveManager.Dir), "Delete removes the pack's copy, not the shared file")
	names = SaveManager.Games().map(func(g: Dictionary) -> String: return g["name"])
	_check(names == ["Rebel run"], "the copy happens once (%s)" % str(names))

	# A save goes to the loaded pack, numbered after the shared list's games.
	GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Standard, 4243)
	CommandLog.Open("user://test-pack-saves-gen.jsonl", CommandLog.Header())
	var saved: String = SaveManager.Save("New one")
	CommandLog.Close()
	_check(saved == "g9" and FileAccess.file_exists("%s/%s/games/g9.jsonl" % [SaveManager.Dir, sw]), "a new save is g9, in the pack's folder (%s)" % saved)
	_check(SaveManager.Games()[0]["name"] == "New one" and SaveManager.Games("ww2").size() == 1, "it lists as the newest, and not under World War II")

	# An import goes to the pack it was played on.
	var text := JSON.stringify({"fwsave": 1, "name": "Torch", "saved_at": "2026-09-30T09:00:00", "day": 40, "side": "allies"}) + "\n" + '{"pack":"ww2","seed":7,"local":"allies"}\n{"day":1}\n'
	var r: Dictionary = SaveManager.Import(text.to_utf8_buffer(), "Torch.fwsave")
	_check(r["ok"] and r["pack"] == "ww2", "a World War II file imports (%s)" % str(r))
	_check(SaveManager.Find("Torch", "ww2") == r["id"] and SaveManager.Find("Torch").is_empty(), "into World War II's list, not the loaded one")
	var note: String = SaveManager.ImportNote(r)
	_check(note.contains("World War II") and note.contains("Torch"), "the player is told where it went (%s)" % note)
	var mine: Dictionary = SaveManager.Import(('{"pack":"%s","seed":8}\n{"day":1}\n' % sw).to_utf8_buffer(), "Mine.jsonl")
	_check(mine["ok"] and SaveManager.Find("Mine") == mine["id"] and SaveManager.ImportNote(mine) == "\"Mine\" is in your saved games.", "the loaded pack's own file lands in its list, as before")
	var evil: Dictionary = SaveManager.Import('{"pack":"../escape","seed":9}\n'.to_utf8_buffer(), "Evil.jsonl")
	_check(not evil["ok"], "a pack id that is not a folder name is refused (%s)" % str(evil["message"]))

	_remove(SaveManager.Dir)
	DirAccess.remove_absolute("user://test-pack-saves-gen.jsonl")
	print("[pack_saves] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove("%s/%s" % [path, sub])
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file])
	DirAccess.remove_absolute(path)
