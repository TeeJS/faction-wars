class_name SaveManager
extends RefCounted
## Single-player save/load, built on the command log (docs/m1-plan.md). The game
## is command-sourced and deterministic, so a SAVE is just the current command
## log copied to a file, and a LOAD replays that file through Replayer.
##
## Saved games are a list, newest first (PROJECT.md, signed off by TeeJ
## 2026-09-27). The Saved Games screen shows the newest; See all games shows
## every one. A game's NAME is its identity: saving under a name that is taken
## overwrites that game, a new name makes a new game.
##
## Game files:   <Dir>/games/<id>.jsonl   - a copy of the command log
## Game index:   <Dir>/games.json         - { "next": n, "games": { id: {name, day, saved_at, side, seq} } }
##
## `seq` orders the list (a save counter: two saves in one second keep their
## order); `saved_at` is shown. `side` is what the Saved Games screen's icon
## shows (manual p075: "an icon ... shows whether you were playing the Empire,
## the Alliance, or a head-to-head game"): the player's faction id, or "h2h".
##
## The six fixed slots this replaced (<Dir>/slot<N>.jsonl + slots.json) are
## copied into the list the first time it is read, and left untouched.
##
## HEAD-TO-HEAD (manual p163, issue #301): "only the host player can save the
## game. Star Wars Rebellion will create a saved game on both computers in the
## same saved game slots." A game's name is its identity here, so both
## computers write the game of the same name. SaveH2H writes one computer's
## copy: the header, then the game's relay lines (both sides' orders, phase
## ends, day hashes) up to the save point - what LockstepSession.rebuild_from_log
## resumes a game from, and a command log CommandLog.Read loads in single player
## (the AI then plays the opponent). Its index entry adds the two players'
## names, this computer's side and the room's settings, for the Multiplayer
## Options' Load Game list; its side is "h2h".
##
## Export / import: a .fwsave file is JSON lines - one line of the game's
## name, saved date, day and side, then the save itself, byte for byte.

## The save directory. A static var (not a const) so a headless test can point it
## at a scratch directory and never touch a player's real saves.
static var Dir := "user://saves"
## The default name for a game saved without one.
const DEFAULT_NAME := "Saved game"
## The first line of an exported file carries this key (and the format version).
const FWSAVE_KEY := "fwsave"
const FWSAVE_VERSION := 1
const OLD_SLOTS := 6
## What a head-to-head save's index entry adds (SaveH2H): the relay save's id,
## the two players' names, this computer's side, the side that seeded the
## galaxy and the room's settings.
const H2H_FIELDS := ["h2h_id", "host", "guest", "local", "seeded_by", "settings"]


static func GamePath(id: String) -> String:
	return "%s/games/%s.jsonl" % [Dir, id]


static func _index_path() -> String:
	return "%s/games.json" % Dir


# ---- the list ------------------------------------------------------------------

## Every saved game as [{id, name, day, saved_at, side}], newest first.
static func Games() -> Array:
	var idx: Dictionary = _index()
	var out: Array = []
	for id: String in idx["games"]:
		var g: Dictionary = idx["games"][id]
		if not FileAccess.file_exists(GamePath(id)):
			continue
		out.append({
			"id": id,
			"name": str(g.get("name", "")),
			"day": int(g.get("day", 0)),
			"saved_at": str(g.get("saved_at", "")),
			"side": str(g.get("side", "")),
			"seq": int(g.get("seq", 0)),
		})
		for k in H2H_FIELDS:
			if g.has(k):
				out[-1][k] = g[k]
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["seq"] > b["seq"])
	return out


## The newest `count` games, newest first.
static func Recent(count: int) -> Array:
	return Games().slice(0, count)


## The id of the game called `name`, or "".
static func Find(name: String) -> String:
	for g: Dictionary in Games():
		if g["name"] == name.strip_edges():
			return g["id"]
	return ""


## The name of game `id` ("" if there is none).
static func NameOf(id: String) -> String:
	return str(_index()["games"].get(id, {}).get("name", "")) if Exists(id) else ""


static func Exists(id: String) -> bool:
	return not id.is_empty() and FileAccess.file_exists(GamePath(id)) and _index()["games"].has(id)


## A name no game has: `base`, else "base (2)", "base (3)" ...
static func FreeName(base: String = DEFAULT_NAME) -> String:
	base = base.strip_edges()
	if base.is_empty():
		base = DEFAULT_NAME
	if Find(base).is_empty():
		return base
	var n := 2
	while not Find("%s (%d)" % [base, n]).is_empty():
		n += 1
	return "%s (%d)" % [base, n]


## What hovering a game shows: "Saved MM/DD/YYYY - Day N" (TeeJ, 2026-09-27),
## the day as the player sees it (StrategicTickManager.Shown, manual p033).
static func SavedLabel(g: Dictionary) -> String:
	return "Saved %s - Day %d" % [SavedDate(g), StrategicTickManager.Shown(int(g.get("day", 0)))]


## The saved date as MM/DD/YYYY ("" if unknown).
static func SavedDate(g: Dictionary) -> String:
	var d: PackedStringArray = str(g.get("saved_at", "")).get_slice("T", 0).split("-")
	if d.size() != 3:
		return ""
	return "%s/%s/%s" % [d[1], d[2], d[0]]


# ---- saving, loading, deleting ------------------------------------------------

## Save the current game under `name`: the game of that name is overwritten,
## or a new one is made. Either way it becomes the newest. Returns its id, or ""
## if there is no open log to save.
static func Save(name: String) -> String:
	# Snapshot flushes the open log and returns its full text. Empty means no
	# game/log is running - nothing to save.
	var content: String = CommandLog.Snapshot()
	if content.is_empty():
		push_error("[SaveManager] no open command log to save")
		return ""
	name = name.strip_edges()
	if name.is_empty():
		name = FreeName()
	var id: String = Find(name)
	var side: String = "h2h" if MpSetup.session != null else (GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else "")
	return _store(id, content, name, StrategicTickManager.Today, side)


static func Read(id: String) -> Array:
	if not Exists(id):
		return [{}, [], {}]
	return CommandLog.Read(GamePath(id))


## Remove a saved game (See all games' Delete). Returns false if there is none.
static func Delete(id: String) -> bool:
	if not Exists(id):
		return false
	var idx: Dictionary = _index()
	(idx["games"] as Dictionary).erase(id)
	_write_index(idx)
	DirAccess.remove_absolute(GamePath(id))
	return true


# ---- head-to-head -------------------------------------------------------------------

## One computer's copy of a head-to-head save (header above), as the game named
## `name` - the same name on both computers, so a name already used is that
## game, overwritten and made the newest. `history` is the session's relay
## lines (LockstepSession.history); the save point is the phases before
## `phase` and the day hashes up to `day`. `save` carries what both computers
## write alike: id, host, guest, settings, state_hash. Returns the game's id,
## or "" when it could not be written.
static func SaveH2H(name: String, history: Array, phase: int, day: int, save: Dictionary) -> String:
	name = name.strip_edges()
	if name.is_empty():
		name = FreeName()
	var header := CommandLog.Header()
	header["h2h"] = {
		"id": str(save.get("id", "")),
		"phase": phase,
		"day": day,
		"host": str(save.get("host", "")),
		"guest": str(save.get("guest", "")),
		"settings": save.get("settings", {}),
		"state_hash": str(save.get("state_hash", "")),
	}
	var text := PackedStringArray([JSON.stringify(header)])
	for m in H2HLines(history, phase, day):
		text.append(JSON.stringify(m))
	return _store(Find(name), "\n".join(text) + "\n", name, day, "h2h", {
		"h2h_id": str(save.get("id", "")),
		"host": str(save.get("host", "")),
		"guest": str(save.get("guest", "")),
		"local": str(header.get("local", "")),
		"seeded_by": str(header.get("host", "")),
		"settings": save.get("settings", {}),
	})


## The relay lines of a save: the orders and phase ends before `phase`, the day
## hashes up to `day`, each side's last speed. What rebuild_from_log reads of
## the ends before its resume tick is only the tick phases (to count days), so
## the ends of the other phases before it are dropped - an hour of play is
## some 24 000 of them (two every 0.3 s), and the Load sends the save to the
## relay line by line. The resume point is found as rebuild_from_log finds it.
static func H2HLines(history: Array, phase: int, day: int) -> Array:
	var kept: Array = []
	var speed: Dictionary = {}   # side -> its last speed line
	var ends: Dictionary = {}    # phase -> [end lines]
	var hash_sides: Dictionary = {}   # day -> { side: true }
	for m: Dictionary in history:
		match str(m.get("t", "")):
			"cmd":
				if int(m.get("phase", 0)) < phase:
					kept.append(m)
			"end":
				var p := int(m.get("phase", 0))
				if p < phase:
					if not ends.has(p):
						ends[p] = []
					ends[p].append(m)
			"hash":
				var d := int(m.get("day", 0))
				if d <= day:
					kept.append(m)
					if not hash_sides.has(d):
						hash_sides[d] = {}
					hash_sides[d][str(m.get("side", ""))] = true
			"speed":
				speed[str(m.get("side", ""))] = m
	# The day a rebuild resumes at: the last both sides hashed.
	var resume := 1
	for d: int in hash_sides.keys():
		if (hash_sides[d] as Dictionary).size() >= 2 and d > resume:
			resume = d
	# The tick phases: both ends in, one carrying advance. The tick into day d
	# is the (d-1)th; the rebuild re-applies every phase after the resume tick.
	var phases: Array = ends.keys()
	phases.sort()
	var ticks: Array = []
	for p: int in phases:
		var sides: Dictionary = {}
		var advance := false
		for e: Dictionary in ends[p]:
			sides[str(e.get("side", ""))] = true
			advance = advance or bool(e.get("advance", false))
		if advance and sides.size() >= 2:
			ticks.append(p)
	var keep_from := 0
	if resume >= 2 and ticks.size() >= resume - 1:
		keep_from = int(ticks[resume - 2]) + 1
	for p: int in phases:
		if p >= keep_from or ticks.has(p):
			kept.append_array(ends[p])
	kept.append_array(speed.values())
	return kept


## A head-to-head game's header and relay lines, for the Load: [header, lines].
## [{}, []] when there is no such game or it is not a head-to-head save.
static func ReadH2H(id: String) -> Array:
	if not Exists(id):
		return [{}, []]
	var header: Dictionary = {}
	var lines: Array = []
	for line in FileAccess.get_file_as_string(GamePath(id)).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if not (d is Dictionary):
			continue
		if header.is_empty():
			header = d
		else:
			lines.append(d)
	if not header.has("h2h"):
		return [{}, []]
	return [header, lines]


# ---- export and import ----------------------------------------------------------

## The game as a .fwsave file's text: its details on the first line, then the
## save itself. "" if there is no such game.
static func ExportText(id: String) -> String:
	if not Exists(id):
		return ""
	var g: Dictionary = _index()["games"][id]
	var meta := {
		FWSAVE_KEY: FWSAVE_VERSION,
		"name": str(g.get("name", "")),
		"saved_at": str(g.get("saved_at", "")),
		"day": int(g.get("day", 0)),
		"side": str(g.get("side", "")),
	}
	return JSON.stringify(meta) + "\n" + FileAccess.get_file_as_string(GamePath(id))


## A file name for exporting `id`: its name with the characters a file name
## cannot hold left out.
static func ExportFileName(id: String) -> String:
	return FileNameFor(str(_index()["games"].get(id, {}).get("name", DEFAULT_NAME)))


## `name` as a .fwsave file name: the characters a file name cannot hold become "_".
static func FileNameFor(name: String) -> String:
	var safe := ""
	for ch in name:
		safe += "_" if "\\/:*?\"<>|".contains(ch) else ch
	return (safe.strip_edges() if not safe.strip_edges().is_empty() else DEFAULT_NAME) + ".fwsave"


## The game being played, as a .fwsave file's text (Export Game): its details,
## then its command log as it stands. "" if no game is running.
static func ExportCurrentText(name: String) -> String:
	var content: String = CommandLog.Snapshot()
	if content.is_empty():
		return ""
	var meta := {
		FWSAVE_KEY: FWSAVE_VERSION,
		"name": name,
		"saved_at": Time.get_datetime_string_from_system(),
		"day": StrategicTickManager.Today,
		"side": GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else "",
	}
	return JSON.stringify(meta) + "\n" + content


## A name for the game being played when it is exported: the side and the day
## ("Alliance - Day 12").
static func CurrentName() -> String:
	var f: Faction = GameSettings.PlayerFaction
	var side: String = f.ShortName if f != null and not f.ShortName.is_empty() else (f.DisplayName if f != null else "Game")
	return "%s - Day %d" % [side, StrategicTickManager.Shown(StrategicTickManager.Today)]


## Which kind of file `bytes` holds: "fwsave" (ours, exported), "log" (ours, a
## bare command log), "original" (a Star Wars: Rebellion SAVEGAME.nnn) or "".
## The original's file starts with its name (u16 length + bytes) and six u32,
## then a u32 holding its own offset (SAVEGAME-FORMAT.md).
static func Detect(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	# Ours is JSON text; only a file that starts like it is read as text.
	var first: Variant = JSON.parse_string(bytes.slice(0, _line_end(bytes)).get_string_from_utf8()) if bytes[0] == 0x7B else null
	if first is Dictionary:
		if (first as Dictionary).has(FWSAVE_KEY):
			return "fwsave"
		if (first as Dictionary).has("pack"):
			return "log"
	if bytes.size() >= 2:
		var n: int = bytes.decode_u16(0)
		var at: int = 2 + n + 24
		if n > 0 and n < 256 and bytes.size() >= at + 4 and bytes.decode_u32(at) == at:
			return "original"
	return ""


## Import a saved game file. Its Saved date is now, and it never overwrites:
## a name already taken gets " (2)". Returns {ok, id, name, message}.
static func Import(bytes: PackedByteArray, file_name: String = "") -> Dictionary:
	var kind: String = Detect(bytes)
	if kind == "original":
		return {"ok": false, "id": "", "name": "", "message": "Star Wars: Rebellion saves can not be imported yet."}
	if kind.is_empty():
		return {"ok": false, "id": "", "name": "", "message": "That is not a saved game."}
	var text: String = bytes.get_string_from_utf8()
	var meta: Dictionary = {}
	if kind == "fwsave":
		var cut: int = text.find("\n")
		var first: Variant = JSON.parse_string(text.substr(0, cut))
		meta = first if first is Dictionary else {}
		text = text.substr(cut + 1) if cut >= 0 else ""
	var lines: PackedStringArray = text.split("\n", false)
	var header: Variant = JSON.parse_string(lines[0]) if lines.size() > 0 else null
	if not (header is Dictionary) or not (header as Dictionary).has("pack"):
		return {"ok": false, "id": "", "name": "", "message": "That saved game is damaged: it has no header."}
	var day: int = int(meta.get("day", 0))
	if day <= 0:
		for line in lines:
			var d: Variant = JSON.parse_string(line)
			if d is Dictionary and (d as Dictionary).has("hash"):
				day = maxi(day, int(d["day"]))
	var base: String = str(meta.get("name", file_name.get_file().get_basename()))
	var name: String = FreeName(base)
	var side: String = str(meta.get("side", (header as Dictionary).get("local", "")))
	var id: String = _store("", text, name, day, side)
	if id.is_empty():
		return {"ok": false, "id": "", "name": "", "message": "The saved game could not be written."}
	return {"ok": true, "id": id, "name": name, "message": ""}


# ---- the store ---------------------------------------------------------------------

## Write `content` as game `id` (a new id if empty) and make it the newest.
static func _store(id: String, content: String, name: String, day: int, side: String, extra: Dictionary = {}) -> String:
	var idx: Dictionary = _index()
	if id.is_empty():
		id = "g%d" % int(idx["next"])
		idx["next"] = int(idx["next"]) + 1
	DirAccess.make_dir_recursive_absolute("%s/games" % Dir)
	var f: FileAccess = FileAccess.open(GamePath(id), FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot write %s" % GamePath(id))
		return ""
	f.store_string(content)
	f.close()
	idx["seq"] = int(idx.get("seq", 0)) + 1
	idx["games"][id] = {
		"name": name,
		"day": day,
		"saved_at": Time.get_datetime_string_from_system(),
		"side": side,
		"seq": int(idx["seq"]),
	}
	(idx["games"][id] as Dictionary).merge(extra)
	_write_index(idx)
	return id


static func _index() -> Dictionary:
	_migrate_slots()
	var d: Variant = null
	if FileAccess.file_exists(_index_path()):
		d = JSON.parse_string(FileAccess.get_file_as_string(_index_path()))
	var idx: Dictionary = d if d is Dictionary else {}
	if not (idx.get("games") is Dictionary):
		idx["games"] = {}
	idx["next"] = int(idx.get("next", 1))
	idx["seq"] = int(idx.get("seq", 0))
	return idx


static func _write_index(idx: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(Dir)
	var f: FileAccess = FileAccess.open(_index_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(idx))
		f.close()


## Copy the six fixed slots this list replaced into it, once: oldest first, so
## the list keeps their order; a repeated name gets " (2)". The slot files and
## their index are only read, never changed or removed.
static func _migrate_slots() -> void:
	var old_index: String = "%s/slots.json" % Dir
	if FileAccess.file_exists(_index_path()) or not FileAccess.file_exists(old_index):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(old_index))
	var old: Dictionary = d if d is Dictionary else {}
	var slots: Array = []
	for i in OLD_SLOTS:
		var path: String = "%s/slot%d.jsonl" % [Dir, i]
		if old.has(str(i)) and FileAccess.file_exists(path):
			slots.append({"path": path, "meta": old[str(i)]})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["meta"].get("saved_at", "")) < str(b["meta"].get("saved_at", "")))
	var idx := {"next": 1, "seq": 0, "games": {}}
	DirAccess.make_dir_recursive_absolute("%s/games" % Dir)
	var taken: Dictionary = {}
	for s: Dictionary in slots:
		var meta: Dictionary = s["meta"]
		var base: String = str(meta.get("name", "")).strip_edges()
		if base.is_empty():
			base = DEFAULT_NAME
		var name: String = base
		var n := 2
		while taken.has(name):
			name = "%s (%d)" % [base, n]
			n += 1
		taken[name] = true
		var id: String = "g%d" % int(idx["next"])
		idx["next"] = int(idx["next"]) + 1
		if DirAccess.copy_absolute(s["path"], GamePath(id)) != OK:
			push_error("[SaveManager] could not copy %s into the list" % s["path"])
			continue
		idx["seq"] = int(idx["seq"]) + 1
		idx["games"][id] = {
			"name": name,
			"day": int(meta.get("day", 0)),
			"saved_at": str(meta.get("saved_at", "")),
			"side": str(meta.get("side", "")),
			"seq": int(idx["seq"]),
		}
		# A head-to-head slot keeps what the Multiplayer Load lists it by (the
		# slot index called the relay save's id "id").
		for k in H2H_FIELDS:
			var from: String = "id" if k == "h2h_id" else k
			if meta.has(from):
				idx["games"][id][k] = meta[from]
	_write_index(idx)


static func _line_end(bytes: PackedByteArray) -> int:
	var i: int = bytes.find(10)
	return i if i >= 0 else bytes.size()
