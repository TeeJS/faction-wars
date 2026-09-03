extends SceneTree
## The headless soak - the source's GameManager.RunSoak, and the step 2 parity gate.
## The AI drives both sides, both droid automations are on, a battle the player is
## in is simulated in place of the Battle Alert, and the replay hash/text is
## recorded exactly as the source's --replay-log / --replay-text do.
##
##   Godot_console.exe --headless --path . -s tests/soak.gd -- --days=100 --seed=12345 \
##       [--snapshot=res://tests/fixtures/snapshot-seed12345.json]   (else a fresh day zero)
##       [--faction=alliance] [--difficulty=Medium] [--size=Large]
##       [--humans=alliance|empire|both] [--host=alliance|empire]
##       (the M0 gate: --humans=both --difficulty=Multiplayer, once with each --faction)
##       [--replay-log=path] [--replay-text=path] [--expect=path]


func _init() -> void:
	var days := int(_arg("--days=", "100"))
	var seed := int(_arg("--seed=", "12345"))
	var snapshot := _arg("--snapshot=", "")
	var log_path := _arg("--replay-log=", "")
	var text_path := _arg("--replay-text=", "")
	var expected := _read_log(_arg("--expect=", ""))

	var engine: StrategicTickManager
	if snapshot.is_empty():
		var faction := _arg("--faction=", "alliance")
		var difficulty: int = JsonUtil.enum_or({ "d": _arg("--difficulty=", "Medium") }, "d", Enums.Difficulty, Enums.Difficulty.Medium)
		var size: int = JsonUtil.enum_or({ "s": _arg("--size=", "Large") }, "s", Enums.GalaxySize, Enums.GalaxySize.Large)
		# Head-to-head: --humans=both (or one side) and --host=<side>. Generation
		# depends on them, so they are inputs to new_game (docs/m0-audit.md).
		var humans_arg := _arg("--humans=", "")
		var humans: Array = []
		if humans_arg == "both":
			FactionRegistry.EnsureLoaded()
			for f in FactionRegistry.Playable:
				humans.append(f.Id)
		elif not humans_arg.is_empty():
			humans = [humans_arg]
		engine = GameSession.new_game(faction, difficulty, size, seed, humans, _arg("--host=", ""))
	else:
		engine = GameSession.start_from_snapshot(snapshot, seed)
	if engine == null:
		push_error("soak: could not start")
		quit(2)
		return

	print("\n=== SOAK: %d days as %s (humans: %s) ===" % [days, GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else "", ", ".join(Lq.select(GameSettings.HumanFactions, func(f: Faction) -> String: return f.Id))])

	# Nobody plays the player's side in a headless run, so the AI takes both.
	AiManager.DriveAllFactions = true
	for f in FactionRegistry.Playable:
		AgentDroid.SetManageProduction(f, true)
		AgentDroid.SetManageGarrisons(f, true)

	var log := FileAccess.open(log_path, FileAccess.WRITE) if not log_path.is_empty() else null
	if log != null:
		log.store_line("# seed=%d" % seed)
	var text := FileAccess.open(text_path, FileAccess.WRITE) if not text_path.is_empty() else null

	var hashes: Array[String] = []
	var state := { "first_divergence": -1 }
	var record := func() -> void:
		var day := StrategicTickManager.Today
		var raw := GameSignature.ReplayText(GameState.ActiveGalaxy)
		var h := raw.sha256_text().to_upper()
		hashes.append(h)
		if log != null:
			log.store_line("%d,%s" % [day, h])
		if text != null:
			text.store_line("%d	%s" % [day, raw])
		if expected.has(day) and expected[day] != h and state.first_divergence < 0:
			state.first_divergence = day

	var t0 := Time.get_ticks_msec()
	for i in days:
		record.call()
		engine.AdvanceDay()

		# No window to click in a headless run: stand in for the player and
		# simulate, after running the tactical simulation over the same fleets.
		var guard := 50   # a battle that will not resolve must not hang the soak
		while FleetBattleManager.HasPendingBattle() and guard > 0:
			guard -= 1
			var pending: FleetBattleManager.BattleReport = FleetBattleManager.AwaitingOrders()[0]
			var sim := TacticalBattle.new(pending.Where, pending.Ours, pending.Theirs, Prng.Session)
			sim.RunToCompletion()
			print("[Soak] tactical sim at %s: t+%ds, loser index %d, strengths %d/%d" % [pending.Where.Name, int(sim.Elapsed), sim.LoserIndex, sim.Sides[0].Strength, sim.Sides[1].Strength])
			FleetBattleManager.SimulateResults(pending, StrategicTickManager.Today)

		if VictoryManager.IsOver():
			print("[Soak] game decided on day %d." % StrategicTickManager.Today)
			break

	record.call()
	if log != null:
		log.close()
	if text != null:
		text.close()

	var elapsed := Time.get_ticks_msec() - t0
	var day := StrategicTickManager.Today
	print("\n=== SOAK COMPLETE: day %d (%d ms, %.2f ms/day) ===" % [day, elapsed, float(elapsed) / max(1, days)])
	for f in FactionRegistry.Playable:
		var worlds := Lq.count(GameState.AllPlanets(), func(p): return p.ControllingFaction == f)
		var charted := Lq.count(GameState.AllPlanets(), func(p): return p.ExploredBy(f))
		print("  %-10s worlds %3d   charted %3d" % [f.Id, worlds, charted])

	if not expected.is_empty():
		var matched := 0
		for d in expected.keys():
			if d - 1 < hashes.size() and hashes[d - 1] == expected[d]:
				matched += 1
		print("[soak] hashes matching source: %d of %d (first divergence day %s)" % [matched, expected.size(), str(state.first_divergence) if state.first_divergence > 0 else "none"])
		quit(0 if state.first_divergence < 0 else 1)
		return
	quit(0)


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
