extends Control
## THE OPENING BRIEFING (docs/advisor-plan.md, phase 4; manual p022): "C-3PO,
## your faithful advisor, is on the right commencing a briefing ... As C-3PO
## talks, notice the location of key systems that he points out, the key goals
## you need to perform, and the events that you need to guard against. (To
## skip the briefing in the future, press the ESC key or click the left mouse
## button.) After the briefing, the Display Message Index opens up to the
## Agent Advice tab."
##
## The agent droid (IMP-22 for the Empire) speaks each line in its own place,
## its animation and its recording together - the pack's `briefing` for this
## side, the original's own script. A skip ends the line playing and plays the
## skip's instead (the original's script 40 / 73, "I do hope you know what
## you're doing"). A `focus` step - the agent pointing out a system - is not
## drawn: how the original shows it is not known.
##
## Over the whole screen while it plays, so a left click anywhere is a skip.
## Whoever starts it holds the clock and the droids' news until `Finished`.
## Nothing plays without the art set's recordings (exporter 2.6.0).
##
## Added by UIManager.StartBriefing at a new game. Preloaded by path.

const SoundLib := preload("res://src/ui/sound.gd")
const Fwa := preload("res://src/ui/fwa.gd")

## The Command Center's agent droid (command_frame.gd Droid).
var Agent: Node = null
## Called once at the end, finished or skipped.
var Finished := Callable()

var _steps: Array = []
var _at := -1
var _skipped := false
var _over := false
var _token := 0                 # a line's callbacks count only while it is the one playing
var _sound: AudioStreamPlayer = null


## This side's briefing, or {} - the pack's `briefing`.
static func ForSide() -> Dictionary:
	var side: Faction = GameSettings.LocalFaction()
	if side == null or FactionRegistry.Pack == null:
		return {}
	var v: Variant = FactionRegistry.Pack.Manifest.Briefing.get(side.Id, {})
	return v if v is Dictionary else {}


## Whether there is a briefing to play here: a line whose recording is there.
static func CanPlay() -> bool:
	var steps: Variant = ForSide().get("steps", [])
	if not steps is Array:
		return false
	for step in steps:
		if step is Dictionary and not SoundLib.FileOf(str(step.get("sound", ""))).is_empty():
			return true
	return false


func _ready() -> void:
	name = "Briefing"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var steps: Variant = ForSide().get("steps", [])
	_steps = steps if steps is Array else []
	_next()


## The next step, or the end.
func _next() -> void:
	_at += 1
	while _at < _steps.size():
		var step: Variant = _steps[_at]
		if step is Dictionary and (step.has("anim") or step.has("sound")):
			_line(step)
			return
		_at += 1   # a focus: not drawn (the original's is not known)
	_finish()


## One line: the agent's animation and its recording; the next once both end.
func _line(step: Dictionary) -> void:
	_token += 1
	var mine := _token
	var left := [2]
	var one := func() -> void:
		if mine != _token:
			return
		left[0] -= 1
		if left[0] == 0:
			_sound = null
			_next()
	var run: RefCounted = null
	var file := SoundLib.FileOf(str(step.get("anim", "")))
	if not file.is_empty():
		run = Fwa.Open(file)
	if Agent != null and is_instance_valid(Agent) and run != null:
		Agent.Play(run, _frame_seconds(), one)
	else:
		one.call()
	# A recording that is not there ends at once, and the next line may have
	# begun inside this call: keep the player only while this line plays.
	var player := SoundLib.Play(get_tree(), step.get("sound", ""), one)
	if mine == _token:
		_sound = player


func _frame_seconds() -> float:
	var advisor: Variant = FactionRegistry.Pack.Manifest.Advisor if FactionRegistry.Pack != null else {}
	return float(advisor.get("frame_seconds", 0.067)) if advisor is Dictionary else 0.067


## Esc or a left click: the line stops and the skip's plays; during the skip's,
## the briefing ends at once.
func Skip() -> void:
	if _over:
		return
	_token += 1
	if _sound != null and is_instance_valid(_sound):
		_sound.stop()
		_sound.queue_free()
	_sound = null
	if Agent != null and is_instance_valid(Agent):
		Agent.Stop()
	if _skipped:
		_finish()
		return
	_skipped = true
	var skip: Variant = ForSide().get("skip", [])
	_steps = skip if skip is Array else []
	_at = -1
	_next()


func _finish() -> void:
	if _over:
		return
	_over = true
	queue_free()
	if Finished.is_valid():
		Finished.call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Skip()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		Skip()


## For tests: the step playing (-1 before the first), and whether it is the skip's.
func At() -> int:
	return _at


func Skipped() -> bool:
	return _skipped
