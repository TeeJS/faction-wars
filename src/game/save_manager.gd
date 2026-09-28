class_name SaveManager
extends RefCounted
## Single-player save/load, built on the command log (docs/m1-plan.md). The game
## is command-sourced and deterministic, so a SAVE is just the current command
## log copied to a slot, and a LOAD replays that slot through Replayer. Six named
## slots, matching the original's Game Options screen (manual p073-077).
##
## Slot files:   user://saves/slot<N>.jsonl   - a copy of the command log
## Slot index:   user://saves/slots.json       - { "<N>": {name, day, saved_at, side} }
##
## `side` is what the Game Options screen's slot icon shows (manual p075: "an
## icon ... shows whether you were playing the Empire, the Alliance, or a
## head-to-head game"): the player's faction id, or "h2h". Older saves have none.
##
## HEAD-TO-HEAD (manual p163, issue #301): "only the host player can save the
## game. Star Wars Rebellion will create a saved game on both computers in the
## same saved game slots." SaveH2H writes one computer's copy: the header, then
## the game's relay lines (both sides' orders, phase ends, day hashes) up to the
## save point - what LockstepSession.rebuild_from_log resumes a game from, and a
## command log CommandLog.Read loads in single player (the AI then plays the
## opponent). Its index entry adds the two players' names, this computer's side
## and the room's settings, for the Multiplayer Options' Load Game list.

const SLOT_COUNT := 6
## The save directory. A static var (not a const) so a headless test can point it
## at a scratch directory and never touch a player's real saves.
static var Dir := "user://saves"


static func SlotPath(slot: int) -> String:
	return "%s/slot%d.jsonl" % [Dir, slot]


static func _index_path() -> String:
	return "%s/slots.json" % Dir


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(Dir)


## Write the current game's command log to `slot` under a display `name`.
## Overwriting a used slot is allowed (the manual treats overwriting your own
## slot as normal). Returns false if the slot index is out of range or there is
## no open log to save.
static func Save(slot: int, name: String) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		push_error("[SaveManager] slot %d out of range" % slot)
		return false
	# Snapshot flushes the open log and returns its full text. Empty means no
	# game/log is running - nothing to save.
	var content: String = CommandLog.Snapshot()
	if content.is_empty():
		push_error("[SaveManager] no open command log to save")
		return false
	_ensure_dir()
	var f: FileAccess = FileAccess.open(SlotPath(slot), FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot write %s" % SlotPath(slot))
		return false
	f.store_string(content)
	f.close()
	var idx: Dictionary = _read_index()
	idx[str(slot)] = {
		"name": name,
		"day": StrategicTickManager.Today,
		"saved_at": Time.get_datetime_string_from_system(),
		"side": "h2h" if MpSetup.session != null else (GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else ""),
	}
	_write_index(idx)
	return true


## One computer's copy of a head-to-head save (header above). `history` is the
## session's relay lines (LockstepSession.history); the save point is the
## phases before `phase` and the day hashes up to `day`. `save` carries what
## both computers write alike: id, host, guest, settings, state_hash. Returns
## false when the slot is out of range or the file cannot be written.
static func SaveH2H(slot: int, name: String, history: Array, phase: int, day: int, save: Dictionary) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		push_error("[SaveManager] slot %d out of range" % slot)
		return false
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
	_ensure_dir()
	var f: FileAccess = FileAccess.open(SlotPath(slot), FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot write %s" % SlotPath(slot))
		return false
	f.store_string("\n".join(text) + "\n")
	f.close()
	var idx: Dictionary = _read_index()
	idx[str(slot)] = {
		"name": name,
		"day": day,
		"saved_at": Time.get_datetime_string_from_system(),
		"side": "h2h",
		"id": str(save.get("id", "")),
		"host": str(save.get("host", "")),
		"guest": str(save.get("guest", "")),
		"local": str(header.get("local", "")),
		"seeded_by": str(header.get("host", "")),
		"settings": save.get("settings", {}),
	}
	_write_index(idx)
	return true


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


## A head-to-head slot's header and relay lines, for the Load: [header, lines].
## [{}, []] when the slot is empty or not a head-to-head save.
static func ReadH2H(slot: int) -> Array:
	if slot < 0 or slot >= SLOT_COUNT or not FileAccess.file_exists(SlotPath(slot)):
		return [{}, []]
	var header: Dictionary = {}
	var lines: Array = []
	for line in FileAccess.get_file_as_string(SlotPath(slot)).split("\n", false):
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


## The six slots as [{slot, used, name, day, saved_at, side}], for the Game
## Options UI; a head-to-head slot adds its index entry's other fields (host,
## guest, local, seeded_by, settings, id).
static func Slots() -> Array:
	var idx: Dictionary = _read_index()
	var out: Array = []
	for i in SLOT_COUNT:
		var meta: Dictionary = idx.get(str(i), {})
		var used: bool = FileAccess.file_exists(SlotPath(i)) and not meta.is_empty()
		var s := {
			"slot": i,
			"used": used,
			"name": str(meta.get("name", "")),
			"day": int(meta.get("day", 0)),
			"saved_at": str(meta.get("saved_at", "")),
			"side": str(meta.get("side", "")),
		}
		if s["side"] == "h2h":
			for k in ["id", "host", "guest", "local", "seeded_by", "settings"]:
				s[k] = meta.get(k, {} if k == "settings" else "")
		out.append(s)
	return out


## Read a slot's log back as [header, commands, hashes] - the input to Replayer.
## Returns [{}, [], {}] if the slot is empty.
static func ReadSlot(slot: int) -> Array:
	if slot < 0 or slot >= SLOT_COUNT or not FileAccess.file_exists(SlotPath(slot)):
		return [{}, [], {}]
	return CommandLog.Read(SlotPath(slot))


static func IsUsed(slot: int) -> bool:
	return FileAccess.file_exists(SlotPath(slot)) and _read_index().has(str(slot))


static func _read_index() -> Dictionary:
	if not FileAccess.file_exists(_index_path()):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index_path()))
	return d if d is Dictionary else {}


static func _write_index(idx: Dictionary) -> void:
	_ensure_dir()
	var f: FileAccess = FileAccess.open(_index_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(idx))
		f.close()
