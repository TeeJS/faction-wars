extends SceneTree
## One lockstep client of the M2 gate (docs/m2-plan.md section 5). Two of these
## run at once, one per side, over a mailbox directory; each issues its own
## scripted orders every day, advances only in step with the other, and writes
## its day hashes to --replay-log. The runner diffs the two logs.
##
##   Godot_console.exe --headless --path . -s tests/lockstep_client.gd -- \
##       --side=alliance --mailbox=D:/tmp/box --days=200 --seed=12345 --replay-log=a.log [--corrupt=50]

func _init() -> void:
	var side := _arg("--side=", "alliance")
	var box := _arg("--mailbox=", "")
	var days := int(_arg("--days=", "200"))
	var seed := int(_arg("--seed=", "12345"))
	var log_path := _arg("--replay-log=", "")
	var corrupt_day := int(_arg("--corrupt=", "0"))
	if box.is_empty():
		push_error("--mailbox required")
		quit(2)
		return

	FactionRegistry.EnsureLoaded()
	var humans: Array = []
	for f in FactionRegistry.Playable:
		humans.append(f.Id)
	var engine := GameSession.new_game(side, Enums.Difficulty.Multiplayer, Enums.GalaxySize.Large, seed, humans, "alliance")
	var us: Faction = GameSettings.PlayerFaction
	var them: Faction = Lq.first_or_null(FactionRegistry.Playable, func(f: Faction) -> bool: return f != us)

	var transport := MailboxTransport.new(box, side, them.Id)
	var session := LockstepSession.new(transport, us, them)
	session.engine = engine
	CommandBus.Immediate = false
	CommandBus.Session = session
	CommandLog.Open("%s/%s.session.jsonl" % [box, side], CommandLog.Header())
	session.start()

	var log := FileAccess.open(log_path, FileAccess.WRITE) if not log_path.is_empty() else null
	if log != null:
		log.store_line("# seed=%d side=%s" % [seed, side])

	var issued := 0
	var waited_ms := 0
	var t0 := Time.get_ticks_msec()
	for i in days:
		var day := StrategicTickManager.Today

		# A battle we are in waits for OUR answer before the day may go on; it is
		# the first thing issued on the day, as the modal alert makes it.
		for r in FleetBattleManager.AwaitingOrders():
			if r.Ours.Faction == us or r.Theirs.Faction == us:
				CommandBus.issue("battle_answer", { "where": r.Where.Name, "ours": r.Ours.Name, "theirs": r.Theirs.Name, "answer": "simulate" })
				issued += 1

		issued += _orders(day, us, them)

		if corrupt_day > 0 and day == corrupt_day:
			# The forced desync: one side quietly changes a support value.
			GameState.AllPlanets()[0].ShiftSupport(us, 5)
			print("[lockstep] %s corrupted its state on day %d" % [side, day])

		var waited := 0
		var resynced := false
		while not session.try_tick():
			if session.state == LockstepSession.State.Desync and not resynced:
				resynced = true
				print("[lockstep] %s: desync detected on day %d; resyncing" % [side, session.desync_day])
				var ok := session.resync()
				print("[lockstep] %s: resync %s" % [side, "OK - repaired" if ok else ("not needed - the opponent diverged, waiting for them" if session.last_resync_faithful else "FAILED")])
				if not ok and not session.last_resync_faithful:
					quit(5)
					return
			OS.delay_msec(10)
			waited += 10
			if waited > 60000:
				push_error("[lockstep] %s waited a minute on day %d for the opponent" % [side, day])
				quit(3)
				return
		waited_ms += waited
		if log != null:
			log.store_line("%d,%s" % [StrategicTickManager.Today, GameSignature.ReplayHash(GameState.ActiveGalaxy)])
		if not session.hello_mismatch.is_empty():
			push_error("[lockstep] hello mismatch: %s" % session.hello_mismatch)
			quit(4)
			return
		if VictoryManager.IsOver():
			break

	if log != null:
		log.close()
	CommandLog.Close()
	transport.close()
	print("[lockstep] %s done: day %d, %d orders issued, %d ms waiting, %d ms total, state %s" % [side, StrategicTickManager.Today, issued, waited_ms, Time.get_ticks_msec() - t0, LockstepSession.State.keys()[session.state]])
	quit(0)


## The scripted orders of tests/command_apply.gd, for either side, plus a
## fleet sent at the enemy every 9th day so battles happen.
func _orders(day: int, us: Faction, them: Faction) -> int:
	var n := 0
	var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
	var idle: Array = []
	for p in ours:
		for f in p.OrbitingFleets:
			if f.Faction == us and f.Status == Enums.Status.AwaitingOrders and not f.IsEmpty():
				idle.append(f)
	if day % 7 == 1 and idle.size() > 0 and ours.size() > 1:
		var f: Fleet = idle[0]
		var dest: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p != f.Attached)
		if dest != null:
			CommandBus.issue("move_fleets", { "fleets": [f.Name], "destination": dest.Name })
			n += 1
	if day % 9 == 4 and idle.size() > 1:
		var f: Fleet = idle[1]
		var enemy: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == them and p.ExploredBy(us))
		if enemy != null:
			CommandBus.issue("move_fleets", { "fleets": [f.Name], "destination": enemy.Name })
			n += 1
	if day % 5 == 2:
		var rule = Lq.first_or_null(MilitaryCatalog.All(), func(r) -> bool: return r.Type == "Troop" and MilitaryCatalog.CanBeBuiltBy(r, us))
		var yard: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p.TrainingFacilities() > 0)
		if rule != null and yard != null:
			CommandBus.issue("queue_units", { "planet": yard.Name, "rule": rule.Name, "destination": yard.Name, "count": 1 })
			n += 1
	if day % 11 == 3:
		var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
			return c.Faction == us and c.CanTakeOrders() and c.Status == Enums.Status.AwaitingOrders and c.Rank == Enums.Rank.None \
				and OrderManager.SystemOf(c.Attached) != null and MissionManager.TeamCanPerform([c], Enums.MissionType.Diplomacy))
		if agent != null:
			var origin: Planet = OrderManager.SystemOf(agent.Attached)
			var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
				return p != origin and p.ExploredBy(us) and MissionManager.CanTarget(Enums.MissionType.Diplomacy, us, p).ok)
			if target != null:
				CommandBus.issue("launch_mission", { "type": Enums.MissionType.Diplomacy, "team": [agent.Serial], "origin": origin.Name, "target": target.Name, "decoys": [] })
				n += 1
	if day % 13 == 6:
		CommandBus.issue("chat", { "text": "%s says: day %d." % [us.Id, day] })
		n += 1
	return n


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
