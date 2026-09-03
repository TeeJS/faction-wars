class_name LockstepSession
extends RefCounted
## The lockstep clock of a head-to-head game (docs/m2-plan.md section 3).
## Both clients run the identical simulation; only commands and day hashes
## cross the wire. A day advances on this client only when the opponent's
## batch for that day has fully arrived; the merged batch is applied in the
## same order on both sides; the hashes are compared after every tick.

enum State { Running, WaitingOpponent, Desync }

var transport: Transport
var local: Faction
var remote: Faction
## The tick manager of the live world. A resync rebuilds the world and replaces
## it, so the clock must always tick THIS one, never a reference it kept.
var engine: StrategicTickManager
var state: int = State.Running
var desync_day: int = -1

var _batch: Dictionary = {}         # day -> Array[Command], mine
var _remote_batch: Dictionary = {}  # day -> Array[Command], theirs
var _remote_end: Dictionary = {}    # day -> n
var _my_end_sent: Dictionary = {}   # day -> true
var _my_hash: Dictionary = {}       # day -> hash
var _remote_hash: Dictionary = {}   # day -> hash
var _seq: int = 0

var my_speed: int = 2
var remote_speed: int = 2
var remote_hello: Dictionary = {}
var hello_mismatch: String = ""
## After a resync: did our replay reproduce our own hash (true = the opponent diverged)?
var last_resync_faithful: bool = false


func _init(t: Transport, local_side: Faction, remote_side: Faction) -> void:
	transport = t
	local = local_side
	remote = remote_side


func start() -> void:
	var hello := CommandLog.Header()
	hello["t"] = "hello"
	hello["side"] = local.Id
	transport.send(hello)


## The day this client is on (the day whose batch is open).
func day() -> int:
	return StrategicTickManager.Today


## An order from the local side. Once my end-of-day for the current day has
## gone out, the order belongs to the next day.
func issue(c: Command) -> void:
	var d := day()
	if _my_end_sent.has(d):
		d += 1
	c.Day = d
	c.Faction = local.Id
	_seq += 1
	c.Seq = _seq
	if not _batch.has(d):
		_batch[d] = []
	_batch[d].append(c)
	CommandLog.Append(c)
	var line := { "t": "cmd", "day": c.Day, "seq": c.Seq, "faction": c.Faction, "kind": c.Kind, "args": c.Args }
	transport.send(line)


func set_speed(level: int) -> void:
	my_speed = level
	transport.send({ "t": "speed", "side": local.Id, "level": level })


## "the game plays at the slowest speed set on either computer" (manual p163).
func effective_speed() -> int:
	return mini(my_speed, remote_speed)


## Drain the wire.
func pump() -> void:
	for msg in transport.poll():
		_handle(msg)


## Game lines the lobby received before this session existed (RelayClient.take_held).
func absorb(lines: Array) -> void:
	for msg in lines:
		_handle(msg)


func _handle(msg: Dictionary) -> void:
	# A `since` replay carries my own lines as well as theirs; mine are not news.
	var author := str(msg.get("side", msg.get("faction", "")))
	if not author.is_empty() and author == local.Id:
		return
	match str(msg.get("t", "")):
		"hello":
			remote_hello = msg
			# JSON numbers arrive as floats; compare by value, not by text.
			var mine := CommandLog.Header()
			for k in ["seed", "size", "difficulty"]:
				if int(mine.get(k, 0)) != int(msg.get(k, 0)):
					hello_mismatch = "%s: ours %s, theirs %s" % [k, str(mine.get(k)), str(msg.get(k))]
			if bool(mine.get("hq_only", false)) != bool(msg.get("hq_only", false)):
				hello_mismatch = "hq_only differs"
			if str(mine.get("host", "")) != str(msg.get("host", "")):
				hello_mismatch = "host: ours %s, theirs %s" % [str(mine.get("host")), str(msg.get("host"))]
		"cmd":
			var c := Command.new()
			c.Day = int(msg.get("day", 0))
			c.Seq = int(msg.get("seq", 0))
			c.Faction = str(msg.get("faction", ""))
			c.Kind = str(msg.get("kind", ""))
			c.Args = msg.get("args", {})
			if not _remote_batch.has(c.Day):
				_remote_batch[c.Day] = []
			_remote_batch[c.Day].append(c)
			CommandLog.Append(c)   # the log holds BOTH sides' orders - it is the save
		"end":
			_remote_end[int(msg.get("day", 0))] = int(msg.get("n", 0))
		"hash":
			var d := int(msg.get("day", 0))
			_remote_hash[d] = str(msg.get("hash", ""))
			_check(d)
		"speed":
			remote_speed = int(msg.get("level", 2))


func _check(d: int) -> void:
	if state == State.Desync:
		# The opponent resynced and re-sent the day's hash: if it matches now, go on.
		if d == desync_day and _my_hash.has(d) and _remote_hash.get(d, "") == _my_hash[d]:
			print("[Lockstep] day %d hashes agree again - the opponent repaired their state" % d)
			state = State.Running
			desync_day = -1
		return
	if _my_hash.has(d) and _remote_hash.has(d) and _my_hash[d] != _remote_hash[d]:
		state = State.Desync
		desync_day = d
		print("[Lockstep] DESYNC on day %d: ours %s theirs %s" % [d, _my_hash[d].substr(0, 12), _remote_hash[d].substr(0, 12)])


## Is the opponent's batch for the day complete?
func remote_ready(d: int) -> bool:
	if not _remote_end.has(d):
		return false
	var have: int = _remote_batch[d].size() if _remote_batch.has(d) else 0
	return have >= int(_remote_end[d])


## The clock wants to advance. Returns true when a day was advanced.
func try_tick(_unused: StrategicTickManager = null) -> bool:
	pump()
	if engine == null:
		return false
	if state == State.Desync:
		return false
	var d := day()
	if not _my_end_sent.has(d):
		_my_end_sent[d] = true
		transport.send({ "t": "end", "side": local.Id, "day": d, "n": _batch[d].size() if _batch.has(d) else 0 })
	if not remote_ready(d):
		state = State.WaitingOpponent
		return false
	state = State.Running

	var merged: Array = []
	merged.append_array(_batch.get(d, []))
	merged.append_array(_remote_batch.get(d, []))
	CommandBus.apply_day(d, merged)
	engine.AdvanceDay()
	var now := day()
	var h := GameSignature.ReplayHash(GameState.ActiveGalaxy)
	_my_hash[now] = h
	CommandLog.DayDone(now, h)
	transport.send({ "t": "hash", "side": local.Id, "day": now, "hash": h })
	_check(now)
	return true


## RECONNECT (docs/multiplayer-plan.md M5): given the relay's whole log for the
## room - both sides' lines, in order - rebuild the world to the last day both
## sides hashed, and re-arm this day's batches, ends and hashes from the log so
## the clock continues exactly where it stopped. Returns the day resumed at,
## or -1 when the log is unusable.
func rebuild_from_log(lines: Array, header: Dictionary) -> int:
	var cmds: Array = []
	var my_end: Dictionary = {}
	var their_end: Dictionary = {}
	var my_hashes: Dictionary = {}
	var their_hashes: Dictionary = {}
	for msg in lines:
		var t := str(msg.get("t", ""))
		var author := str(msg.get("side", msg.get("faction", "")))
		match t:
			"cmd":
				var c := Command.new()
				c.Day = int(msg.get("day", 0))
				c.Seq = int(msg.get("seq", 0))
				c.Faction = str(msg.get("faction", ""))
				c.Kind = str(msg.get("kind", ""))
				c.Args = msg.get("args", {})
				cmds.append(c)
			"end":
				(my_end if author == local.Id else their_end)[int(msg.get("day", 0))] = int(msg.get("n", 0))
			"hash":
				(my_hashes if author == local.Id else their_hashes)[int(msg.get("day", 0))] = str(msg.get("hash", ""))
			"speed":
				if author == local.Id:
					my_speed = int(msg.get("level", 2))
				else:
					remote_speed = int(msg.get("level", 2))
	# The last day BOTH sides reached: the highest day with a hash from each.
	var resume_day := 1
	for d in my_hashes.keys():
		if their_hashes.has(d) and int(d) > resume_day:
			resume_day = int(d)
	engine = Replayer.replay_entries(header, cmds, resume_day)
	if engine == null:
		return -1
	# Re-arm the session from the log.
	_batch.clear()
	_remote_batch.clear()
	_seq = 0
	for c in cmds:
		if c.Faction == local.Id:
			_seq = maxi(_seq, c.Seq)
		if c.Day < resume_day:
			continue
		var into: Dictionary = _batch if c.Faction == local.Id else _remote_batch
		if not into.has(c.Day):
			into[c.Day] = []
		into[c.Day].append(c)
	_my_end_sent.clear()
	for d in my_end.keys():
		if int(d) >= resume_day:
			_my_end_sent[int(d)] = true
	_remote_end.clear()
	for d in their_end.keys():
		if int(d) >= resume_day:
			_remote_end[int(d)] = their_end[d]
	_my_hash.clear()
	_remote_hash.clear()
	_my_hash[resume_day] = my_hashes.get(resume_day, "")
	_remote_hash[resume_day] = their_hashes.get(resume_day, "")
	state = State.Running
	desync_day = -1
	# Everything in the log is now in CommandLog.Entries via the replayer's copy;
	# the file, if any, was reopened by it.
	print("[Lockstep] rebuilt from the relay log: %d commands, resumed at day %d (my end sent: %s)" % [cmds.size(), resume_day, str(_my_end_sent.has(resume_day))])
	return resume_day


## Resync after a desync: rebuild from the log and compare with the opponent's
## hash for the desync day. True when the replayed state matches theirs.
func resync() -> bool:
	if desync_day < 0:
		return true
	var target := desync_day
	var replayed := Replayer.replay_entries(CommandLog.Header(), CommandLog.Entries, target)
	if replayed == null:
		return false
	engine = replayed   # the rebuilt world's clock
	var h := GameSignature.ReplayHash(GameState.ActiveGalaxy)
	var ok: bool = _remote_hash.has(target) and _remote_hash[target] == h
	var faithful: bool = _my_hash.has(target) and _my_hash[target] == h
	var verdict := "still differs - the two logs disagree"
	if ok:
		verdict = "matches the opponent - our live state had drifted and is repaired"
	elif faithful:
		verdict = "our replay matches our own hash - the OPPONENT diverged; they must resync"
	print("[Lockstep] resync to day %d: %s" % [target, verdict])
	last_resync_faithful = faithful
	if ok:
		_my_hash[target] = h
		state = State.Running
		desync_day = -1
		transport.send({ "t": "hash", "side": local.Id, "day": target, "hash": h })   # so the other side clears too
	return ok
