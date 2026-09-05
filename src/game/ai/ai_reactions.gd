class_name AIReactions
extends RefCounted
## STAGE: REACTIONS — the event loop (docs/ai-framework/01-architecture.md).
## Subscribes to EventBus, filters to messages addressed to our faction, and turns
## them into context writes or interrupts. AR-4 (decided): reactions REPRIORITISE,
## they do not spend — an event may reorder what the next daily pass does; it may
## not consume budget itself. 84 of 180 corpus rules are on-event.
##
## Populated at M4. M0 ships the subscription lifecycle only (so we never leak a
## callback across game restarts) with a no-op handler.

## Queued events since the last daily pass, per faction id -> Array[GameMessage].
static var _queue: Dictionary = {}
static var _handler: Callable = Callable()


## Register our EventBus callback exactly once. Called from AiManager.ProcessDay.
static func Subscribe() -> void:
	if not _handler.is_null():
		return
	_handler = _on_message
	EventBus.OnMessageReceived.append(_handler)


## Remove our callback and clear queues. Called from AiManager.Reset so a new game
## (or a test that resets) does not accumulate duplicate subscriptions.
static func Reset() -> void:
	if not _handler.is_null():
		EventBus.OnMessageReceived.erase(_handler)
		_handler = Callable()
	_queue.clear()


## EventBus sink. Enqueue for the addressed faction; interpretation happens in
## Apply during the owning faction's daily pass (deterministic, no work here). M4
## fills the per-type handling.
static func _on_message(_message: GameMessage) -> void:
	pass


## Fold queued events for `ctx.Us` into the context (interrupts + inferences).
## Reprioritise, never spend (AR-4). M4.
static func Apply(_ctx: AIContext) -> void:
	pass
