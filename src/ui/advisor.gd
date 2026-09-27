extends Node
## THE DROIDS SPEAK (docs/advisor-plan.md, phase 2). The message droid (R2-D2 /
## SD-7) "announces every event"; the agent (C-3PO / IMP-22) "translates the
## message droid" (manual; GAMEPLAY.md, the droids' roles) - aloud, while
## Translate Counterpart is on. What each says for which news is the pack's
## `advisor` (Rebellion 2's map of the original's own animations and
## recordings - its information, our code), per side: an event, how many days
## it may wait, the message droid's animation and sound, the agent's
## animation and line (`translated`: only with Translate Counterpart).
##
## News tags itself (GameMessage.Advisor / Voice, set where the simulation
## writes it). An event waits up to its days; the droids take the waiting one
## the pack lists first, one at a time, and an event does not play again
## within `repeat_days`. A character's own line (the pack's `voices`) follows.
## Nothing plays without the art set's sounds and animations (exporter 2.6.0).
##
## THE AGENT'S ANSWERS (phase 3): an order the agent turns down, or one of his
## own toggles, he answers at once in his own words - the pack's
## "answer_<code>" (Result.code, where the engine refuses; the agent's menu).
## An answer stops the news playing: that news is in the Message Index.
##
## Added by UIManager beside the Command Center's droids.

const SoundLib := preload("res://src/ui/sound.gd")
const Fwa := preload("res://src/ui/fwa.gd")

## The events that take a character: the pack's "<prefix>.<character id>".
const CHARACTER_EVENTS := {"personnel_report": "report", "captured": "captured", "released": "released"}

var Agent: Node = null       # the Command Center's droids (command_frame.gd Droid)
var Messenger: Node = null
## While true the droids keep their news for later (the opening briefing).
var Held: bool = false

var _pending: Dictionary = {}   # event -> the last day it may still play
var _allowed: Dictionary = {}   # event -> the first day it may play again
var _voices: Array = []         # character lines waiting, each a reference or a pool
var _busy: bool = false
var _waiting: int = 0           # parts of the playing step not yet done
var _token: int = 0             # a part's callbacks count only while its step plays
var _players: Array = []        # the sounds of the step playing
var _answering: String = ""     # the answer playing, if one is


func _ready() -> void:
	name = "Advisor"
	EventBus.OnMessageReceived.append(_on_message)


func _exit_tree() -> void:
	EventBus.OnMessageReceived.erase(_on_message)


## The pack's `advisor`.
static func Config() -> Dictionary:
	return FactionRegistry.Pack.Manifest.Advisor if FactionRegistry.Pack != null else {}


## This client's side's events, in the pack's order.
static func Events() -> Dictionary:
	var side: Faction = GameSettings.LocalFaction()
	var v: Variant = Config().get(side.Id, {}) if side != null else {}
	return v if v is Dictionary else {}


## The event a message's tag names for this side, or "": a character's own
## ("report.luke_skywalker") where the pack has one, else the event itself.
static func Resolve(advisor: String, character: Character) -> String:
	if advisor.is_empty():
		return ""
	var events := Events()
	if CHARACTER_EVENTS.has(advisor) and character != null and not character.PackId.is_empty():
		var own := "%s.%s" % [CHARACTER_EVENTS[advisor], character.PackId]
		if events.has(own):
			return own
	return advisor if events.has(advisor) else ""


## A character's line for a message, or null: the pack's `voices`.
static func VoiceFor(character: Character, line: String) -> Variant:
	if character == null or line.is_empty() or FactionRegistry.Pack == null:
		return null
	var lines: Variant = FactionRegistry.Pack.Manifest.Voices.get(character.PackId, {})
	return lines.get(line) if lines is Dictionary else null


func _on_message(msg: GameMessage) -> void:
	if msg == null or not EventBus.Visible(msg):
		return
	var event := Resolve(msg.Advisor, msg.AssociatedCharacter)
	if not event.is_empty():
		var days: int = int((Events()[event] as Dictionary).get("days", 10))
		_pending[event] = StrategicTickManager.Today + maxi(0, days)
	var line: Variant = VoiceFor(msg.AssociatedCharacter, msg.Voice)
	if line != null:
		_voices.append(line)


## The waiting event to say next, or "" (and the expired ones forgotten).
func _next_event(today: int) -> String:
	for event in _pending.keys():
		if int(_pending[event]) < today:
			_pending.erase(event)
	for event in Events():
		if _pending.has(event) and int(_allowed.get(event, -1)) <= today:
			return event
	return ""


func _process(_delta: float) -> void:
	if _busy or Held or FactionRegistry.Pack == null:
		return
	var today: int = StrategicTickManager.Today
	var event := _next_event(today)
	if not event.is_empty():
		_pending.erase(event)
		_allowed[event] = today + int(Config().get("repeat_days", 60))
		_say(Events()[event])
	elif not _voices.is_empty():
		_busy = true
		_token += 1
		var mine := _token
		var player := SoundLib.Play(get_tree(), _voices.pop_front(), func() -> void:
			if mine == _token:
				_busy = false)
		if player != null and mine == _token:
			_players.append(player)


## One event: the message droid, then the agent (when it speaks).
func _say(entry: Dictionary) -> void:
	_busy = true
	_token += 1
	var mine := _token
	var agent: Variant = entry.get("agent")
	var speaks: bool = agent is Dictionary and (not bool(agent.get("translated", false)) or SoundLib.TranslateCounterpart)
	_part(Messenger, entry.get("messenger"), mine, func() -> void:
		if speaks:
			_part(Agent, agent, mine, func() -> void: _busy = false)
		else:
			_busy = false)


## The agent answers at once ("answer_<code>" for this side), stopping the
## news playing; the same answer already playing is not begun again.
func Answer(code: String) -> void:
	var event := "answer_" + code
	var events := Events()
	if code.is_empty() or not events.has(event) or _answering == event or FactionRegistry.Pack == null:
		return
	_interrupt()
	_busy = true
	_answering = event
	var mine := _token
	_part(Agent, (events[event] as Dictionary).get("agent"), mine, func() -> void:
		_answering = ""
		_busy = false)


## What is playing stops, its callbacks void.
func _interrupt() -> void:
	_token += 1
	for p in _players:
		if is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
			(p as Node).queue_free()
	_players.clear()
	for d in [Agent, Messenger]:
		if d != null and is_instance_valid(d) and d.has_method("Stop"):
			d.Stop()
	_answering = ""
	_busy = false


## The advisor on `tree`'s Command Center answers `code` (see Answer).
static func AnswerOn(tree: SceneTree, code: String) -> void:
	if tree == null or code.is_empty():
		return
	var a: Node = tree.root.find_child("Advisor", true, false)
	if a != null and a.has_method("Answer"):
		a.Answer(code)


## A droid's animation and sound together; `done` once both have ended, if
## the step `mine` is still the one playing.
func _part(droid: Node, part: Variant, mine: int, done: Callable) -> void:
	if not part is Dictionary:
		done.call()
		return
	var left := [2]
	var one := func() -> void:
		if mine != _token:
			return
		left[0] -= 1
		if left[0] == 0:
			done.call()
	var run: RefCounted = null
	var file := SoundLib.FileOf(str(part.get("anim", "")))
	if not file.is_empty():
		run = Fwa.Open(file)
	if droid != null and is_instance_valid(droid) and run != null:
		droid.Play(run, float(Config().get("frame_seconds", 0.067)), one)
	else:
		one.call()
	var player := SoundLib.Play(get_tree(), part.get("sound", ""), one)
	if player != null and mine == _token:
		_players = _players.filter(func(p: Variant) -> bool: return is_instance_valid(p))
		_players.append(player)


## An order given: the first of `group` with a voice acknowledges it (its
## `order` line), at once. `group` may hold units too.
static func SayOrder(tree: SceneTree, group: Array) -> void:
	for c in group:
		if c is Character:
			var line: Variant = VoiceFor(c, "order")
			if line != null:
				SoundLib.Play(tree, line)
				return


## For tests: what waits.
func Pending() -> Dictionary:
	return _pending


func Busy() -> bool:
	return _busy
