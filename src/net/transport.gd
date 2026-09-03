class_name Transport
extends RefCounted
## The wire between two lockstep clients (docs/m2-plan.md section 1): send a
## line, poll for lines. M2 ships the mailbox (files); M3 the WebSocket relay.


func send(_msg: Dictionary) -> void:
	pass


## Every message that has arrived since the last poll, in order.
func poll() -> Array:
	return []


func close() -> void:
	pass
