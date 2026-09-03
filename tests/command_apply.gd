extends SceneTree
## M1 gate, half one: a SCRIPTED single-player session issued through the
## CommandBus and recorded to a log. Every day a few orders of different kinds
## are issued from live state (a fleet move, a build, a mission, a droid toggle,
## a chat line, a message deletion ...), the day advances, pending battles are
## answered through the bus, and the day hash goes into the log.
##
##   Godot_console.exe --headless --path . -s tests/command_apply.gd -- --days=100 --seed=12345 --record=user://session.jsonl
##
## Half two is tests/replay.gd on the same log.

func _init() -> void:
	var days := int(_arg("--days=", "100"))
	var seed := int(_arg("--seed=", "12345"))
	var record := _arg("--record=", "user://session.jsonl")

	var engine := GameSession.new_game("alliance", Enums.Difficulty.Medium, Enums.GalaxySize.Large, seed)
	CommandLog.Open(record, CommandLog.Header())

	var us: Faction = GameSettings.PlayerFaction
	var kinds := {}
	var tally := { "issued": 0, "refused": 0 }   # a dictionary: lambdas capture ints by value

	var issue := func(kind: String, args: Dictionary) -> void:
		var r: Result = CommandBus.issue(kind, args)
		tally.issued += 1
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if not r.ok:
			tally.refused += 1
			print("[command_apply] day %d %s refused: %s" % [StrategicTickManager.Today, kind, r.error])

	for i in days:
		var day := StrategicTickManager.Today
		var ours: Array = Lq.where(GameState.AllPlanets(), func(p: Planet) -> bool: return p.ControllingFaction == us)
		var idle_fleets: Array = []
		for p in ours:
			for f in p.OrbitingFleets:
				if f.Faction == us and f.Status == Enums.Status.AwaitingOrders and not f.IsEmpty():
					idle_fleets.append(f)

		# Every 7th day: send an idle fleet to the nearest other world we hold.
		if day % 7 == 1 and idle_fleets.size() > 0 and ours.size() > 1:
			var f: Fleet = idle_fleets[0]
			var dest: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p != f.Attached)
			if dest != null:
				issue.call("move_fleets", { "fleets": [f.Name], "destination": dest.Name })

		# Every 5th day: queue a regiment at a world with a training facility.
		if day % 5 == 2:
			var rule = Lq.first_or_null(MilitaryCatalog.All(), func(r) -> bool: return r.Type == "Troop" and MilitaryCatalog.CanBeBuiltBy(r, us))
			var yard: Planet = Lq.first_or_null(ours, func(p: Planet) -> bool: return p.TrainingFacilities() > 0)
			if rule != null and yard != null:
				issue.call("queue_units", { "planet": yard.Name, "rule": rule.Name, "destination": yard.Name, "count": 1 })

		# Every 11th day: a diplomacy mission by an idle character at a world we hold.
		if day % 11 == 3:
			var agent: Character = Lq.first_or_null(GameState.ActiveRoster, func(c: Character) -> bool:
				return c.Faction == us and c.CanTakeOrders() and c.Status == Enums.Status.AwaitingOrders and c.Rank == Enums.Rank.None \
					and OrderManager.SystemOf(c.Attached) != null and MissionManager.TeamCanPerform([c], Enums.MissionType.Diplomacy))
			if agent != null:
				var origin: Planet = OrderManager.SystemOf(agent.Attached)
				var target: Planet = Lq.first_or_null(GameState.AllPlanets(), func(p: Planet) -> bool:
					return p != origin and p.ExploredBy(us) and MissionManager.CanTarget(Enums.MissionType.Diplomacy, us, p).ok)
				if target != null:
					issue.call("launch_mission", { "type": Enums.MissionType.Diplomacy, "team": [agent.Serial], "origin": origin.Name, "target": target.Name, "decoys": [] })

		# Day 4: droid automation on; day 40: off again.
		if day == 4:
			issue.call("droid", { "manage": "production", "on": true })
		if day == 40:
			issue.call("droid", { "manage": "production", "on": false })

		# Every 13th day: say something, and delete the oldest read message.
		if day % 13 == 6:
			issue.call("chat", { "text": "Day %d." % day })
			var vis: Array = EventBus.VisibleMessages()
			if vis.size() > 3:
				issue.call("delete_messages", { "messages": [vis[0].Serial] })

		engine.AdvanceDay()

		# A battle the player is in waits for an answer: answer through the bus.
		var guard := 20
		while FleetBattleManager.HasPendingBattle() and guard > 0:
			guard -= 1
			var r: FleetBattleManager.BattleReport = FleetBattleManager.AwaitingOrders()[0]
			issue.call("battle_answer", { "where": r.Where.Name, "ours": r.Ours.Name, "theirs": r.Theirs.Name, "answer": "simulate" })

		CommandBus.day_done()
		if VictoryManager.IsOver():
			break

	CommandLog.Close()
	print("[command_apply] %d commands issued (%d refused) over %d days: %s" % [tally.issued, tally.refused, StrategicTickManager.Today - 1, JSON.stringify(kinds)])
	print("[command_apply] log: %s (%d hash lines)" % [record, CommandLog.Hashes.size()])
	quit(0)


func _arg(prefix: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
