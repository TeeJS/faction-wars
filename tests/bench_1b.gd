extends SceneTree
## HANDOFF step 1B - the go/no-go benchmark. Hydrates the source's day-zero
## snapshot, runs the real Planet/Mission tick for N days with the other daily
## subsystems stubbed, and reports per-day timing. Also writes the per-day replay
## hash in the source's format, and checks day 1 against the source's log: a
## match proves the hydrated state IS the source's state for everything
## GameSignature covers.
##
##   Godot_console.exe --headless --path . -s tests/bench_1b.gd -- \
##       --snapshot=res://tests/fixtures/snapshot-seed12345.json --seed=12345 --days=100 \
##       --replay-log=C:\out\gd-replay.log --expect=res://tests/fixtures/replay-seed12345-100d.log \
##       [--missions]   launch a fixed set of missions on day 1 so Mission.ProcessDay has work


func _init() -> void:
	var snapshot := _arg("--snapshot=", "res://tests/fixtures/snapshot-seed12345.json")
	var seed := int(_arg("--seed=", "12345"))
	var days := int(_arg("--days=", "100"))
	var log_path := _arg("--replay-log=", "")
	var text_path := _arg("--replay-text=", "")
	var expect_path := _arg("--expect=", "")
	var launch := _has("--missions")

	var engine := GameSession.start_from_snapshot(snapshot, seed)
	if engine == null:
		push_error("bench: could not start from %s" % snapshot)
		quit(2)
		return

	var expected := _read_log(expect_path)
	var hashes: Array[String] = []
	var log := FileAccess.open(log_path, FileAccess.WRITE) if not log_path.is_empty() else null
	if log != null:
		log.store_line("# seed=%d" % seed)

	# Lambdas capture by value, so the divergence marker lives in a holder.
	var state := { "first_divergence": -1 }
	var text := FileAccess.open(text_path, FileAccess.WRITE) if not text_path.is_empty() else null
	var record := func(day: int) -> void:
		var raw := GameSignature.ReplayText(GameState.ActiveGalaxy)
		var h := raw.sha256_text().to_upper()
		hashes.append(h)
		if log != null:
			log.store_line("%d,%s" % [day, h])
		if text != null:
			text.store_line("%d	%s" % [day, raw])
		if expected.has(day) and expected[day] != h and state.first_divergence < 0:
			state.first_divergence = day

	# Day 1 = the state after day zero, before any tick - the snapshot itself.
	record.call(StrategicTickManager.Today)
	var day1_ok: bool = expected.has(1) and expected[1] == hashes[0]

	if launch:
		_launch_missions()

	var times: Array[float] = []
	for i in days:
		var t0 := Time.get_ticks_usec()
		engine.AdvanceDay()
		var t1 := Time.get_ticks_usec()
		times.append((t1 - t0) / 1000.0)
		record.call(StrategicTickManager.Today)

	if log != null:
		log.close()
	if text != null:
		text.close()

	var warm := 5
	var steady := times.slice(warm) if times.size() > warm else times.duplicate()
	steady.sort()
	var mean := 0.0
	for t in steady:
		mean += t
	mean /= max(1, steady.size())
	var p50: float = steady[steady.size() / 2] if not steady.is_empty() else 0.0
	var p95: float = steady[int(floor(steady.size() * 0.95))] if not steady.is_empty() else 0.0
	var worst: float = steady[steady.size() - 1] if not steady.is_empty() else 0.0
	var warm_mean := 0.0
	for t in times.slice(0, min(warm, times.size())):
		warm_mean += t
	warm_mean /= max(1, min(warm, times.size()))

	print("[bench_1b] snapshot=%s seed=%d days=%d missions=%s" % [snapshot, seed, days, launch])
	print("[bench_1b] planets=%d characters=%d active_missions=%d messages=%d" % [GameState.AllPlanets().size(), GameState.ActiveRoster.size(), MissionManager.Active().size(), EventBus.MessageLog.size()])
	print("[bench_1b] tick ms: warm-up mean %.3f | steady mean %.3f p50 %.3f p95 %.3f max %.3f" % [warm_mean, mean, p50, p95, worst])
	print("[bench_1b] day-1 hash matches source: %s" % ("YES" if day1_ok else ("NO" if expected.has(1) else "n/a - no --expect")))
	if not expected.is_empty():
		var matched := 0
		for d in expected.keys():
			if d - 1 < hashes.size() and hashes[d - 1] == expected[d]:
				matched += 1
		print("[bench_1b] hashes matching source: %d of %d (first divergence day %s)" % [matched, expected.size(), str(state.first_divergence) if state.first_divergence > 0 else "none"])
	print("[bench_1b] %s" % ("PASS" if day1_ok or not expected.has(1) else "FAIL"))
	quit(0 if (day1_ok or not expected.has(1)) else 1)


## A fixed, deterministic set of missions so the Mission tick has work: each
## playable faction sends its idle characters, one per world, on Espionage to
## the nearest explored world it does not hold. Test driver only - not a rule.
func _launch_missions() -> void:
	var launched := 0
	for f in FactionRegistry.Playable:
		var used_worlds := {}
		for c in GameState.ActiveRoster:
			if c.Faction != f or not (c.Attached is Planet) or not c.CanTakeOrders():
				continue
			var from: Planet = c.Attached
			if used_worlds.has(from.Name):
				continue
			var candidates := Lq.where(GameState.AllPlanets(), func(p): return p.ExploredBy(f) and p.ControllingFaction != f and p != from)
			if candidates.is_empty():
				continue
			var target: Planet = Lq.order_by(candidates, func(p): return [from.DeploymentDaysTo(p), p.Name])[0]
			var team: Array = [c]
			if MissionManager.Launch(Enums.MissionType.Espionage, team, from, target) != null:
				used_worlds[from.Name] = true
				launched += 1
	print("[bench_1b] launched %d espionage missions" % launched)


func _read_log(path: String) -> Dictionary:
	var out := {}
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		if line.begins_with("#"):
			continue
		var parts := line.split(",")
		if parts.size() == 2 and parts[0].is_valid_int():
			out[int(parts[0])] = parts[1].strip_edges().to_upper()
	return out


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default


func _has(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)
