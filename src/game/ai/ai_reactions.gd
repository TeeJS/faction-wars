class_name AIReactions
extends RefCounted
## STAGE: REACTIONS — the event loop (docs/ai-framework/01-architecture.md).
## Subscribes to EventBus, filters to messages addressed to a driven faction, and
## turns them into context writes: URGENCIES (situational interrupts) and fog-legal
## INFERENCES. AR-4 (decided): reactions REPRIORITISE, they do not spend — an event
## reorders what the next daily pass does; it never consumes budget itself.
##
## 84 of 180 corpus rules are on-event. The interrupt set is small and justified
## (AR-2): an uprising on OUR world is "handle immediately" (RULE-06-09); a garrison
## warning is the sabotage->uprising chain forming (RULE-09-02); an uprising on THEIR
## world is an attack window (RULE-06-12). Battle reports and control flips are
## fog-legal inferences (RULE-09-03, RULE-10-04), not interrupts.
##
## DETERMINISM (A2): the queue drains in Serial order (GameMessage.Serial is a
## deterministic per-game counter), so replay is stable. All magnitudes are OURS.

const U_DEFEND_OWN := 600     # OURS: subdue our own uprising / answer a garrison warning
const U_ENEMY_WINDOW := 150   # OURS: an enemy uprising is an opening

# Only these kinds are worth queuing (bounds memory on long games).
const _INTERESTING := [
	Enums.MessageType.Uprising, Enums.MessageType.GarrisonWarning,
	Enums.MessageType.TacticalAfterActionReport, Enums.MessageType.SystemControl,
	Enums.MessageType.Blockade, Enums.MessageType.CharacterCaptured,
]

static var _queue: Dictionary = {}   # faction id -> Array[GameMessage]
static var _handler: Callable = Callable()


## Register our EventBus callback exactly once. Called from AiManager.ProcessDay.
static func Subscribe() -> void:
	if not _handler.is_null():
		return
	_handler = _on_message
	EventBus.OnMessageReceived.append(_handler)


## Remove our callback and clear queues (new game / test reset) so we never
## accumulate duplicate subscriptions or stale events.
static func Reset() -> void:
	if not _handler.is_null():
		EventBus.OnMessageReceived.erase(_handler)
		_handler = Callable()
	_queue.clear()


## EventBus sink. Enqueue interesting, addressed events for a DRIVEN faction only
## (a human faction's queue would never drain). No interpretation here — Apply does
## that during the owning faction's pass, deterministically.
static func _on_message(msg: GameMessage) -> void:
	if msg == null or msg.For == null or msg.Type == Enums.MessageType.None:
		return
	if not _INTERESTING.has(msg.Type):
		return
	if GameSettings.IsHuman(msg.For) and not AiManager.DriveAllFactions:
		return
	var id: String = msg.For.Id
	if not _queue.has(id):
		_queue[id] = []
	_queue[id].append(msg)


## Fold queued events for ctx.Us into the context: interrupts (urgencies) and
## fog-legal inferences. Reprioritise, never spend (AR-4). Drains our queue.
static func Apply(ctx: AIContext) -> void:
	ctx.Interrupts = []
	var q: Array = _queue.get(ctx.Us.Id, [])
	if q.is_empty():
		return
	q.sort_custom(func(a, b): return a.Serial < b.Serial)   # deterministic order (A2)
	for msg in q:
		var where := msg.AssociatedLocation as Planet if msg.AssociatedLocation is Planet else null
		match msg.Type:
			Enums.MessageType.Uprising:
				if where != null and where.ControllingFaction == ctx.Us:
					ctx.Interrupts.append({"kind": "defend_own", "planet": where})   # RULE-06-09
				elif where != null:
					ctx.Interrupts.append({"kind": "enemy_window", "planet": where}) # RULE-06-12
			Enums.MessageType.GarrisonWarning:
				if where != null and where.ControllingFaction == ctx.Us:
					ctx.Interrupts.append({"kind": "defend_own", "planet": where})   # RULE-09-02
			Enums.MessageType.TacticalAfterActionReport:
				# Fog-legal inference: a battle we were in tells us the enemy garrison's
				# size without a mission (RULE-09-03). Recorded, not an interrupt.
				if where != null:
					ctx.Inferences[where] = "battle-observed"
			Enums.MessageType.SystemControl:
				# A flip is evidence a diplomat is at work there (RULE-10-04).
				if where != null:
					ctx.Inferences[where] = "control-flip"
			_:
				pass
	_queue[ctx.Us.Id] = []


## Total urgency (fixed-point, OURS) that queued interrupts add to a candidate
## acting on `planet`. Read by Action Selection; this is how a reaction reprioritises
## the day's plan without spending budget.
static func urgency_for(ctx: AIContext, kind: String, planet: Planet) -> int:
	if planet == null:
		return 0
	var total := 0
	for it in ctx.Interrupts:
		if it["planet"] != planet:
			continue
		match kind:
			"defend_own":
				if it["kind"] == "defend_own":
					total += U_DEFEND_OWN
			"enemy_window":
				if it["kind"] == "enemy_window":
					total += U_ENEMY_WINDOW
	return total
