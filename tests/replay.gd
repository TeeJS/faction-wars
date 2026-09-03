extends SceneTree
## M1 gate, half two: rebuild a game from a command log and replay it - every
## day's commands applied in faction order then Seq, the day advanced, and the
## day hash compared with the one the log recorded.
##
##   Godot_console.exe --headless --path . -s tests/replay.gd -- --log=user://session.jsonl
##
## Exit 0 when every hash matches.

func _init() -> void:
	var path := _arg("--log=", "user://session.jsonl")
	var read: Array = CommandLog.Read(path)
	var header: Dictionary = read[0]
	var commands: Array = read[1]
	var hashes: Dictionary = read[2]
	if header.is_empty():
		push_error("[replay] no header in %s" % path)
		quit(2)
		return

	var last_day: int = 0
	for d in hashes.keys():
		last_day = maxi(last_day, int(d))
	# Rebuild and replay through the shared Replayer, checking the hash after
	# every tick against the one the log recorded.
	var matched := 0
	var first_bad := -1
	var by_day: Dictionary = {}
	for c in commands:
		if not by_day.has(c.Day):
			by_day[c.Day] = []
		by_day[c.Day].append(c)
	var engine := Replayer.replay_entries(header, [], 1)
	var applied := 0
	while true:
		var day := StrategicTickManager.Today
		# The day hash is the state right after the tick into `day`.
		if hashes.has(day):
			if hashes[day] == GameSignature.ReplayHash(GameState.ActiveGalaxy):
				matched += 1
			elif first_bad < 0:
				first_bad = day
		if day >= last_day or VictoryManager.IsOver():
			break
		var todays: Array = by_day.get(day, [])
		CommandBus.apply_day(day, todays)
		applied += todays.size()
		engine.AdvanceDay()
	print("[replay] %d commands replayed; hashes matching the log: %d of %d (first divergence day %s)" % [applied, matched, hashes.size(), str(first_bad) if first_bad > 0 else "none"])
	quit(0 if first_bad < 0 and matched == hashes.size() else 1)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
