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
## M2: the lockstep session, when this client is in a head-to-head game. It
## owns the day a command belongs to and the wire.
static var Session: LockstepSession = null


static func Reset() -> void:
	Immediate = true
	_seq.clear()
	Pending.clear()
	Session = null
	CommandLog.Reset()


## Issue an order from the local side. Returns the applier's Result when
## applied immediately; a queued command returns success (it is accepted).
static func issue(kind: String, args: Dictionary) -> Result:
	var c := Command.make(kind, args)
	if Session != null:
		Session.issue(c)   # assigns Day, Seq and Faction; logs; sends
		return Result.success()
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


## THE one canonical order (live phases and replays alike): by phase, then
## retreat answers first ("until one side withdraws", manual p152), then
## faction order, then Seq. A live phase batch has one phase; a replayed day
## has all of that day's phases, and sorting by phase first reproduces the
## live application phase by phase.
static func apply_batch(label: String, commands: Array) -> void:
	var ordered: Array = Lq.order_by(commands, func(c: Command) -> Array:
		var retreat: int = 0 if (c.Kind == "battle_answer" and str(c.Args.get("answer", "")) == "retreat") else 1
		return [c.Phase, retreat] + Command.sort_key(c))
	for c in ordered:
		var r: Result = CommandApplier.apply(c)
		if not r.ok:
			print("[Command] %s %s %s refused: %s" % [label, c.Faction, c.Kind, r.error])


## Apply everything of a day (replay / the M1 single-player queue).
static func apply_day(day: int, commands: Array) -> void:
	apply_batch("day %d" % day, commands)


## The tick calls this after each AdvanceDay so the log carries the day hash.
static func day_done() -> void:
	CommandLog.DayDone(StrategicTickManager.Today, GameSignature.ReplayHash(GameState.ActiveGalaxy))
