class_name CommandLog
extends RefCounted
## The append-only record of a game: a header that can rebuild it, one line per
## command, and the day hash after every tick so a replay checks itself
## (docs/m1-plan.md section 1). This IS the save in head-to-head play.

static var _file: FileAccess = null
static var _path: String = ""
## Everything issued this game, in order, whether or not a file is open.
static var Entries: Array = []          # Array[Command]
static var Hashes: Dictionary = {}      # day -> hash


static func Reset() -> void:
	Close()
	Entries.clear()
	Hashes.clear()


## Open a log for writing and record how the game was made.
static func Open(path: String, header: Dictionary) -> bool:
	Close()
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("[CommandLog] cannot write %s" % path)
		return false
	_path = path
	_file.store_line(JSON.stringify(header))
	_file.flush()
	return true


## Reopen an existing log for appending (a resync rebuilt the game but the
## file and its history stay).
static func Reopen(path: String) -> void:
	Close()
	if path.is_empty():
		return
	_file = FileAccess.open(path, FileAccess.READ_WRITE)
	if _file == null:
		push_error("[CommandLog] cannot reopen %s" % path)
		return
	_file.seek_end()
	_path = path


static func Path() -> String:
	return _path


static func Close() -> void:
	if _file != null:
		_file.close()
		_file = null
	_path = ""


static func Header() -> Dictionary:
	var humans: Array = []
	for f in GameSettings.HumanFactions:
		humans.append(f.Id)
	return {
		"seed": GameSettings.Seed,
		"local": GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else "",
		"humans": humans,
		"host": GameSettings.HostFaction.Id if GameSettings.HostFaction != null else "",
		"difficulty": GameSettings.SelectedDifficulty,
		"size": GameSettings.SelectedSize,
		"hq_only": GameSettings.HQOnlyVictory,
	}


static func Append(c: Command) -> void:
	Entries.append(c)
	if _file != null:
		_file.store_line(c.to_json())
		_file.flush()


static func DayDone(day: int, hash: String) -> void:
	Hashes[day] = hash
	if _file != null:
		_file.store_line(JSON.stringify({ "day": day, "hash": hash }))
		_file.flush()


## Read a log back: [header, commands, hashes].
## The whole session so far as the file's own JSON lines (header, commands,
## day hashes), for a feedback report. Flushes the open file first.
static func Snapshot() -> String:
	if _file != null:
		_file.flush()
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return ""
	return FileAccess.get_file_as_string(_path)


static func Read(path: String) -> Array:
	var header: Dictionary = {}
	var commands: Array = []
	var hashes: Dictionary = {}
	if not FileAccess.file_exists(path):
		push_error("[CommandLog] no such log: %s" % path)
		return [header, commands, hashes]
	var first := true
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var d: Variant = JSON.parse_string(line)
		if not (d is Dictionary):
			continue
		if first:
			header = d
			first = false
		elif d.has("kind"):
			commands.append(Command.from_json(line))
		elif d.has("hash"):
			hashes[int(d["day"])] = str(d["hash"])
	return [header, commands, hashes]
