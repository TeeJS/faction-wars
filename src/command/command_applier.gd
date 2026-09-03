class_name CommandApplier
extends RefCounted
## Turns a Command back into the backend call the UI used to make directly
## (docs/m1-plan.md section 2). Every kind returns a Result so the refusal
## dialogs keep working; a kind that cannot resolve its ids fails softly - on a
## replay or the other client that means the log and the world disagree, which
## the day hash will then report.

const Kinds := [
	"move_fleets", "move_units", "move_characters", "board_fleet", "load_aboard",
	"unload", "unload_units", "disembark", "run_blockade",
	"queue_facility", "queue_units", "cancel_build", "scrap_facility", "scrap_unit",
	"retire", "take_command", "launch_mission", "abort_mission",
	"bombard", "assault", "battle_answer", "droid", "delete_messages",
	"chat", "set_speed", "pause", "resume",
]


static func apply(c: Command) -> Result:
	var a: Dictionary = c.Args
	var day: int = StrategicTickManager.Today
	match c.Kind:
		"move_fleets":
			return OrderManager.MoveFleets(EntityIndex.fleets(a.get("fleets", [])), EntityIndex.planet(str(a.get("destination", ""))))
		"move_units":
			return OrderManager.MoveUnits(EntityIndex.units(a.get("units", [])), EntityIndex.planet(str(a.get("destination", ""))))
		"move_characters":
			return OrderManager.MoveCharacters(EntityIndex.characters(a.get("characters", [])), EntityIndex.planet(str(a.get("destination", ""))))
		"board_fleet":
			return OrderManager.BoardFleet(EntityIndex.characters(a.get("characters", [])), EntityIndex.fleet(str(a.get("fleet", ""))))
		"load_aboard":
			return OrderManager.LoadAboard(EntityIndex.units(a.get("units", [])), EntityIndex.fleet(str(a.get("fleet", ""))))
		"unload":
			return OrderManager.Unload(EntityIndex.fleet(str(a.get("fleet", ""))))
		"unload_units":
			return OrderManager.UnloadUnits(EntityIndex.units(a.get("units", [])))
		"disembark":
			return OrderManager.Disembark(EntityIndex.characters(a.get("characters", [])))
		"run_blockade":
			# The evacuation the player confirmed: roll the losses, move the survivors.
			var units: Array = EntityIndex.units(a.get("units", []))
			var from: Planet = EntityIndex.planet(str(a.get("from", "")))
			var to: Planet = EntityIndex.planet(str(a.get("destination", "")))
			if from == null or to == null:
				return Result.fail("Unknown world.")
			var survivors: Array = OrderManager.RunBlockade(units, from, Prng.Session)
			var r: Result = OrderManager.MoveUnits(survivors, to) if not survivors.is_empty() else Result.success(0)
			EventBus.BroadcastChanged()
			return r
		"queue_facility":
			var p: Planet = EntityIndex.planet(str(a.get("planet", "")))
			if p == null:
				return Result.fail("Unknown world.")
			return p.TryQueueMany(int(a.get("type", 0)), int(a.get("tier", 1)), EntityIndex.planet(str(a.get("destination", ""))), int(a.get("count", 1)))
		"queue_units":
			var p: Planet = EntityIndex.planet(str(a.get("planet", "")))
			var rule: CatalogDtos.UnitStatRule = Lq.first_or_null(MilitaryCatalog.All(), func(r) -> bool: return r.Name == str(a.get("rule", "")))
			if p == null or rule == null:
				return Result.fail("Unknown world or unit type.")
			return p.TryQueueManyUnits(rule, EntityIndex.planet(str(a.get("destination", ""))), int(a.get("count", 1)))
		"cancel_build":
			var p: Planet = EntityIndex.planet(str(a.get("planet", "")))
			if p == null:
				return Result.fail("Unknown world.")
			p.CancelCurrentBuild(int(a.get("producer", 0)))
			return Result.success()
		"scrap_facility":
			var f: Facility = EntityIndex.facility(int(a.get("facility", 0)))
			if f == null or f.Attached == null:
				return Result.fail("Unknown facility.")
			return Result.success(f.Attached.ScrapFacility(f))
		"scrap_unit":
			var u: Unit = EntityIndex.unit(int(a.get("unit", 0)))
			var p: Planet = OrderManager.SystemOf(u.Attached) if u != null else null
			if u == null or p == null:
				return Result.fail("Unknown unit.")
			return Result.success(p.ScrapUnit(u))
		"retire":
			# The Retire block of DraggableWindow, verbatim.
			for ch in EntityIndex.characters(a.get("characters", [])):
				ch.Commanding = null
				GameState.ActiveRoster.erase(ch)
				print("[Personnel] %s has been retired." % ch.Name)
			EventBus.BroadcastChanged()
			return Result.success()
		"take_command":
			var ch: Character = EntityIndex.character(str(a.get("character", "")))
			if ch == null:
				return Result.fail("Unknown character.")
			var r: Result = ch.TryTakeCommand(int(a.get("rank", 0)))
			EventBus.BroadcastChanged()
			return r
		"launch_mission":
			var team: Array = EntityIndex.units(a.get("team", []))
			var decoys: Array = EntityIndex.units(a.get("decoys", []))
			var origin: Planet = EntityIndex.planet(str(a.get("origin", "")))
			var target: Planet = EntityIndex.planet(str(a.get("target", "")))
			if team.is_empty() or origin == null or target == null:
				return Result.fail("Unknown team or world.")
			MissionManager.Launch(int(a.get("type", 0)), team, origin, target, decoys,
				EntityIndex.character(str(a.get("victim", ""))), EntityIndex.target_object(a))
			return Result.success()
		"abort_mission":
			var m: Mission = EntityIndex.mission(int(a.get("mission", 0)))
			if m == null:
				return Result.fail("No such mission.")
			MissionManager.Abort(m)
			return Result.success()
		"bombard":
			var fleet: Fleet = EntityIndex.fleet(str(a.get("fleet", "")))
			var target: Planet = EntityIndex.planet(str(a.get("planet", "")))
			if fleet == null or target == null:
				return Result.fail("Unknown fleet or world.")
			BombardmentManager.Bombard(fleet, target, int(a.get("mode", 0)), Prng.Session, day)
			return Result.success()
		"assault":
			var fleet: Fleet = EntityIndex.fleet(str(a.get("fleet", "")))
			var target: Planet = EntityIndex.planet(str(a.get("planet", "")))
			if fleet == null or target == null:
				return Result.fail("Unknown fleet or world.")
			AssaultManager.Resolve(fleet, target, Prng.Session, day)
			return Result.success()
		"battle_answer":
			var r: FleetBattleManager.BattleReport = EntityIndex.battle(str(a.get("where", "")), str(a.get("ours", "")), str(a.get("theirs", "")))
			if r == null:
				return Result.fail("No such battle is waiting.")
			if str(a.get("answer", "")) == "retreat":
				return FleetBattleManager.Retreat(r, day, FactionRegistry.ById(c.Faction))
			FleetBattleManager.SimulateResults(r, day)
			return Result.success()
		"droid":
			var f: Faction = FactionRegistry.ById(c.Faction)
			if f == null:
				return Result.fail("Unknown side.")
			if str(a.get("manage", "")) == "garrisons":
				AgentDroid.SetManageGarrisons(f, bool(a.get("on", false)))
			else:
				AgentDroid.SetManageProduction(f, bool(a.get("on", false)))
			return Result.success()
		"delete_messages":
			for m in EntityIndex.messages(a.get("messages", [])):
				EventBus.DeleteMessage(m)
			return Result.success()
		"chat":
			# "processed through SD-7 or R2-D2's messaging system" (manual p162):
			# a message in the Chat category, addressed to the OTHER human side.
			var sender: Faction = FactionRegistry.ById(c.Faction)
			for h in GameSettings.HumanFactions:
				if h == sender:
					continue
				var msg := GameMessage.new("Message from %s" % (sender.DisplayName if sender != null else "the other side"),
					str(a.get("text", "")), Enums.MessageCategory.Chat, day)
				EventBus.Tell(h, msg)
			return Result.success()
		"set_speed", "pause", "resume":
			# Applied by the clock (GameManager in single player; M2's lockstep clock
			# in head-to-head). The applier only records that it was issued.
			return Result.success()
		_:
			return Result.fail("Unknown command kind '%s'." % c.Kind)
