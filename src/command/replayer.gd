class_name Replayer
extends RefCounted
## Rebuild a game from a command log's header and replay its commands day by
## day (docs/m1-plan.md section 3). Used by tests/replay.gd and by the
## lockstep session's Resync. ONE order for every recorder and every client: on
## day D apply D's whole batch in one sorted pass (retreat answers first, then
## faction order, then Seq - so the answers to the tick into D, issued first,
## come before D's orders), then the tick into D+1. A day hash is always the
## state right after the tick, before that day's batch.


## Rebuild and replay up to and including the tick INTO `upto_day` (or the
## last day the commands mention). Returns the engine, or null.
static func replay_entries(header: Dictionary, commands: Array, upto_day: int = -1) -> StrategicTickManager:
	if header.is_empty():
		return null
	# new_game resets the bus and the log; keep what a live session needs.
	var session: LockstepSession = CommandBus.Session
	var entries: Array = commands.duplicate()
	var hashes: Dictionary = CommandLog.Hashes.duplicate()
	var log_path: String = CommandLog.Path()
	var engine := GameSession.new_game(str(header.get("local", "alliance")), int(header.get("difficulty", 2)),
		int(header.get("size", 1)), int(header.get("seed", 0)), header.get("humans", []), str(header.get("host", "")))
	GameSettings.HQOnlyVictory = bool(header.get("hq_only", false))
	CommandBus.Immediate = false
	CommandBus.Session = null   # the replay applies directly; the session is put back below
	commands = entries

	var by_day: Dictionary = {}
	var last := 1
	for c in commands:
		if not by_day.has(c.Day):
			by_day[c.Day] = []
		by_day[c.Day].append(c)
		last = maxi(last, c.Day)
	if upto_day > 0:
		last = upto_day

	while StrategicTickManager.Today < last:
		var d := StrategicTickManager.Today
		CommandBus.apply_day(d, by_day.get(d, []))
		engine.AdvanceDay()
		if VictoryManager.IsOver():
			break
	# The live session's world: its log history, its file, its wire.
	CommandLog.Entries = entries
	CommandLog.Hashes = hashes
	if not log_path.is_empty():
		CommandLog.Reopen(log_path)
	CommandBus.Session = session
	return engine
