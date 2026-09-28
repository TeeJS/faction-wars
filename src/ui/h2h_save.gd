class_name H2hSave
extends RefCounted
## THE HOST'S SAVE IN A HEAD-TO-HEAD GAME, as a Game Options screen shows it
## (manual p163: "only the host player can save the game. Star Wars Rebellion
## will create a saved game on both computers in the same saved game slots").
## This computer writes the game at once (LockstepSession.save_game); the
## guest's writes it when the save line reaches it and answers. The message
## says what actually happened (issue #301: the old one said "saved on both
## computers" and nothing was written anywhere).
##
## begin() starts one; poll() every frame returns "" until there is something
## to tell the player, then the message once.

## How long the guest's computer has to answer before the host is told the save
## is on this computer only. A save line crosses in a round trip (well under a
## second on the relay); the rest is room for a slow connection.
const AnswerSeconds := 10.0

var _session: LockstepSession = null
var _id: String = ""
var _name: String = ""
var _day: int = 0
var _since_ms: int = 0
var _said: String = ""


func begin(session: LockstepSession, name: String) -> void:
	_session = session
	_name = name
	_day = StrategicTickManager.Today
	_id = session.save_game(name)
	_since_ms = Time.get_ticks_msec()
	if _id.is_empty():
		_said = "Not saved: this computer could not write \"%s\"." % name
		_session = null


## Waiting for the guest's answer?
func waiting() -> bool:
	return _session != null


func poll() -> String:
	if not _said.is_empty():
		var s := _said
		_said = ""
		return s
	if _session == null:
		return ""
	var where := "\"%s\", Day %d" % [_name, StrategicTickManager.Shown(_day)]
	if _session.saves_answered.has(_id):
		var ok: bool = _session.saves_answered[_id]
		_session = null
		if ok:
			return "Saved on both computers: %s." % where
		return "Saved on this computer only: %s. Your opponent's computer could not write it." % where
	if Time.get_ticks_msec() - _since_ms > int(AnswerSeconds * 1000.0):
		_session = null
		return "Saved on this computer only: %s. Your opponent's computer did not answer." % where
	return ""
