class_name SaveManager
extends RefCounted
## Single-player save/load, built on the command log (docs/m1-plan.md). The game
## is command-sourced and deterministic, so a SAVE is just the current command
## log copied to a slot, and a LOAD replays that slot through Replayer. Six named
## slots, matching the original's Game Options screen (manual p073-077).
##
## Slot files:   user://saves/slot<N>.jsonl   - a copy of the command log
## Slot index:   user://saves/slots.json       - { "<N>": {name, day, saved_at} }

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
	}
	_write_index(idx)
	return true


## The six slots as [{slot, used, name, day, saved_at}], for the Game Options UI.
static func Slots() -> Array:
	var idx: Dictionary = _read_index()
	var out: Array = []
	for i in SLOT_COUNT:
		var meta: Dictionary = idx.get(str(i), {})
		var used: bool = FileAccess.file_exists(SlotPath(i)) and not meta.is_empty()
		out.append({
			"slot": i,
			"used": used,
			"name": str(meta.get("name", "")),
			"day": int(meta.get("day", 0)),
			"saved_at": str(meta.get("saved_at", "")),
		})
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
