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
## you're doing"). A `focus` step - the agent pointing out what his next line
## is about - puts its view on the display (the pack's `views`: a caption and
## the systems lit, or the display off, as recordings of the original show);
## at the end the display is as it was.
##
## Over the whole screen while it plays, on a layer above every other, so a
## left click anywhere is a skip and nothing else can be done: no window,
## console, pause or shortcut until it ends (it takes every key too).
## Whoever starts it holds the clock and the droids' news until `Finished`.
## Nothing plays without the art set's recordings (exporter 2.6.0).
##
## Added by UIManager.StartBriefing at a new game. Preloaded by path.

const SoundLib := preload("res://src/ui/sound.gd")
const Fwa := preload("res://src/ui/fwa.gd")

## The Command Center's agent droid (command_frame.gd Droid).
var Agent: Node = null
## The galaxy map (galaxy_map.gd), for the views.
var Map: Node = null
## Called once at the end, finished or skipped.
var Finished := Callable()

var _steps: Array = []
var _at := -1
var _skipped := false
var _over := false
var _token := 0                 # a line's callbacks count only while it is the one playing
var _sound: AudioStreamPlayer = null
var _mode_before: RefCounted = null   # the display's mode when the briefing began


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
	_mode_before = Gid.ActiveMode() if Map != null else null
	_next()


## The next step, or the end.
func _next() -> void:
	_at += 1
	while _at < _steps.size():
		var step: Variant = _steps[_at]
		if step is Dictionary and (step.has("anim") or step.has("sound")):
			_line(step)
			return
		if step is Dictionary and step.has("focus"):
			_focus(int(step["focus"]))
		_at += 1
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


## A focus step: its view on the display; a number the pack gives no view
## leaves the display as it is.
func _focus(n: int) -> void:
	if Map == null or not is_instance_valid(Map):
		return
	var views: Variant = ForSide().get("views", {})
	var v: Variant = views.get(str(n)) if views is Dictionary else null
	if not v is Dictionary:
		return
	var show := str(v.get("show", ""))
	if show == "off":
		Map.ShowView("", {}, true)
	elif show.begins_with("mode:"):
		Map.ClearView()
		Map.SetMode(GalaxyMap.FindMode(show.substr(5)))
	else:
		Map.ShowView(str(v.get("caption", "")), Lit(show), false)


## The systems a view lights, each with the side whose star it wears.
static func Lit(show: String) -> Dictionary:
	var me: Faction = GameSettings.LocalFaction()
	var kind := show.get_slice(":", 0)
	var id := show.get_slice(":", 1)
	var lit := {}
	var at: Planet = null
	if kind == "character":
		var c: Character = Lq.first_or_null(GameState.ActiveRoster, func(x: Character) -> bool: return x.PackId == id)
		at = OrderManager.SystemOf(c.Attached) if c != null else null
	for p: Planet in GameState.AllPlanets():
		var owner: Faction = IntelManager.OwnerSeen(me, p) if p.IsExplored else null
		var side: String = owner.ArtSkin if owner != null else "neutral"
		var on := false
		match kind:
			"loyal": on = owner != null and owner.Id == id
			"military": on = owner != null and p.ControllingFaction == owner and p.GarrisonRequirement() > 0
			"unexplored": on = not p.IsExplored
			"defenses": on = p.IsExplored and _defended(p)
			"system": on = p.PackId == id
			"hq": on = p.HasHeadquarters() and p.ControllingFaction != null and p.ControllingFaction.Id == id
			"character": on = p == at
		if on:
			lit[p] = side
	return lit


## Any defenses the player knows of here: batteries, shields, squadrons,
## regiments (the display's own Defense modes).
static func _defended(p: Planet) -> bool:
	for id in ["defense_batteries", "shield_generators", "fighter_squadrons", "trooper_regiments"]:
		var m: Gid.GidMode = Gid.ModeById(id)
		if m != null and float(m.Magnitude.call(p)) > 0.0:
			return true
	return false


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
	if Map != null and is_instance_valid(Map):
		Map.ClearView()
		if _mode_before != null and Gid.ActiveMode() != _mode_before:
			Map.SetMode(_mode_before)
	queue_free()
	if Finished.is_valid():
		Finished.call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Skip()


## Every key is the briefing's while it plays: Esc skips, and nothing else
## reaches the game - no pause, no speed, no window's shortcut (TeeJ,
## 2026-09-27). The mouse is kept by the briefing lying over everything.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Skip()


## For tests: the step playing (-1 before the first), and whether it is the skip's.
func At() -> int:
	return _at


func Skipped() -> bool:
	return _skipped
