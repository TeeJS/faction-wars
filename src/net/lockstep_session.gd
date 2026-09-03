class_name LockstepSession
extends RefCounted
## The lockstep clock of a head-to-head game (docs/m2-plan.md section 3, and
## the PHASES of TeeJ's room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #97/#99, reviewed by
## Doof #118/#121). Both clients run the identical simulation; only commands,
## end-of-phase lines and day hashes cross the wire.
##
## A PHASE is the unit of lockstep: every few hundred milliseconds each client
## ends its open phase; once BOTH ends for a phase are in, both apply that
## phase's merged batch in one canonical order (retreat answers first, then
## faction order, then sequence) - without advancing the day - exactly as
## single player applies an order the moment it is given. The DAY advances
## only at a phase whose end line from the HOST carries advance:true (the
## host's clock fired); both apply that batch, tick, hash and compare. The
## guest's clock never emits anything. Phases are numbered from 0 for the whole
## game; commands carry their phase so the log replays in the live order.

enum State { Running, WaitingOpponent, Desync }

var transport: Transport
var local: Faction
var remote: Faction
## Is this client the host - the one clock whose end lines may carry advance?
var hosting: bool = false
## The tick manager of the live world. A resync rebuilds the world and replaces
## it, so the clock must always tick THIS one, never a reference it kept.
var engine: StrategicTickManager
var state: int = State.Running
var desync_day: int = -1

## The open phase: my orders go here until I end it.
var phase: int = 0
var _batch: Dictionary = {}         # phase -> Array[Command], mine
var _remote_batch: Dictionary = {}  # phase -> Array[Command], theirs
var _remote_end: Dictionary = {}    # phase -> { n, advance }
var _my_end: Dictionary = {}        # phase -> { n, advance } (sent)
var _end_sent_at_ms: int = -1       # when my end for the open phase went out
var _my_hash: Dictionary = {}       # day -> hash
var _remote_hash: Dictionary = {}   # day -> hash
var _seq: int = 0
## Measured: from my end of a phase to its application, most recent, milliseconds.
var last_phase_ms: int = 0

var my_speed: int = 2
var remote_speed: int = 2
var remote_hello: Dictionary = {}
## The relay said the opponent's seat dropped (`left`) and has not been retaken.
var opponent_gone: bool = false
var hello_mismatch: String = ""
## After a resync: did our replay reproduce our own hash (true = the opponent diverged)?
var last_resync_faithful: bool = false


func _init(t: Transport, local_side: Faction, remote_side: Faction, is_host: bool = false) -> void:
	transport = t
	local = local_side
	remote = remote_side
	hosting = is_host


func start() -> void:
	var hello := CommandLog.Header()
	hello["t"] = "hello"
	hello["side"] = local.Id
	transport.send(hello)


## The day this client is on.
func day() -> int:
	return StrategicTickManager.Today


## An order from the local side. Once my end for the open phase has gone out,
## the order belongs to the next phase.
func issue(c: Command) -> void:
	var p := phase
	if _my_end.has(p):
		p += 1
	c.Day = day()
	c.Phase = p
	c.Faction = local.Id
	_seq += 1
	c.Seq = _seq
	if not _batch.has(p):
		_batch[p] = []
	_batch[p].append(c)
	CommandLog.Append(c)
	transport.send({ "t": "cmd", "day": c.Day, "phase": c.Phase, "seq": c.Seq, "faction": c.Faction, "kind": c.Kind, "args": c.Args })


func set_speed(level: int) -> void:
	my_speed = level
	transport.send({ "t": "speed", "side": local.Id, "level": level })


## "the game plays at the slowest speed set on either computer" (manual p163) -
## or, under TeeJ's "average" rule (GameSettings.SpeedRule), the floor of the
## two settings' mean. Pause (0) on either side is a pause under both rules.
func effective_speed() -> int:
	return combine_speeds(my_speed, remote_speed, GameSettings.SpeedRule)


static func combine_speeds(a: int, b: int, rule: String) -> int:
	if a <= 0 or b <= 0:
		return 0
	if rule == "average":
		@warning_ignore("integer_division")
		return (a + b) / 2
	return mini(a, b)


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
			var c := _command_of(msg)
			if not _remote_batch.has(c.Phase):
				_remote_batch[c.Phase] = []
			_remote_batch[c.Phase].append(c)
			CommandLog.Append(c)   # the log holds BOTH sides' orders - it is the save
		"end":
			_remote_end[int(msg.get("phase", 0))] = { "n": int(msg.get("n", 0)), "advance": bool(msg.get("advance", false)) }
		"hash":
			var d := int(msg.get("day", 0))
			_remote_hash[d] = str(msg.get("hash", ""))
			_check(d)
		"speed":
			remote_speed = int(msg.get("level", 2))
		"left":
			opponent_gone = true
		"guest", "host":
			opponent_gone = false


static func _command_of(msg: Dictionary) -> Command:
	var c := Command.new()
	c.Day = int(msg.get("day", 0))
	c.Phase = int(msg.get("phase", 0))
	c.Seq = int(msg.get("seq", 0))
	c.Faction = str(msg.get("faction", ""))
	c.Kind = str(msg.get("kind", ""))
	c.Args = msg.get("args", {})
	return c


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


## Is the opponent's batch for the phase complete?
func remote_ready(p: int) -> bool:
	if not _remote_end.has(p):
		return false
	var have: int = _remote_batch[p].size() if _remote_batch.has(p) else 0
	return have >= int(_remote_end[p]["n"])


## End my open phase: the batch is closed and the opponent told how many
## orders to expect. `advance` (host only) says the day ticks at this phase.
## Returns true when the end went out now (false if it had already).
func end_phase(advance: bool = false) -> bool:
	if _my_end.has(phase):
		return false
	var adv := advance and hosting
	_my_end[phase] = { "n": _batch[phase].size() if _batch.has(phase) else 0, "advance": adv }
	_end_sent_at_ms = Time.get_ticks_msec()
	transport.send({ "t": "end", "side": local.Id, "phase": phase, "day": day(), "n": _my_end[phase]["n"], "advance": adv })
	return true


## Has my end for the open phase gone out?
func phase_ended() -> bool:
	return _my_end.has(phase)


## How long the opponent's end for my ended phase has been overdue, in ms.
func overdue_ms() -> int:
	if not _my_end.has(phase) or remote_ready(phase) or _end_sent_at_ms < 0:
		return 0
	return Time.get_ticks_msec() - _end_sent_at_ms


## Complete the open phase if both ends are in: apply the merged batch in the
## canonical order and, when the host's end carried advance, tick the day.
## Returns true when a phase was completed (call again: more may be ready).
func try_phase() -> bool:
	pump()
	if engine == null or state == State.Desync:
		return false
	var p := phase
	if not _my_end.has(p) or not remote_ready(p):
		state = State.WaitingOpponent if _my_end.has(p) else State.Running
		return false
	state = State.Running
	var merged: Array = []
	merged.append_array(_batch.get(p, []))
	merged.append_array(_remote_batch.get(p, []))
	CommandBus.apply_batch("phase %d" % p, merged)
	last_phase_ms = Time.get_ticks_msec() - _end_sent_at_ms if _end_sent_at_ms >= 0 else 0
	var advance: bool = bool(_my_end[p]["advance"]) if hosting else bool(_remote_end[p]["advance"])
	if advance:
		_tick()
	_batch.erase(p)
	_remote_batch.erase(p)
	_my_end.erase(p)
	_remote_end.erase(p)
	phase = p + 1
	_end_sent_at_ms = -1
	return true


func _tick() -> void:
	engine.AdvanceDay()
	var now := day()
	var h := GameSignature.ReplayHash(GameState.ActiveGalaxy)
	_my_hash[now] = h
	CommandLog.DayDone(now, h)
	transport.send({ "t": "hash", "side": local.Id, "day": now, "hash": h })
	_check(now)


## The M2 shape kept for the headless clients: end my phase (with advance when
## I am the host) and complete what is ready. Returns true when the day
## advanced, i.e. the tick into the next day happened during this call.
func try_tick(_unused: StrategicTickManager = null) -> bool:
	var before := day()
	end_phase(true)
	while try_phase():
		if day() != before:
			return true
	return day() != before


## RECONNECT (docs/multiplayer-plan.md M5): given the relay's whole log for the
## room - both sides' lines, in order - rebuild the world to the last day both
## sides hashed, re-apply the phases completed since, and re-arm the open phase
## from the log so the clock continues exactly where it stopped. Returns the
## day resumed at, or -1 when the log is unusable.
func rebuild_from_log(lines: Array, header: Dictionary) -> int:
	var cmds: Array = []
	var my_end: Dictionary = {}       # phase -> {n, advance}
	var their_end: Dictionary = {}
	var my_hashes: Dictionary = {}
	var their_hashes: Dictionary = {}
	for msg in lines:
		var t := str(msg.get("t", ""))
		var author := str(msg.get("side", msg.get("faction", "")))
		match t:
			"cmd":
				cmds.append(_command_of(msg))
			"end":
				(my_end if author == local.Id else their_end)[int(msg.get("phase", 0))] = { "n": int(msg.get("n", 0)), "advance": bool(msg.get("advance", false)) }
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
	# Re-arm the session from the log: everything from the resume day on.
	_batch.clear()
	_remote_batch.clear()
	_seq = 0
	for c in cmds:
		if c.Faction == local.Id:
			_seq = maxi(_seq, c.Seq)
		if c.Day < resume_day:
			continue
		var into: Dictionary = _batch if c.Faction == local.Id else _remote_batch
		if not into.has(c.Phase):
			into[c.Phase] = []
		into[c.Phase].append(c)
	_my_end.clear()
	_remote_end.clear()
	var phases: Array = []
	for p in my_end.keys():
		if not phases.has(p):
			phases.append(p)
	for p in their_end.keys():
		if not phases.has(p):
			phases.append(p)
	phases.sort()
	# The phases of the resume day start after the last COMPLETED tick phase:
	# the host's end carried advance and both ends are in. That tick is the
	# resume day's tick (both hashed it), or an earlier one.
	var start_phase := 0
	var ticks_seen := 0
	for p in phases:
		var host_end: Dictionary = my_end.get(p, {}) if hosting else their_end.get(p, {})
		if bool(host_end.get("advance", false)) and my_end.has(p) and their_end.has(p):
			ticks_seen += 1
			if ticks_seen <= resume_day - 1:
				start_phase = int(p) + 1
	phase = start_phase
	_my_hash.clear()
	_remote_hash.clear()
	_my_hash[resume_day] = my_hashes.get(resume_day, "")
	_remote_hash[resume_day] = their_hashes.get(resume_day, "")
	state = State.Running
	desync_day = -1
	# Re-apply the phases completed since the resume tick, in order; then the
	# open phase keeps its batches and my end, if it had gone out.
	var replayed := 0
	for p in phases:
		if int(p) < phase:
			continue
		if my_end.has(p) and their_end.has(p):
			_my_end[p] = my_end[p]
			_remote_end[p] = their_end[p]
			if try_phase():
				replayed += 1
			else:
				break
		else:
			if my_end.has(p):
				_my_end[p] = my_end[p]
				_end_sent_at_ms = Time.get_ticks_msec()
			if their_end.has(p):
				_remote_end[p] = their_end[p]
			break
	print("[Lockstep] rebuilt from the relay log: %d commands, resumed at day %d, phase %d (%d phases re-applied, my end sent: %s)" % [cmds.size(), day(), phase, replayed, str(_my_end.has(phase))])
	return day()


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
