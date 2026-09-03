class_name CommandBus
extends RefCounted
## Where the UI hands in an order (docs/m1-plan.md section 3). Single player:
## the command is logged and applied on the same frame, so nothing the player
## sees changes. Head-to-head (M2): logged, sent, and applied at the next tick
## with the opponent's batch.

static var Immediate: bool = true
static var _seq: Dictionary = {}       # faction id -> next Seq
## M2: commands waiting for their tick, by day.
static var Pending: Dictionary = {}    # day -> Array[Command]


static func Reset() -> void:
	Immediate = true
	_seq.clear()
	Pending.clear()
	CommandLog.Reset()


## Issue an order from the local side. Returns the applier's Result when
## applied immediately; a queued command returns success (it is accepted).
static func issue(kind: String, args: Dictionary) -> Result:
	var c := Command.make(kind, args)
	c.Day = StrategicTickManager.Today
	c.Faction = GameSettings.PlayerFaction.Id if GameSettings.PlayerFaction != null else ""
	c.Seq = int(_seq.get(c.Faction, 0)) + 1
	_seq[c.Faction] = c.Seq
	CommandLog.Append(c)
	if Immediate:
		return CommandApplier.apply(c)
	if not Pending.has(c.Day):
		Pending[c.Day] = []
	Pending[c.Day].append(c)
	return Result.success()


## Apply everything queued for a day, in faction order then Seq (M2 / replay).
static func apply_day(day: int, commands: Array) -> void:
	var ordered: Array = Lq.order_by(commands, func(c: Command) -> Array: return Command.sort_key(c))
	for c in ordered:
		var r: Result = CommandApplier.apply(c)
		if not r.ok:
			print("[Command] day %d %s %s refused: %s" % [day, c.Faction, c.Kind, r.error])


## The tick calls this after each AdvanceDay so the log carries the day hash.
static func day_done() -> void:
	CommandLog.DayDone(StrategicTickManager.Today, GameSignature.ReplayHash(GameState.ActiveGalaxy))
